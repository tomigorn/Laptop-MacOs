# Display arrangement per workspace

## Config (local `~/.config/yabai/zones.conf`)
- `arrange <location> <top|bottom|center> <name> <name> ...`: screens left→right, aligned on that edge.
- `model <Product-Name> <name> [<location>]`: optional location for model-matched (shared-desk) screens.

## Location of a screen
UUID `monitor` line's location; for a model-matched screen the rule's location.

## Picking the arrange line
First `arrange` line whose location is one of the connected screens' locations and whose names are exactly the connected screens' resolved names (same count). None → print a note, change nothing.

## Applying
- `yabai-snap.sh arrange`.
- Read `displayplacer list`; its last line is the full command for the current setup (`"id:<uuid> res:... origin:(x,y) degree:..."` per screen). Replace only `origin:(x,y)` per id; keep everything else (resolution, scaling, rotation untouched).
- Origins in points from yabai frames: x cumulative left→right; y: top 0, bottom `maxH-h`, center `(maxH-h)/2` (macOS y grows downward); then shift all so the current main screen (origin (0,0) in the list) stays at (0,0).
- Skip calling displayplacer when all computed origins already equal the current frames.
- `yabairc`: `yabai -m signal --add event=display_added action="$HOME/.config/yabai/yabai-snap.sh arrange"` (and display_removed).

## Tests
Stub `displayplacer` (fixture `list` output, records the apply call), stub yabai/ioreg; check the applied command for a 3-screen fixed desk, a model-matched open-office desk, no-match, already-arranged.
