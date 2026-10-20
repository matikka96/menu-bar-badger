# Launch at login

## Behaviour

- A switch in the General tab, default off. The system keeps the state; the config file does not.
- On: `SMAppService.mainApp.register()`. Off: `unregister()`. No helper app.
- The switch shows the real state of `SMAppService.mainApp.status`. The app reads it each time the settings
  window opens and each time the app becomes active, because the user can change it in System Settings.

| Status | Switch | Hint and action |
|---|---|---|
| `.enabled` | on | none |
| `.notRegistered` | off | none |
| `.requiresApproval` | on, with a warning | "Needs your approval in System Settings." and a button "Open Login Items" (`SMAppService.openSystemSettingsLoginItems()`) |
| `.notFound` | off, disabled | "Move ‹App name› to the Applications folder to use this." |

- When `register()` or `unregister()` fails, the switch goes back to the real state, and the hint shows the
  error text for 5 s.
- A launch at login does not show the settings window, except when the permission is missing (see
  [settings-window.md](settings-window.md)).

## Acceptance criteria

- On, then a log out and a log in: the app runs, and no window shows.
- A change in System Settings › General › Login Items shows in the switch the next time the window opens.
- The state "Needs approval" shows its hint and its button.
