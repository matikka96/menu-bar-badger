# Testing

Few tests, where they matter. No TDD rule.

## Unit tests

- Swift Testing, in `Packages/BadgerCore/Tests`. `make test` runs them. CI runs them.
- Write a unit test for a rule that is easy to get wrong and hard to see by hand. The acceptance criteria
  of each spec file name these rules:
  - the config codec and its errors, and the shortcut text format;
  - the red badge label and the count parser;
  - the Dock item match rule;
  - the show rules of the alert and the arrow;
  - the screen geometry and the panel placement.
- Engine tests for the Dock reader use a fake Dock source behind a protocol: the stale item, the Dock with
  zero items, and the Dock restart.
- Do not test SwiftUI layout, simple getters, or code that only forwards to AppKit.

## E2E smoke scenarios

`make e2e` runs them on a real Mac. They are not in CI. The runner is `E2E/run.py` (Python 3, standard
library only). It sends the clicks and the keys, and reads the Dock and the windows, through a small Swift
tool in `E2E/Driver`. A file lock in the git folder lets only one run go at a time, also across worktrees.

### Fixtures

- Small fixture apps in `E2E/Fixtures`. Each one sets its own Dock badge (`NSApp.dockTile.badgeLabel`)
  from a control file that the runner writes.
  - **A**: a plain app.
  - **B**: an app whose Dock title differs from its bundle name.
  - **D**: an agent app with no Dock icon.
  - **Text**: an app with one text field that reports the typed text, for the focus scenarios.
- The runner starts the Debug flavor with `-MBBConfigFile` (a temporary file), `-MBBStateFile` and
  `-MBBSkipSetup YES`. It never touches the user's config file or the installed Release copy.
- The test host (the terminal) and MenuBarBadger Dev need the Accessibility permission.
- After the run, the runner checks that the user's config file and the installed Release copy did not
  change.

### Debug state file

With `-MBBStateFile <path>`, the Debug flavor writes a JSON file to that path each 0.25 s, with an atomic
write. It contains: the process ID; the Accessibility state; for each item, the bundle ID, the badge, the
"Dock item found" state, the visible state, the frame of the item on screen, the title, the red badge label,
the icon mode and the redraw count; the frames and the window levels of the visible alerts and arrows. The
frames use the AppKit screen coordinates.

### Scenarios

1. A Dock badge shows in the item; a cleared badge clears it.
2. After `killall Dock`, the badges work again.
3. The monitored app quits and starts again; its badge works again.
4. App B shows its badge.
5. A click shows the app; a second click hides it. The same for app D.
6. Red badge: "99", "123" and "hello" give "99", "99+" and "•".
7. Hide for nothing new: the item hides and comes back at the same x position, also after a relaunch.
8. A hand edit of the config file changes the badge style in less than 1 s.
9. In full screen, the alert shows, and the keys typed into app Text all arrive.
10. While the arrow shows, a click on the item activates the app, and a click on the arrow away from the item
    reaches the window below.

## UI tests

XCUITest flows for the settings window, in the target `MenuBarBadgerUITests` and `make ui-test`. They use a
fake Dock source (a Debug launch argument) so that they need no Accessibility permission. They take the
keyboard focus, so run them only when the Mac is free. They are not in CI.

- add an app through the add sheet with the keyboard only: "+" opens the sheet, then the search text, the
  Down Arrow key and Return add the app;
- remove with "−", with the Delete key and with the context menu;
- the selection stays after a setting change;
- the config error banner shows for a bad file and goes away after a fix;
- the setup screen: a first launch shows only the setup screen, Monochrome in the "Icon" row and Done show
  the tab picker and the add sheet, the added app gets the Monochrome icon, and a relaunch after Done shows
  no setup screen. The fake Dock source grants the permission.

## Accessibility identifiers

Every control that a test uses has a fixed identifier: `appsList`, `appRow`, `addApp`, `removeApp`,
`appIconMode`, `appArrow`, `openApp`, `searchApps`, `appResults`, `confirmAdd`, `cancelAdd`,
`chooseFromFinder`, `badgeStyle`, `whenNothingNew`, `hideWhenNotRunning`, `alertWhenMenuBarHidden`,
`launchAtLogin`, `openSettingsShortcut`, `showConfigFile`, `about`, `quit`, `accessibilityBanner`,
`configErrorBanner`, `setupScreen`, `setupOpenSettings`, `setupIconMode`, `setupBadgePreview`, `setupDone`, `settingsTabs`.
