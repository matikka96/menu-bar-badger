# Visibility: nothing-new mode and hide while not running

## Nothing-new mode (`whenNothingNew`)

One global setting with three values. It applies when the badge is empty or the app has no Dock item. A
change applies to all items at once.

| Mode | Effect |
|---|---|
| Show (`"show"`, default) | The item stays as it is. |
| Dim (`"dim"`) | The icon shows dimmed. A Color icon shows in grey at reduced opacity. A Monochrome icon shows at reduced opacity. Dim applies in every badge style. |
| Hide (`"hide"`) | The item goes away from the menu bar. It comes back at its old position as soon as a badge appears. |

## Hide while the app isn't running (`hideWhenNotRunning`)

- One global switch, default off.
- When it is on, the item of an app with no running instance goes away. It comes back in less than 1 s
  after the app starts.
- It works with every badge style, also Icon only.

## Rules

- An item that is hidden by either rule uses `NSStatusItem.isVisible = false`, so its autosave name and its
  position stay. See [item-position.md](item-position.md).
- The model updates the badge also while the item is hidden.
- When an item hides, its alert and its arrow hide too.

## Acceptance criteria

- Dim changes the image and keeps the item visible. Show restores the first image.
- Hide hides an item with an empty badge. A new badge shows it again at the same x position.
- With "Hide while the app isn't running", a quit hides the item and a launch shows it again.
- Hide, badge "1", clear, then "1" again: the item shows again, and the alert and the arrow follow their
  normal rules.
