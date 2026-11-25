# backdrop-carousel: version

## Goal
backdrop-carousel gets a version like the other folders: `VERSION` file, `sync.sh --version`, a Version block in `CLAUDE.md`, tag `backdrop-carousel-1.0.0`.

## Done-list
| # | Item | Verified by |
|---|---|---|
| 1 | `backdrop-carousel/VERSION` = `1.0.0` | read |
| 2 | `sync.sh --version` prints `backdrop-carousel <VERSION>`, exit 0, no network, nothing synced | test (curl log empty) + real `~/bin/backdrop-sync.sh --version` |
| 3 | Works through the `~/bin` symlink (VERSION read next to the real script) | test + real command |
| 4 | Missing `VERSION` → `backdrop-carousel ?` (as mac-outdated) | test |
| 5 | `CLAUDE.md`: `## Version (backdrop-carousel)` block | read |
| 6 | `backdrop-carousel.md`: `--version` and VERSION in the file table | read |
| 7 | Commit, then annotated tag `backdrop-carousel-1.0.0` (`backdrop carousel 1.0.0`) | `git tag -n` |

## Untouched
- Sync behaviour and messages; other arguments stay ignored as before.

## Decisions (2026-11-24)
- Start at 1.0.0 (in daily use since spring); the single-photo feature becomes 1.1.0.
- `--version` like `mac-outdated --version`.
- Versioning first, own commit and tag; single-photo feature on top.
