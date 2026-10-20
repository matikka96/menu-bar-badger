# MenuBarBadger

MenuBarBadger puts the Dock badges of the apps that you choose into the macOS menu bar.

Mail, Slack, Microsoft Teams and many other apps show their unread count only on their Dock icon. When the
Dock is hidden, when an app is full screen, or when you work on a second display, you do not see that count.
MenuBarBadger gives each of these apps an item in the menu bar with its icon and its badge.

**Status:** in development. There is no release yet.

## Requirements

- macOS 26 (Tahoe) or later
- The Accessibility permission. MenuBarBadger reads the badges from the Dock through the Accessibility API.

## Build from source

1. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set your team ID. A stable signing
   identity keeps the Accessibility permission after each install.
2. Run `make install`. It builds the Release configuration, replaces `/Applications/MenuBarBadger.app` and
   launches it.

`make help` lists all the targets.

## Settings

MenuBarBadger keeps its settings in `~/.MenuBarBadger/config.json`. You can change them in the settings
window or edit the file. The app applies an edit of the file at once.

## Documentation

- [Specification](docs/spec/README.md)
- [Glossary](GLOSSARY.md)

## License

MenuBarBadger is free software under the [GNU General Public License v3.0](LICENSE).
