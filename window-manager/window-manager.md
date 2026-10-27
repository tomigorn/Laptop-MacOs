# Window Manager (yabai + skhd)

Keyboard-driven window snapping with **per-monitor split ratios** that survive
reboots, sleep/wake, and moving between work locations.

> **Everything lives in `config/` here, symlinked into `~/.config/yabai/`.** Editing `~/.config/yabai/zones.conf` edits the repo file. Only `connected.txt` is local.
>
> | What | Where |
> |------|-------|
> | sizes, monitors, `model` rules, `arrange` lines | `config/zones.conf` → `~/.config/yabai/zones.conf` |
> | logic, keys, yabai settings | `config/` → `~/.config/yabai/` |
> | currently connected screens | `~/.config/yabai/connected.txt` (local, generated) |

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
- That's it — `install.sh` pulls `yabai`, `skhd`, `jq`, `displayplacer`.

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

This is the only file you normally edit. Main lines:

```
monitor <uuid> <name> <location>     # a physical screen (auto-added; edit name+location)
model   <Product-Name> <name>        # any screen of that model uses <name>'s layout (shared desks)
layout  <name> <size> <size> ...     # zone sizes for that monitor, % left→right, sum 100
bottom  <pt>                         # gap kept free at the bottom of every screen for the Dock (default 59)
```

Lookup: UUID's name (if it has a `layout` line) → `model` rule → `layout default`.

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

`connected.txt` tells you which of the accumulated UUIDs you are actually looking at; freshly registered screens appear
there with `-` for name and location.

Because each physical screen has its own UUID line, your home Dell-27 and Dell-24
get separate layouts, and office screens stay distinct from home — no
cross-location confusion.

## Shared desks (open office)

Every desk is a new UUID, so match the monitor model instead:

```
model HP-E34m-G4  Work-HP-Ultrawide  open-office
```

The optional third field is the workspace (location) for `arrange` lines.

- Product name from the `model` column of `connected.txt`, or the comment of a registered line (spaces written as `-`).
- Screens covered by a `model` rule are not registered, so desks don't pile up lines.
- Model comes from `ioreg`, matched to the display by aspect ratio. Two connected screens with the same aspect ratio but different models: no match, `default` is used.

## Screen arrangement per workspace

```
arrange <location> <top|bottom|center> <name> <name> ...    # screens left→right, aligned on that edge
arrange Work5-WEV  bottom  Work-Dell Work-HP-Ultrawide MacBook
```

| What | How |
|------|-----|
| apply | `yabai-snap.sh arrange`; automatically on plug in/out (`display_added`/`display_removed` signals in `yabairc`) |
| which line | the first whose location is a connected screen's location and whose names are exactly the connected screens |
| workspace of a screen | its `monitor` line's location, or the `model` rule's third field |
| tool | `displayplacer`: only `origin` is changed, resolution/scaling/rotation stay; the main screen stays at (0,0) |
| skipped | no matching line, already arranged, yabai reports no screens, or a screen listed as `enabled:false` (asleep/locked) |

## Which monitors are connected right now?

`zones.conf` accumulates every monitor ever plugged in, so `~/.config/yabai/connected.txt` (local, not in the repo) names the ones that are live — the built-in laptop screen included:

```
# --- Currently connected (auto-generated — do not edit) ---------------------
#   Last refreshed 2026-08-18 09:45. Regenerate with:  ./yabai-snap.sh connected
#   (also runs automatically when you open this folder from Spotlight)
#
#   idx uuid                                 width   name                location      layout       model
#   1   37D8832A-2D66-02CA-B9F7-8F30A301B230 1470pt  MacBook             laptop        50 50        -
# * 2   269F4E09-0D04-41E9-A7A4-CE591643DAE0 3440pt  HP                  home          40 60        HP-E34m-G4
#
#   * = display with keyboard focus.  name/location "-" = not named below yet.
# --- end currently connected ------------------------------------------------
```

`yabai-snap.sh connected` regenerates it (and prints the same table to stdout).
`launcher.sh` runs it before opening the folder, so the **yabai window manager**
Spotlight app always leaves you looking at current information. It never touches `zones.conf`, so the repo doesn't change on every refresh.
If yabai isn't running, the command says so and changes nothing.

Unlike the other subcommands, `connected` doesn't need a focused window, so it
skips the focused-window guard that makes the snap commands no-op.

## How it works

- `yabairc` sets yabai to `layout float` (no auto-tiling) and a couple of
  options. No scripting addition is loaded.
- `keys.conf` binds the keys to `yabai-snap.sh left|right|fill` (skhd reads it
  via the `~/.config/skhd/skhdrc` symlink).
- `yabai-snap.sh`:
  - captures the focused window by **id** (focus doesn't reliably follow a
    window across displays, so it never re-queries "the focused window"),
  - resolves the window's display **UUID → name → layout** from `zones.conf`, falling back to a `model` rule (via `ioreg`), auto-registering any unknown connected monitors without one,
  - figures out which zone the window currently occupies (by position **and**
    width, so a filled window matches nothing),
  - snaps to the next/previous zone, crossing displays only at the real edge,
  - then sets the window's bottom edge to the screen bottom minus `bottom` (yabai often misses the Dock),
  - and, as `yabai-snap.sh connected`, writes `connected.txt` (see above).

## Files

```
window-manager/
├── install.sh                  # install / re-run
├── uninstall.sh                # remove (zones.conf stays in the repo)
├── build-launcher.sh           # builds both Spotlight launcher apps
├── launcher.sh                 # "yabai window manager" executable (opens config in VS Code)
├── Info.plist                  # "yabai window manager" bundle metadata
├── restart-launcher.sh         # "… - restart" executable (restarts yabai + skhd)
├── restart-Info.plist          # "… - restart" bundle metadata
├── make-icon.sh                # regenerates an .icns from an SF Symbol
├── AppIcon.icns                # config launcher's icon (white tiling glyph on blue)
├── RestartIcon.icns            # restart launcher's icon (white refresh glyph on blue)
├── window-manager.md           # this file
├── tests/model-fallback.sh     # tests for the model fallback (stubs yabai + ioreg)
├── tests/arrange.sh            # tests for arrange (stubs yabai, ioreg, displayplacer)
├── tests/bottom.sh             # tests for the fixed bottom gap (stubs yabai)
└── config/
    ├── yabairc                 # → ~/.config/yabai/yabairc
    ├── yabai-snap.sh           # → ~/.config/yabai/yabai-snap.sh
    ├── keys.conf               # → ~/.config/yabai/keys.conf (skhd reads it via ~/.config/skhd/skhdrc)
    ├── README.md               # → ~/.config/yabai/README.md  (how-to next to the live files)
    └── zones.conf              # → ~/.config/yabai/zones.conf (monitors, layouts, models, arrangements)
```

`install.sh` symlinks the config files into `~/.config` (backing up any existing
real files) and builds the Spotlight launcher.

## Spotlight launchers

`install.sh` (via `build-launcher.sh`) creates **two** apps in `~/Applications`.
Both are found by typing **`yabai`** or **`window manager`** in Spotlight:

| App | What it does |
|-----|--------------|
| `yabai window manager` | refreshes the connected-monitor block in `zones.conf`, then opens `~/.config/yabai` in VS Code |
| `yabai window manager - restart` | restarts the yabai + skhd services (notifies when done) |

Use **restart** when a window won't move/snap (e.g. a fullscreen-video window
yabai lost its Accessibility handle to — see [Known limitations](#known-limitations))
or when the keyboard shortcuts stop firing.

Each app's executable and `Info.plist` are symlinked back into this repo, so it's
the source of truth; re-run `build-launcher.sh` after editing them. Icons are
`AppIcon.icns` (tiling glyph) and `RestartIcon.icns` (refresh glyph) — regenerate
with `./make-icon.sh [symbol] [out-name]` (e.g.
`./make-icon.sh arrow.clockwise RestartIcon`), then re-run `build-launcher.sh`.

## Known limitations

**Steam (and other windows with no Accessibility window) can't be snapped.**

This setup runs yabai **without the scripting addition** (so SIP stays enabled),
which means yabai's *only* way to move or resize a window is the macOS
Accessibility (AX) API. A few apps don't expose an AX window at all — most
notably **Steam**, whose UI is the CEF-rendered "Steam Helper" window
(`role`/`subrole` empty, `has-ax-reference: false`, `can-move`/`can-resize`
false). For those windows:

- `yabai -m window <id> --grid …` → `could not locate the window to act on!`
- with the window focused, `yabai -m query --windows --window` → `could not
  retrieve window details`

So the snap shortcuts simply do nothing on a Steam window — that's expected, not
a bug in this config. It can't be fixed without the scripting addition (which
requires partially disabling SIP), and even then it isn't guaranteed to work
because Steam exposes no AX handle to act on. **Workaround:** position Steam by
hand — it remembers its window size/position across launches.

`yabai-snap.sh` guards its focused-window query so these cases no-op cleanly
instead of erroring out.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Nothing happens on a shortcut | Grant **skhd** Accessibility **and** Input Monitoring, then `skhd --restart-service`. |
| Windows don't move | Grant **yabai** Accessibility; `yabai --restart-service`. Check `/tmp/yabai_$USER.err.log`. |
| A specific window won't snap | Likely a window with no Accessibility handle (e.g. **Steam**, some overlays/dialogs, a **fullscreen YouTube/video window**) — yabai can't move it without the scripting addition. Exit the video's fullscreen, or launch **yabai window manager - restart** to have yabai re-acquire it. See [Known limitations](#known-limitations). |
| Window-manager just "bugged out" | Launch **yabai window manager - restart** from Spotlight (or `yabai --restart-service && skhd --restart-service`). |
| Ratios look wrong on a monitor | Check its `monitor` line is named and has a matching `layout` line in `zones.conf`, or a `model` rule for its model. |
| Service won't start | `tail /tmp/{yabai,skhd}_$USER.err.log` |

## Uninstall

```sh
./uninstall.sh                 # stop services, remove symlinks (zones.conf stays in the repo)
./uninstall.sh --uninstall     # also brew-uninstall yabai, skhd, displayplacer
```
