# Window Manager (yabai + skhd)

Keyboard-driven window snapping with **per-monitor split ratios** that survive
reboots, sleep/wake, and moving between work locations.

- Windows open as normal floating macOS windows.
- A keyboard shortcut "walks" the focused window left/right through snap zones,
  crossing to the next display at the edge.
- Each **physical monitor** has its own layout (e.g. Dell `50/50`, ultrawide
  `40/60`), matched by **stable display UUID** — so two identical monitors, or
  the same model at different offices, never get confused.
- "Fill" fills the whole display (not the macOS green-button fullscreen that
  hides everything else).

It deliberately does **not** use yabai's scripting addition, so **SIP stays
enabled** — everything here works on Apple Silicon with System Integrity
Protection on.

> Why this exists: GUI snappers (e.g. EasySnaps) key their per-display layouts
> by a volatile display index, so after a re-enumeration the wrong ratio gets
> applied (or reset to 50/50). Keying by UUID in a plain-text config fixes that.

## Requirements

- macOS (Apple Silicon or Intel), Homebrew.
- That's it — `install.sh` pulls `yabai`, `skhd`, `jq`.

## Install

```sh
cd window-manager
./install.sh
```

The script is safe to re-run. On a **fresh machine** you'll be prompted (by
macOS) to grant Accessibility — do this once:

1. System Settings → Privacy & Security → **Accessibility**
2. Enable **yabai** and **skhd** (add `/opt/homebrew/bin/{yabai,skhd}` via `+`
   if they're not listed). On Intel, that's `/usr/local/bin`.
3. If the shortcuts don't fire, also add **skhd** under **Input Monitoring**.
4. `yabai --restart-service && skhd --restart-service`

## Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌥⌘ ←` | walk window **left** through zones (crosses to the display on the left at the edge) |
| `⌥⌘ →` | walk window **right** through zones (crosses to the next display) |
| `⌥⌘ ↑` | **fill** the whole display |
| `⇧⌥⌘ ←` / `⇧⌥⌘ →` | **extend** the window across zones (grow left / right; reset with plain `⌥⌘ ←/→`) |

`config/keys.conf` documents the full menu of options
(Spectacle / Rectangle / Magnet / macOS Sequoia / Windows / Linux conventions).

Behaviour: open a window (it floats), press `⌥⌘→` to snap it into a zone, press
again to walk across — at a display edge it crosses to the next monitor. If a
window isn't in a zone (e.g. just filled), `←`/`→` snap it to the left/right
zone of the **current** display rather than jumping to a neighbour.

**Spanning zones** (`⇧⌥⌘ ←/→`): grow the window across adjacent zones. E.g. on
an HP set to `20 60 20`, from the centre zone `⇧⌥⌘→` makes it cover centre +
right; repeat to keep growing. It stops at the display edge (it does **not**
span across monitors). It only grows — to shrink back, press a plain `⌥⌘ ←/→`
to snap to a single zone again.

Change the keys (or modifier) in [`config/keys.conf`](config/keys.conf), then
`skhd --restart-service`.

## Changing sizes — `~/.config/yabai/zones.conf`

This is the only file you normally edit. Two kinds of lines:

```
monitor <uuid> <name> <location>     # a physical screen (auto-added; edit name+location)
layout  <name> <size> <size> ...     # zone sizes for that monitor, % left→right, sum 100
```

Examples for the sizes on a `layout` line:

| Sizes       | Result                          |
|-------------|---------------------------------|
| `50 50`     | two equal halves                |
| `40 60`     | 40 % left, 60 % right           |
| `20 60 20`  | three columns (small/big/small) |
| `33 34 33`  | three thirds                    |
| `100`       | one full-width zone             |

Edit the numbers, save — **no restart needed** (the script re-reads the file on
every keypress). The number of values = the number of stops you walk through on
that monitor.

`layout default …` applies to any monitor that has no `layout` line of its own.

## Adding a monitor / a new work location

Monitors are recognised by UUID and **registered automatically**:

1. Plug in the monitor(s).
2. Press any shortcut once — each new screen is appended to `zones.conf` as
   `monitor <uuid> mon-XXXXXXXX unknown # <width>pt, first seen <date>`.
3. Open `zones.conf`, rename them (e.g. `Dell27 office-a`, `Dell24 office-a`)
   and add a `layout <name> …` line for each (or let them ride on `default`).

Because each physical screen has its own UUID line, your home Dell-27 and Dell-24
get separate layouts, and office screens stay distinct from home — no
cross-location confusion.

## How it works

- `yabairc` sets yabai to `layout float` (no auto-tiling) and a couple of
  options. No scripting addition is loaded.
- `keys.conf` binds the keys to `yabai-snap.sh left|right|fill` (skhd reads it
  via the `~/.config/skhd/skhdrc` symlink).
- `yabai-snap.sh`:
  - captures the focused window by **id** (focus doesn't reliably follow a
    window across displays, so it never re-queries "the focused window"),
  - resolves the window's display **UUID → name → layout** from `zones.conf`,
    auto-registering any unknown connected monitors,
  - figures out which zone the window currently occupies (by position **and**
    width, so a filled window matches nothing),
  - snaps to the next/previous zone, crossing displays only at the real edge.

## Files

```
window-manager/
├── install.sh                  # install / re-run
├── uninstall.sh                # remove (keeps zones.conf unless --purge-zones)
├── build-launcher.sh           # builds the Spotlight launcher app
├── launcher.sh                 # the app's executable (opens config in VS Code)
├── Info.plist                  # the app's bundle metadata
├── window-manager.md           # this file
└── config/
    ├── yabairc                 # → ~/.config/yabai/yabairc
    ├── yabai-snap.sh           # → ~/.config/yabai/yabai-snap.sh
    ├── keys.conf               # → ~/.config/yabai/keys.conf (skhd reads it via ~/.config/skhd/skhdrc)
    ├── README.md               # → ~/.config/yabai/README.md  (how-to next to the live files)
    └── zones.conf.example      # copied to ~/.config/yabai/zones.conf if absent
```

`install.sh` symlinks the config files into `~/.config` (backing up any existing
real files), copies `zones.conf.example` to the live, machine-local
`zones.conf` only if it doesn't exist yet, and builds the Spotlight launcher.

## Spotlight launcher

`install.sh` (via `build-launcher.sh`) creates
`~/Applications/yabai window manager.app`. Type **`yabai`** in Spotlight and hit
Enter to open `~/.config/yabai` in VS Code. The app's executable and `Info.plist`
are symlinked back into this repo, so it's the source of truth; re-run
`build-launcher.sh` after editing them. Drop an `AppIcon.icns` next to
`build-launcher.sh` to give it a custom icon (optional).

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Nothing happens on a shortcut | Grant **skhd** Accessibility **and** Input Monitoring, then `skhd --restart-service`. |
| Windows don't move | Grant **yabai** Accessibility; `yabai --restart-service`. Check `/tmp/yabai_$USER.err.log`. |
| A specific window won't snap | Some windows (overlays, certain dialogs) can't be resized by any WM — expected. |
| Ratios look wrong on a monitor | Check its `monitor` line is named and has a matching `layout` line in `zones.conf`. |
| Service won't start | `tail /tmp/{yabai,skhd}_$USER.err.log` |

## Uninstall

```sh
./uninstall.sh                 # stop services, remove symlinks (keeps zones.conf)
./uninstall.sh --purge-zones   # also delete your monitor list
./uninstall.sh --uninstall     # also brew-uninstall yabai + skhd
```
