# General tab

A grouped form with these sections, from top to bottom.

## Menu Bar

| Row | Control | Hint |
|---|---|---|
| Badge | Segmented: Number / Red Badge / Icon Only | "Number next to the icon." / "Red badge on the icon." / "Only the icon, with no alerts or arrows." |
| When there's nothing new | Segmented: Show / Dim / Hide | "The icon stays as it is." / "The icon is dimmed." / "The icon is hidden until something arrives." |
| Hide while the app isn't running | Switch | "The icon comes back when the app starts." |

See [badge-style.md](badge-style.md) and [visibility.md](visibility.md).

## Alerts

| Row | Control | Hint |
|---|---|---|
| Show an alert when the menu bar is hidden | Switch | "For example, while an app is full screen." With Icon only: "Doesn't apply to Icon only." and the switch is disabled. |

See [alert.md](alert.md).

## General

| Row | Control | Hint |
|---|---|---|
| Launch at login | Switch | See [launch-at-login.md](launch-at-login.md) for the states. |
| Shortcut to open settings | KeyboardShortcuts recorder | "Click the field, then press the keys." |

## Config File

| Row | Control |
|---|---|
| The path, for example `~/.MenuBarBadger/config.json`, in a monospaced font, selectable | Button "Show in Finder" |

## Footer

Below the form: "‹App name› ‹version›" in the secondary colour, and the buttons "About" (the standard About
panel, `NSApp.orderFrontStandardAboutPanel`) and "Quit" (normal termination).

The About panel shows the app icon, the name, the version and the copyright line.

## Acceptance criteria

- Each change writes the config file at once and changes the items at once.
- Each choice of Badge keeps the height of the window and the positions of the rows below it.
- With Icon only: the hide switch and the Hide segment stay enabled; the alert switch is disabled with its
  hint "Doesn't apply to Icon only."; after Number, the alert switch is enabled with its normal hint.
- "Show in Finder" selects the config file in Finder.
