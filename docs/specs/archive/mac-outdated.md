# mac-outdated

One command that shows every outdated piece of software on this Mac and can install the updates.

## Folder
```
software-updates/
  mac-outdated              bash 5 script (#!/opt/homebrew/bin/bash), works from fish, zsh, bash
  install.sh                links mac-outdated -> ~/.local/bin/mac-outdated (same symlink helper style as ssh/install.sh)
  software-updates.md       short doc
  tests/mac-outdated.sh     offline tests, every external tool stubbed
```
README index row, CLAUDE.md install step, tests/tests.md.

## Usage
| Command | Admin | Does |
|---|---|---|
| `mac-outdated` | no | check all sources, print one table, write last-check stamp |
| `mac-outdated --install` | yes | require admin with >= 15 min left, `sudo -v` once, install every available update |
| `mac-outdated --help` | no | usage |

Exit codes: 0 nothing outdated / all installed, 1 something outdated (check mode) or something failed (install mode), 2 usage error or admin precondition not met.

## Sources
Each source is a function pair `check_<src>` (prints `src|name|installed|latest|note` lines) and `install_<src>`. A missing tool is a note line ("mas not installed: brew install mas"), never a crash.

| Source | Check | Install | Note |
|---|---|---|---|
| brew | `brew outdated --greedy --json=v2` (formulae + casks) | `brew upgrade --greedy` | never under sudo; `brew update` first in both modes |
| Microsoft AutoUpdate | `msupdate --list` | `msupdate --install` | path `/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app/Contents/MacOS/msupdate` |
| Adobe | `/usr/local/bin/RemoteUpdateManager --action=list` | `sudo RemoteUpdateManager --action=install` | |
| App Store | `mas outdated` | `mas upgrade` | skip with note if mas missing |
| macOS | `softwareupdate --list` | `sudo softwareupdate --install --all` | never restarts; prints "restart required" if reported |
| pipx | `pipx list --json`: per package, latest from `pipx runpip <pkg> index versions <pkg>` (first line) | `pipx upgrade-all` | lookup failure -> note, not an error |
| VS Code extensions | `code --list-extensions --show-versions` (report count) | `code --update-extensions` | `code` found via PATH or `~/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code` |
| Sparkle apps | for apps in /Applications and ~/Applications with Sparkle.framework: `SUFeedURL` from Info.plist, fetch appcast (curl, 10 s timeout), compare newest `sparkle:shortVersionString`/`sparkle:version` with CFBundleShortVersionString | none: note "open <App> to update" | |
| Unmanaged apps | apps not from brew/App Store/Sparkle/known self-updaters: look up a cask with the same app name (`brew search --cask`-free: `brew info --cask --json=v2` over the cask token derived from the app name); compare versions | none: note `brew install --cask --adopt <token>` | Jamf/ETH-managed and Microsoft/Adobe apps excluded |
| Self-updating | Chrome, Brave, Firefox, Discord, Signal, Obsidian, Docker, Steam, Zoom, Element, Autodesk Fusion | none | listed once as "updates itself on launch" |

## Admin precondition (--install)
- Rules: the tool never requests or changes admin rights (no `PrivilegesCLI --add/--remove`), no sudo keep-alive loop, no `sudo -S`, no stored password. Elevation is the user's click in the Privileges app.
- Admin check: `PrivilegesCLI --status` output contains "administrator" (path `/Applications/Privileges.app/Contents/MacOS/PrivilegesCLI`). Not admin -> print "Click Privileges (lock icon in the menu bar), then rerun mac-outdated --install", exit 2.
- Expiry interval: `ExpirationInterval` from `/Library/Managed Preferences/corp.sap.privileges.plist` (plutil/PlistBuddy read; currently 20). Missing -> unknown.
- Grant time: newest Privileges grant in the unified log (`log show --last 1h --style ndjson --predicate 'subsystem BEGINSWITH "corp.sap.privileges"'`), isolated in one function so the parser can be fixed after a live check. Not found -> unknown.
- Remaining = interval - (now - grant). >= 15 -> continue. < 15 -> "only N min of admin left, need 15: revert and click Privileges again", exit 2. Unknown -> "admin time left unknown" + `Continue anyway? [y/N]`, default no -> exit 2.
- Then `sudo -v` once (normal password prompt), then install: sudo sources first (macOS, Adobe), then brew, MAU, mas, pipx, VS Code extensions. A failing source does not stop the others; summary table at the end; failures exit 1.

## Check output
Grouped by source, one line per outdated item: `name  installed -> latest`, plus note lines. Last line: `N outdated, M need a manual step` and, if anything is installable, `run: mac-outdated --install`.
Last-check stamp: `~/.local/state/mac-outdated/last-check` (epoch seconds), written after every check run.

## Greeting nudge (terminal/)
`fish_greeting`: if `mac-outdated` is on PATH and the stamp is missing or older than 7 days -> one line `software not checked for N days: mac-outdated`. No check runs in the greeting itself. Terminal minor bump.

## Tests (offline, stubs on PATH, HOME in a temp dir)
- check: each source parses its stubbed output into the right lines; missing tool -> note, no crash; nothing outdated -> exit 0; something outdated -> exit 1; stamp written.
- install: not admin -> exit 2 and no install command run; admin, 20 min left -> sudo -v then installs in order sudo sources first; 10 min left -> exit 2, nothing run; unknown time + "n" -> exit 2; unknown + "y" -> runs; one source failing -> others still run, exit 1; never calls PrivilegesCLI with --add/--remove (assert on stub log); brew never run via sudo.
- greeting: stamp 8 days old -> nudge line; 1 day -> none; mac-outdated not on PATH -> none.
