# Alert

A small glass panel that shows a new badge below the item when the user cannot see the menu bar.

## When the alert shows

On a change of the badge of a monitored app, the alert of that app shows when all of these are true:

1. `alertWhenMenuBarHidden` is on, and the badge style is not Icon only.
2. The new badge is not empty. A badge that clears shows no alert.
3. The item is not hidden by a [visibility](visibility.md) rule after the change.
4. The menu bar is hidden on the screen of the item.

**The screen of the item** is the screen that holds the window of the item button. If no screen holds it,
the screen that holds the horizontal centre of the item. Else the screen with the menu bar
(`NSScreen.screens[0]`).

**The menu bar is hidden on a screen** when one of these is true:

- The frontmost app has a window with `AXFullScreen` = true, and the largest part of that window is on this
  screen. A window on no screen does not count.
- The top of `NSScreen.visibleFrame` equals the top of `NSScreen.frame` for this screen: the user set the
  menu bar to hide automatically.

The check reads the windows of another app through the Accessibility API, so it runs off the main actor.
Both rules are heuristics. An app that fakes full screen without the system full-screen mode does not count.

## Look

- A rounded panel with the system glass material (`NSGlassEffectView`), a corner radius of 12 pt and the
  system shadow.
- Content: the 20 pt app icon (with its [icon mode](status-item.md)) and the badge text in a bold system
  font, for example "3".
- The panel appears and goes away with a short fade (0.15 s). With Reduce Motion on, it has no fade.

## Placement

- Horizontally centred under the item, but moved so that the whole panel stays on the screen of the item.
- Vertically: the top of the panel is 6 pt below the bottom of the item. If the item is above the top of the
  screen (the menu bar slid away in full screen), the top of the panel is 6 pt below the top of the screen.
- When an item comes back from hidden, or grows (icon only to icon and "5"), the menu bar moves it some time
  later. The alert waits until the frame of the item stays the same for 0.1 s, at most 0.5 s, before it
  shows. While it shows, it follows the item when the item moves.

## Window

- An `NSPanel` with `.nonactivatingPanel`. It never becomes key or main and never activates MenuBarBadger.
  Typing in the full-screen app continues with no lost key, and the frontmost app does not change.
- Level `.screenSaver`, so that it shows above full-screen content. Collection behaviour:
  `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary`. `hidesOnDeactivate` = false. Show it with
  `orderFrontRegardless()`.
- One panel for each app at most.

## Lifetime

- The alert goes away 3 s after its last show. A new badge while it shows updates the text and starts the
  3 s again.
- It goes away at once when the badge clears, when the user clicks the item, when the item hides, and when
  the app becomes active.
- A click on the alert (the first click counts) closes it and opens the app the way a left click on the item
  does (step 2 in [item-clicks.md](item-clicks.md)).

## Acceptance criteria

- In full screen, a new badge shows the alert below the item; keys typed during the alert all reach the
  full-screen app; the frontmost app stays the same.
- With the menu bar set to hide automatically, a new badge shows the alert.
- With a visible menu bar, no alert shows.
- A click on the alert closes it in less than 1 s and activates the app.
- A second badge change updates the text. The alert goes away 3 s (± 1 s) after the last change, and not
  before 2 s.
- With two screens, the alert is fully on one screen, and it shows for a full-screen window on either
  screen, wherever the pointer is.
- With Hide for nothing new, the item comes back and the alert shows below it after the item settles.
- Unit tests in `BadgerCore`: the show rules, the screen of a rectangle (full screen under a notch, a taller
  screen at the side, a screen above, a window across two screens, a window on no screen) and the placement
  that keeps the panel on one screen.
