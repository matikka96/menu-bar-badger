# Item

Each monitored app has one `NSStatusItem`. This file covers its drawing. The badge styles are in
[badge-style.md](badge-style.md), the show and hide rules in [visibility.md](visibility.md), and the clicks
in [item-clicks.md](item-clicks.md).

## Icon

- The icon is 18 × 18 pt and is centred vertically in the menu bar.
- Source, in this order:
  1. the icon of the installed app (`NSWorkspace.icon(forFile:)`);
  2. else the SF Symbol `app.badge` as a template image.
- **Icon mode** (per app, `apps[].icon`):
  - **Color** (default): the app icon in its own colours. Never a template image.
  - **Monochrome**: a template image, so the system tints it for the light and the dark menu bar and for
    the selected state.
- The app makes the Monochrome image from the brightness of the app icon, not only from its alpha. A
  template from the alpha of a macOS 26 app icon is only a filled rounded square. The filter must keep the
  shape inside the icon visible. Tune it on real icons.
- The app makes each icon image one time and caches it. It makes the image again only when the app, the
  icon mode or the scale of the screen changes.

## Text and width

- In the Number style, the badge text shows to the right of the icon, in the menu bar font with monospaced
  digits.
- The width of the item fits the full text. A badge never gets clipped: "1", "12" and "123" all fit. With no
  text, the item has the width of the icon.

## Redraw

- The item redraws only when something visible changes: the badge text, the badge style, the nothing-new
  mode, the icon mode or the icon.
- A badge that does not change causes no redraw.

## Tooltip and VoiceOver

- An item of an installed app has no tooltip.
- An item of an app that is not installed has the tooltip "‹bundle ID› is not installed. Click for
  options."
- The accessibility label of the item is "‹App name›, ‹badge› new" with a badge, or "‹App name›, nothing
  new" with no badge. It uses the real badge also when the badge style is Icon only.

## Acceptance criteria

- The item width fits "1", "12" and "123" with no clipping.
- No redraw occurs in 5 s while the badge stays the same.
- Monochrome icons of Mail, Slack and Microsoft Teams are easy to recognise on a light and on a dark menu
  bar.
- VoiceOver reads the app name and the badge of an item.
