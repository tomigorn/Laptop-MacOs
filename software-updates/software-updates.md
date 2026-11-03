# Software updates — `mac-outdated`

One command for every outdated piece of software on this Mac. Install: `software-updates/install.sh` (links it into `~/.local/bin`).

| Command | Admin | Does |
|---|---|---|
| `mac-outdated` | no | check all sources, print progress, details and a summary, write the last-check stamp (not when a check failed) |
| `mac-outdated --install` | yes, >= 15 min left | `sudo -v`, install every available update; sudo may ask for your password at the start, during brew (some casks), and again for later steps |
| `mac-outdated --help` | no | usage |

Exit: `0` nothing outdated / all installed, `1` something outdated / a check or step failed, `2` usage error or admin precondition not met, `130` interrupted.

## Output

```
mac-outdated · 2026-11-03 11:20

  brew ......................... 33 outdated
  Microsoft AutoUpdate ......... up to date
  Adobe ........................ checked during --install
  App Store .................... skipped (mas not installed)

══════════════════════════════════════════════════════════
 brew · 33 outdated
══════════════════════════════════════════════════════════
  formulae
    openssl@3                3.6.3     →  3.5.9  (older version: brew moved to the 3.5 line)

══════════════════════════════════════════════════════════
 Summary
══════════════════════════════════════════════════════════
  brew                        33   mac-outdated --install
  ────────────────────────────────
  total                       33   33 via --install · 0 by hand

  next: mac-outdated --install
```

- One line per source while checking, then a detail section only for sources with outdated items or notes; the summary lists sources with something to report (`?` unknown, `–` skipped, `!` check failed). Adobe is only listed with admin, so check mode shows `checked during --install`.
- A source that could not be checked (`brew outdated`, `msupdate --list`, `mas outdated`, `softwareupdate --list`, `pipx list`, `RemoteUpdateManager` failing, e.g. offline) shows `check failed` in red, counts as `N checks failed` in the total, exits 1 and leaves the last-check stamp alone, so the greeting keeps reminding.
- `(older version: brew moved to the X.Y line)`: brew deliberately moved to an older (LTS) line; `--install` still installs it and it counts as outdated.
- brew warns `The following taps are not trusted:` (in `brew update`/`brew outdated` stderr) -> yellow note `brew ignores untrusted tap <tap> (its formulae get no updates): brew trust --formula <tap>/<formula> …` with the installed formulae of that tap (also those installed under the tap's old name), counted by hand (`brew by hand` row).
- "updates itself on launch" lists apps with their own updater, minus those managed by a brew cask.
- `--install` prints a `── <source>` block per step with the tool output indented as it arrives (macOS runs straight on the terminal: `softwareupdate` may ask for the owner password), a result line (`installed` / `up to date` / `failed (exit N)` / `skipped (<tool> not installed)` / `skipped (admin expired: …)` / `skipped (admin expires in N min: …)`) and a summary.
- Adobe exit 2 (an update could not be installed, often because an Adobe app is open; details in Adobe's RUM log) shows yellow `some updates failed (Adobe exit 2: …)`, still exit 1; exit 1 is `failed (exit 1)`.
- Ctrl-C during `--install` stops the whole run: the current step ends, then `interrupted — remaining steps not run`, the summary so far (`interrupted` / `not run`), exit 130. A step ending with 130 counts the same.
- Colours only on a terminal; `NO_COLOR=1` turns them off, `MAC_OUTDATED_COLOR=always` forces them.
- Colours (traffic light):

| Colour | Means |
|---|---|
| green | `up to date`, `installed` |
| yellow | outdated: count, name, new version, `(older version …)`, by-hand hints, `skipped (…)`, `some updates failed (…)`, summary counts |
| red | `check failed`, `failed (exit N)`, `interrupted`, `not run`, `!` rows |
| dim | installed version, notes, informational lines |

## Sources

| Source | Check | Install |
|---|---|---|
| brew (formulae + casks) | `brew outdated --greedy --json=v2` (after `brew update`) | `brew upgrade --greedy`, never under sudo |
| Microsoft AutoUpdate | `msupdate --list` | `msupdate --list` first: no updates -> `up to date`; else `msupdate --install --wait 600` (without a wait it can hang until the MAU window is clicked) |
| Adobe | `RemoteUpdateManager --action=list` (needs admin, else a note) | `sudo RemoteUpdateManager --action=install` |
| App Store | `mas outdated --json` (note if `mas` is missing) | `sudo mas upgrade` (mas needs root to update apps) |
| macOS | `softwareupdate --list` | `softwareupdate --list` first: nothing new -> `up to date` (no admin, no sudo); else `sudo softwareupdate --install --all`, never restarts; `restart required` only after a successful install |
| pipx | `pipx list --json` + `pip index versions` (packages installed from a local path are skipped; non-zero exit with valid JSON -> note `pipx reports a broken package: run pipx reinstall-all`) | `pipx upgrade-all` |
| VS Code extensions | count only | `code --update-extensions` |
| Sparkle apps | appcast from `SUFeedURL` (beta channel skipped) | none: open the app |
| Apps without an updater | cask with the same app name | none: `brew install --cask --adopt <token>` |
| Self-updating (Chrome, Brave, Firefox, Discord, Signal, Obsidian, Docker, Steam, Zoom, Element, Autodesk Fusion, iStat Menus) | listed once | none: update on launch |

Run it as your own user, never with sudo: `--install` asks for the password itself. Install order: Adobe, App Store (sudo, short), brew, Microsoft, pipx, VS Code, macOS last (sudo, longest). A failing source does not stop the others; a summary follows.

`brew upgrade --greedy` runs each cask's own uninstall/quit steps: it may quit running apps and show macOS Automation/App Management prompts, and pkg casks (e.g. XQuartz) call sudo themselves. Quit Discord, BetterDisplay, Hiddenbar, UTM, XQuartz and apps launched from Ghostty before running.

## Admin rules

- Never asks for or changes admin rights itself: elevation is your click in Privileges (menu bar lock icon).
- No sudo keep-alive, no `sudo -S`, no stored password, no restart.
- The tests' path overrides (`MAC_OUTDATED_RUM`, `…_MSUPDATE`, `…_PRIVILEGESCLI`, `…_APP_DIRS`) count only with `MAC_OUTDATED_TEST=1`, so nothing from the environment picks what runs under sudo.
- Before each sudo step (Adobe, App Store, macOS) `PrivilegesCLI --status` is checked again, the others go on, exit 1:
  - admin gone -> `skipped (admin expired: click Privileges and rerun)`
  - under 2 min left -> `skipped (admin expires in N min: click Privileges and rerun)`
  - time unknown -> runs (the start already checked it)
- Admin means `PrivilegesCLI --status` says `has administrator privileges` (or `Administrator privileges have been assigned`); any other text, e.g. `Standard user privileges have been assigned by your administrator`, is not admin.
- Not admin -> exit 2. Less than 15 min left (`expire in N minutes` from `PrivilegesCLI --status`) -> exit 2. Time unknown -> asks `Continue anyway? [y/N]`.

## Greeting

New fish shells show `software not checked for N days: mac-outdated` when the last check is older than 7 days (`software not checked yet` without a stamp). Mac only, the greeting never runs the check.

## Files

| Path | What |
|---|---|
| `software-updates/mac-outdated` | the script (bash 5) |
| `software-updates/install.sh` | symlink into `~/.local/bin` |
| `software-updates/tests/mac-outdated.sh` | offline tests, every tool stubbed |
| `~/.local/state/mac-outdated/last-check` | epoch of the last check without a failed source |
