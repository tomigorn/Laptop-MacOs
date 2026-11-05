# yabai window manager — your config folder

Live config of the keyboard-driven window snapper (yabai + skhd).

- Open this folder: type **`yabai`** in Spotlight, or `code ~/.config/yabai`.
- Full docs (shortcuts, adding monitors, shared desks, arrangement, logs, troubleshooting): `~/development/private/Laptop-MacOs/window-manager/window-manager.md`.
- Line syntax of `zones.conf`: its own header. Active shortcuts: top of `keys.conf`.

## Files here

| File | What it is | Edit it? |
|------|------------|----------|
| `zones.conf`   | **Your monitors, split sizes, models, arrangements, Dock gap (`bottom`)** | ✅ yes — this is the main one |
| `connected.txt`| Which monitors are connected right now (generated, local only) | no |
| `keys.conf`    | Keyboard shortcuts (skhd reads it via the symlink `~/.config/skhd/skhdrc`) | ✅ to rebind keys |
| `yabairc`      | yabai settings (float layout), arrange on start and plug in/out | rarely |
| `yabai-snap.sh`| The snapping logic | no |
| `README.md`    | This file | — |

Everything except `connected.txt` is a symlink into `~/development/private/Laptop-MacOs/window-manager/config/`: edits here are repo changes, commit them there.

## Applying changes

| Changed | Apply |
|---------|-------|
| `zones.conf`: sizes, names, `model`, `bottom` | nothing, re-read on every keypress |
| `zones.conf`: `arrange` lines | `~/.config/yabai/yabai-snap.sh arrange` (also runs on yabai start/restart and plug in/out) |
| `keys.conf` | `skhd --restart-service` |
| `yabairc` | `yabai --restart-service` |

Refresh `connected.txt` (also prints it; runs when you open this folder from Spotlight): `~/.config/yabai/yabai-snap.sh connected`

Check the services are alive: `pgrep -x yabai; pgrep -x skhd`
