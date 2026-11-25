# mac-outdated: colours inside the --install blocks

Date: 2026-11-20. Trigger: `--install` run 14:29: step results are green, but mac-outdated's own lines inside a block are plain and drown in tool output. Built in 1.5.0.

## Goal
Inside each `--install` block, mac-outdated's own lines get the existing `c()` colours, tool output stays plain. The brew block ends with one result line per package.

## Done-list
**Own lines** (only in `--install`, colours from `c()`, nothing new)
- [x] Green, done: `<token>: removed brew's leftover backup …` (both variants).
- [x] Yellow, you act: `<token>: updates itself on start, open the app` · `<name>: third-party tap, held for review (see mac-outdated)` · `<name>: ETH-licensed, ETH Self Service offers <v>`.
- [x] Dim, info only: `<token>: app already current, brew's record is stale` · `<name>: ETH-licensed, App Store has <v>, left to Jamf / ETH Self Service`.
- [x] Red, error: `jq not found: brew install jq` · `brew update failed, upgrading anyway` · `brew outdated failed, no formula upgraded` · `brew outdated --cask failed` · `mas outdated failed, nothing upgraded` · `sudo failed`.
- [x] Tool output (brew, mas, msupdate, pipx, uv, code, softwareupdate, RemoteUpdateManager) unchanged and plain.

**brew result lines**
- [x] At the end of the brew block, one line per formula and cask it tried to upgrade: green `gpgme 2.2.0 → 2.3.1 ✓`; still outdated afterwards (second `brew outdated`) red `utm 5.0.9 → 5.0.9-2 ✗`. Aligned like the check-mode rows.
- [x] Held, self-updating and stale casks get no result line (they already have their own line).
- [x] Nothing tried: no result lines.

**Everywhere**
- [x] Log keeps every line without colour codes (as today).
- [x] `NO_COLOR` / not a terminal: no escape codes (as today).
- [x] Tests for each item; `software-updates.md` example updated; version 1.5.0.
- [ ] Verify: tests pass and `MAC_OUTDATED_COLOR=always` test runs show the codes (done); the owner's next real `--install` shows the colours (open, needs admin).

## Untouched
- Check mode, the step result words and their colours, the summary, By hand, failure logic.
- No per-package lines for App Store, pipx, uv, VS Code, Microsoft, macOS (only brew).

## Decisions (2026-11-20)
- Option A: colour only mac-outdated's own lines plus brew per-package results; tool output stays plain.
- Success per package from a second `brew outdated --json=v2` after the upgrades (local, no parsing of brew's text).
- That second `brew outdated` failing: red `brew outdated failed, results unknown`, no result lines, step result unchanged.
