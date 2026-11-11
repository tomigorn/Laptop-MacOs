# Software updates — `mac-outdated`

One command for every outdated piece of software on this Mac. Install: `software-updates/install.sh` (links it into `~/.local/bin`, the fish completion into `~/.config/fish/completions`).

| Command | Admin | Does |
|---|---|---|
| `mac-outdated` | no | check all sources, print progress, details and a summary, write the last-check stamp (not when a check failed) |
| `mac-outdated --install` | yes, >= 15 min left | `sudo -v`, install every available update except third-party tap formulae (held for review); sudo asks again before a step when the last sudo was over a minute ago; the macOS step asks for your sudo password and then the owner password (both your login password) |
| `mac-outdated --help`, `-h` | no | usage and examples |
| `mac-outdated --version` | no | print the version (from `software-updates/VERSION`) |

Exit: `0` nothing outdated / all installed, `1` something outdated / a check or step failed, `2` usage error or admin precondition not met, `130` interrupted.

## Output

```
mac-outdated v1.0.0 · 2026-11-03 11:20

  brew ......................... 33 outdated
  brew taps .................... 1 by hand
  brew vulnerabilities ......... none known
  Install scripts .............. up to date
  Microsoft AutoUpdate ......... up to date
  Adobe ........................ checked during --install
  App Store .................... skipped (mas not installed)
  uv tools ..................... none installed
  VS Code extensions ........... 3 extensions, updated during --install
  xxh remote binaries .......... 1 outdated
  Sparkle apps ................. 1 to open

══════════════════════════════════════════════════════════
 brew · 33 outdated
══════════════════════════════════════════════════════════
  formulae
    openssl@3                3.6.3     →  3.5.9  (older version: brew moved to the 3.5 line)

══════════════════════════════════════════════════════════
 brew taps · 1 by hand
══════════════════════════════════════════════════════════
  arthurk/virt-manager: nothing installed from it, no commit since 2021-05-11: brew untap arthurk/virt-manager

══════════════════════════════════════════════════════════
 VS Code extensions · 3 installed
══════════════════════════════════════════════════════════
    catppuccin.catppuccin-vsc  3.19.0

══════════════════════════════════════════════════════════
 xxh remote binaries · 1 outdated
══════════════════════════════════════════════════════════
    starship                 1.27.0  →  1.28.0
  bump the pin in terminal/remote-binaries.conf, then terminal/install.sh --refresh-remote

══════════════════════════════════════════════════════════
 Open to update · 2
══════════════════════════════════════════════════════════
  These apps update themselves on start: open them by hand.
    Discord                  0.0.420  →  0.0.421
    Fork                     2.70.2   →  2.71.0
  also update themselves on start: Google Chrome, Brave Browser, Firefox, …

══════════════════════════════════════════════════════════
 Summary
══════════════════════════════════════════════════════════
  brew                          33   mac-outdated --install
  brew taps by hand              1   brew untap arthurk/virt-manager
  xxh remote binaries            1   terminal/install.sh --refresh-remote
  open to update                 2   open the app (updates on start)
  ────────────────────────────────
  total                         37   33 via --install · 4 by hand

  next: mac-outdated --install
```

- One line per source while checking, then a detail section only for sources with outdated items or notes; the summary lists sources with something to report (`?` unknown, `–` skipped, `!` check failed). Adobe is only listed with admin, so check mode shows `checked during --install`.
- A source that could not be checked (`brew outdated`, `brew tap`, `msupdate --list`, `mas outdated`, `softwareupdate --list`, `pipx list`, `uv tool list`, GitHub for xxh, `RemoteUpdateManager` failing, e.g. offline) shows `check failed` in red, counts as `N checks failed` in the total, exits 1 and leaves the last-check stamp alone, so the greeting keeps reminding.
- `(older version: brew moved to the X.Y line)`: brew deliberately moved to an older (LTS) line; `--install` still installs it and it counts as outdated.
- Third-party tap formulae (yabai, skhd) are held for review, counted by hand: `yabai 7.1.25 → 7.1.26, third-party tap, held for review: released 3 days ago, wait 11 more days · changes: <compare link> · then: brew upgrade yabai`. Read the changes, wait until the release is 14 days old, then run the command. Limits: yabai ships a prebuilt binary the source can't vouch for, and `brew outdated` already loads the tap's formula file, so a compromised tap runs code at the check.
- `brew vulnerabilities`: one note per package with known issues, `libsndfile 1.2.2: 2 high, 3 medium, 1 unknown`, without those fixed by a formula patch; never counted as outdated, `brew vulns` shows the details. No result (offline, no `brew vulns`): `could not check`, the stamp is still written.
- brew warns `The following taps are not trusted:` (in `brew update`/`brew outdated` stderr) -> yellow note `brew ignores untrusted tap <tap> (its formulae get no updates): brew trust --formula <tap>/<formula> …` with the installed formulae of that tap (also those installed under the tap's old name), counted by hand (`brew by hand` row).
- xxh remote binaries are outdated items counted by hand (`N outdated` on the progress line, not via `--install`): the pins are bumped deliberately.
- "Open to update" (sorted by name, counted by hand, not under their source):
  - outdated Sparkle apps (progress line `N to open`)
  - outdated casks with `auto_updates` (not counted on the brew line)
  - outdated apps from the self-updating list, from any source
- "also update themselves on start" lists the other installed self-updating apps, minus those managed by a brew cask; shown also when nothing is outdated (then without the "Open to update" header).
- Outdated casks are checked against the real app (`CFBundleShortVersionString` in `/Applications` or `~/Applications`):

| Real app | Shown | Counts |
|---|---|---|
| at or above brew's latest | dim `<token>: app already at <ver> (brew's record is stale)`, in the brew section, else under "Open to update" | no |
| older, cask `auto_updates` | "Open to update" | by hand |
| older (or unknown), no `auto_updates` | casks row | via `--install` |

- brew can't replace an app ("Operation not permitted"): give the terminal App Management permission (System Settings > Privacy & Security > App Management), or let the app update itself.
- `--install` prints a `── <source>` block per step with the tool output indented as it arrives (macOS runs through `script(1)` straight on the terminal, not indented: both password prompts stay hidden; stdin not a terminal: plain `sudo softwareupdate`; Ctrl-C there -> `interrupted`), a result line (`installed` / `up to date` / `failed (exit N)` / `skipped (<tool> not installed)` / `skipped (admin expired: …)` / `skipped (admin expires in N min: …)`) and a summary. After the `total` row: `✓ nothing failed`, or `✗ failed: <step> (<why>), …` with the log path and `rerun: mac-outdated --install`; then a `By hand` block.

  | By hand lists | Example |
  |---|---|
  | self-updating apps | `discord: open the app, it updates itself` |
  | restart required (only labels marked `Action: restart`) | `macOS <label>: restart the Mac when it suits you` |
  | skipped (admin expired) | `App Store: skipped, admin expired: click Privileges, then mac-outdated --install` |
  | skipped (admin nearly out) | `App Store: skipped, admin expires in 1 min: click Privileges, then mac-outdated --install` |
  | pipx link conflict | `pipx example-tool: ~/.local/bin/example-tool links elsewhere: rm it, then pipx reinstall example-tool` |
  | held third-party formulae | `yabai: third-party tap, held for review (mac-outdated lists it)` |

  Nothing to list: `nothing to do by hand`. Both also print after Ctrl-C. Exit code unchanged.
- `up to date` instead of `installed` when nothing was updated:

| Source | Signal |
|---|---|
| Adobe | `No new applicable Updates` |
| App Store | `mas outdated` lists nothing (then no `mas upgrade`, no admin check) |
| pipx | `No packages upgraded` |
| uv tools | `Nothing to upgrade` |
| VS Code extensions | `No extension to update` |
| Microsoft AutoUpdate, macOS | `--list` finds nothing |

- Repetitive tool output folds on the terminal (blank lines dropped), the log keeps all:

| More than 5 lines in a row with | Shows | Example |
|---|---|---|
| the same first word and ending | the first 3, `… N more similar lines (full output in log)` | 300 × `chown: …: Operation not permitted` |
| the same text before the first `:` | the first, `… N progress lines (full output in log)`, the last | `Update Assistant: …` from `msupdate --install` |

- Adobe exit 2 (an update could not be installed, often because an Adobe app is open; details in Adobe's RUM log) shows yellow `some updates failed (Adobe exit 2: …)`, still exit 1; exit 1 is `failed (exit 1)`.
- Ctrl-C during `--install` stops the whole run: the current step ends, then `interrupted — remaining steps not run`, the summary so far (`interrupted` / `not run`), exit 130. A step ending with 130 counts the same.
- Every run (check and `--install`) writes its full output without colour codes to `~/.local/state/mac-outdated/logs/<YYYY-MM-DD-HHMMSS>-<check|install>.log`; the newest 20 are kept. Last line on the terminal: `log: <path>`. Log only: first line `mac-outdated <version> · <mode> · <date time>`, per `--install` step `step <src>: start <time>` and `step <src>: end <time>, <N>s, exit <rc>, <result>`, last line `end <time>, <N>s total`. sudo prompts go to the terminal only; `softwareupdate --install` output and `softwareupdate --list` before/after go to the log.
- Colours only on a terminal; `NO_COLOR=1` turns them off, `MAC_OUTDATED_COLOR=always` forces them.
- Colours (traffic light):

| Colour | Means |
|---|---|
| green | `up to date`, `installed`, `none installed` (uv tools) |
| yellow | outdated: count, name, new version, `(older version …)`, by-hand hints, `skipped (…)`, `some updates failed (…)`, summary counts |
| red | `check failed`, `failed (exit N)`, `interrupted`, `not run`, `!` rows |
| dim | installed version, notes, informational lines |

## Sources

| Source | Check | Install |
|---|---|---|
| brew (formulae + casks) | `brew outdated --greedy --json=v2` (after `brew update`), casks checked against the real app | `brew upgrade --formula` (naming the formulae when a third-party tap formula is installed, those are held), then `brew upgrade --cask <tokens>` only for non-auto-updating casks whose app is older; never `--greedy`, never under sudo |
| brew taps | `brew tap` minus core/cask: by hand when nothing installed comes from the tap (`brew list --full-name`; installed under the tap's old owner counts, e.g. `koekeishiya/formulae/yabai` for `asmvik/formulae`) or its last commit is over 2 years old (`git log` in `brew --repo <tap>`); loads no formula from the tap | none: `brew untap <tap>` |
| brew vulnerabilities | `brew vulns --json` (OSV.dev; formulae only, some skipped), info only | none |
| Install scripts | `*.sh` and `install*` files of this repo (found from the script's real path; `.git`, `tests`, `fixtures` skipped) naming `brew install <owner>/<tap>/<name>` or `brew tap <owner>/<tap>` for a tap that is not tapped (comments and `homebrew/*` skipped) | none: fix the script |
| Microsoft AutoUpdate | `msupdate --list`, lines `<app ID>  <title> Update <version> (<build>)`: app ID -> app (`MSWD2019` Word, `XCEL2019` Excel, `PPT32019` PowerPoint, `OPIM2019` Outlook, `ONMC2019` OneNote, `ONDR18` OneDrive, `MSau04` AutoUpdate, Teams, Defender, Edge, …; unknown ID: the title), installed = the app's `CFBundleShortVersionString`, latest = the title's version (the build only without one) | `msupdate --list` first: no updates -> `up to date`; else `msupdate --install --wait 600` (without a wait it can hang until the MAU window is clicked) |
| Adobe | `RemoteUpdateManager --action=list` (needs admin, else a note) | `sudo RemoteUpdateManager --action=install` |
| App Store | `mas outdated --json` (note if `mas` is missing) | `mas outdated` first: nothing -> `up to date`; else `sudo mas upgrade` (mas needs root to update apps) |
| macOS | `softwareupdate --list` | `softwareupdate --list` first: nothing new -> `up to date` (no admin, no sudo); else `sudo softwareupdate --install --all` through `script -q`, never restarts; then `--list` again: nothing left -> `installed`; still offered: labels whose `--list` entry says `Action: restart` count as staged when the output mentions restart, all others (Command Line Tools, …) as failed; nothing failed -> `installed, restart required`, else `failed (still offered after install: <labels>)` plus `; owner password empty or wrong?` when no restart label was staged; `--list` failing -> `installed (not verified: …)`; stdin not a terminal and still offered -> `not verified (still offered, no terminal: restart if macOS asks, else rerun in a terminal)`, counts as failed |
| pipx | `pipx list --json` + `pip index versions` (packages installed from a local path are skipped; non-zero exit with valid JSON -> note `pipx reports a broken package: run pipx reinstall-all`) | `pipx upgrade-all` |
| uv tools | `uv tool list --outdated` (`none installed` without tools; skipped when uv is missing) | `uv tool upgrade --all` |
| VS Code extensions | count on the progress line, then a section with every extension and its version (`code --list-extensions --show-versions`), shown also when nothing is outdated; no outdated check | `code --update-extensions` (all) |
| xxh remote binaries | `~/.xxh/arch/<arch>/VERSIONS` (`tool version` per line, written by `terminal/install.sh`) vs GitHub's latest release (API, then the `releases/latest` page redirect when the API is rate limited); one row per tool, `tool (<arch>)` when the stores differ; no `VERSIONS` -> by hand `run terminal/install.sh --refresh-remote`; no store -> `none stored` | none: bump the pin in `terminal/remote-binaries.conf`, then `terminal/install.sh --refresh-remote` |
| Sparkle apps | appcast from `SUFeedURL` (beta channel skipped); no `SUFeedURL` (VLC, TeamViewer): the cask that installs the app, as for apps without an updater | none: "Open to update"; no feed and cask without `auto_updates`: `brew install --cask --force <token>` |
| Apps without an updater | cask that installs the app (see below) | none: `brew install --cask --force <token>` (replaces the older app, settings stay; `--adopt` only takes an identical version); `auto_updates` cask -> "Open to update" |
| Self-updating (Chrome, Brave, Firefox, Discord, Signal, Obsidian, Docker, Steam, Zoom, Element, Autodesk Fusion, iStat Menus) | listed once | none: update on start |

App -> cask lookup (no network, no `brew info` per app):

| Step | Source |
|---|---|
| 1 | Homebrew's API cache, `$(brew --cache)/api/internal/packages.*.jws.json` (older brew: `api/cask.jws.json`) |
| 2 | the cask's `app` artifact (`BambuStudio.app` -> `bambu-studio`), else `/Applications/<x>.app` in its `uninstall delete` (`logioptionsplus.app` -> `logi-options+`) |
| 3 | several casks for one app: the token named like the app, then one without `@` (`firefox` before `firefox@beta`); disabled casks skipped |
| no cache | the cask named like the app (`brew info --cask <name>`) |

Run it as your own user, never with sudo: `--install` asks for the password itself. Install order: Adobe, App Store (sudo, short), brew, Microsoft, pipx, uv tools, VS Code, macOS last (sudo, longest). A failing source does not stop the others; a summary follows.

`brew upgrade --cask` runs each cask's own uninstall/quit steps: it may quit running apps and show macOS Automation/App Management prompts, and pkg casks (e.g. XQuartz) call sudo themselves. Quit Discord, BetterDisplay, Hiddenbar, UTM, XQuartz and apps launched from Ghostty before running.

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
| `software-updates/VERSION` | the version, shown in the header, `--help` and `--version` |
| `software-updates/install.sh` | symlinks into `~/.local/bin` and `~/.config/fish/completions` |
| `software-updates/completions/mac-outdated.fish` | fish tab completion: `--install`, `--version`, `--help` |
| `software-updates/tests/mac-outdated.sh` | offline tests, every tool stubbed |
| `~/.local/state/mac-outdated/last-check` | epoch of the last check without a failed source |
| `~/.local/state/mac-outdated/logs/` | one log per run, newest 20 kept |
