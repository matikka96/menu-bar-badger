# Item clicks

## Left click

On the item of an installed app, a left click shows or hides the app:

1. If an instance of the app is **active**, hide it (`NSRunningApplication.hide()`). If the system refuses
   the hide (an agent app with no Dock icon refuses it), set the Accessibility attribute `AXHidden` of the
   app to true. The app then becomes inactive and shows no window.
2. Else, open the app as a Dock click does: activate it and send a "reopen", so that an app with no open
   window shows its main window (for example Mail with all windows closed). If the app runs, use the
   running instance and never start a second copy from another path. If it does not run, launch it
   (`NSWorkspace.openApplication(at:configuration:)` with activation).

On the item of an app that is not installed, a left click opens the settings window on the Apps tab with
that app selected.

A left click with the Option key held is a normal left click.

## Right-click menu

A right click, or a Control-click, shows a menu under the item:

| Item | Action |
|---|---|
| Open ‹App› | Step 2 of the left click. Disabled when the app is not installed. |
| ‹App› Options… | Opens the settings window on the Apps tab with this app selected. |
| — | separator |
| Settings… | Opens the settings window on its last tab. |
| Check for Updates… | Sparkle. Only after the release work. |
| Quit MenuBarBadger | Ends the app with a normal termination. |

## Both clicks

- Any click first hides the alert and the arrow of that item.
- The click works on any display, and also while the arrow covers part of the item (the arrow ignores the
  mouse).

## Risks

- Developers report that right clicks on status items break on macOS 27. Detect the button with the
  action of the status item button (`sendAction(on: [.leftMouseUp, .rightMouseUp])` and the current
  event), not with an event monitor. Check the right-click menu on macOS 27 before v1.

## Acceptance criteria

- A click shows the app; a second click hides it.
- The same for an agent app with no Dock icon: the second click makes it inactive with no window on screen.
- A click on the item of Mail with no open window shows the Mail viewer window.
- A right click shows the menu, and "‹App› Options…" opens the settings window with that app selected.
- No tooltip shows while the pointer stays on the item of an installed app.
