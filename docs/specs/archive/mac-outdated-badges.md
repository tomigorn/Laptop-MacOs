# mac-outdated: badges and section bars

Date: 2026-11-26. Version 1.7.0.

## Goal
Results that changed or need the owner stand out as badges; steps and sections are grey bars; version rows are aligned and read old → new at a glance. Same look in check mode and `--install`. Picked from the demo (variant C, red option 1).

## Done-list
Only with colour on (terminal, no `NO_COLOR`); piped output and `NO_COLOR` stay exactly as today. The log stays without colour codes: badges back in lower case, bars as `── <title>`.

- [x] Badges, bold black text on the colour, padded with one space (` INSTALLED `):

  | Badge | Colour | Where |
  |---|---|---|
  | ` INSTALLED ` | green | `--install` result `installed…` |
  | ` N OUTDATED `, ` N TO OPEN `, ` N BY HAND ` | yellow | check progress lines; `--install` `N to open` |
  | ` FAILED `, ` CHECK FAILED `, ` INTERRUPTED `, ` NOT RUN ` | red (SGR 1;30;41) | both modes; the reason follows in red text (` FAILED ` exit 1) |
  | ` ✗ FAILED ` | red | the `✗ failed: …` line after the Summary |

- [x] Quiet results without a badge: `up to date` dim; `skipped …`, notes, `some updates failed`, `not verified` keep today's text colour
- [x] Bars: the `── <step>` headers of `--install` and the `═══` section boxes (`brew · 1 outdated`, `Open to update · 4`, `Summary`, `By hand`) become one full-width grey bar (bold white on grey, 58 columns) with the same text
- [x] Version rows (check-mode sections, Open to update, `Apps to open`, By hand app lines, brew result lines `libffi 3.8.1 → 3.8.2 ✓`): name bold, old version dim, new version bold yellow (green with ✓ in the brew result), hint dim; aligned in columns within a block
- [x] `--install` Summary `total`: each part in its colour (installed green, failed red, to open yellow, up to date dim)
- [x] By hand lines that are not app versions (restart, admin skipped, held formula, …) keep their yellow text
- [x] Tests: the colour tests (`MAC_OUTDATED_COLOR=always`) assert the badges, bars and row parts; one test that output without colour is unchanged (no SGR, `═══` and `──` as today)
- [x] `software-updates.md` colour section updated, 1.7.0 tagged
- [x] Verify: tests by `verifier` (152 passed); real coloured and `NO_COLOR` check runs and their logs inspected by `verifier` (badges, bars, rows, no `═══` with colour, plain output and log unchanged in form)
- [ ] Owner looks at a real `mac-outdated` and `mac-outdated --install` in Ghostty

## Untouched
- Texts, counts, order, exit codes and output without colour
- Tool output inside the `--install` blocks stays plain

## Decisions (2026-11-26)
- Variant C: badges only for what changed or needs you; up to date quiet (dim)
- Red badge: black on red (SGR 1;30;41), like green and yellow; white on red was unreadable in the owner's theme
- Same style in check mode and `--install`
- Log: it is the terminal output with the codes stripped, so a coloured run's log shows bars as `── <title>` instead of `═══` boxes; badges are turned back into lower-case words. A second plain rendering just for the log was not worth it
- `none installed`, `N checked, all current` keep green text; only `up to date` turns dim
- The coloured `✗ FAILED` line has no colon after the badge, so its log line reads `✗ failed <names>`
