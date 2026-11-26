# mac-outdated: apps to open in --install

Date: 2026-11-26. Version 1.6.0.

## Goal
`--install` runs only the install sources, so self-updating, Sparkle and no-updater apps never show up there. On 2026-11-26 a clean `--install` was followed by a plain run with 7 apps to open (Firefox, Fork, Chrome, iStat Menus, Teams, OneDrive, Shottr). `--install` now checks them at the end and lists them under By hand.

## Done-list
- [x] New step `── Apps to open` after macOS, before the Summary; needs no admin, runs after brew so freshly upgraded casks are not listed
- [x] It runs the existing checks: Self-updating apps, Sparkle apps, Apps without an updater (same logic as check mode, no copy)
- [x] Step result: `N to open` (yellow), `up to date` (green), `check failed (<why>)` (red, no brew or jq)
- [x] Summary table: row `Apps to open` with that result; total adds `N to open`; `check failed` counts as failed
- [x] By hand, one yellow line per app, sorted by name:
  - self-updating / Sparkle / `auto_updates` cask: `Firefox 160.0.1 → 161.0: open the app, it updates itself`
  - no updater: `<app> 1.2 → 1.3: brew install --cask --force <token>` (shown, never run)
- [x] No app twice: an app already in By hand from the brew step (Discord, Shottr) is not listed again
- [x] "not checkable (no upstream source)" note not shown in `--install`
- [x] Exit code: apps to open alone → 0; `check failed` → 1
- [x] Ctrl-C before the step → `Apps to open not run` (same loop as every step)
- [x] Tests (`tests/test-all.sh`, offline fixtures): each of the lines above, the duplicate case, the failed case
- [x] `software-updates.md` updated (install order, Summary, By hand), 1.6.0 tagged
- [x] Verify: tests by `verifier` (152 passed), the step run alone on this Mac matches the plain check (Fork, iStat Menus, Teams, OneDrive; Shottr from the brew step)
- [x] Real `mac-outdated --install` run by the owner 2026-11-26: Fork, iStat Menus, Teams, OneDrive in the step, Summary (`4 to open`) and By hand

## Untouched
- Check mode output and logic
- The install steps themselves and their order (the new step is appended)
- Nothing is installed or opened by the new step

## Decisions (2026-11-26)
- Sources: self-updating, Sparkle and no-updater apps (1B); no-updater apps get their `brew install --cask --force` line, not run
- Visible step plus a Summary row (2B)
- "not checkable" note stays in check mode only (3A)
- GitHub-release check for apps without a cask: wanted, separate feature on the roadmap
- Nothing to open → `up to date`, like the other steps, not `N checked, all current`: three checks share the step and only one counts what it checked
- Ctrl-C: the step itself is quick; an interrupt before it shows `Apps to open not run`, as for every later step
