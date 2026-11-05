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
- That's it — `install.sh` pulls `yabai`, `skhd` (tap `asmvik/formulae`), `jq`, `displayplacer`.

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

Tests: `window-manager/tests/*.sh`, or all via `tests/test-all.sh`.

## Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌥⌘ ←` | walk window **left** through zones (crosses to the display on the left at the edge) |
| `⌥⌘ →` | walk window **right** through zones (crosses to the next display) |
| `⌥⌘ ↑` | **fill** the whole display |
| `⇧⌥⌘ ←` / `⇧⌥⌘ →` | **extend** the window across zones (grow left / right; reset with plain `⌥⌘ ←/→`) |

[`config/keys.conf`](config/keys.conf) is authoritative, with a menu of other conventions (Spectacle, Rectangle, Magnet, macOS Sequoia, Windows, Linux) as comments.

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
monitor <uuid> <name> <location>                   # a physical screen (auto-added; edit name+location)
model   <Product-Name> <name> [<location>]         # any screen of that model uses <name>'s layout (shared desks)
layout  <name> <size> <size> ...                   # zone sizes for that monitor, % left→right, sum 100
arrange <location> <top|bottom|center> <name> ...  # screens left→right per workspace (see below)
bottom  <pt>                                       # gap kept free at the bottom of every screen for the Dock (default 59)
* monitor …  /  * model …                          # leading "* " = connected right now (set automatically)
```

Lookup: UUID's name (if it has a `layout` line) → `model` rule → `layout default` → 50 50.

Examples for the sizes on a `layout` line:

| Sizes       | Result                          |
|-------------|---------------------------------|
| `50 50`     | two equal halves                |
| `40 60`     | 40 % left, 60 % right           |
| `20 60 20`  | three columns (small/big/small) |
| `33 34 33`  | three thirds                    |
| `100`       | one full-width zone             |

Edit the numbers, save — **no restart needed** (the script re-reads the file on every keypress). The number of values = the number of stops you walk through on that monitor.

## Adding a monitor / a new work location

Monitors are recognised by UUID and **registered automatically**:

1. Plug in the monitor(s). Any run of `yabai-snap.sh` (the plug-in signal, a shortcut) adds each new screen after the last `monitor` line, as `monitor <uuid> mon-XXXXXXXX unknown # <width>pt, first seen <date>`. Screens covered by a `model` rule are left out.
2. Open `zones.conf`, rename them (e.g. `Dell27 office-a`, `Dell24 office-a`) and add a `layout <name> …` line for each (or let them ride on `default`).

## Shared desks (open office)

Every desk is a new UUID, so match the monitor model instead:

```
model HP-E34m-G4  Work-HP-Ultrawide  open-office
```

The optional third field is the workspace (location) for `arrange` lines.

- Product name from the `model` column of `connected.txt`, or the comment of a registered line (spaces written as `-`).
- Screens covered by a `model` rule are not registered, so desks don't pile up lines.
- One rule can serve every desk with that model, fixed ones too: `arrange` takes the location from any connected screen, so `arrange Work5-WEV bottom Work-Dell Work-HP-Ultrawide MacBook` matches as long as the Dell is at `Work5-WEV`.
- Model comes from `ioreg`, matched to the display by aspect ratio. Two connected screens with the same aspect ratio but different models: no match, `default` is used.

## Screen arrangement per workspace

```
arrange <location> <top|bottom|center> <name> <name> ...    # screens left→right, aligned on that edge
arrange Work5-WEV  bottom  Work-Dell Work-HP-Ultrawide MacBook
```

| What | How |
|------|-----|
| apply | `yabai-snap.sh arrange`; automatically on yabai start/restart (restart app) and on plug in/out (`display_added`/`display_removed` signals in `yabairc`) |
| which line | the first whose location is one of the connected screens' locations and whose names are exactly the connected screens (any order), both matched exactly, case included |
| name and workspace of a screen | its `monitor` line's name and location, unless that name has no `layout` line and a `model` rule covers the screen: then the rule's name and location |
| tool | `displayplacer`: only `origin` is changed, resolution/scaling/rotation stay; the main screen stays at (0,0) |
| skipped | no matching line, already arranged, yabai not running or reports no screens, `displayplacer` missing or gives no arrangement, `displayplacer` and yabai list different screens, or a screen listed as `enabled:false` (asleep/locked) |

No match: the message `no arrange line for the connected screens (names: …; locations: …)` lists the values to use. Where it lands: [Logs](#logs).

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

Columns: `idx` is yabai's display index, `layout` the zone sizes the screen resolves to. `-` under name/location: the screen has no `monitor` line (it uses a `model` rule, or `zones.conf` isn't writable).

`yabai-snap.sh connected` regenerates it and prints the same table. `launcher.sh` runs it before opening the folder from Spotlight. If yabai isn't running, the command says so and changes nothing.

`zones.conf` also marks them: `* ` in front of the `monitor` line of each connected screen, or of the `model` rule a screen without its own line uses; the other lines start with two spaces, so the columns stay aligned. Every run of `yabai-snap.sh` (any shortcut, plug in/out) updates the marks; the file is only rewritten when a mark changes, and then replaced in one step (temp file + rename), so runs firing at once never empty it. Because `zones.conf` is in the repo, git shows it as modified after a plug in/out.

`connected` and `arrange` work on displays only, so they skip the focused-window guard that makes the snap commands no-op.

## How it works

- `yabairc` sets yabai to `layout float` (no auto-tiling) and a couple of options, adds the `display_added`/`display_removed` signals and runs `yabai-snap.sh arrange`. No scripting addition is loaded.
- `keys.conf` binds the keys to `yabai-snap.sh left|right|fill|extend-left|extend-right` (skhd reads it via the `~/.config/skhd/skhdrc` symlink).
- `yabai-snap.sh`:
  - captures the focused window by **id** (focus doesn't reliably follow a
    window across displays, so it never re-queries "the focused window"),
  - resolves the window's display **UUID → name → layout** from `zones.conf`, falling back to a `model` rule (via `ioreg`), auto-registering any unknown connected monitors without one,
  - figures out which zone the window currently occupies (by position **and**
    width, so a filled window matches nothing),
  - snaps to the next/previous zone, crossing displays only at the real edge,
  - then sets the window's bottom edge to the screen bottom minus `bottom` (yabai often misses the Dock),
  - and, as `yabai-snap.sh connected`, writes `connected.txt`; as `yabai-snap.sh arrange`, places the screens (see above).

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
├── VERSION                     # window manager version (tag window-manager-X.Y.Z)
├── tests/model-fallback.sh     # tests for the model fallback, marks and safe rewrites (stubs yabai + ioreg)
├── tests/arrange.sh            # tests for arrange (stubs yabai, ioreg, displayplacer)
├── tests/bottom.sh             # tests for the fixed bottom gap (stubs yabai)
├── tests/restart-launcher.sh   # tests for the restart notification (stubs yabai, skhd, pgrep, osascript)
├── tests/snap-log.sh           # tests for the snap log (stubs yabai, ioreg)
├── tests/walk.sh               # tests for left, right, fill, extend (stubs yabai, ioreg; bash 5 and 3.2)
├── tests/launcher.sh           # tests for launcher.sh
├── tests/make-icon.sh          # tests for make-icon.sh
├── tests/install.sh            # tests for install.sh: brew tap asmvik/formulae (stubs brew)
└── config/
    ├── yabairc                 # → ~/.config/yabai/yabairc
    ├── yabai-snap.sh           # → ~/.config/yabai/yabai-snap.sh
    ├── keys.conf               # → ~/.config/yabai/keys.conf (skhd reads it via ~/.config/skhd/skhdrc)
    ├── README.md               # → ~/.config/yabai/README.md  (how-to next to the live files)
    └── zones.conf              # → ~/.config/yabai/zones.conf (monitors, layouts, models, arrangements)
```

`install.sh` symlinks the config files into `~/.config` (backing up any existing real files) and builds the Spotlight launchers.

## Spotlight launchers

`install.sh` (via `build-launcher.sh`) creates **two** apps in `~/Applications`.
Both are found by typing **`yabai`** or **`window manager`** in Spotlight:

| App | What it does |
|-----|--------------|
| `yabai window manager` | refreshes `connected.txt`, then opens `~/.config/yabai` in VS Code |
| `yabai window manager - restart` | restarts the yabai + skhd services; the notification says whether both run afterwards, or which doesn't |

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

Without the scripting addition (SIP stays on), yabai can only move a window through the macOS Accessibility (AX) API. Some apps expose no AX window, most notably **Steam** (`has-ax-reference: false`, `can-move`/`can-resize` false):

- `yabai -m window <id> --grid …` → `could not locate the window to act on!`
- with the window focused, `yabai -m query --windows --window` → `could not retrieve window details`

The snap shortcuts then do nothing and leave `no window to act on` in the [snap log](#logs). Expected, not a bug. **Workaround:** position Steam by hand; it remembers its window size/position across launches.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Nothing happens on a shortcut | Grant **skhd** Accessibility **and** Input Monitoring, then `skhd --restart-service`. |
| Windows don't move | Grant **yabai** Accessibility; `yabai --restart-service`. Check `tail ~/.local/state/yabai/snap.log` and `tail /tmp/yabai_$USER.err.log`. |
| A window won't change screen | `tail ~/.local/state/yabai/snap.log`: the direction tried and yabai's message ([Logs](#logs)). No screen on that side: check the arrangement, or add an `arrange` line to `zones.conf`. A maximised window, or one too wide for its zone, needs one press to reach the edge zone first. |
| Screens not arranged | `tail /tmp/yabai_$USER.err.log`: `no arrange line` lists the names and locations of the connected screens. The `arrange` line must have exactly those names and one of those locations, case included. |
| A specific window won't snap | Likely a window with no Accessibility handle (e.g. **Steam**, some overlays/dialogs, a **fullscreen YouTube/video window**) — yabai can't move it without the scripting addition. Exit the video's fullscreen, or launch **yabai window manager - restart** to have yabai re-acquire it. See [Known limitations](#known-limitations). |
| Window-manager just "bugged out" | Launch **yabai window manager - restart** from Spotlight (or `yabai --restart-service && skhd --restart-service`). |
| Ratios look wrong on a monitor | Check its `monitor` line is named and has a matching `layout` line in `zones.conf`, or a `model` rule for its model. |
| Service won't start | `tail /tmp/{yabai,skhd}_$USER.err.log` |

## Logs

The snap log stays across reboots, trimmed to its last 1000 lines past 1 MB. The `/tmp` logs are gone after a reboot.

| Log | Contains |
|-----|----------|
| `~/.local/state/yabai/snap.log` (path override: `YABAI_SNAP_LOG`) | failed window moves, see below |
| `/tmp/yabai_$USER.err.log` | yabai's errors; `arrange` from `yabairc` or a signal: `no arrange line …` and the other skip reasons |
| `/tmp/yabai_$USER.out.log` | `yabai configuration loaded`; `already arranged`; the `displayplacer` command applied |
| `/tmp/skhd_$USER.err.log`, `/tmp/skhd_$USER.out.log` | skhd |

Snap log lines, only from `left`, `right`, `fill`, `extend-left`, `extend-right`, as `<date> <time> <command>: …`:

| Line | Meaning |
|------|---------|
| `window <id> (<app>) --display east failed: <yabai's message>` | no screen that way (or `west`); also on every press at the outermost zone, the window just re-snaps |
| `window <id> (<app>) still on display <n> after --display east` | yabai accepted the move, the window stayed |
| `no window to act on` | yabai can't query the focused window; its message is on the line above |
| `yabai not answering` | yabai isn't running or not responding |
| `failed at line <n>: <command>` | any other failed step; yabai's message is on the line above |

Not logged: successful moves, `connected`, `arrange` (run by hand, these print to the terminal).

## Uninstall

```sh
./uninstall.sh                 # stop services, remove symlinks, launchers, connected.txt (zones.conf stays in the repo)
./uninstall.sh --uninstall     # also brew-uninstall yabai, skhd, displayplacer
```
