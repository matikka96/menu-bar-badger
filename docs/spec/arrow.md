# Arrow

A small red arrow under an item, with no background. It points to a new badge while the app is in the
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

- The SF Symbol `arrow.up` with the bold weight, 33 pt, in the system red colour, in the centre of a
  42 × 42 pt transparent window.
- The system shadow of the window, around the symbol.

## Animation

- The arrow appears with a fade of 0.2 s.
- The symbol plays the SF Symbols effect `.bounce.up` three times, then stays still.
- When the arrow shows again while it is still visible (a new qualifying badge), the symbol bounces one more
  time. The arrow does not fade again.
- The arrow goes away with a flight to the north under the menu bar: the window goes one level below the menu
  bar (`.mainMenu` − 1), and in 0.3 s with an ease-in curve it moves up until it is above the top of the
  screen. The menu bar and its items draw over it. The arrow does not fade.
- With Reduce Motion on: no fade, no bounce and no flight. The arrow shows and goes away at once.
- The animation runs on the main thread, which has no poll work, so it loses no frames.

## Placement

- Horizontally centred on the item. When the item moves, the arrow moves to the new centre with a short
  animation (no animation with Reduce Motion). The arrow ignores a resize of the item: the menu bar first
  resizes an item at its old origin, and then moves it to its final frame some 0.15 s later. When the
  badge clears, the arrow flies away from where it is and does not follow the item that gets narrower.
- Vertically: the top of the window is 10 pt above the bottom of the menu bar of the screen of the item, so the
  tip of the arrow is slightly on the menu bar.
- Like the alert, the arrow waits until the frame of the item stays the same for 0.1 s, at most 0.5 s,
  before it shows.

## Window

- A borderless, transparent `NSPanel` with `.nonactivatingPanel`, 42 × 42 pt. The window server draws the
  system shadow around the symbol.
- It ignores the mouse (`ignoresMouseEvents` = true): a click on the item reaches the item, and a click on
  the arrow reaches the window below.
- Level: one step above the alert, and `.mainMenu` − 1 during the flight. Collection behaviour: `.canJoinAllSpaces`, `.fullScreenAuxiliary`,
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
