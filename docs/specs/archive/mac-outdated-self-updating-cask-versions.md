# mac-outdated: versions on self-updating cask lines in --install

Date: 2026-11-23. Version 1.5.1.

## Goal
In `--install`, outdated casks with `auto_updates` (Shottr, Discord) showed only their name. Now they show `installed → latest`, like everywhere else.

## Done-list
- [x] brew block: `shottr 1.9.3 → 1.10.0: updates itself on start, open the app` (yellow)
- [x] By hand: one line per app, `shottr 1.9.3 → 1.10.0: open the app, it updates itself`
- [x] Installed version = the real app's `Info.plist` version; no app found (pkg cask) → brew's record
- [x] Tests updated (discord with real app, xquartz without app), `software-updates.md` updated, 1.5.1 tagged
- [x] Real `mac-outdated --install` run by the owner 2026-11-23: both lines show `shottr 1.9.3 → 1.10.0`

## Untouched
- Check mode ("Open to update" already had versions), counting, install logic.

## Decisions (2026-11-23)
- Real app version over brew's record (brew's can be stale, e.g. `1.9.3b` while the app says `1.9.3`).
- By hand: one line per app instead of one joined line.
