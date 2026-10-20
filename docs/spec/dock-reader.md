# Dock reader

The Dock reader gets the badge of each monitored app from the Dock through the Accessibility API.

## Source of the badge

- The Dock process (`com.apple.dock`) has an Accessibility tree. Each app in the Dock is an element with the
  subrole `AXApplicationDockItem`. Its attribute `AXStatusLabel` is the badge text. Its attribute `AXURL`
  gives the app bundle, and `AXTitle` gives the name that the Dock shows.
- No item, or no `AXStatusLabel`, means "no badge" (an empty text).
- `AXStatusLabel` is not a documented API. Check it again on each new major macOS version.
- Facts from research: an `AXObserver` gets no notification when a badge changes,
  so the reader must poll. The LaunchServices status label and the Notification Center database are not
  usable sources.

## Match rule

For each monitored app, the reader finds the Dock item in this order:

1. The item whose `AXURL` resolves to a bundle with the same bundle ID.
2. Only if no item has that bundle ID: an item that has no bundle ID and whose title equals the display
   name.
3. An item with a different bundle ID never matches, also with the same title. Examples: two apps with the
   title "Teams"; "Microsoft Outlook" in the Dock and "Outlook" as the bundle name; a localized name.

## Timing

- **Poll:** once each second, with a tolerance of 0.25 s. A badge change shows in the menu bar in less than
  1.25 s.
- **Full lookup:** once each 10 s, the reader looks up all Dock items again, also for apps that already
  have an item.
- **Events that start a lookup at once:**
  - an element appears in the Dock (`AXObserver`, `kAXCreatedNotification` on the Dock app element): look
    up the apps that have no item yet;
  - an element goes away in the Dock (`kAXUIElementDestroyedNotification`): poll at once, so that a quit
    clears the badge at once;
  - an app launches or terminates (`NSWorkspace`): look up that bundle ID.
- **Pause:** the reader stops the poll while the screens sleep (`NSWorkspace.screensDidSleepNotification`)
  and when the list is empty. It polls at once after the screens wake.
- **No permission:** while the app has no Accessibility permission, the reader does not poll. It checks the
  permission once each second, and starts within 1 s after the user grants it.

## Recovery

- **Stale item:** an item that answers "invalid element" or "cannot complete" is stale. The reader looks
  it up again at once and reads the badge from the new item in the same poll. If there is no new item, the
  badge is empty and the reader forgets the item.
- **Dock restart:** when the process ID of the Dock changes, the reader attaches its observer to the new
  Dock process and looks up all items again. Badges continue with no relaunch of MenuBarBadger.
- **Dock not ready:** while a restarted Dock reports no items at all, the reader keeps its old item
  references and tries again on the next poll. (The Dock always has Finder, so zero items means that the
  Dock is not ready.)
- **Timeout:** each Accessibility element has a messaging timeout of 0.5 s. A timeout counts like a stale
  item.

## Output

- The reader runs as an actor, off the main thread. See [architecture.md](architecture.md).
- After each poll, it sends to the model only the apps whose badge or "Dock item found" state changed.
- It never touches AppKit objects.

## Limits

- An app that is not in the Dock has no badge: an app that does not run and is not pinned, or an agent app
  with no Dock icon.
- Only the text of the badge is available. The reader cannot tell, for example, a direct message from a
  channel post.

## Acceptance criteria

- A new Dock badge shows in the item in less than 1.25 s.
- A cleared Dock badge clears the item in less than 1.25 s.
- After `killall Dock`, badges work again with no relaunch.
- After the monitored app quits and starts again, its badge works. The badge is empty while the app is not
  in the Dock.
- An app whose Dock title differs from its bundle name shows its badge.
- An app with a localized display name shows its badge.
- Unit tests in `BadgerCore`: the match rule (bundle ID wins over an earlier item with the same title; the
  title is used only for an item with no bundle ID; another bundle ID never matches). Engine tests with a
  fake Dock source: a stale item is replaced in the same poll; a stale item with no replacement gives an
  empty badge; a Dock with zero items keeps the old references and recovers.
