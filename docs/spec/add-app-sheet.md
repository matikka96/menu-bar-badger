# Add-app sheet

A sheet on the settings window that adds one app to the list.

## Content

- Title: "Choose an App".
- A search field with the keyboard focus at once.
- A list with one row for each app: the 24 pt icon and the name, sorted by the localized name.
- Buttons: "Choose from Finder…" on the leading side; "Cancel" (Escape) and "Add" (Return, default) on the
  trailing side.

## Sources of the list

- The application bundles that Spotlight knows in `/Applications`, `/System/Applications` and
  `~/Applications`, also in their subfolders: an `NSMetadataQuery` for
  `kMDItemContentType == "com.apple.application-bundle"`. An app inside another app bundle does not show.
- All running apps with the regular activation policy, so that an app outside these folders or outside the
  Spotlight index still shows while it runs.
- Each bundle ID shows one time. The Spotlight entry wins.
- When Spotlight knows more than one copy of a bundle ID, the copy in `/Applications` or
  `/System/Applications` wins.
- The app loads the list at launch, and loads it again each time the settings window opens. Thus the sheet
  shows the full list at once. Until the first query delivers its results, the list shows the running apps
  and a small progress indicator.

## Behaviour

- Search: a match of the trimmed search text anywhere in the name, with no regard to case or diacritics. A
  change of the search text clears the selection.
- With search text and no match: "No app matches “‹text›”."
- An app that is already in the list shows dimmed with the label "Added". The user cannot select it.
- "Add" adds the selected app, selects its row in the Apps tab and closes the sheet. It is disabled with no
  selection.
- A double-click on a row adds that app and closes the sheet.
- "Choose from Finder…" opens an open panel for one application bundle, in `/Applications`. The chosen app
  is added and the sheet closes. A bundle with no bundle ID shows the error "This app has no bundle ID."
  and the sheet stays open.

## Acceptance criteria

- The search field has the focus when the sheet opens, with no click.
- An app that runs but is outside the Spotlight index shows in the list and can be added; its item and its
  badge show.
- An app that is already in the list shows "Added" and cannot be added again.
- "Choose from Finder…" adds an app from any folder.
