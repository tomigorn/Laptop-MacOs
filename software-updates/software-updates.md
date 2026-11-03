# Software updates — `mac-outdated`

One command for every outdated piece of software on this Mac. Install: `software-updates/install.sh` (links it into `~/.local/bin`).

| Command | Admin | Does |
|---|---|---|
| `mac-outdated` | no | check all sources, print progress, details and a summary, write the last-check stamp |
| `mac-outdated --install` | yes, >= 15 min left | `sudo -v` once, install every available update |
| `mac-outdated --help` | no | usage |

Exit: `0` nothing outdated / all installed, `1` something outdated / something failed, `2` usage error or admin precondition not met.

## Output

```
mac-outdated · 2026-11-03 11:20

  brew ......................... 33 outdated
  Microsoft AutoUpdate ......... up to date
  Adobe ........................ needs admin to list
  App Store .................... skipped (mas not installed)

══════════════════════════════════════════════════════════
 brew · 33 outdated
══════════════════════════════════════════════════════════
  formulae
    openssl@3                3.6.3     →  3.5.9  (downgrade)

══════════════════════════════════════════════════════════
 Summary
══════════════════════════════════════════════════════════
  brew                        33   mac-outdated --install
  Adobe                        ?   listing needs admin
  ────────────────────────────────
  total                       33   33 via --install · 0 by hand

  next: mac-outdated --install
```

- One line per source while checking, then a detail section only for sources with outdated items or notes; the summary lists sources with something to report (`?` unknown, `–` skipped).
- `--install` prints a `── <source>` block with the indented tool output per step, a result line (`installed` / `up to date` / `failed (exit N)` / `skipped (…)`) and a summary.
- Colours only on a terminal; `NO_COLOR=1` turns them off, `MAC_OUTDATED_COLOR=always` forces them.

## Sources

| Source | Check | Install |
|---|---|---|
| brew (formulae + casks) | `brew outdated --greedy --json=v2` (after `brew update`) | `brew upgrade --greedy`, never under sudo |
| Microsoft AutoUpdate | `msupdate --list` | `msupdate --install` |
| Adobe | `RemoteUpdateManager --action=list` (needs admin, else a note) | `sudo RemoteUpdateManager --action=install` |
| App Store | `mas outdated` (note if `mas` is missing) | `mas upgrade` |
| macOS | `softwareupdate --list` | `sudo softwareupdate --install --all`, never restarts |
| pipx | `pipx list --json` + `pip index versions` (packages installed from a local path are skipped) | `pipx upgrade-all` |
| VS Code extensions | count only | `code --update-extensions` |
| Sparkle apps | appcast from `SUFeedURL` (beta channel skipped) | none: open the app |
| Apps without an updater | cask with the same app name | none: `brew install --cask --adopt <token>` |
| Self-updating (Chrome, Brave, Firefox, Discord, Signal, Obsidian, Docker, Steam, Zoom, Element, Autodesk Fusion) | listed once | none: update on launch |

Run it as your own user, never with sudo: `--install` asks for the password itself. Install order: macOS, Adobe (sudo), then brew, Microsoft, App Store, pipx, VS Code. A failing source does not stop the others; a summary follows.

## Admin rules

- Never asks for or changes admin rights itself: elevation is your click in Privileges (menu bar lock icon).
- No sudo keep-alive, no `sudo -S`, no stored password, no restart.
- Not admin -> exit 2. Less than 15 min left (`expire in N minutes` from `PrivilegesCLI --status`) -> exit 2. Time unknown -> asks `Continue anyway? [y/N]`.

## Greeting

New fish shells show `software not checked for N days: mac-outdated` when the last check is older than 7 days (`software not checked yet` without a stamp). Mac only, the greeting never runs the check.

## Files

| Path | What |
|---|---|
| `software-updates/mac-outdated` | the script (bash 5) |
| `software-updates/install.sh` | symlink into `~/.local/bin` |
| `software-updates/tests/mac-outdated.sh` | offline tests, every tool stubbed |
| `~/.local/state/mac-outdated/last-check` | epoch of the last check run |
