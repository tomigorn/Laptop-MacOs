# yabai window manager — your config folder

This folder holds the live config for the keyboard-driven window snapper
(yabai + skhd). Edit the files here; most changes apply instantly.

> Quick open: type **`yabai`** in Spotlight (the "yabai window manager" app
> opens this folder in VS Code), or run `code ~/.config/yabai`.

## Files here

| File | What it is | Edit it? |
|------|------------|----------|
| `zones.conf`   | **Your monitors + their split sizes** | ✅ yes — this is the main one |
| `keys.conf`    | Keyboard shortcuts | ✅ to rebind keys |
| `yabairc`      | yabai settings (float layout) | rarely |
| `yabai-snap.sh`| The snapping logic | no |
| `README.md`    | This file | — |

(`keys.conf` is the skhd config; skhd reads it via the symlink
`~/.config/skhd/skhdrc → keys.conf`, because that's the only path skhd looks in.)

## Shortcuts

| Key | Action |
|-----|--------|
| `⌥⌘ ←` / `⌥⌘ →` | walk the focused window left / right through its zones; at the edge it crosses to the next display |
| `⌥⌘ ↑` | fill the whole display (not macOS fullscreen) |
| `⇧⌥⌘ ←` / `⇧⌥⌘ →` | extend the window across zones (grow left / right; reset with plain `⌥⌘ ←/→`) |

See `keys.conf` for the full list of options and conventions from other tools.

## Change window sizes — `zones.conf`

Two kinds of lines:

```
monitor <uuid> <name> <location>     # a physical screen (auto-added; you edit name+location)
layout  <name> <size> <size> ...     # zone sizes for that monitor: % left→right, summing to 100
```

Edit the numbers on a `layout` line and **save — no restart needed** (the script
re-reads this file on every keypress). Sizes examples:

| Sizes      | Result |
|------------|--------|
| `50 50`    | two halves |
| `40 60`    | 40 % left, 60 % right |
| `20 60 20` | three columns (small/big/small) |
| `33 34 33` | three thirds |
| `100`      | one full-width zone |

The number of values = how many stops you walk through on that monitor.
`layout default …` is used for any monitor without its own `layout` line.

## Add a monitor / a new work location

Monitors are recognised by **stable UUID** (so two identical screens, or the
same model at different offices, never get mixed up) and registered
automatically:

1. Plug in the monitor(s).
2. Press any shortcut once → each new screen is appended here as
   `monitor <uuid> mon-XXXXXXXX unknown # <width>pt, first seen <date>`.
3. Rename it (e.g. `Dell27 office-a`) and add a `layout <name> …` line.

## Change the keyboard shortcuts — `keys.conf`

Lines look like `ctrl + alt - left : … left`. Edit, then reload:

```sh
skhd --restart-service
```

To change the modifier everywhere, swap `ctrl + alt` for e.g. `cmd + alt`.

## Applying changes / services

- `zones.conf`  → no restart (re-read each keypress).
- `keys.conf`   → `skhd --restart-service`
- `yabairc`     → `yabai --restart-service`

Check they're alive: `pgrep -x yabai; pgrep -x skhd`.
Logs: `/tmp/yabai_$USER.err.log`, `/tmp/skhd_$USER.err.log`.

## Source of truth

These files are maintained in the dotfiles repo at
`~/development/private/Laptop-MacOs/window-manager/` (install/uninstall scripts
and full docs live there). If this folder was set up via that repo's
`install.sh`, the files here are symlinks back to it.
