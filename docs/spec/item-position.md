# Item position

The user can move an item with Command-drag. The item must keep that position across hide and show, and
across a relaunch.

## Behaviour

- Each item has the autosave name `MenuBarBadger.<bundleID>`. macOS saves the position of the item under
  this name in the `UserDefaults` of the app (`NSStatusItem Preferred Position <autosave name>`). The value
  is the distance in points from the right edge of the screen to the right edge of the item. The menu bar
  sorts the items by it.
- macOS saves a position only after the user moves the item. An item with no saved position comes back
  to the left of the other items after a hide. Thus a visible item with no saved position records its
  current place once, as macOS would. Before macOS places an item, its window is at the left edge of the
  screen; the app records nothing then.
- macOS forgets the saved position when an item hides (Apple feedback FB9052637). Thus the app keeps its
  own backup of the position, `MBB.position.<bundleID>`, in `UserDefaults`:
  1. while the item is visible, copy the system value to the backup each time the `UserDefaults` of the
     app change, and before each hide. macOS writes the new position into the `UserDefaults` of the app
     after a Command-drag. Thus the drag goes into the backup at once, and an old backup never replaces it
     at the next launch;
  2. before each show, and before an item gets its autosave name at launch, copy the backup to the system
     value.
- On a remove, delete the backup and the system keys of that item: the position, and the visible state
  (`NSStatusItem VisibleCC <autosave name>` on macOS 26, `NSStatusItem Visible <autosave name>` before).
- The positions do not go into the config file: they belong to this Mac and its displays.

## Risks

- This is a workaround for a macOS bug, and it depends on a system key name. Check it on each new major
  macOS version.
- When several items show again at the same time (for example after a change from Hide to Show), macOS
  can put them back to the right of the items that stayed visible. One item that hides and shows keeps its
  place (tested on macOS 26.4).
- macOS 27 manages the menu bar in a new way and has an overflow button. Check the position rules on
  macOS 27 before v1.

## Acceptance criteria

- An item keeps its x position after a hide and a show.
- An item keeps its x position after a hide, a relaunch of MenuBarBadger and a show.
- After a remove, no key of that item stays in `UserDefaults`.
