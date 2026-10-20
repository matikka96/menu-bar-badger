# Localisation

v1 ships in English only. The code is ready for more languages from the first commit.

## Rules

- One String Catalog, `MenuBarBadger/Resources/Localizable.xcstrings`. The development language is English.
- Every user-visible string goes through the catalog: labels, hints, status texts, menu items, button
  titles, alerts, accessibility labels and error messages. Use `String(localized:)` in AppKit code and
  `LocalizedStringKey` (the plain string literal) in SwiftUI.
- The English text is the key. Add a comment for each string whose meaning is not clear from the text.
- Never build a sentence from parts. Use one format string with arguments, for example
  `"\(appName) can't read Dock badges"`.
- Do not translate the badge. It is the text of another app.
- The app name comes from the bundle (`CFBundleDisplayName`), never from a literal, so that the Debug flavor
  shows "MenuBarBadger Dev".
- System texts (the About panel, the open panel, the KeyboardShortcuts recorder) stay as the system or the
  package gives them.

## Acceptance criteria

- The catalog has no stale or missing entries after a build.
- A search in the app target for a quoted user-visible string outside the catalog finds nothing.
