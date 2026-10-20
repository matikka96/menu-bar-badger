# Apps tab

A list on the leading side and the options of the selected app on the trailing side, as in System Settings
lists with a detail pane.

## List

- One row for each monitored app, in config order: the 24 pt app icon, the display name, and a status text
  below the name in the secondary colour.
- Status text:
  - "Not installed" when no app with the bundle ID is installed;
  - "Not running" when no instance runs;
  - "Nothing new" when the app runs with an empty badge;
  - "‹badge› new" when the app runs with a badge, for example "3 new" or "• new".
- The status text follows the model at once. It does not poll.
- Single selection. A click selects a row. After an add, the new row is selected.
- A bar under the list with "+" (accessibility label "Add App") and "−" (accessibility label "Remove App"),
  in the style of System Settings.
  - "+" opens the [add sheet](add-app-sheet.md).
  - "−" removes the selected app. It is disabled when no row is selected.
- The Delete key removes the selected app.
- The context menu of a row has "Remove".
- A remove has the effects in [monitored-apps.md](monitored-apps.md). After a remove, no row is selected.
- The selection stays when a setting changes, when the config file reloads with the same app, and when the
  window becomes active again.
- Empty list: the list shows "No apps yet" and "Click + to add an app." in its centre.

## Detail

With no selection, the detail pane shows "Select an app" in its centre.

With a selected app:

- Header: the 48 pt app icon, the display name, and a status line: "Running · 3 new", "Running · nothing
  new", "Not running" or "Not installed · ‹bundle ID›".
- A grouped form:

| Row | Control | Hint |
|---|---|---|
| Icon | Segmented: Color / Monochrome | "Color uses the app's own colours. Monochrome matches the menu bar." |
| Point to new badges | Switch | "A red arrow points to the item while the app is in the background." With Icon only: "Doesn't apply to Icon only." and the switch is disabled. |

- A button "Open ‹App›" at the end of the form. It is disabled when the app is not installed.
- A change writes the config file at once and changes the item at once.

## Acceptance criteria

- A selected row stays selected after a setting changes.
- "Remove" in the context menu removes the row and the item.
- "−" is disabled with no selection, removes the selected row, and is disabled again after the remove.
- The Delete key removes the selected row.
- The arrow switch is disabled with Icon only and enabled again with Number.
- The status text changes from "Nothing new" to "3 new" in less than 1.5 s after the Dock badge changes.
