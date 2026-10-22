# Architecture

## Platform

| Topic | Decision |
|---|---|
| Minimum macOS | 26 (Tahoe). macOS 27 APIs go behind `#available`. |
| Toolchain | Xcode 26.6 and Swift 6.3 today. Change to Xcode 27 when the development Mac runs macOS 26.6 or later. |
| Language mode | Swift 6, with `MainActor` as the default isolation in the app target. |
| Sandbox | Off. The sandbox does not allow the Accessibility API. |
| Hardened runtime | On. |
| App type | Agent app (`LSUIElement`): no Dock icon and no visible main menu. |
| Dependencies | [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) (MIT) for the global shortcut. Sparkle 2 (MIT) comes with the release work. No other third-party code. |

## Main decisions

- **AppKit lifecycle, SwiftUI views.** An `NSApplicationDelegate` is the entry point. The settings window,
  the setup screen, the alert content and the arrow content are SwiftUI views in `NSHostingController` or
  `NSHostingView`. Reason: an agent app cannot open the SwiftUI `Settings` scene in a reliable way, and the
  known workarounds use hidden windows.
- **One `NSStatusItem` for each monitored app.** `MenuBarExtra` cannot make a dynamic number of items, and
  it gives no autosave name and no right-click.
- **Non-activating `NSPanel` windows for the alert and the arrow**, so that they never take the focus from
  the frontmost app.
- **Polling.** The Accessibility API sends no notification when a badge changes (tested on macOS 26.4).
  The Dock reader polls once each second, off the main thread.
- **One observable model.** All UI reads one `@Observable` model on the main actor. Nothing else holds UI
  state.
- **Config file, not `UserDefaults`, for user settings.** See [config-file.md](config-file.md).
  `UserDefaults` keeps only machine UI state: window frames, the last tab, the position backups and the
  pending setup (`MBB.setupPending`).

## Components

```
                         ┌──────────────────────┐
  ~/.MenuBarBadger/ ───▶ │ ConfigStore          │── Config or ConfigError ──┐
  config.json       ◀─── │ load, save, watch    │                           │
                         └──────────────────────┘                           ▼
┌───────────────┐  badge changes   ┌───────────────────────────────────────────────┐
│ DockReader    │ ───────────────▶ │ AppModel  (@Observable, @MainActor)            │
│ (actor, poll) │ ◀─ bundle IDs ── │ config, app states, permission, config error  │
└───────────────┘                  └───────────────────────────────────────────────┘
┌───────────────┐  running apps          │ observed by
│ RunningApps   │ ─────────────────────▶ ▼
│ (NSWorkspace) │        ┌────────────────────────┬─────────────────┬─────────────────┐
└───────────────┘        │ MenuBarController      │ AttentionCtrl   │ SettingsWindow  │
                         │  └ StatusItemController│  alert, arrow   │ setup screen    │
                         │    (one for each app)  │                 │                 │
                         └────────────────────────┴─────────────────┴─────────────────┘
```

| Component | Job |
|---|---|
| `AppDelegate` | Builds the components at launch and owns them. Handles reopen and termination. |
| `AppModel` | The single source of UI state: the config, one state for each monitored app (name, icon, running, active, badge, Dock item found), the permission state, the config error and the pending setup. It applies changes to the config through `ConfigStore`. |
| `ConfigStore` | Reads, validates, writes and watches the config file. It lives in `BadgerCore` (Foundation only). See [config-file.md](config-file.md). |
| `DockReader` | An actor. It finds the Dock items, polls the badges and recovers from stale items and Dock restarts. It sends only changes to the model. See [dock-reader.md](dock-reader.md). |
| `RunningApps` | Watches app launch, termination and activation through `NSWorkspace` and updates the model. |
| `MenuBarController` | Keeps exactly one `StatusItemController` for each monitored app, in config order. |
| `StatusItemController` | Owns one `NSStatusItem`. It draws the item from the model and handles its clicks. |
| `ItemFace` | Draws the icon, the Number text and the red capsule on an item button. The status item and the menu bar preview of the setup screen use it. |
| `AttentionController` | Shows and hides the alert and the arrow from the model changes. See [alert.md](alert.md) and [arrow.md](arrow.md). |
| `SettingsWindowController` | Owns the settings window, also while it shows the setup screen. See [settings-window.md](settings-window.md). |
| `LoginItem`, `Shortcut`, `AccessibilityPermission` | Thin adapters over `SMAppService`, KeyboardShortcuts and the Accessibility prompt. |

The names are a guide, not a rule. Keep the split: pure rules in `BadgerCore`, system calls at the edge,
and one model in the middle.

## `BadgerCore` package

A local Swift package with no AppKit dependency (Foundation and CoreGraphics only). It holds the rules that
need unit tests:

- the config types, their JSON codec and their validation, the shortcut text format, and `ConfigStore` (file read, atomic write, folder watch);
- the badge rules: the count parser and the red badge label;
- the Dock item match rule, on plain values (bundle ID, title);
- the attention rules: when the alert and the arrow show;
- the screen geometry: the screen of a rectangle, the placement of a panel under an item.

`swift test` in the package runs the unit tests with no Xcode project and no Accessibility permission.

## Threads

- The main actor owns the model, all AppKit objects and all SwiftUI views.
- The `DockReader` actor does all Accessibility calls on the Dock. Each Accessibility element has a
  messaging timeout of 0.5 s, so a hung Dock cannot block a poll for long, and it never blocks the main
  thread.
- The full-screen check of the alert reads the windows of another app through the Accessibility API. It
  also runs off the main actor.
- An `AXUIElement` never leaves the actor that created it.
- Arrow and alert animations run on the main thread. No poll work runs there, so the animations do not
  lose frames.

## Project layout

```
menu-bar-badger/
├── MenuBarBadger.xcodeproj      buildable folders: a new file needs no project edit
├── MenuBarBadger/               the app target
│   ├── App/  MenuBar/  Dock/  Attention/  Settings/  Config/
│   └── Resources/               Assets.xcassets, Localizable.xcstrings, app icon
├── MenuBarBadgerUITests/        the XCUITest flows (see testing.md)
├── Packages/BadgerCore/         Sources/BadgerCore, Tests/BadgerCoreTests
├── E2E/                         fixture apps and the e2e runner (see testing.md)
├── Config/                      Base.xcconfig, Debug.xcconfig, Release.xcconfig,
│                                Local.xcconfig.example (Local.xcconfig is git-ignored)
├── docs/spec/
├── Scripts/                     shell scripts that the Makefile calls (install.sh)
├── Makefile
└── .github/workflows/
```

- Use buildable folders (`PBXFileSystemSynchronizedRootGroup`). Create the project with the local Xcode, so
  that its object version is one that Xcode 26.6 can open.
- Build settings go in the `.xcconfig` files, not in the project file.
