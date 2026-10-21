# Global shortcut

One global keyboard shortcut opens the settings window.

## Behaviour

- The KeyboardShortcuts package registers the shortcut. It needs no Accessibility permission.
- A press opens the settings window and brings it to the front (see
  [settings-window.md](settings-window.md)). A press does not close the window.
- There is no default shortcut. Common defaults such as ⌘⇧D take a key from other apps.
- The user records or clears the shortcut with the recorder in the General tab.

## Config file

- The config file is the source of truth: `openSettingsShortcut`, a string or `null`.
- Format: the modifiers, then the key, joined with "+", in lower case. Examples: `"command+shift+b"`,
  `"control+option+space"`, `"command+f5"`.
  - Modifiers: `command`, `control`, `option`, `shift`. Each one at most one time, in any order on read, in
    this order on write.
  - Keys: `a`–`z`, `0`–`9`, `f1`–`f20`, `space`, `return`, `tab`, `escape`, `delete`, `up`, `down`, `left`,
    `right`, `home`, `end`, `pageup`, `pagedown`, and these characters: `` - = [ ] ; ' , . / \ ` ``. The
    names map to the key positions of the US layout.
  - The shortcut must contain `command` or `control`. macOS 15 and later limit hotkeys with only Option or
    Shift.
- Any other text is a config error.
- At load and at each live reload, the app gives the shortcut to KeyboardShortcuts.
- When the user records a shortcut, the app writes it to the file. A recorded shortcut with no Command and
  no Control is refused, and the recorder shows "Use ⌘ or ⌃ in the shortcut."
- A recorded key that is not in the list of keys is refused, and the recorder shows "Use another key." In
  both cases, the recorder shows the shortcut from the file again.

## Acceptance criteria

- A shortcut that the user records works at once from any app and writes the file.
- A hand edit of the shortcut in the file works in less than 1 s.
- Unit tests in `BadgerCore`: a round trip of the text format for each modifier and each key kind, and the
  errors for an unknown key, a repeated modifier and a shortcut with no Command and no Control.
