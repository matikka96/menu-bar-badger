# Accessibility permission

MenuBarBadger needs the Accessibility permission to read the Dock, to read the windows of the frontmost app
for the alert, and to hide an agent app. Without it, the items show icons but no badges.

## Setup screen

The setup screen explains the permission and the main choices at the first launch. It fills the settings
window: the window shows no tab picker, no Apps tab and no General tab (see
[settings-window.md](settings-window.md)).

### When it shows

- At the first launch (the config file did not exist before this launch), the app sets the `UserDefaults`
  key `MBB.setupPending`.
- While the key is set, the settings window opens at each launch and shows only the setup screen. Each path
  that opens the settings window (the main menu, the right-click menu of an item, the global shortcut, a
  second open of the app) shows the setup screen.
- The key stays across relaunches until the user clicks Done. Done removes the key.
- An existing user with a config file never sees the setup screen.
- The Debug argument `-MBBSkipSetup YES` stops the setup screen.

### Content

- Header: the 48 pt app icon, the title "Welcome to ‹App name›" and the text "Only Accessibility is
  required. You can change the preferences later."
- A grouped form with two sections. Each row has a symbol in a leading column, so that the titles align.
- **Required**: "Allow Accessibility". This is the only mandatory step.
  - Before the grant: an empty circle, the hint "‹App name› needs it to read the Dock badges." and the
    button "Open Accessibility Settings".
  - The button calls `AXIsProcessTrustedWithOptions` with the prompt option. This adds the app to the list
    in System Settings, so the user only needs to turn on the switch. Then the button opens System
    Settings › Privacy & Security › Accessibility. After a click, a small spinner shows next to the button,
    and the hint is "Turn on ‹App name› in System Settings. This window updates by itself."
  - The app checks the permission once each second. After the grant, the row shows a green check mark,
    the hint "‹App name› can read Dock badges now." and the text "Allowed" in less than 1 s.
- **Preferences**: these rows are choices, so they show no check mark.
  - First, the [menu bar preview](badge-style.md#menu-bar-preview) at the full width of the section, with
    the caption "Preview with Mail as an example." under it. It has no symbol column, because it shows the
    effect of the two rows below it.
  - "Icon": a segmented control Color / Monochrome for `newAppIcon`, the icon mode that each added app
    gets. The hint is the hint of the mode in the Apps tab, then "You can change it for each app later."
    The preview uses this mode.
  - "Badge style": the same segmented control and config value as the General tab, with the same hints.
    The preview uses this style.
  - "Launch at login": the same switch and states as the General tab
    ([launch-at-login.md](launch-at-login.md)).
- The setup screen has no row that adds apps. The user adds apps after Done.
- Footer: a divider, then a text and the button "Done" (default button). The text is "Allow Accessibility to finish the
  setup." before the grant, and "You can change all of this later in Settings." after it.

### Done

- Done is disabled until the permission is granted.
- Done removes the setup screen. The window then shows the tab picker and the Apps tab, and its height
  animates to fit the Apps tab.
- If the app list is empty after Done, the add sheet opens at once (see [apps-tab.md](apps-tab.md)).
- The close button closes the window at any time. The setup screen shows again at the next open.

## Later launches

- At each launch, the app checks the permission with no prompt (`AXIsProcessTrusted`).
- When the permission is missing at a later launch and the setup screen is done, the settings window opens
  with the banner. This also occurs at a launch at login, because the app cannot do its job without the
  permission.

## Banner

- The settings window shows the banner at the top of each tab while the permission is missing:
  - a yellow `exclamationmark.triangle.fill` symbol;
  - "‹App name› can't read Dock badges";
  - "Turn on ‹App name› in Privacy & Security › Accessibility.";
  - the button "Open System Settings", which acts like the button of the setup screen.
- The banner goes away less than 1 s after the user grants the permission, with no relaunch.
- While the setup screen shows, the banner does not show.

## Facts

- The permission belongs to the signing identity and the bundle ID. A build with another signature loses
  it. Each flavor has its own entry.

## Acceptance criteria

- With no config file, the first launch opens the settings window with only the setup screen. No other
  window shows, and the window shows no tabs.
- Done is disabled until the permission is granted, and enabled in less than 1 s after the grant.
- A quit and relaunch before Done shows the setup screen again. After Done, a relaunch shows no setup
  screen.
- A launch with an existing config file shows no setup screen.
- With Monochrome in the "Icon" row, an app that the user adds after Done gets the Monochrome icon.
- With no permission at a later launch, the settings window opens with the banner. After the grant, the
  banner goes away and the badges show in less than 2 s.
