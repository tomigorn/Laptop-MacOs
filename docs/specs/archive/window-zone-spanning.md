# Window zone spanning — design

Date: 2026-06-15
Component: `window-manager` (yabai-snap.sh + keys.conf)

## Goal

Let a window span multiple snap zones via the keyboard, e.g. fill the current
zone *and* the one to its right.

## Shortcuts (added to the active set)

| Key      | Action                                            |
|----------|---------------------------------------------------|
| `⇧⌥⌘ →`  | extend the window's right edge into the next zone  |
| `⇧⌥⌘ ←`  | extend the window's left edge into the previous zone |

(Existing `⌥⌘ ←/→` move/walk a single zone; `⌥⌘ F`/`↑` fills.)

## Behaviour

- The window's current span is found by snapping each edge to the nearest zone
  boundary, giving an inclusive zone range `[lo, hi]`.
- `extend-right`: `hi = min(hi+1, last)` (left edge anchored, grows right).
- `extend-left`:  `lo = max(lo-1, 0)`   (right edge anchored, grows left).
- Repeating keeps growing until the display edge, then clamps (no-op).
- **Grow-only.** Shrinking is done with the existing single-zone `⌥⌘ ←/→`.
- **No display crossing** while spanning — it clamps at the display edge.
- A filled / unaligned window maps to `[0, last]` (already full), so extending
  is a no-op — acceptable.

## Implementation

In `yabai-snap.sh` (float layout, grid-based), two helpers + two cases:

- `current_span` → echoes `lo hi`: for each zone `1:100:S:0:W:1`, `lo` is the
  zone whose start `S` is nearest the window's left-edge percent, `hi` the zone
  whose end `S+W` is nearest the right-edge percent.
- `span_grid lo hi` → one combined spec `1:100:Sx:0:(Ex+Ew-Sx):1`.
- cases `extend-right` / `extend-left` call `read_zones`, `current_span`, adjust
  `lo`/`hi`, then `snap "$(span_grid …)"`.

`keys.conf` gains two lines binding `shift + alt + cmd - right|left`.

## Out of scope

- Spanning across displays.
- Shrink-via-shift (use the plain single-zone keys).
- Vertical spanning (zones are horizontal only).
