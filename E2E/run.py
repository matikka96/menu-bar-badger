#!/usr/bin/env python3
"""The e2e smoke scenarios of docs/spec/testing.md.

Run it with `make e2e`, or with `python3 -I E2E/run.py [run [NAME ...] | list | build]`. It needs a real Mac
session, the Accessibility permission for the terminal and for MenuBarBadger Dev, and it takes the keyboard
focus.
"""

import fcntl
import hashlib
import json
import os
import plistlib
import shutil
import signal
import subprocess
import sys
import time
from contextlib import contextmanager, suppress
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "build/Build/Products/Debug/MenuBarBadger Dev.app"
APP_BINARY = APP / "Contents/MacOS/MenuBarBadger Dev"
APP_BUNDLE_ID = "com.matikka96.MenuBarBadger.dev"
WORK = ROOT / "build/e2e"
DRIVER = WORK / "driver"
RUN = WORK / "run"
# In a folder of its own: the config watch waits for a quiet folder, and the state file changes each 0.25 s.
CONFIG_FILE = RUN / "config/config.json"
STATE_FILE = RUN / "state.json"
LOGS = RUN / "logs"

USER_CONFIG = Path.home() / ".MenuBarBadger/config.json"
RELEASE_APP = Path("/Applications/MenuBarBadger.app")
RELEASE_BUNDLE_ID = "com.matikka96.MenuBarBadger"

POLL = 0.1
TIMEOUT = 8.0
SETTLE = 1.0
FULL_SCREEN_SETTLE = 1.5
HAND_EDIT_LIMIT = 1.0
POSITION_TOLERANCE = 1.0
# About 5 s at the key interval of the driver, so the keys flow before, during and after the alert shows.
KEYS_ACROSS_ALERT = "abcdefghijklmnopqrstuvwxyz" * 6
TEXT_WINDOW_SIZE = (480, 160)


class CheckFailed(Exception):
    pass


class EnvironmentProblem(Exception):
    pass


@dataclass(frozen=True)
class Fixture:
    key: str
    bundle_id: str
    bundle_name: str
    dock_title: str
    is_agent: bool = False
    has_text_window: bool = False

    @property
    def app(self) -> Path:
        return WORK / "fixtures" / f"{self.dock_title}.app"

    @property
    def control_file(self) -> Path:
        return RUN / f"{self.key}.badge"

    @property
    def report_file(self) -> Path:
        return RUN / f"{self.key}.report.json"

    @property
    def autosave_name(self) -> str:
        return f"MenuBarBadger.{self.bundle_id}"

    @property
    def position_keys(self) -> list[str]:
        return [
            f"NSStatusItem Preferred Position {self.autosave_name}",
            f"NSStatusItem Visible {self.autosave_name}",
            f"NSStatusItem VisibleCC {self.autosave_name}",
            f"MBB.position.{self.bundle_id}",
        ]


A = Fixture("a", "com.matikka96.MenuBarBadger.fixture.a", "MBBFixtureA", "MBBFixtureA")
# As Microsoft Outlook: the Dock shows the display name, and the bundle name differs.
B = Fixture("b", "com.matikka96.MenuBarBadger.fixture.b", "MBBFixtureB", "MBB Fixture Display")
D = Fixture("d", "com.matikka96.MenuBarBadger.fixture.d", "MBBFixtureD", "MBBFixtureD", is_agent=True)
TEXT = Fixture("text", "com.matikka96.MenuBarBadger.fixture.text", "MBBFixtureText", "MBBFixtureText",
               has_text_window=True)
FIXTURES = [A, B, D, TEXT]


# Quartz coordinates: the origin at the top left of the main display, and y down.
@dataclass(frozen=True)
class Rect:
    x: float
    y: float
    width: float
    height: float

    @classmethod
    def of(cls, frame: dict) -> "Rect":
        return cls(frame["x"], frame["y"], frame["width"], frame["height"])

    @property
    def max_x(self) -> float:
        return self.x + self.width

    @property
    def max_y(self) -> float:
        return self.y + self.height

    @property
    def center(self) -> tuple[float, float]:
        return self.x + self.width / 2, self.y + self.height / 2

    def contains(self, point) -> bool:
        return self.x <= point[0] <= self.max_x and self.y <= point[1] <= self.max_y


def run(command, **kwargs):
    return subprocess.run(command, check=True, **kwargs)


def wait_until(condition, what: str, timeout=TIMEOUT, describe=lambda: ""):
    deadline = time.monotonic() + timeout
    while True:
        result = condition()
        if result:
            return result
        if time.monotonic() > deadline:
            detail = describe()
            raise CheckFailed(f"{what} (after {timeout:.1f} s)" + (f". {detail}" if detail else ""))
        time.sleep(POLL)


@contextmanager
def as_environment_problem():
    try:
        yield
    except CheckFailed as error:
        raise EnvironmentProblem(str(error))


# Build

def build():
    if not APP_BINARY.is_file():
        sys.exit(f"{APP} does not exist. Run: make build")
    WORK.mkdir(parents=True, exist_ok=True)
    run(["swiftc", "-O", "-o", str(DRIVER), str(ROOT / "E2E/Driver/Driver.swift")])
    fixture_binary = WORK / "fixture"
    run(["swiftc", "-O", "-o", str(fixture_binary), str(ROOT / "E2E/Fixtures/Fixture.swift")])
    for fixture in FIXTURES:
        build_fixture(fixture, fixture_binary)


def build_fixture(fixture: Fixture, binary: Path):
    shutil.rmtree(fixture.app, ignore_errors=True)
    contents = fixture.app / "Contents"
    (contents / "MacOS").mkdir(parents=True)
    shutil.copy(binary, contents / "MacOS" / fixture.bundle_name)
    info = {
        "CFBundleIdentifier": fixture.bundle_id,
        "CFBundleName": fixture.bundle_name,
        "CFBundleDisplayName": fixture.dock_title,
        "CFBundleExecutable": fixture.bundle_name,
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": "1.0",
        "CFBundleVersion": "1",
        "LSMinimumSystemVersion": "26.0",
        "NSPrincipalClass": "NSApplication",
        "MBBFixtureControlFile": str(fixture.control_file),
    }
    if fixture.is_agent:
        info["LSUIElement"] = True
    if fixture.has_text_window:
        info["MBBFixtureReportFile"] = str(fixture.report_file)
    with open(contents / "Info.plist", "wb") as file:
        plistlib.dump(info, file)
    run(["codesign", "--force", "--sign", "-", str(fixture.app)], stderr=subprocess.DEVNULL)


# The system

def driver(*args):
    result = subprocess.run([str(DRIVER), *map(str, args)], capture_output=True, text=True)
    try:
        output = json.loads(result.stdout)
    except json.JSONDecodeError:
        raise EnvironmentProblem(f"the driver printed no JSON: {result.stdout}{result.stderr}")
    if result.returncode != 0:
        raise EnvironmentProblem(f"driver {args[0]}: {output.get('error')}")
    return output


def dock_item(fixture: Fixture):
    return next((item for item in driver("dock")["items"] if item["bundleID"] == fixture.bundle_id), None)


def app_state(fixture: Fixture) -> dict:
    return driver("app", fixture.bundle_id)


def main_screen_height() -> float:
    return driver("screens")["screens"][0]["height"]


def quartz_rect(frame: dict) -> Rect:
    rect = Rect.of(frame)
    return Rect(rect.x, main_screen_height() - rect.max_y, rect.width, rect.height)


def click(point):
    driver("click", *point)


def set_badge(fixture: Fixture, text: str):
    fixture.control_file.write_text(text)


def wait_dock_badge(fixture: Fixture, text: str):
    with as_environment_problem():
        wait_until(lambda: (item := dock_item(fixture)) is not None and item["badge"] == text,
                   f"the Dock did not show the badge {text!r} for {fixture.dock_title}",
                   describe=lambda: f"Dock item: {dock_item(fixture)}")


def launch_fixture(fixture: Fixture):
    run(["open", "-g", str(fixture.app)])
    with as_environment_problem():
        if fixture.is_agent:
            wait_until(lambda: app_state(fixture)["processIDs"], f"{fixture.dock_title} did not start")
        else:
            wait_until(lambda: dock_item(fixture), f"{fixture.dock_title} did not show in the Dock")


def quit_fixture(fixture: Fixture):
    for process_id in app_state(fixture)["processIDs"]:
        with suppress(ProcessLookupError):
            os.kill(process_id, signal.SIGTERM)
    with as_environment_problem():
        wait_until(lambda: not app_state(fixture)["processIDs"] and dock_item(fixture) is None,
                   f"{fixture.dock_title} did not quit")


def wait_fixture(fixture: Fixture, condition, what: str):
    wait_until(lambda: condition(app_state(fixture)), f"{fixture.dock_title} did not become {what}",
               describe=lambda: f"state: {app_state(fixture)}")


def activate(fixture: Fixture):
    run(["open", str(fixture.app)])
    with as_environment_problem():
        wait_fixture(fixture, lambda s: s["isActive"], "active")


def deactivate(fixture: Fixture):
    if app_state(fixture)["isActive"]:
        activate(TEXT if fixture != TEXT else A)


def text_report() -> dict:
    try:
        return json.loads(TEXT.report_file.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def start_text():
    if not app_state(TEXT)["processIDs"]:
        TEXT.report_file.unlink(missing_ok=True)
        launch_fixture(TEXT)
    with as_environment_problem():
        wait_until(text_report, f"{TEXT.dock_title} wrote no report")
        # Just after a launch, the Accessibility API can give no window.
        wait_until(lambda: has_window(text_process_id()), f"{TEXT.dock_title} has no window")
    activate(TEXT)


def text_process_id() -> int:
    return app_state(TEXT)["processIDs"][0]


def has_window(process_id: int) -> bool:
    return subprocess.run([str(DRIVER), "window", str(process_id)], capture_output=True).returncode == 0


def text_window() -> dict:
    return driver("window", text_process_id())


@contextmanager
def full_screen(fixture: Fixture):
    process_id = app_state(fixture)["processIDs"][0]
    driver("fullscreen", process_id, "on")
    try:
        with as_environment_problem():
            wait_until(lambda: driver("window", process_id)["isFullScreen"], f"{fixture.dock_title} did not go full screen")
        time.sleep(FULL_SCREEN_SETTLE)
        yield
    finally:
        with suppress(CheckFailed, EnvironmentProblem):
            driver("fullscreen", process_id, "off")
            wait_until(lambda: not driver("window", process_id)["isFullScreen"], "full screen did not end")
            time.sleep(FULL_SCREEN_SETTLE)


def restart_dock():
    old = driver("dock")["dockProcessID"]
    run(["killall", "Dock"])
    with as_environment_problem():
        wait_until(lambda: (dock := driver("dock")).get("dockProcessID") not in (None, old) and dock["items"],
                   "the Dock did not start again", timeout=15)


def read_default(key: str):
    result = subprocess.run(["defaults", "read", APP_BUNDLE_ID, key], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else None


def delete_position_keys(fixture: Fixture):
    for key in fixture.position_keys:
        subprocess.run(["defaults", "delete", APP_BUNDLE_ID, key], capture_output=True)


# The app under test

def write_config(fixtures, arrow=False, **settings):
    config = {
        "version": 1,
        "apps": [{"bundleID": f.bundle_id, "name": f.bundle_name, "arrow": arrow} for f in fixtures],
        "badgeStyle": "number",
        "whenNothingNew": "show",
        "hideWhenNotRunning": False,
        "alertWhenMenuBarHidden": False,
        **settings,
    }
    temporary = CONFIG_FILE.with_suffix(".tmp")
    temporary.write_text(json.dumps(config, indent=2))
    os.replace(temporary, CONFIG_FILE)


class Badger:
    def __init__(self, name: str, fixtures):
        self.name = name
        self.fixtures = fixtures
        self.process = None

    def __enter__(self):
        self.start()
        return self

    def __exit__(self, *exc):
        self.stop()

    def start(self):
        STATE_FILE.unlink(missing_ok=True)
        with open(LOGS / f"{self.name}.log", "a") as log:
            self.process = subprocess.Popen(
                [str(APP_BINARY), "-MBBConfigFile", str(CONFIG_FILE), "-MBBStateFile", str(STATE_FILE),
                 "-MBBSkipWelcome", "YES", "-ApplePersistenceIgnoreState", "YES"],
                stdout=log, stderr=subprocess.STDOUT)
        try:
            with as_environment_problem():
                wait_until(lambda: len(self.state().get("items", [])) == len(self.fixtures)
                           and self.state().get("isTrusted") is not None,
                           "MenuBarBadger Dev did not make its items", describe=lambda: f"state: {self.state()}")
            if self.state()["isTrusted"] is False:
                raise EnvironmentProblem("MenuBarBadger Dev has no Accessibility permission. "
                                         "Turn it on in System Settings › Privacy & Security › Accessibility")
        except BaseException:
            self.stop()
            raise

    def stop(self):
        if self.process and self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()

    def relaunch(self):
        self.stop()
        self.start()

    def state(self) -> dict:
        if self.process and self.process.poll() is not None:
            raise CheckFailed(f"MenuBarBadger Dev ended with the code {self.process.returncode}")
        try:
            return json.loads(STATE_FILE.read_text())
        except (FileNotFoundError, json.JSONDecodeError):
            return {}

    def item(self, fixture: Fixture):
        return next((i for i in self.state().get("items", []) if i["bundleID"] == fixture.bundle_id), None)

    def wait_item(self, fixture: Fixture, condition, what: str, timeout=TIMEOUT):
        return wait_until(lambda: (item := self.item(fixture)) is not None and condition(item) and item, what,
                          timeout=timeout, describe=lambda: f"item: {self.item(fixture)}")

    def wait_badge(self, fixture: Fixture, badge: str):
        return self.wait_item(fixture, lambda i: i["badge"] == badge,
                              f"the item of {fixture.dock_title} did not get the badge {badge!r}")

    def item_rect(self, fixture: Fixture) -> Rect:
        item = self.item(fixture)
        if not item or not item["frame"]:
            raise CheckFailed(f"the item of {fixture.dock_title} is not on screen: {item}")
        return quartz_rect(item["frame"])

    def settled_item_rect(self, fixture: Fixture) -> Rect:
        """The menu bar moves an item with an animation after a show or a resize."""
        time.sleep(SETTLE)
        previous = None

        def settled():
            nonlocal previous
            rect = self.item_rect(fixture)
            stable = rect if rect == previous else None
            previous = rect
            return stable

        return wait_until(settled, f"the item of {fixture.dock_title} did not stop moving")

    def panels(self, kind: str, fixture: Fixture) -> list[Rect]:
        return [quartz_rect(p["frame"]) for p in self.state().get(kind, []) if p["bundleID"] == fixture.bundle_id]


# Scenarios

@dataclass
class Scenario:
    name: str
    summary: str
    fixtures: list
    body: object


SCENARIOS: list[Scenario] = []


def scenario(summary: str, fixtures=(A,)):
    def register(body):
        SCENARIOS.append(Scenario(body.__name__.replace("_", "-"), summary, list(fixtures), body))
        return body
    return register


@scenario("1. A Dock badge shows in the item; a cleared badge clears it")
def badge_shows_and_clears(name, a):
    write_config([a])
    with Badger(name, [a]) as badger:
        set_badge(a, "3")
        wait_dock_badge(a, "3")
        badger.wait_item(a, lambda i: i["badge"] == "3" and i["title"] == "3", "the item does not show 3")
        set_badge(a, "")
        wait_dock_badge(a, "")
        badger.wait_item(a, lambda i: i["badge"] == "" and i["title"] == "", "the item did not clear")


@scenario("2. After killall Dock, the badges work again")
def dock_restart(name, a):
    write_config([a])
    with Badger(name, [a]) as badger:
        set_badge(a, "1")
        wait_dock_badge(a, "1")
        badger.wait_badge(a, "1")
        restart_dock()
        set_badge(a, "2")
        wait_dock_badge(a, "2")
        badger.wait_item(a, lambda i: i["badge"] == "2" and i["title"] == "2", "the item does not show 2")


@scenario("3. The monitored app quits and starts again; its badge works again")
def app_relaunch(name, a):
    write_config([a])
    with Badger(name, [a]) as badger:
        set_badge(a, "7")
        wait_dock_badge(a, "7")
        badger.wait_badge(a, "7")
        quit_fixture(a)
        badger.wait_badge(a, "")
        set_badge(a, "8")
        launch_fixture(a)
        wait_dock_badge(a, "8")
        badger.wait_item(a, lambda i: i["badge"] == "8" and i["title"] == "8", "the item does not show 8")


@scenario("4. App B shows its badge", fixtures=(B,))
def dock_title_differs(name, b):
    write_config([b])
    with Badger(name, [b]) as badger:
        set_badge(b, "5")
        wait_dock_badge(b, "5")
        badger.wait_item(b, lambda i: i["badge"] == "5" and i["isDockItemFound"] and i["title"] == "5",
                         "the item of B does not show 5")


def click_item(badger: Badger, fixture: Fixture):
    click(badger.settled_item_rect(fixture).center)


@scenario("5. A click shows the app; a second click hides it. The same for app D", fixtures=(A, D))
def click_shows_and_hides(name, a, d):
    write_config([a, d])
    with Badger(name, [a, d]) as badger:
        deactivate(a)
        click_item(badger, a)
        wait_fixture(a, lambda s: s["isActive"] and not s["isHidden"], "active")
        click_item(badger, a)
        wait_fixture(a, lambda s: s["isHidden"] and not s["isActive"], "hidden")

        deactivate(d)
        if app_state(d)["windowsOnScreen"]:
            raise EnvironmentProblem(f"{d.dock_title} shows a window before the first click")
        click_item(badger, d)
        wait_fixture(d, lambda s: s["isActive"] and s["windowsOnScreen"] > 0, "active with a window")
        click_item(badger, d)
        # An agent app stays not hidden for NSRunningApplication; it shows no window instead.
        wait_fixture(d, lambda s: not s["isActive"] and s["windowsOnScreen"] == 0, "inactive with no window")


@scenario("6. Red badge: 99, 123 and hello give 99, 99+ and •")
def red_badge(name, a):
    write_config([a], badgeStyle="redBadge")
    with Badger(name, [a]) as badger:
        for badge, label in [("99", "99"), ("123", "99+"), ("hello", "•")]:
            set_badge(a, badge)
            wait_dock_badge(a, badge)
            badger.wait_item(a, lambda i: i["badge"] == badge and i["redBadgeLabel"] == label and i["title"] == "",
                             f"the badge {badge!r} does not give the red badge {label!r}")


def show_item_x(badger: Badger, fixture: Fixture, badge: str) -> float:
    set_badge(fixture, badge)
    wait_dock_badge(fixture, badge)
    badger.wait_item(fixture, lambda i: i["isVisible"] and i["frame"], f"the item did not show for {badge!r}")
    return badger.settled_item_rect(fixture).x


def hide_item(badger: Badger, fixture: Fixture):
    set_badge(fixture, "")
    wait_dock_badge(fixture, "")
    badger.wait_item(fixture, lambda i: not i["isVisible"], "the item did not hide for nothing new")


def check_same_x(before: float, after: float, when: str):
    if abs(after - before) > POSITION_TOLERANCE:
        raise CheckFailed(f"the item moved from x {before:.0f} to x {after:.0f} {when}")


@scenario("7. Hide for nothing new: the item hides and comes back at the same x position, also after a relaunch")
def hide_keeps_position(name, a):
    write_config([a], whenNothingNew="hide")
    delete_position_keys(a)
    try:
        with Badger(name, [a]) as badger:
            first_x = show_item_x(badger, a, "1")
            hide_item(badger, a)
            check_same_x(first_x, show_item_x(badger, a, "2"), "after a hide and a show")
            hide_item(badger, a)
            badger.relaunch()
            check_same_x(first_x, show_item_x(badger, a, "3"), "after a hide, a relaunch and a show")
    finally:
        delete_position_keys(a)


@scenario("8. A hand edit of the config file changes the badge style in less than 1 s")
def hand_edit(name, a):
    write_config([a])
    with Badger(name, [a]) as badger:
        set_badge(a, "123")
        wait_dock_badge(a, "123")
        badger.wait_item(a, lambda i: i["title"] == "123", "the item does not show 123")
        start = time.monotonic()
        write_config([a], badgeStyle="redBadge")
        badger.wait_item(a, lambda i: i["title"] == "" and i["redBadgeLabel"] == "99+",
                         "the item did not change to the red badge")
        elapsed = time.monotonic() - start
        if elapsed >= HAND_EDIT_LIMIT:
            raise CheckFailed(f"the badge style changed {elapsed:.2f} s after the edit")


@scenario("9. In full screen, the alert shows, and the keys typed into app Text all arrive", fixtures=(A,))
def full_screen_alert(name, a):
    write_config([a], alertWhenMenuBarHidden=True)
    with Badger(name, [a]) as badger:
        set_badge(a, "4")
        wait_dock_badge(a, "4")
        badger.wait_badge(a, "4")
        start_text()
        with full_screen(TEXT):
            typist = subprocess.Popen([str(DRIVER), "type", KEYS_ACROSS_ALERT], stdout=subprocess.DEVNULL)
            try:
                set_badge(a, "5")
                wait_until(lambda: badger.panels("alerts", a), "the alert did not show",
                           describe=lambda: f"state: {badger.state()}")
                if typist.poll() is not None:
                    raise EnvironmentProblem("the typed keys ended before the alert showed")
            finally:
                typist.wait()
            wait_until(lambda: text_report().get("text") == KEYS_ACROSS_ALERT, "app Text did not get all the typed keys",
                       describe=lambda: f"report: {text_report()}")
            if not app_state(TEXT)["isFrontmost"]:
                raise CheckFailed("app Text is not the frontmost app after the alert")


@scenario("10. While the arrow shows, a click on the item activates the app, and a click on the arrow away "
          "from the item reaches the window below")
def arrow_click_through(name, a):
    write_config([a], arrow=True)
    with Badger(name, [a]) as badger:
        start_text()
        set_badge(a, "3")
        arrow = wait_until(lambda: next(iter(badger.panels("arrows", a)), None), "the arrow did not show")
        item = badger.settled_item_rect(a)
        if arrow.y >= item.max_y:
            raise EnvironmentProblem(f"the arrow {arrow} does not cover a part of the item {item}")
        click((item.center[0], (max(arrow.y, item.y) + item.max_y) / 2))
        wait_fixture(a, lambda s: s["isActive"], "active after a click on the item under the arrow")

        activate(TEXT)
        set_badge(a, "")
        wait_until(lambda: not badger.panels("arrows", a), "the arrow did not go away after the badge cleared")
        target = arrow.x + arrow.width / 2, arrow.max_y - arrow.height / 4
        width, height = TEXT_WINDOW_SIZE
        driver("place", text_process_id(), target[0] - width / 2, target[1] - height / 2, width, height)
        window = Rect.of(text_window()["frame"])
        if not window.contains(target):
            raise EnvironmentProblem(f"the window of app Text {window} does not cover the point {target}")
        set_badge(a, "4")
        arrow = wait_until(lambda: next(iter(badger.panels("arrows", a)), None), "the arrow did not show again")
        if not arrow.contains(target):
            raise EnvironmentProblem(f"the arrow {arrow} does not cover the point {target}")
        clicks = text_report().get("clicks", 0)
        click(target)
        wait_until(lambda: text_report().get("clicks", 0) > clicks, "the click on the arrow did not reach app Text",
                   describe=lambda: f"report: {text_report()}")


# Runner

def file_digest(path: Path):
    try:
        return hashlib.sha256(path.read_bytes()).hexdigest()
    except FileNotFoundError:
        return None


def release_snapshot() -> dict:
    """The user's config file and the installed Release copy, which a run must not change."""
    running = subprocess.run(["pgrep", "-f", f"{RELEASE_APP}/Contents/MacOS/"], capture_output=True, text=True)
    return {
        "config file": file_digest(USER_CONFIG),
        "Release binary": file_digest(RELEASE_APP / "Contents/MacOS/MenuBarBadger"),
        "Release processes": set(running.stdout.split()),
    }


def reset_fixtures():
    for fixture in FIXTURES:
        set_badge(fixture, "")


def quit_all_fixtures():
    for fixture in FIXTURES:
        with suppress(CheckFailed, EnvironmentProblem):
            quit_fixture(fixture)


def prepare(s: Scenario):
    reset_fixtures()
    for fixture in s.fixtures:
        if not app_state(fixture)["processIDs"]:
            launch_fixture(fixture)
        if not fixture.is_agent:
            wait_dock_badge(fixture, "")


def run_scenario(s: Scenario) -> bool:
    try:
        prepare(s)
        s.body(s.name, *s.fixtures)
    except CheckFailed as error:
        print(f"FAIL   {s.name}: {error}")
        return False
    except EnvironmentProblem as error:
        print(f"ERROR  {s.name}: {error}")
        return False
    print(f"PASS   {s.name}")
    return True


@contextmanager
def run_lock():
    """The scenarios share the Dock and the fixture apps, so one run at a time, also across worktrees."""
    common = run(["git", "-C", str(ROOT), "rev-parse", "--git-common-dir"], capture_output=True, text=True).stdout.strip()
    with open((ROOT / common).resolve() / "menu-bar-badger-e2e.lock", "a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print("Another e2e run holds the lock. Waiting for it to end.")
            fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def command_run(names) -> int:
    selected = [s for s in SCENARIOS if not names or s.name in names]
    if unknown := set(names) - {s.name for s in SCENARIOS}:
        sys.exit(f"Unknown scenarios: {', '.join(sorted(unknown))}. Run: python3 -I E2E/run.py list")
    with run_lock():
        build()
        if not driver("dock")["trusted"]:
            sys.exit("This terminal has no Accessibility permission. Turn it on in System Settings › Privacy & "
                     "Security › Accessibility, then run again.")
        quit_all_fixtures()
        shutil.rmtree(RUN, ignore_errors=True)
        LOGS.mkdir(parents=True)
        CONFIG_FILE.parent.mkdir()
        before = release_snapshot()
        passed = 0
        try:
            for s in selected:
                passed += run_scenario(s)
        finally:
            quit_all_fixtures()
        after = release_snapshot()
    changed = [key for key in before if before[key] != after[key]]
    # The user can start the Release copy during the run. The run must only not quit it.
    if "Release processes" in changed and before["Release processes"] <= after["Release processes"]:
        changed.remove("Release processes")
    if changed:
        print(f"FAIL   the run changed: {', '.join(changed)}")
    print(f"\n{passed} of {len(selected)} scenarios passed. Logs: {LOGS.relative_to(ROOT)}")
    return 0 if passed == len(selected) and not changed else 1


def main():
    args = sys.argv[1:] or ["run"]
    match args:
        case ["build"]:
            build()
        case ["list"]:
            for s in SCENARIOS:
                print(f"{s.name:28} {s.summary}")
        case ["run", *names]:
            sys.exit(command_run(names))
        case _:
            sys.exit(__doc__)


if __name__ == "__main__":
    main()
