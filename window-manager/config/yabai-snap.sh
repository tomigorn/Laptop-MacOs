#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Display-aware window snapping for yabai (float layout).
#
#   yabai-snap.sh left    walk the window one zone left  (crosses displays)
#   yabai-snap.sh right   walk the window one zone right (crosses displays)
#   yabai-snap.sh fill    fill the whole display (NOT native fullscreen)
#   yabai-snap.sh extend-right  grow the window's right edge into the next zone
#   yabai-snap.sh extend-left   grow the window's left edge into the previous zone
#
# Each monitor's zones are defined in ~/.config/yabai/zones.conf, matched by
# stable display UUID so reconnecting a monitor never scrambles the ratios.
# ---------------------------------------------------------------------------
set -euo pipefail
cmd="${1:-}"

# launchd (skhd) gives a minimal PATH; make the Homebrew bins findable.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

YABAI="$(command -v yabai)"
JQ="$(command -v jq)"
ZONES_FILE="${YABAI_ZONES_FILE:-$HOME/.config/yabai/zones.conf}"
FILL_GRID="1:1:0:0:1:1"

# Act on the focused window, addressed by id (focus doesn't reliably follow a
# window across displays, so we never re-query "the focused window").
win="$("$YABAI" -m query --windows --window)"
[ -n "$win" ] || exit 0
wid="$(echo "$win" | "$JQ" '.id')"
di="$(echo "$win" | "$JQ" '.display')"
displays="$("$YABAI" -m query --displays)"

disp_json() { echo "$displays" | "$JQ" "map(select(.index==$1))[0]"; }
snap()      { "$YABAI" -m window "$wid" --grid "$1"; }

# Append a "monitor" line for any connected display not yet in zones.conf,
# so the file fills itself in as monitors are plugged in.
register_displays() {
  [ -w "$ZONES_FILE" ] || return 0
  local uuid w
  while read -r uuid w; do
    [ -n "$uuid" ] || continue
    grep -q "$uuid" "$ZONES_FILE" 2>/dev/null && continue
    printf 'monitor %s  mon-%s  unknown    # %spt, first seen %s\n' \
      "$uuid" "${uuid:0:8}" "$w" "$(date +%F)" >> "$ZONES_FILE"
  done < <(echo "$displays" | "$JQ" -r '.[] | "\(.uuid) \(.frame.w|floor)"')
}

# Echo display $1's zones as grid specs (ROWS:COLS:X:Y:W:H), left -> right.
# Resolve UUID -> monitor name -> layout percentages (else the "default" layout).
# COLS is fixed at 100 so percentages map straight to columns.
profile_for_display() {
  local uuid name
  uuid="$(disp_json "$1" | "$JQ" -r '.uuid')"
  name="$(awk -v u="$uuid" '$1=="monitor" && $2==u {print $3; exit}' "$ZONES_FILE")"
  [ -n "$name" ] || name="default"
  awk -v n="$name" '
    $1=="layout" && $2==n         { for (i=3;i<=NF;i++) sel[++s]=$i; got=1 }
    $1=="layout" && $2=="default" { for (i=3;i<=NF;i++) def[++d]=$i }
    END { x=0
      if (got) for (i=1;i<=s;i++) { printf "1:100:%d:0:%d:1\n", x, sel[i]; x+=sel[i] }
      else     for (i=1;i<=d;i++) { printf "1:100:%d:0:%d:1\n", x, def[i]; x+=def[i] }
    }' "$ZONES_FILE"
}

# Load display $1's zones into the ZONES array (bash 3.2-safe; falls back 50/50).
read_zones() {
  ZONES=()
  local line
  while IFS= read -r line; do ZONES+=("$line"); done < <(profile_for_display "$1")
  [ "${#ZONES[@]}" -gt 0 ] || ZONES=("1:2:0:0:1:1" "1:2:1:0:1:1")
}

# Index of the zone the window currently fills, or -1 if it matches none (e.g.
# it's filled/fullscreen or a free floating size). Matching on both position and
# width is what makes a filled window count as "no zone", so left/right then
# snap within THIS display instead of jumping to a neighbour.
current_zone_index() {
  local dj dx dw wx ww best=-1 bestd i=0 z zx zw dist
  dj="$(disp_json "$di")"
  dx="$(echo "$dj"  | "$JQ" '.frame.x')"; dw="$(echo "$dj"  | "$JQ" '.frame.w')"
  wx="$(echo "$win" | "$JQ" '.frame.x')"; ww="$(echo "$win" | "$JQ" '.frame.w')"
  bestd="$(awk -v d="$dw" 'BEGIN{print d*0.15}')"   # tolerance: 15% of display width
  for z in "${ZONES[@]}"; do
    IFS=: read -r _ _ zx _ zw _ <<<"$z"             # ROWS:COLS:X:Y:W:H (COLS is 100)
    dist="$(awk -v dx="$dx" -v dw="$dw" -v zx="$zx" -v zw="$zw" -v wx="$wx" -v ww="$ww" \
      'BEGIN{ex=dx+zx/100*dw; ew=zw/100*dw; print (wx>ex?wx-ex:ex-wx)+(ww>ew?ww-ew:ew-ww)}')"
    if awk -v d="$dist" -v bd="$bestd" 'BEGIN{exit !(d<bd)}'; then bestd="$dist"; best="$i"; fi
    i=$((i+1))
  done
  echo "$best"
}

# Window's current zone span as "lo hi": lo = zone whose start is nearest the
# window's left edge, hi = zone whose end is nearest its right edge.
current_span() {
  local dj dx dw wx ww lp rp i=0 lo=0 hi=0 lod=1e18 hid=1e18 z s w end dl dr
  dj="$(disp_json "$di")"
  dx="$(echo "$dj"  | "$JQ" '.frame.x')"; dw="$(echo "$dj"  | "$JQ" '.frame.w')"
  wx="$(echo "$win" | "$JQ" '.frame.x')"; ww="$(echo "$win" | "$JQ" '.frame.w')"
  lp="$(awk -v wx="$wx" -v dx="$dx" -v dw="$dw" 'BEGIN{print (wx-dx)/dw*100}')"
  rp="$(awk -v wx="$wx" -v ww="$ww" -v dx="$dx" -v dw="$dw" 'BEGIN{print (wx+ww-dx)/dw*100}')"
  for z in "${ZONES[@]}"; do
    IFS=: read -r _ _ s _ w _ <<<"$z"; end=$(( s + w ))
    dl="$(awk -v a="$s"   -v b="$lp" 'BEGIN{d=a-b;print (d<0?-d:d)}')"
    dr="$(awk -v a="$end" -v b="$rp" 'BEGIN{d=a-b;print (d<0?-d:d)}')"
    if awk -v d="$dl" -v bd="$lod" 'BEGIN{exit !(d<bd)}'; then lod="$dl"; lo="$i"; fi
    if awk -v d="$dr" -v bd="$hid" 'BEGIN{exit !(d<bd)}'; then hid="$dr"; hi="$i"; fi
    i=$(( i + 1 ))
  done
  [ "$hi" -ge "$lo" ] || hi="$lo"
  echo "$lo $hi"
}

# One grid spec covering zones $1..$2 (inclusive).
span_grid() {
  local sx ex ew
  IFS=: read -r _ _ sx _ _  _ <<<"${ZONES[$1]}"
  IFS=: read -r _ _ ex _ ew _ <<<"${ZONES[$2]}"
  echo "1:100:$sx:0:$(( ex + ew - sx )):1"
}

register_displays

case "$cmd" in
  fill)
    snap "$FILL_GRID"
    ;;
  right)
    read_zones "$di"; ci="$(current_zone_index)"; last=$(( ${#ZONES[@]} - 1 ))
    if   [ "$ci" -eq -1 ];      then snap "${ZONES[$last]}"        # filled/none -> right zone here
    elif [ "$ci" -lt "$last" ]; then snap "${ZONES[$((ci + 1))]}"  # next zone here
    elif "$YABAI" -m window "$wid" --display east >/dev/null 2>&1; then
      ndi="$("$YABAI" -m query --windows --window "$wid" | "$JQ" '.display')"
      read_zones "$ndi"; snap "${ZONES[0]}"                        # crossed east -> its left zone
      "$YABAI" -m window --focus "$wid" || true
    else snap "${ZONES[$ci]}"                                      # rightmost, no display east
    fi
    ;;
  left)
    read_zones "$di"; ci="$(current_zone_index)"
    if   [ "$ci" -eq -1 ]; then snap "${ZONES[0]}"                 # filled/none -> left zone here
    elif [ "$ci" -gt 0 ];  then snap "${ZONES[$((ci - 1))]}"       # previous zone here
    elif "$YABAI" -m window "$wid" --display west >/dev/null 2>&1; then
      ndi="$("$YABAI" -m query --windows --window "$wid" | "$JQ" '.display')"
      read_zones "$ndi"; snap "${ZONES[$(( ${#ZONES[@]} - 1 ))]}"  # crossed west -> its right zone
      "$YABAI" -m window --focus "$wid" || true
    else snap "${ZONES[0]}"                                        # leftmost, no display west
    fi
    ;;
  extend-right)
    read_zones "$di"; read -r lo hi <<<"$(current_span)"; last=$(( ${#ZONES[@]} - 1 ))
    if [ "$hi" -lt "$last" ]; then hi=$(( hi + 1 )); fi               # grow right edge one zone
    snap "$(span_grid "$lo" "$hi")"
    ;;
  extend-left)
    read_zones "$di"; read -r lo hi <<<"$(current_span)"
    if [ "$lo" -gt 0 ]; then lo=$(( lo - 1 )); fi                     # grow left edge one zone
    snap "$(span_grid "$lo" "$hi")"
    ;;
  *)
    echo "usage: $(basename "$0") left|right|fill|extend-left|extend-right" >&2; exit 1
    ;;
esac
