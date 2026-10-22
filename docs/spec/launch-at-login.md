# Launch at login

## Behaviour

- A switch in the General tab, default off. The system keeps the state; the config file does not.
- On: `SMAppService.mainApp.register()`. Off: `unregister()`. No helper app.
- The switch shows the real state of `SMAppService.mainApp.status`. The app reads it each time the settings
  window opens and each time the app becomes active, because the user can change it in System Settings.

| Status | Switch | Hint and action |
|---|---|---|
| `.enabled` | on | "The badges stay in the menu bar after a restart." |
| `.notRegistered` | off | "The badges stay in the menu bar after a restart." |
| `.requiresApproval` | on, with a warning | "Needs your approval in System Settings." and a button "Open Login Items" (`SMAppService.openSystemSettingsLoginItems()`) |
| `.notFound` | off | "The badges stay in the menu bar after a restart." |

- When the app is not in `/Applications` or `~/Applications`, the switch is off and disabled, with the hint
  "Move ‹App name› to the Applications folder to use this." The app checks its own path, not the status:
  the status is also `.notFound` for an app in `/Applications` when Launch Services knows other copies of the
  same bundle ID.

- The switch is disabled whenever the app cannot turn on launch at login. Then it is off, and the hint says
  why:
  - The app is not in `/Applications` or `~/Applications` (see above).
  - `register()` failed. The hint shows the error text, and the switch stays disabled until the next launch.
    When `register()` fails but the status is `.enabled` or `.requiresApproval` after it, the row shows the
    status as in the table, with no error.
- A switch that is on stays enabled, so that the user can always turn it off.
- When `unregister()` fails, the switch goes back to the real state, and the hint shows the error text for
  5 s.
- A launch at login does not show the settings window, except when the permission is missing (see
  [settings-window.md](settings-window.md)).

## Acceptance criteria

- On, then a log out and a log in: the app runs, and no window shows.
- A change in System Settings › General › Login Items shows in the switch the next time the window opens.
- The state "Needs approval" shows its hint and its button.
- A copy outside the Applications folder shows a disabled switch. The copy in `/Applications` shows an enabled
  switch, and a click turns on the login item also when the status was `.notFound`.
- A failed `register()` shows its error, and the switch stays off and disabled.
