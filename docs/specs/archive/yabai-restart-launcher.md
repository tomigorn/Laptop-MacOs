# yabai restart launcher — design

Date: 2026-07-01

## Problem

yabai occasionally gets into a state where it can't act on a window (e.g. a
YouTube fullscreen-video window with `has-ax-reference: false`), or skhd stops
firing shortcuts. The fix is `yabai --restart-service` (and sometimes
`skhd --restart-service`). Today that means opening a terminal and typing it.

The repo already ships one Spotlight launcher —
`~/Applications/yabai window manager.app` — that opens the yabai config folder in
VS Code. We want a **second** Spotlight item that restarts the window-manager
services with one launch: an "it's bugged, fix it" button.

## Goals

- A second `.app` bundle, launchable from Spotlight/Launchpad.
- Named so it's found by searching **`yabai`** or **`window manager`**, matching
  the existing launcher's discoverability.
- Restarts **both** yabai and skhd (skhd drives the keyboard shortcuts, so a
  single button recovers both window-moving and shortcut failures).
- Gives visible feedback that it ran (a macOS notification), since the app has
  no window of its own.
- Built, installed, and removed by the same machinery as the existing launcher.

## Non-goals

- No new dependencies (use `osascript` for the notification).
- No changes to the yabai/skhd runtime config (`yabairc`, `keys.conf`,
  `zones.conf`). This is purely a launcher.

## Design

### New app bundle

`~/Applications/yabai window manager - restart.app`, with:

- **Name / display name:** `yabai window manager - restart` — contains both
  "yabai" and "window manager", so either Spotlight query surfaces it.
- **Bundle id:** `com.tomigorn.yabai-window-manager-restart-launcher`
- **Executable:** `yabai-window-manager-restart` (symlinked from the repo's
  `restart-launcher.sh`, matching the existing "repo is source of truth" pattern).
- **Icon:** `RestartIcon.icns` — a circular-refresh SF Symbol on the same blue
  rounded-rect, visually distinct from the existing tiling glyph.

### `restart-launcher.sh` (new, the app's executable)

```sh
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"   # Launch Services gives a minimal PATH
yabai --restart-service 2>/dev/null || yabai --start-service
skhd  --restart-service 2>/dev/null || skhd  --start-service
osascript -e 'display notification "yabai + skhd restarted" with title "Window manager reloaded"'
```

Sets PATH like `yabai-snap.sh` does (the same minimal-env problem). Restart with
a start fallback so it also works if a service was fully stopped. The
notification is the user-visible confirmation.

### `restart-Info.plist` (new)

A copy of `Info.plist` with the name, bundle id, executable, and icon file
changed to the values above.

### `make-icon.sh` (edit — backward compatible)

Accept an optional **second** argument: the output `.icns` basename (default
`AppIcon`). So:

- `./make-icon.sh` → `AppIcon.icns` (unchanged behaviour)
- `./make-icon.sh arrow.clockwise RestartIcon` → `RestartIcon.icns`

### `build-launcher.sh` (refactor — table-driven)

Extract a `build_app <app-name> <exec-script> <exec-name> <plist> <icns>`
helper and call it for **both** launchers:

1. `yabai window manager` / `launcher.sh` / `yabai-window-manager` / `Info.plist` / `AppIcon.icns`
2. `yabai window manager - restart` / `restart-launcher.sh` / `yabai-window-manager-restart` / `restart-Info.plist` / `RestartIcon.icns`

Same per-app steps as today: symlink executable + plist back into the repo, write
PkgInfo, copy the icns, `lsregister -f`, strip quarantine.

### `install.sh` / `uninstall.sh` (edit)

- install: step 5 already calls `build-launcher.sh`; update its message to mention
  both launchers (open config / restart services).
- uninstall: remove **both** `.app` bundles.

### `window-manager.md` (edit)

- Update the Files list (add `restart-launcher.sh`, `restart-Info.plist`,
  `RestartIcon.icns`).
- Expand the "Spotlight launcher" section to describe both apps.
- Add a Troubleshooting pointer: "a window won't move / shortcut stopped →
  launch **yabai window manager - restart**".

## Versioning

No `terminal/SETUP_VERSION` bump — that rule applies only to files under
`terminal/`. This change is entirely under `window-manager/`.

## Verification

- Run `build-launcher.sh`; confirm both `.app` bundles exist under
  `~/Applications` and `lsregister` picks them up.
- Launch the restart app; confirm the notification appears and both services are
  running (`pgrep -x yabai`, `pgrep -x skhd`).
- Confirm Spotlight finds `yabai window manager - restart` by "yabai" and by
  "window manager".
```
