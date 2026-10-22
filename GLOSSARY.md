# Glossary

Use these words with these meanings in the code, the spec, the UI and the issues. Use one word for one
meaning.

| Word | Meaning | Do not say |
|---|---|---|
| **Monitored app** | An app that the user added to the list. MenuBarBadger identifies it by its bundle ID. | watched app, tracked app |
| **Badge** | The text that the Dock shows on the icon of an app, for example `3`, `99+` or `•`. An empty text means "no badge". | count (except for a parsed number), notification |
| **Count** | A badge that MenuBarBadger can read as a whole number. See [badge style](docs/spec/badge-style.md). | |
| **Dock item** | The Accessibility element of an app in the Dock. MenuBarBadger reads the badge from it. | Dock tile, Dock icon (in code) |
| **Poll** | One read of the badges of all Dock items. It occurs once each second. | sync, tick |
| **Item** | The status item of one monitored app in the menu bar (`NSStatusItem`). | icon, button, status bar icon |
| **Badge style** | How an item shows the badge: Red badge, Number or Icon only. | display mode |
| **Nothing-new mode** | What an item does when its badge is empty: Show, Dim or Hide. | |
| **Icon mode** | How an item draws the app icon: Color or Monochrome. | |
| **Alert** | The small panel that shows a new badge below an item when the menu bar is hidden. | popover, notification, banner |
| **Arrow** | The glass capsule with a red arrow that points to an item when a monitored app gets a new badge. | giant badge, pointer |
| **Config** | The settings of the user, in the config file. | defaults |
| **Config file** | `~/.MenuBarBadger/config.json` (Release) or `~/.MenuBarBadger/dev.config.json` (Debug). | settings file |
| **Flavor** | The Release build or the Debug build. Each flavor has its own name, bundle ID and config file. | variant, scheme |
| **Settings window** | The window with the Apps tab and the General tab. | config window, preferences window |
| **Setup screen** | The content of the settings window from the first launch until the user clicks Done: the Accessibility permission, the menu bar preview, the icon mode of new apps, the badge style and the login item. | welcome window, onboarding |
| **Menu bar preview** | The mock menu bar on the setup screen that shows the badge style and the icon mode on a Mail item. | sample, demo |
| **Running** | At least one instance of the monitored app runs. | open, launched |
| **Active** | The monitored app is the frontmost app. | focused |
