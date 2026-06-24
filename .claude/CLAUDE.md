# Laptop-MacOs — project instructions

This repo holds the macOS laptop dotfiles and terminal setup. These instructions
apply on top of the global `~/.claude/CLAUDE.md` (both are loaded together).

## Versioning the terminal setup — ALWAYS bump on change

`terminal/VERSION` is the single source of truth for the terminal-setup version.
It is shown in the fish greeting — both locally on the Mac and on every `xxhc`
connect (via `XXH_VERSION`) — so the version on screen must always reflect the
latest change.

**Rule:** whenever you change anything that affects the terminal setup (any file
under `terminal/`), bump `terminal/VERSION` in the SAME commit. No terminal change
may land without a matching bump.

Use semantic versioning:
- **patch** (`x.y.Z`) — bug fixes, small tweaks, doc-only changes to terminal docs
- **minor** (`x.Y.0`) — new features or capabilities
- **major** (`X.0.0`) — breaking changes or significant restructuring

After bumping, the new number appears in any new fish shell (the greeting reads
`VERSION` live) and on the next `xxhc` connect — that's the at-a-glance check that
the latest changes are live.
