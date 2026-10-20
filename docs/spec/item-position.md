# Item position

The user can move an item with Command-drag. The item must keep that position across hide and show, and
across a relaunch.

## Behaviour

- Each item has the autosave name `MenuBarBadger.<bundleID>`. macOS saves the position of the item under
  this name in the `UserDefaults` of the app (`NSStatusItem Preferred Position <autosave name>`).
- macOS forgets the saved position when an item hides (Apple feedback FB9052637). Thus the app keeps its
  own backup of the position, `MBB.position.<bundleID>`, in `UserDefaults`:
  1. before each hide, copy the system value to the backup;
  2. before each show, and before an item gets its autosave name at launch, copy the backup to the system
     value.
- On a remove, delete the backup and the system keys of that item.
- The positions do not go into the config file: they belong to this Mac and its displays.

## Risks

- This is a workaround for a macOS bug, and it depends on a system key name. Check it on each new major
  macOS version.
- macOS 27 manages the menu bar in a new way and has an overflow button. Check the position rules on
  macOS 27 before v1.

## Acceptance criteria

- An item keeps its x position after a hide and a show.
- An item keeps its x position after a hide, a relaunch of MenuBarBadger and a show.
- After a remove, no key of that item stays in `UserDefaults`.
