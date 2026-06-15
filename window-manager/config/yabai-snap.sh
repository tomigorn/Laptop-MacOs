#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Display-aware window snapping for yabai (float layout).
#
# Walks the FOCUSED window through an ordered list of zones. At the left/right
# edge of a display it crosses to the neighbouring display and continues. Each
# monitor chooses its own zone layout (defined in zones.conf) by stable UUID,
# so the same key gives 50/50 on the Dell and 40/60 on the HP automatically.
#
#   yabai-snap.sh left    walk one zone to the left  (crossing displays)
#   yabai-snap.sh right   walk one zone to the right (crossing displays)
#   yabai-snap.sh fill    fill the whole display (NOT native fullscreen)
#
# Stable: monitors are matched by UUID, not by volatile index, so reconnecting
# a monitor (or moving between work locations) never scrambles the ratios.
# ---------------------------------------------------------------------------
set -euo pipefail
cmd="${1:-}"

# launchd (skhd) gives a minimal PATH; ensure Homebrew bins are findable.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

YABAI="$(command -v yabai)"
JQ="$(command -v jq)"

# ===========================================================================
# Monitors and layouts live in a separate, friendly file: ~/.config/yabai/zones.conf
# Monitors are matched by stable display UUID (so two identical models, or the
# same model at different locations, never get confused). See zones.conf.
# You normally never touch the logic below this point.
# ===========================================================================
ZONES_FILE="${YABAI_ZONES_FILE:-$HOME/.config/yabai/zones.conf}"

FILL_GRID="1:1:0:0:1:1"   # fill the entire display

# ===========================================================================
win="$("$YABAI" -m query --windows --window)"
[ -n "$win" ] || exit 0

# Operate on this specific window id from here on. Focus does NOT reliably
# follow a window across displays, so never re-query "the focused window".
wid="$(echo "$win" | "$JQ" '.id')"
di="$(echo "$win" | "$JQ" '.display')"
displays="$("$YABAI" -m query --displays)"

disp_json()  { echo "$displays" | "$JQ" "map(select(.index==$1))[0]"; }
disp_width() { disp_json "$1" | "$JQ" '.frame.w | floor'; }
disp_uuid()  { disp_json "$1" | "$JQ" -r '.uuid'; }

# Auto-register: append a "monitor" line for any connected display whose UUID
# isn't in the config yet, so the file fills itself in as you plug things in.
register_displays() {
  [ -w "$ZONES_FILE" ] || return 0
  local uuid w
  while read -r uuid w; do
    [ -n "$uuid" ] || continue
    if ! grep -q "$uuid" "$ZONES_FILE" 2>/dev/null; then
      printf 'monitor %s  mon-%s  unknown    # %spt, first seen %s\n' \
        "$uuid" "${uuid:0:8}" "$w" "$(date +%F)" >> "$ZONES_FILE"
    fi
  done < <(echo "$displays" | "$JQ" -r '.[] | "\(.uuid) \(.frame.w|floor)"')
}

# Echo grid specs (ROWS:COLS:X:Y:W:H), one per line, for display index $1.
# Resolve UUID -> monitor name -> layout percentages (falling back to the
# "default" layout). COLS is fixed at 100 so percentages map 1:1.
profile_for_display() {
  local idx="$1" uuid name
  uuid="$(disp_uuid "$idx")"
  name="$(awk -v u="$uuid" '$1=="monitor" && $2==u {print $3; exit}' "$ZONES_FILE")"
  [ -n "$name" ] || name="default"
  awk -v n="$name" '
    $1=="layout" && $2==n         { for (i=3;i<=NF;i++) sel[++s]=$i; got=1 }
    $1=="layout" && $2=="default" { for (i=3;i<=NF;i++) def[++d]=$i }
    END {
      if (got) { x=0; for (i=1;i<=s;i++) { printf "1:100:%d:0:%d:1\n", x, sel[i]; x+=sel[i] } }
      else     { x=0; for (i=1;i<=d;i++) { printf "1:100:%d:0:%d:1\n", x, def[i]; x+=def[i] } }
    }
  ' "$ZONES_FILE"
}

# Fill ZONES (bash 3.2-safe; no mapfile) with the profile for display index $1.
read_zones() {
  ZONES=()
  local line
  while IFS= read -r line; do ZONES+=("$line"); done < <(profile_for_display "$1")
  # Fallback to 50/50 if zones.conf is missing or a layout is malformed.
  if [ "${#ZONES[@]}" -eq 0 ]; then ZONES=("1:2:0:0:1:1" "1:2:1:0:1:1"); fi
}

register_displays

# Expected "x w" (points) of grid spec $1 on display index $2.
zone_rect() {
  local spec="$1" idx="$2" r c zx zy zw zh dj dx dw
  IFS=: read -r r c zx zy zw zh <<<"$spec"
  dj="$(disp_json "$idx")"
  dx="$(echo "$dj" | "$JQ" '.frame.x')"
  dw="$(echo "$dj" | "$JQ" '.frame.w')"
  awk -v dx="$dx" -v dw="$dw" -v c="$c" -v zx="$zx" -v zw="$zw" \
      'BEGIN{printf "%.2f %.2f", dx + zx/c*dw, zw/c*dw}'
}

# Index of the zone the window currently occupies, or -1 if it doesn't match
# any zone closely (e.g. it's filled/fullscreen or an arbitrary floating size).
# Matching by x AND width means a filled window matches nothing, so left/right
# then snap within the CURRENT display instead of crossing to a neighbour.
current_zone_index() {
  local wx ww dw tol best=0 bestd="1e18" i=0 z zx zw d
  wx="$(echo "$win" | "$JQ" '.frame.x')"
  ww="$(echo "$win" | "$JQ" '.frame.w')"
  dw="$(disp_json "$di" | "$JQ" '.frame.w')"
  tol="$(awk -v d="$dw" 'BEGIN{printf "%.2f", d*0.15}')"   # within 15% of display width
  for z in "${ZONES[@]}"; do
    read -r zx zw <<<"$(zone_rect "$z" "$di")"
    d="$(awk -v a="$wx" -v b="$zx" -v c="$ww" -v e="$zw" \
         'BEGIN{p=a-b;if(p<0)p=-p;q=c-e;if(q<0)q=-q;print p+q}')"
    if awk -v d="$d" -v bd="$bestd" 'BEGIN{exit !(d<bd)}'; then bestd="$d"; best="$i"; fi
    i=$((i+1))
  done
  if awk -v bd="$bestd" -v t="$tol" 'BEGIN{exit !(bd>t)}'; then echo "-1"; else echo "$best"; fi
}

snap() { "$YABAI" -m window "$wid" --grid "$1"; }

case "$cmd" in
  fill)
    snap "$FILL_GRID"
    ;;
  right)
    read_zones "$di"; ci="$(current_zone_index)"; last=$(( ${#ZONES[@]} - 1 ))
    if [ "$ci" -eq -1 ]; then
      snap "${ZONES[$last]}"                       # not in a zone (e.g. filled) -> right side of THIS display
    elif [ "$ci" -lt "$last" ]; then
      snap "${ZONES[$((ci+1))]}"
    elif "$YABAI" -m window "$wid" --display east >/dev/null 2>&1; then
      "$YABAI" -m window --focus "$wid" >/dev/null 2>&1 || true
      ndi="$("$YABAI" -m query --windows --window "$wid" | "$JQ" '.display')"
      read_zones "$ndi"; snap "${ZONES[0]}"
    else
      snap "${ZONES[$ci]}"
    fi
    ;;
  left)
    read_zones "$di"; ci="$(current_zone_index)"
    if [ "$ci" -eq -1 ]; then
      snap "${ZONES[0]}"                           # not in a zone (e.g. filled) -> left side of THIS display
    elif [ "$ci" -gt 0 ]; then
      snap "${ZONES[$((ci-1))]}"
    elif "$YABAI" -m window "$wid" --display west >/dev/null 2>&1; then
      "$YABAI" -m window --focus "$wid" >/dev/null 2>&1 || true
      ndi="$("$YABAI" -m query --windows --window "$wid" | "$JQ" '.display')"
      read_zones "$ndi"; snap "${ZONES[$(( ${#ZONES[@]} - 1 ))]}"
    else
      snap "${ZONES[0]}"
    fi
    ;;
  *)
    echo "usage: $(basename "$0") left|right|fill" >&2; exit 1
    ;;
esac
