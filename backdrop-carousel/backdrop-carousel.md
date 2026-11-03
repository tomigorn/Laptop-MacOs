# Backdrop carousel

Syncs a photo set from a server to `~/Pictures/BackdropCarousel` (wallpaper rotation) and, when Brave is closed, into Brave's new-tab custom backgrounds. Run by a Shortcut.

| File | What |
|---|---|
| `sync.sh` | zsh: fetches the photo list (`GET /`), downloads missing photos, removes ones no longer listed, updates Brave images and `Preferences` |
| `install.sh` | symlinks `sync.sh` to `~/bin/backdrop-sync.sh` for the Shortcut |
| `tests/sync.sh` | offline test (stubbed `curl` and `pgrep`, temp `HOME`) |

## Install

```sh
backdrop-carousel/install.sh
```

Then point the Shortcut's "Run Shell Script" action (shell `/bin/zsh`) at `~/bin/backdrop-sync.sh`. If it fails from Control Center, give Shortcuts.app and Finder Full Disk Access.

## Behaviour

| Case | Output |
|---|---|
| server unreachable or bad list | `ERROR: Failed to fetch photo list from server`, exit 1 |
| Brave not installed | `Synced N photos to wallpaper. Brave not installed.` |
| Brave running | `Synced N photos to wallpaper. Brave skipped (running).` |
| otherwise | `Synced N photos to wallpaper + Brave.` |

## Tests

```sh
backdrop-carousel/tests/sync.sh
```
