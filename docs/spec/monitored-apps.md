# Monitored apps

## Behaviour

- The user keeps an ordered list of monitored apps in the config file (`apps`). The bundle ID identifies
  each app.
- Each monitored app has exactly one item in the menu bar. At launch, the app creates the items in list
  order. macOS puts each new item to the left of the existing status items; after that, the user can move
  an item with Command-drag (see [item-position.md](item-position.md)).
- An add of a bundle ID that is already in the list does nothing.
- An add or a remove changes the config file at once.

## Display name and icon

- The display name comes from the installed app: the localized name of the bundle, with one trailing
  ".app" removed. Example: "My.app Tools.app" gives "My.app Tools".
- The app finds the installed bundle with `NSWorkspace.urlForApplication(withBundleIdentifier:)`.
- When no app with that bundle ID is installed, the display name is the bundle ID, and the app is **not
  installed**. The entry stays in the list.
- When an app becomes installed or uninstalled while MenuBarBadger runs, the name and the icon update at
  the next app launch or termination event, or at the next open of the settings window.

## App state

The model keeps this state for each monitored app:

| State | Source |
|---|---|
| Display name, app icon, installed | The installed bundle |
| Running | At least one instance runs (`NSWorkspace.runningApplications`) |
| Active | An instance is the frontmost app |
| Badge | The [Dock reader](dock-reader.md). Empty when the app has no Dock item. |
| Dock item found | The Dock reader |

The model updates the badge also while the item is hidden, so that the alert, the arrow and the status
texts always use the current badge.

## Remove

A remove (from the Apps tab, the Delete key or the context menu):

1. removes the entry and its per-app settings from the config file;
2. removes the item from the menu bar at once;
3. hides the alert and the arrow of that app;
4. deletes the position backup of the item.

## Empty list

- When the list is empty at launch, the settings window opens on the Apps tab.
- When the user removes the last app, the settings window stays open.

## Acceptance criteria

- Two entries with the same bundle ID give one item and one row.
- An app that is not installed keeps its row with the status "Not installed" and an item with the default
  icon.
- A remove takes the item away in less than 0.5 s and removes the entry from the file.
- Unit test in `BadgerCore`: the ".app" rule.
