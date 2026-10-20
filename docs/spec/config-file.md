# Config file

All user settings live in one JSON file on the Mac. The user can change them in the settings window or
edit the file by hand. The app applies a hand edit at once.

## Location

| Flavor | File |
|---|---|
| Release | `~/.MenuBarBadger/config.json` |
| Debug | `~/.MenuBarBadger/dev.config.json` |
| Debug with `-MBBConfigFile <path>` | `<path>` (used by the e2e tests, see [build-flavors.md](build-flavors.md)) |

- At launch, if the folder does not exist, the app creates it.
- At launch, if the file does not exist, the app writes a file with the default values and an empty app
  list.

## Format

```json
{
  "version": 1,
  "apps": [
    { "bundleID": "com.apple.mail", "name": "Mail", "icon": "color", "arrow": false },
    { "bundleID": "com.tinyspeck.slackmacgap", "name": "Slack", "icon": "monochrome", "arrow": true }
  ],
  "badgeStyle": "number",
  "whenNothingNew": "show",
  "hideWhenNotRunning": false,
  "alertWhenMenuBarHidden": true,
  "openSettingsShortcut": null
}
```

| Field | Type | Default | Meaning |
|---|---|---|---|
| `version` | integer | required | The format version. This spec describes version 1. |
| `apps` | array | `[]` | The monitored apps, in the order of item creation at launch. |
| `apps[].bundleID` | string | required | The bundle ID of the app. It must not be empty. |
| `apps[].name` | string | none | The app writes the display name here so that a person can read the file. The app ignores this field when it reads the file. |
| `apps[].icon` | `"color"` or `"monochrome"` | `"color"` | The icon mode. See [status-item.md](status-item.md). |
| `apps[].arrow` | boolean | `false` | Show the arrow for this app. See [arrow.md](arrow.md). |
| `badgeStyle` | `"number"`, `"redBadge"` or `"iconOnly"` | `"number"` | See [badge-style.md](badge-style.md). |
| `whenNothingNew` | `"show"`, `"dim"` or `"hide"` | `"show"` | See [visibility.md](visibility.md). |
| `hideWhenNotRunning` | boolean | `false` | See [visibility.md](visibility.md). |
| `alertWhenMenuBarHidden` | boolean | `true` | See [alert.md](alert.md). |
| `openSettingsShortcut` | string or `null` | `null` | See [shortcut.md](shortcut.md). |

The per-app settings live in the `apps` entry of the app. When the user removes an app, its per-app
settings go away with it.

Rules for a read:

1. A field that is absent gets its default. Only `version` and `apps[].bundleID` are required.
2. The app ignores a field that it does not know. The next write of the app removes it.
3. When two entries have the same bundle ID, the first entry wins. The app ignores the others.
4. A `version` higher than 1 is an error: "This config file is from a newer version of MenuBarBadger."
5. Each other wrong value is an error: bad JSON, a wrong type, an unknown enum value, an empty bundle ID,
   or a shortcut text that the app cannot read.
6. An error makes the whole file invalid. The app never applies a part of a file.

Rules for a write:

- The app writes the file after each change in the settings window, at once.
- The write is atomic: a temporary file in the same folder, then a rename.
- The output is pretty-printed JSON with 2-space indentation, with the fields in the order of the table
  above, so that a diff of two versions stays small.

## Live reload

- The app watches the folder of the file, not the file itself, because many editors replace a file when
  they save it.
- After a change, the app waits 0.3 s for more changes, then reads the file.
- If the content is the same as the last content that the app wrote or read, the app does nothing.
- A valid file replaces the whole config at once: the items, the styles and the shortcut change together.

## Error state

When the file is invalid, or when it goes away while the app runs:

- The items keep the last valid config and continue to work.
- Each tab of the settings window shows a banner at the top: a warning symbol, "The config file has an
  error", the error message (with the line and the column when JSON gives them), and the buttons "Show in
  Finder" and "Reload".
- For a missing file, the banner says "The config file is missing" and has the button "Create It". That
  button writes the current config to the file.
- While the error state lasts, the controls of the settings window are disabled. The app never writes the
  file in the error state, so it never overwrites an edit of the user.
- When the user fixes the file, the live reload applies it and the banner goes away.

## Not in the config file

| Data | Where |
|---|---|
| The frame of the settings window and its last tab | `UserDefaults` of the app |
| The menu bar position of each item and its backup | `UserDefaults`, see [item-position.md](item-position.md) |
| The login item | The system (`SMAppService`) |
| The Accessibility permission | The system |

## Acceptance criteria

- A file with only `{"version": 1}` gives an empty list and all the defaults.
- A hand edit that adds an app makes its item show in less than 1 s.
- A hand edit that changes `badgeStyle` changes all the items at once.
- A file with bad JSON keeps the old items, shows the banner with the line of the error, and stays
  unchanged on disk.
- A change in the settings window writes the file. A second identical change does not write it again.
- Unit tests in `BadgerCore`: the defaults, each error kind, the duplicate rule, the version rule, and a
  round trip of encode and decode with the stable field order.
