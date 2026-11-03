# Software updates — `mac-outdated`

One command for every outdated piece of software on this Mac. Install: `software-updates/install.sh` (links it into `~/.local/bin`).

| Command | Admin | Does |
|---|---|---|
| `mac-outdated` | no | check all sources, print one list, write the last-check stamp |
| `mac-outdated --install` | yes, >= 15 min left | `sudo -v` once, install every available update |
| `mac-outdated --help` | no | usage |

Exit: `0` nothing outdated / all installed, `1` something outdated / something failed, `2` usage error or admin precondition not met.

## Sources

| Source | Check | Install |
|---|---|---|
| brew (formulae + casks) | `brew outdated --greedy --json=v2` (after `brew update`) | `brew upgrade --greedy`, never under sudo |
| Microsoft AutoUpdate | `msupdate --list` | `msupdate --install` |
| Adobe | `RemoteUpdateManager --action=list` (needs admin, else a note) | `sudo RemoteUpdateManager --action=install` |
| App Store | `mas outdated` (note if `mas` is missing) | `mas upgrade` |
| macOS | `softwareupdate --list` | `sudo softwareupdate --install --all`, never restarts |
| pipx | `pipx list --json` + `pip index versions` | `pipx upgrade-all` |
| VS Code extensions | count only | `code --update-extensions` |
| Sparkle apps | appcast from `SUFeedURL` (beta channel skipped) | none: open the app |
| Apps without an updater | cask with the same app name | none: `brew install --cask --adopt <token>` |
| Self-updating (Chrome, Brave, Firefox, Discord, Signal, Obsidian, Docker, Steam, Zoom, Element, Autodesk Fusion) | listed once | none: update on launch |

Install order: macOS, Adobe (sudo), then brew, Microsoft, App Store, pipx, VS Code. A failing source does not stop the others; a summary follows.

## Admin rules

- Never asks for or changes admin rights itself: elevation is your click in Privileges (menu bar lock icon).
- No sudo keep-alive, no `sudo -S`, no stored password, no restart.
- Not admin -> exit 2. Less than 15 min left (`ExpirationInterval` from the managed Privileges plist minus time since the grant in the unified log) -> exit 2. Time unknown -> asks `Continue anyway? [y/N]`.

## Greeting

New fish shells show `software not checked for N days: mac-outdated` when the last check is older than 7 days (`software not checked yet` without a stamp). Mac only, the greeting never runs the check.

## Files

| Path | What |
|---|---|
| `software-updates/mac-outdated` | the script (bash 5) |
| `software-updates/install.sh` | symlink into `~/.local/bin` |
| `software-updates/tests/mac-outdated.sh` | offline tests, every tool stubbed |
| `~/.local/state/mac-outdated/last-check` | epoch of the last check run |
