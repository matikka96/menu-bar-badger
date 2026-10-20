# Arrow

A small glass capsule with a red arrow under an item. It points to a new badge while the app is in the
background. It is an opt-in for each app (`apps[].arrow`).

## When the arrow shows

On a change of the badge of a monitored app, the arrow of that app shows when all of these are true:

1. `apps[].arrow` is on, and the badge style is not Icon only.
2. The app is not active.
3. The new badge is not empty.
4. The new badge is not lower than the old badge. Compare the [counts](badge-style.md) when both badges
   are counts. When one of them is not a count (for example "•"), any change of the text qualifies.
5. The item is not hidden by a [visibility](visibility.md) rule after the change.
6. The menu bar is visible on the screen of the item. When the menu bar is hidden, the [alert](alert.md)
   covers the case, so the arrow does not show.

A badge change that does not meet these conditions hides the arrow.

## When the arrow goes away

- The user clicks the item.
- The app becomes active.
- The badge clears.
- The item hides.
- The menu bar of the screen of the item becomes hidden.
- The badge style changes to Icon only, or the user turns off the arrow of this app.

The arrow has no timeout. It stays until one of these events.

## Look

- A capsule with the system glass material (`NSGlassEffectView`), 32 pt wide and 44 pt high.
- In its centre, the SF Symbol `arrow.up` with the semibold weight, 22 pt, in the system red colour.
- The system shadow.

## Animation

- The capsule appears with a fade of 0.2 s.
- The symbol plays the SF Symbols effect `.bounce.up` three times, then stays still.
- When the arrow shows again while it is still visible (a new qualifying badge), the symbol bounces one more
  time. The capsule does not fade again.
- With Reduce Motion on: no fade and no bounce.
- The animation runs on the main thread, which has no poll work, so it loses no frames.

## Placement

- Horizontally centred on the item. When the item moves or grows, the arrow follows it with no jump.
- Vertically: the top of the capsule is 4 pt below the bottom of the menu bar of the screen of the item.
- Like the alert, the arrow waits until the frame of the item stays the same for 0.1 s, at most 0.5 s,
  before it shows.

## Window

- A borderless, transparent `NSPanel` with `.nonactivatingPanel`, the size of the capsule plus its shadow.
- It ignores the mouse (`ignoresMouseEvents` = true): a click on the item reaches the item, and a click on
  the arrow reaches the window below.
- Level: one step above the alert. Collection behaviour: `.canJoinAllSpaces`, `.fullScreenAuxiliary`,
  `.stationary`.
- One arrow for each app at most.

## Acceptance criteria

- With the arrow on, a new badge of a background app shows the arrow, centred (± 2 pt) under the item.
- The arrow does not show for the active app, for a lower count, or when a badge clears.
- A click on the item under the arrow activates the app and hides the arrow.
- A click on the arrow away from the item reaches the window below.
- When the app becomes active, the arrow goes away.
- With Reduce Motion on, the arrow shows with no motion.
- Unit tests in `BadgerCore`: the show rules, with counts, non-count badges, the active app and the hidden
  menu bar.
