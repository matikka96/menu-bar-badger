# Branches, CI, versions and release

## Branches

- `dev` is the work branch. Each issue gets its own branch from `dev` (use `make worktree`).
- An issue branch merges into `dev` with a squash merge after the owner approves it. No CI runs on `dev` or
  on issue branches. Run `make build test` before each push.
- The owner merges `dev` into `main` when they want. CI runs on each push to `main`.
- A release is a tag `vX.Y.Z` on `main`.
- Commit messages have a subject line only, with no body.

## CI (issue Skeleton)

One GitHub Actions workflow, `.github/workflows/ci.yml`:

- Trigger: `push` to `main` only.
- Runner: the GitHub-hosted macOS 26 runner.
- Steps: check out; `swift test` in `Packages/BadgerCore`; build the Release flavor with no signing
  (`CODE_SIGNING_ALLOWED=NO`).
- Limit: the run must finish in less than 5 minutes. Set `timeout-minutes: 10`. Cancel an older run on the
  same branch (`concurrency`).
- The repo is public, so standard runners cost no minutes.
- No e2e scenarios and no UI tests in CI: they need the Accessibility permission and a real desktop.

## Versions

- Semantic versions. The first version is 0.1.0. Version 1.0.0 is the first public release.
- `MARKETING_VERSION` is in `Config/Base.xcconfig`.
- `CURRENT_PROJECT_VERSION` (`CFBundleVersion`) is the GitHub Actions run number in a release build, and
  the number of commits on `HEAD` in a local build.

## Release (issue Release)

This work waits until the owner joins the Apple Developer Program, which gives the Developer ID
certificate.

A second workflow, `.github/workflows/release.yml`, runs on a tag `v*`:

1. Archive the Release flavor.
2. Sign it with the Developer ID Application certificate and the hardened runtime.
3. Notarize it with `notarytool` and staple the ticket.
4. Make a DMG, then sign, notarize and staple the DMG.
5. Make the Sparkle 2 appcast entry, signed with the EdDSA key from the repo secrets.
6. Create a GitHub Release with the DMG and the release notes, and publish the appcast.
7. Update the cask in the owner's Homebrew tap (`matikka96/homebrew-tap`).

The app includes Sparkle 2 with "Check for Updates…" in the right-click menu and an automatic check once a
day. `make release` runs steps 1–4 on the local Mac for a test.

## Acceptance criteria

- A push to `main` runs CI, and the run finishes in less than 5 minutes.
- A push to `dev` runs nothing.
- A tag produces a notarized DMG that opens on a clean Mac with no Gatekeeper warning, and Sparkle offers
  the update to the previous version.
