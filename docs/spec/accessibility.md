# Accessibility permission

MenuBarBadger needs the Accessibility permission to read the Dock, to read the windows of the frontmost app
for the alert, and to hide an agent app. Without it, the items show icons but no badges.

## Welcome window

- It shows at the first launch: when the config file did not exist before this launch.
- Content, centred, with the app icon at the top:
  - title: "Welcome to ‹App name›";
  - text: "‹App name› shows the Dock badges of your apps in the menu bar. To read the badges, it needs the
    Accessibility permission.";
  - button "Open Accessibility Settings" (default button).
- The button calls `AXIsProcessTrustedWithOptions` with the prompt option. This adds the app to the list in
  System Settings, so the user only needs to turn on the switch. Then the button opens System Settings ›
  Privacy & Security › Accessibility.
- The window checks the permission once each second. When the user grants it, the window shows a green
  check mark, the text "‹App name› can read Dock badges now.", and the button "Add Apps…". That button
  closes the welcome window and opens the settings window on the Apps tab with the add sheet open.
- When the permission is already granted at the first launch, the window shows the granted state at once.
- The window is a normal titled window with a close button. It has the size of its content and is centred
  on the screen with the pointer.
- The Debug argument `-MBBSkipWelcome YES` stops the window.

## Later launches

- At each launch, the app checks the permission with no prompt (`AXIsProcessTrusted`).
- When the permission is missing at a later launch, the settings window opens with the banner. This also
  occurs at a launch at login, because the app cannot do its job without the permission.

## Banner

- The settings window shows the banner at the top of each tab while the permission is missing:
  - a yellow `exclamationmark.triangle.fill` symbol;
  - "‹App name› can't read Dock badges";
  - "Turn on ‹App name› in Privacy & Security › Accessibility.";
  - the button "Open System Settings", which acts like the button of the welcome window.
- The banner goes away less than 1 s after the user grants the permission, with no relaunch.

## Facts

- The permission belongs to the signing identity and the bundle ID. A build with another signature loses
  it. Each flavor has its own entry.

## Acceptance criteria

- At the first launch, the welcome window shows. After the grant, it shows the granted state in less than
  1 s.
- "Add Apps…" opens the add sheet in the settings window.
- With no permission at a later launch, the settings window opens with the banner. After the grant, the
  banner goes away and the badges show in less than 2 s.
