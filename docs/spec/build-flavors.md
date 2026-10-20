# Build flavors, launch arguments and `make` targets

## Flavors

| | Release | Debug |
|---|---|---|
| App name | MenuBarBadger | MenuBarBadger Dev |
| Bundle ID | `com.matikka96.MenuBarBadger` | `com.matikka96.MenuBarBadger.dev` |
| Config file | `~/.MenuBarBadger/config.json` | `~/.MenuBarBadger/dev.config.json` |
| Launch arguments below | ignored (compiled out with `#if DEBUG`) | accepted |

- Each flavor has its own `UserDefaults`, its own Accessibility entry and its own login item. Development
  never changes the installed Release copy.
- The settings window and the About panel show the name of the flavor.
- `Info.plist`: `LSUIElement` = YES, category Productivity, minimum system version 26.0.
- Signing: `Config/Local.xcconfig` sets `DEVELOPMENT_TEAM`. Git ignores this file;
  `Config/Local.xcconfig.example` shows the format. A stable signing identity keeps the Accessibility
  permission after each rebuild. With no team, the build uses an ad-hoc signature.
- Never write the team ID into a tracked file or into the output of a script.

## Debug launch arguments

| Argument | Effect |
|---|---|
| `-MBBConfigFile <path>` | Use this config file instead of `dev.config.json`. |
| `-MBBStateFile <path>` | Write the debug state file to this path. See [testing.md](testing.md). |
| `-MBBSkipWelcome YES` | Do not show the welcome window. |
| `-MBBFakeDock <path>` | Read the badges from this JSON file (bundle ID to badge text) instead of the Dock. The UI tests use it, so they need no Accessibility permission. |

## `make` targets

| Target | Job |
|---|---|
| `make help` | List the targets. |
| `make build` | Build the Debug flavor. |
| `make test` | Run `swift test` in `Packages/BadgerCore`. |
| `make ui-test` | Run the XCUITest flows. |
| `make e2e` | Build the fixtures and run the e2e smoke scenarios. It needs the Accessibility permission for the test host and takes the keyboard focus. |
| `make install` | Build Release, quit the running Release copy (10 s limit), replace `/Applications/MenuBarBadger.app` with a roll-back on failure, and launch it. It refuses to run with a dirty tree or on a branch other than `main`. |
| `make worktree NAME=<name>` | Create the worktree `/Users/masa/Documents/repos/worktrees/menu-bar-badger-<name>` on a new branch `<name>` from `dev`, and copy the local files that git does not track (`AGENTS.md`, `.local/`) into it. |
| `make release` | The release pipeline on the local Mac. See [ci-and-release.md](ci-and-release.md). |

## Acceptance criteria

- A Debug build and the installed Release copy run at the same time, each with its own items and its own
  config file.
- A Release build ignores `-MBBConfigFile`.
- `make install` on a dirty tree stops with a clear message and changes nothing.
