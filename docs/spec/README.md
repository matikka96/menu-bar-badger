# MenuBarBadger specification

MenuBarBadger is a macOS menu bar app. For each app that the user chooses, it shows one item in the menu bar
with the app icon and the badge that the Dock shows for that app. Optional attention aids (an alert when the
menu bar is hidden, and an arrow under the item) make a new badge easy to see.

This spec is the source of truth for the app. When the code and the spec do not agree, one of them is
wrong: fix the code, or change the spec in the same pull request.

## Product rules

- Native macOS look and behaviour. Use system controls, SF Symbols, system colours and system materials
  (Liquid Glass). Follow the Human Interface Guidelines.
- Minimum macOS 26. Put each macOS 27 API behind `#available`.
- Distribution outside the Mac App Store only: the App Store does not allow the Accessibility API in a
  sandboxed app.
- English only, but every user-visible string is localizable.

## Files

Each file describes one feature: its behaviour, its rules and its acceptance criteria. The issue column
names the GitHub issue that builds the feature.

| File | Feature | Issue |
|---|---|---|
| [architecture.md](architecture.md) | Modules, threads, data flow and project layout | Skeleton |
| [config-file.md](config-file.md) | The config file: format, location, live reload, errors | Skeleton |
| [build-flavors.md](build-flavors.md) | Release and Debug identities, launch arguments, `make` targets | Skeleton |
| [localisation.md](localisation.md) | String Catalog and string rules | Skeleton |
| [ci-and-release.md](ci-and-release.md) | Branches, CI, versions, release pipeline | Skeleton, Release |
| [monitored-apps.md](monitored-apps.md) | The list of monitored apps | Badges |
| [dock-reader.md](dock-reader.md) | Read the badges from the Dock | Badges |
| [status-item.md](status-item.md) | The item: icon, icon mode, text, redraw | Badges |
| [badge-style.md](badge-style.md) | Number, Red badge, Icon only | Badges |
| [visibility.md](visibility.md) | Show, Dim, Hide, and hide while not running | Badges |
| [item-position.md](item-position.md) | Keep the menu bar position of an item | Badges |
| [item-clicks.md](item-clicks.md) | Left click and the right-click menu | Badges |
| [accessibility.md](accessibility.md) | The permission, the welcome window and the banner | Badges |
| [settings-window.md](settings-window.md) | The settings window: opening rules, tabs, main menu | Settings |
| [apps-tab.md](apps-tab.md) | The Apps tab: list and detail | Settings |
| [add-app-sheet.md](add-app-sheet.md) | The sheet that adds an app | Settings |
| [general-tab.md](general-tab.md) | The General tab | Settings |
| [launch-at-login.md](launch-at-login.md) | The login item | Settings |
| [shortcut.md](shortcut.md) | The global shortcut that opens the settings window | Settings |
| [alert.md](alert.md) | The alert when the menu bar is hidden | Attention |
| [arrow.md](arrow.md) | The arrow that points to an item | Attention |
| [testing.md](testing.md) | Unit tests, e2e smoke scenarios, UI tests | E2E |

## Not in v1

- Custom icons for an item.
- Other badge styles, for example a tint or a dot with no count.
- A separate icon for Dark Mode.
- A Focus filter for the alert and the arrow. This is the first candidate after v1
  (`SetFocusFilterIntent`).
- A shortcut for each monitored app.
- An export of the badge state to other tools.
- App groups with one summed badge.
- An import of settings from other apps.
- Other languages than English.
