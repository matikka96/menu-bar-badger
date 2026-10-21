# Settings window

## Structure

- One window with a unified toolbar. The window title, the app name, is on the leading side. A segmented
  control in the centre of the toolbar selects the tab: **Apps** or **General**. The toolbar shows no labels
  and has no customization menu.
- An `NSWindowController` owns the window. Each tab is a SwiftUI view in an `NSHostingController`, in an
  `NSTabViewController` that shows no tabs of its own.
- The window has a close button. Minimize and zoom are disabled. The width is fixed. The height fits the
  selected tab, and a tab change animates the height.
- The window remembers its frame (autosave name `Settings`) and its last tab, also across relaunches. The
  first show centres it.
- Contents: [apps-tab.md](apps-tab.md) and [general-tab.md](general-tab.md).
- Banners at the top of each tab: the Accessibility banner ([accessibility.md](accessibility.md)) and the
  config error banner ([config-file.md](config-file.md)). When both apply, the config banner is first.

## When the window opens

The window opens and comes to the front in these cases:

1. At launch, when the list of monitored apps is empty.
2. At launch, when the Accessibility permission is missing and the welcome window does not show.
3. At the first activation of the process: a launch from Finder or Spotlight activates the app, so the
   window shows. A launch at login, or a launch in the background, does not activate the app, so the window
   does not show.
4. On a second open of the app while it runs (Finder, Spotlight, `open`). No second process starts.
5. On the global shortcut ([shortcut.md](shortcut.md)).
6. On "Settings…" or "‹App› Options…" in the right-click menu, or a click on the item of an app that is not
   installed ([item-clicks.md](item-clicks.md)).
7. On ⌘, while MenuBarBadger is active.
8. On "Add Apps…" in the welcome window.

## Open rules

- The window must come to the front, in front of the frontmost app, with the keyboard focus. The app stays
  an agent app. On macOS 26, `NSApp.activate()` and `makeKeyAndOrderFront` are not sufficient from the
  right-click menu of an item; `orderFrontRegardless()` after them brings the window to the front. The menu
  opens the window only after the menu tracking ends, else the window does not keep the keyboard focus.
- When the window is closed, an open shows it at its saved frame with fresh state: the login item state
  and the installed apps are read again.
- When the window is already open, an open only brings it to the front. It keeps its frame, its tab, the
  selected row and an open sheet.
- "‹App› Options…" selects the Apps tab and that app.
- An activation of MenuBarBadger by itself (Command-Tab, a click on the window) never moves or rebuilds the
  window.

## Main menu

The app has a main menu. An agent app does not show it, but its key equivalents work while the app is
active:

- App menu: About ‹App name›, Settings… (⌘,), Quit ‹App name› (⌘Q).
- Edit menu: Undo, Redo, Cut, Copy, Paste, Select All, so that text fields support the standard keys.
- Window menu: Close (⌘W).

## Layout rules

- Use a SwiftUI `Form` with `.formStyle(.grouped)` and system controls only.
- Spacing comes from a 4 pt scale of named constants. The content, the form sections and the footer keep
  12 pt from the window edges, and 12 pt between the app list and the detail pane.
- Each row has a title, an optional hint below it in the secondary colour, and the control at the trailing
  edge, centred vertically. A long hint wraps in its column; the control never moves below the title.
- A change of a setting never changes the height of the window or moves other rows: give each hint the
  space of its longest variant.
- A change applies at once. There is no Apply button and no Save button.
- Every control has an accessibility label and an accessibility identifier (see [testing.md](testing.md)).
  A control without a visible label keeps its accessibility label.

## Acceptance criteria

- The window keeps its frame, its tab and its selected row when MenuBarBadger becomes active again.
- A second open of the app shows the closed window at its last frame, with no second process.
- After a relaunch, the window opens at the same frame and on the same tab.
- The window opens in front of a full-screen app's Space or the frontmost app, with the keyboard focus.
- ⌘C, ⌘V and ⌘A work in the search field of the add sheet.
