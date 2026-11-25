# backdrop-carousel: one photo on all displays and Spaces (1.1.0)

Status: done 2026-11-25 (backdrop-carousel 1.1.0, window-manager 1.4.0). ✅ verified (tests, verifier; 7 and 8 by the owner with 5 s) · ✋ 9, 10 still to check by hand (see roadmap By hand).

## Goal
All displays and Spaces show the same photo, changed on an interval while the Mac is unlocked. A small background program (`backdrop-wallpaper`, Swift, started from `yabairc`) picks a random photo from `~/Pictures/BackdropCarousel/`, writes a copy scaled to the largest connected display into `~/Pictures/BackdropCarousel Current/`, and sets it through AppKit (`NSWorkspace.setDesktopImageURL`). Originals and `sync.sh` stay as they are.

## Done-list
| # | Item | Verified by |
|---|---|---|
| 1 | ✅ `backdrop-carousel/wallpaper.swift`; `install.sh` compiles it with `swiftc` to `~/bin/backdrop-wallpaper` | real `install.sh` run, binary exists |
| 2 | ✅ `backdrop-wallpaper --pick`: one-shot new photo on all displays (active Space), prints `Wallpaper: <name> (<w>x<h>)`; `--rescale`: same photo, sized for the displays now | test (dry run) + real run, owner by eye |
| 3 | ✅ Never the photo showing now (set of 2+); 1 photo: stays | test |
| 4 | ✅ Copy just covers ("Fill Screen") the largest connected display in pixels (`NSScreen` frame × scale), never upscaled, JPEG (quality 0.92) | test (`--screens WxH,...` override) + `sips` on the real file |
| 5 | ✅ `BackdropCarousel Current/` holds exactly one file; file name changes on every write (macOS caches a same-name file) | test |
| 6 | ✅ No photos → `ERROR: No photos to pick from`, exit 1 | test |
| 7 | ✅ `backdrop-wallpaper --watch --interval <s>`: timer picks only while the screen is unlocked; lock → timer paused, unlock → resumes | real run with 5 s, owner locks/unlocks |
| 8 | ✅ Space switch: the new Space gets the current photo if it shows something else | owner swipes through Spaces |
| 9 | ✋ Display connected → new pick; disconnected → same photo rescaled | owner plugs a display |
| 10 | ✋ Wake / unlock: catches up a missed interval | owner, after sleep |
| 11 | ✅ Single instance: a second `--watch` replaces the first (pid file `~/.local/state/backdrop-carousel/watch.pid`) | test + real (`pgrep -fl backdrop-wallpaper` shows one) |
| 12 | ✅ No CPU between events; RAM flat: each change runs as a short `--pick`/`--rescale` child process | test 11 (RAM growth under 20 MB over ~10 changes) + measured: idle watcher 7 MB own RAM (57 MB RSS incl. shared libraries), 0 CPU over 20 s; per change 0.25–0.5 s, 100–170 MB RAM until the child exits |
| 13 | ✅ `yabairc`: one line starting `~/bin/backdrop-wallpaper --watch --interval 600` in the background; missing binary → yabai still loads | read + `yabai --restart-service` by owner |
| 14 | ✅ Docs: `backdrop-carousel.md` (program, modes, Settings: nothing to set by hand), `window-manager/config/README.md` (new line) | read |
| 15 | ✅ Versions: backdrop-carousel 1.1.0, window-manager bump; tags | `git tag -n` |

## Untouched
- `sync.sh` and its Shortcut, Brave handling; originals in `BackdropCarousel/`.
- yabai signals and snapping.

## Not covered
- Spaces not visited keep the old photo until visited (Apple offers no public call for inactive Spaces); briefly visible on the switch.
- Displays change one after the other, not at once: macOS's wallpaper service fades them in per display; parallel calls and a smaller file didn't change it.
- If yabai is stopped, the program keeps running until logout; the next yabai start replaces it.

## Mac security list (owner said yes 2026-11-24)
- Persistent background process for the login session, started by `yabairc` (no LaunchAgent, no launchctl, no login item, no sudo, no osascript, no network).

## Decisions (2026-11-24)
- Same-name file swap and folder swap don't work: macOS caches; AppKit call works at once on all displays, only for the active Space per display.
- Spaces included, via the space-change event.
- Background program started from `yabairc` (option 1), not Shortcuts or launchd; it handles interval, Spaces, displays, wake, unlock.
- Interval 600 s (2026-11-24, after testing with 5 s).
- Size per connected displays; RAM holds unpacked pixels whatever the format.
- JPEG instead of PNG (2026-11-24): half the CPU time per change, 2–4.5 MB instead of 9–16 MB of disk space per file.
- Each change in a child process (2026-11-24): rendering inside the watcher kept ~30 MB of RAM per change (ImageIO); autoreleasepool and no-cache options didn't help.
- Domino (displays one after the other) accepted as a macOS limit (2026-11-24); no private APIs, no Dock restart.
- Originals stay full size (2026-11-24); smaller originals would cut the per-change peak to ~40 MB of RAM, not wanted.
- Never repeat the photo showing now.
- Not Shortcuts "Set Wallpaper" (own picture library, reports of 35 GB of disk space; multi-display bugs).
