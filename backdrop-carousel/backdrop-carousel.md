# Backdrop carousel

Syncs a photo set from a server to `~/Pictures/BackdropCarousel` and, when Brave is closed, into Brave's new-tab custom backgrounds (run by a Shortcut). `backdrop-wallpaper` shows one of those photos on all displays and Spaces, a new one every 10 min.

| File | What |
|---|---|
| `sync.sh` | zsh: fetches the photo list (`GET /`), downloads missing photos, removes ones no longer listed, updates Brave images and `Preferences` |
| `wallpaper.swift` | `backdrop-wallpaper`: picks a photo, writes a JPEG copy sized for the largest display to `~/Pictures/BackdropCarousel Current/`, sets it on every display |
| `install.sh` | symlinks `sync.sh` to `~/bin/backdrop-sync.sh` for the Shortcut, builds `~/bin/backdrop-wallpaper` (needs `swiftc`) |
| `VERSION` | version, printed by `sync.sh --version` |
| `tests/sync.sh` | offline test (stubbed `curl` and `pgrep`, temp `HOME`) |
| `tests/wallpaper.sh` | builds `backdrop-wallpaper` into a temp dir, runs it with `--no-apply` on fixture photos |

## Install

```sh
backdrop-carousel/install.sh
```

Then point the Shortcut's "Run Shell Script" action (shell `/bin/zsh`) at `~/bin/backdrop-sync.sh`. If it fails from Control Center, give Shortcuts.app and Finder Full Disk Access.

## Behaviour

| Case | Output |
|---|---|
| `--version` | `backdrop-carousel 1.0.0`, nothing synced |
| server unreachable or bad list | `ERROR: Failed to fetch photo list from server`, exit 1 |
| Brave not installed | `Synced N photos to wallpaper. Brave not installed.` |
| Brave running | `Synced N photos to wallpaper. Brave skipped (running).` |
| otherwise | `Synced N photos to wallpaper + Brave.` |

## backdrop-wallpaper

Started by `window-manager/config/yabairc` (`--watch --interval 600`); a new start replaces the running one. Nothing to set by hand.

| Command | What |
|---|---|
| `backdrop-wallpaper --pick` | new photo now (never the one showing) |
| `backdrop-wallpaper --rescale` | same photo, sized for the displays connected now |
| `backdrop-wallpaper --watch --interval <s>` | new photo every `<s>` seconds while unlocked; catches up after unlock and wake; a switched-to Space gets the current photo; display added → new photo, removed → rescaled |
| `--no-apply`, `--screens WxH,...`, `--ignore-lock` | for tests: don't set the wallpaper, fake display sizes, ignore the lock |

- Each change runs as a short child process (0.25–0.5 s, 100–170 MB of RAM, freed when it exits); the watcher itself uses 7 MB of its own RAM and no CPU between changes.
- Displays change one after the other (macOS fades them in per display).
- Spaces you don't visit keep their old photo until you switch to them.
- Stop the watcher: `kill (cat ~/.local/state/backdrop-carousel/watch.pid)`; `yabai --restart-service` starts it again.

## Tests

```sh
backdrop-carousel/tests/sync.sh
backdrop-carousel/tests/wallpaper.sh
```
