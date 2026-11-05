#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Display-aware window snapping for yabai (float layout).
#
#   yabai-snap.sh left    walk the window one zone left  (crosses displays)
#   yabai-snap.sh right   walk the window one zone right (crosses displays)
#   yabai-snap.sh fill    fill the whole display (NOT native fullscreen)
#   yabai-snap.sh extend-right  grow the window's right edge into the next zone
#   yabai-snap.sh extend-left   grow the window's left edge into the previous zone
#   yabai-snap.sh connected     write the "Currently connected" block to connected.txt
#   yabai-snap.sh arrange       place the screens as the matching "arrange" line says
#
# Each monitor's zones are defined in ~/.config/yabai/zones.conf, matched by
# stable display UUID so reconnecting a monitor never scrambles the ratios.
# ---------------------------------------------------------------------------
set -euo pipefail
cmd="${1:-}"

# launchd (skhd) gives a minimal PATH; make the Homebrew bins findable.
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

YABAI="$(command -v yabai)"
JQ="$(command -v jq)"
ZONES_FILE="${YABAI_ZONES_FILE:-$HOME/.config/yabai/zones.conf}"
ZONES_REAL="$(readlink -f "$ZONES_FILE" 2>/dev/null || echo "$ZONES_FILE")"
CONNECTED_DIR="$(dirname "$ZONES_FILE")"
FILL_GRID="1:1:0:0:1:1"
SNAP_LOG="${YABAI_SNAP_LOG:-/tmp/yabai-snap_${USER:-$(id -un)}.log}"

note() { { printf '%s %s: %s\n' "$(date '+%F %T')" "$cmd" "$*" >> "$SNAP_LOG"; } 2>/dev/null || true; }

displays="$("$YABAI" -m query --displays 2>/dev/null || true)"
if [ -z "$displays" ]; then                      # yabai not running / not answering
  if [ "$cmd" = "connected" ]; then
    echo "yabai is not running — connected-monitor list not refreshed" >&2
  elif [ "$cmd" != "arrange" ]; then
    note "yabai not answering"
  fi
  exit 0
fi

# Act on the focused window, addressed by id (focus doesn't reliably follow a
# window across displays, so we never re-query "the focused window").
#
# Guard the query: some focused windows can't be queried (no managed/AX window —
# see "Known limitations" in window-manager.md). A yabai error or non-JSON result
# must make us no-op cleanly, not abort the whole script under `set -e`.
# "connected" and "arrange" work on displays only, so they skip this guard —
# otherwise they would silently do nothing whenever no window is focusable.
if [ "$cmd" != "connected" ] && [ "$cmd" != "arrange" ]; then
  # skhd has no terminal to show errors in; keep them until the next reboot
  case "$cmd" in
    left|right|fill|extend-left|extend-right)
      exec 2>>"$SNAP_LOG" || true
      set -E
      trap '[ "$BASH_SUBSHELL" -gt 0 ] || note "failed at line $LINENO: $BASH_COMMAND"' ERR
      ;;
  esac
  win="$("$YABAI" -m query --windows --window || true)"
  wid="$(printf '%s' "$win" | "$JQ" -r '.id // empty' 2>/dev/null || true)"
  if [ -z "$wid" ]; then note "no window to act on"; exit 0; fi
  di="$(printf '%s' "$win" | "$JQ" -r '.display' 2>/dev/null || true)"
  app="$(printf '%s' "$win" | "$JQ" -r '.app // "?"' 2>/dev/null || true)"
fi

disp_json() { echo "$displays" | "$JQ" "map(select(.index==$1))[0]"; }
# yabai misses the Dock often, so the bottom gap is fixed: "bottom <pt>" in zones.conf, default 59.
BOTTOM="$(awk '$1=="bottom" { b=$2 } END { print (b=="" ? 59 : b) }' "$ZONES_FILE" 2>/dev/null || echo 59)"
snap() {
  local w dj
  "$YABAI" -m window "$wid" --grid "$1"
  w="$("$YABAI" -m query --windows --window "$wid")"
  dj="$(disp_json "$(echo "$w" | "$JQ" '.display')")"
  "$YABAI" -m window "$wid" --resize "abs:$(echo "$w $dj" | "$JQ" -rs --argjson b "$BOTTOM" \
    '"\(.[0].frame.w|floor):\(.[1].frame.y + .[1].frame.h - $b - .[0].frame.y|floor)"')"
}

# --- Monitor model fallback -------------------------------------------------
# Shared desks give every monitor a new UUID, so a "model <Product-Name> <name> [<location>]"
# line picks the layout by monitor model when the UUID has none.

# "<w> <h> <Product-Name>" per external display (the built-in has no ProductName).
display_models() {
  ioreg -lw0 2>/dev/null | awk '
    function val(re,   s) { if (!match($0, re)) return ""; s = substr($0, RSTART, RLENGTH); sub(/^[^=]*=/, "", s); gsub(/"/, "", s); return s }
    /"DisplayAttributes"/ {
      p = val("\"ProductName\"=\"[^\"]*\""); w = val("\"NativeFormatHorizontalPixels\"=[0-9]+"); h = val("\"NativeFormatVerticalPixels\"=[0-9]+")
      if (p == "" || w == "" || h == "") next
      gsub(/ /, "-", p); print w, h, p
    }'
}

# ioreg takes ~170ms: read it at most once per run, and only when needed.
MODELS="" MODELS_READ=""
load_models() {
  [ -z "$MODELS_READ" ] || return 0
  MODELS="$(display_models || true)"; MODELS_READ=1
}

# Product name of the display with frame $1 x $2: the ioreg entries within 2% of
# its aspect ratio, if they all agree; empty otherwise. Needs load_models first.
model_for_display() {
  printf '%s\n' "$MODELS" | awk -v fw="$1" -v fh="$2" '
    NF >= 3 && $2 > 0 && fh > 0 { r = ($1 / $2) / (fw / fh)
      if (r > 0.98 && r < 1.02) { if (m != "" && m != $3) bad = 1; m = $3 } }
    END { if (!bad) print m }'
}

model_rule() { awk -v m="$1" '{ sub(/^\* +/, "") } $1=="model" && $2==m && m!="" {print $3; exit}' "$ZONES_FILE"; }
model_rule_location() { awk -v m="$1" '{ sub(/^\* +/, "") } $1=="model" && $2==m && m!="" {print $4; exit}' "$ZONES_FILE"; }
has_layout() { awk -v n="$1" '$1=="layout" && $2==n {f=1; exit} END {exit !f}' "$ZONES_FILE"; }

# Set RES_NAME for display UUID $1 with frame $2 x $3: the UUID's monitor name if
# it has a layout line, else the name of its model rule, else "default".
# Sets a variable instead of echoing so the ioreg cache survives (no subshell).
resolve_name() {
  RES_NAME="$(awk -v u="$1" '{ sub(/^\* +/, "") } $1=="monitor" && $2==u {print $3; exit}' "$ZONES_FILE")"
  has_layout "$RES_NAME" && return 0
  load_models
  RES_NAME="$(model_rule "$(model_for_display "$2" "$3")")"
  [ -n "$RES_NAME" ] || RES_NAME="default"
}

# Rename over the link target: runs fire concurrently, none may read a half-written zones.conf.
save_zones() { chmod "$(stat -f %Lp "$ZONES_REAL")" "$1" && mv -f "$1" "$ZONES_REAL"; }

# Add a "monitor" line after the last one for any connected display not yet in
# zones.conf, so the file fills itself in as monitors are plugged in. Displays
# covered by a model rule are left out, so shared desks don't pile up lines.
register_displays() {
  [ -w "$ZONES_FILE" ] || return 0
  local uuid w h model new="" tmp
  while read -r uuid w h; do
    [ -n "$uuid" ] || continue
    grep -q "$uuid" "$ZONES_FILE" 2>/dev/null && continue
    load_models
    model="$(model_for_display "$w" "$h")"
    [ -n "$(model_rule "$model")" ] && continue
    new+="$(printf 'monitor %s  %-22s%-25s# %spt, %sfirst seen %s' \
      "$uuid" "mon-${uuid:0:8}" unknown "$w" "${model:+$model, }" "$(date +%F)")"$'\n'
  done < <(echo "$displays" | "$JQ" -r '.[] | "\(.uuid) \(.frame.w|floor) \(.frame.h|floor)"')
  [ -n "$new" ] || return 0
  tmp="$(mktemp "$ZONES_REAL.XXXXXX")" || return 0
  if NEW="$new" awk '
      function add(   n, i, l, f) {
        n = split(ENVIRON["NEW"], l, "\n")
        for (i = 1; i <= n; i++) { split(l[i], f, " "); if (f[2] != "" && !(f[2] in seen)) print l[i] }
      }
      FNR==NR { sub(/^\* +/, ""); if ($1=="monitor") { last=FNR; seen[$2]=1 } next }
      { print } FNR==last { add() }
      END { if (!last) add() }' "$ZONES_FILE" "$ZONES_FILE" > "$tmp"; then
    save_zones "$tmp"
  fi
  rm -f "$tmp"
}

# Mark the lines of connected screens with "* ": their monitor line, or the model
# rule used by a screen without one. The others get "  ", so the columns stay
# aligned. Rewritten only when a mark changes.
mark_connected() {
  [ -w "$ZONES_FILE" ] || return 0
  local uuid w h model on_uuids=" " on_models=" " tmp
  while read -r uuid w h; do
    [ -n "$uuid" ] || continue
    on_uuids+="$uuid "
    awk -v u="$uuid" '{ sub(/^\* +/, "") } $1=="monitor" && $2==u {f=1; exit} END {exit !f}' "$ZONES_FILE" && continue
    load_models
    model="$(model_for_display "$w" "$h")"
    [ -z "$model" ] || on_models+="$model "
  done < <(echo "$displays" | "$JQ" -r '.[] | "\(.uuid) \(.frame.w|floor) \(.frame.h|floor)"')
  tmp="$(mktemp "$ZONES_REAL.XXXXXX")" || return 0
  if ON_UUIDS="$on_uuids" ON_MODELS="$on_models" awk '
      { line = $0; sub(/^[* ]+/, "", line); split(line, f, " ") }
      f[1]=="monitor" { print (index(ENVIRON["ON_UUIDS"], " " f[2] " ") ? "* " : "  ") line; next }
      f[1]=="model"   { print (index(ENVIRON["ON_MODELS"], " " f[2] " ") ? "* " : "  ") line; next }
      { print }' "$ZONES_FILE" > "$tmp" && ! cmp -s "$tmp" "$ZONES_FILE"; then
    save_zones "$tmp"
  fi
  rm -f "$tmp"
}

# --- "Currently connected" report -------------------------------------------
# zones.conf grows into "every monitor I've ever plugged in", so the interesting
# question when you open it is which of those lines are live *right now*.
# connected.txt (next to zones.conf, local) answers that, refreshed on demand.

# "<name> <location>" for a display UUID; "- -" if it isn't in zones.conf yet.
monitor_entry() {
  awk -v u="$1" '
    { sub(/^\* +/, "") }
    $1=="monitor" && $2==u { print $3, ($4=="" ? "-" : $4); found=1; exit }
    END { if (!found) print "-", "-" }' "$ZONES_FILE"
}

# The layout percentages for monitor <name>, falling back to "layout default".
layout_sizes() {
  awk -v n="$1" '
    $1=="layout" && $2==n         { for (i=3;i<=NF && $i !~ /^#/;i++) s = s (i>3 ? " " : "") $i; got=1 }
    $1=="layout" && $2=="default" { for (i=3;i<=NF && $i !~ /^#/;i++) d = d (i>3 ? " " : "") $i }
    END { print (got ? s : d) }' "$ZONES_FILE"
}

# The whole comment block, on stdout.
connected_block() {
  local idx uuid w h focus name loc sizes entry mark model
  local fmt='# %s %-3s %-36s %-7s %-19s %-13s %-12s %s\n'
  echo "# --- Currently connected (auto-generated — do not edit) ---------------------"
  echo "#   Last refreshed $(date '+%F %H:%M'). Regenerate with:  ./yabai-snap.sh connected"
  echo "#   (also runs automatically when you open this folder from Spotlight)"
  echo "#"
  # shellcheck disable=SC2059
  printf "$fmt" ' ' 'idx' 'uuid' 'width' 'name' 'location' 'layout' 'model'
  load_models
  while read -r idx uuid w h focus; do
    [ -n "$uuid" ] || continue
    entry="$(monitor_entry "$uuid")"
    name="${entry%% *}"
    loc="${entry##* }"
    resolve_name "$uuid" "$w" "$h"
    sizes="$(layout_sizes "$RES_NAME")"
    model="$(model_for_display "$w" "$h")"
    if [ "$focus" = "true" ]; then mark='*'; else mark=' '; fi
    # shellcheck disable=SC2059
    printf "$fmt" "$mark" "$idx" "$uuid" "${w}pt" "$name" "$loc" "$sizes" "${model:--}"
  done < <(echo "$displays" | "$JQ" -r '.[] | "\(.index) \(.uuid) \(.frame.w|floor) \(.frame.h|floor) \(.["has-focus"])"')
  echo "#"
  echo "#   * = display with keyboard focus.  name/location \"-\" = no monitor line (a model rule covers it)."
  echo "# --- end currently connected ------------------------------------------------"
}

# Write the block to connected.txt next to zones.conf, so zones.conf (in the
# repo) doesn't change on every refresh. Temp file + mv: never half-written.
update_connected_block() {
  local tmp
  [ -w "$CONNECTED_DIR" ] || return 0
  tmp="$(mktemp "$CONNECTED_DIR/.connected.XXXXXX")" || return 0
  if connected_block > "$tmp"; then mv -f "$tmp" "$CONNECTED_DIR/connected.txt"; else rm -f "$tmp"; fi
}

# --- Screen arrangement -------------------------------------------------------
# "arrange <location> <top|bottom|center> <name>..." places the screens left to
# right, applied with displayplacer.

# Set RES_NAME and RES_LOC for display UUID $1 with frame $2 x $3: the UUID line's,
# unless a model rule applies to a line without a layout.
resolve_location() {
  local entry
  resolve_name "$1" "$2" "$3"
  entry="$(monitor_entry "$1")"
  if [ "${entry%% *}" = "$RES_NAME" ] || { [ "$RES_NAME" = "default" ] && [ "${entry%% *}" != "-" ]; }; then
    RES_NAME="${entry%% *}"
    RES_LOC="${entry##* }"; [ "$RES_LOC" != "-" ] || RES_LOC=""
  else
    load_models
    RES_LOC="$(model_rule_location "$(model_for_display "$2" "$3")")"
  fi
}

sorted_words() { printf '%s\n' "$@" | sort | tr '\n' ' '; }
upper() { printf '%s' "$1" | tr '[:lower:]' '[:upper:]'; }

arrange_screens() {
  local uuid x y w h line kw loc align names have i j n found=""
  local S_UUID=() S_NAME=() S_LOC=() S_X=() S_Y=() S_W=() S_H=() ORDER=() USED=()
  load_models
  while read -r uuid x y w h; do
    [ -n "$uuid" ] || continue
    resolve_location "$uuid" "$w" "$h"
    S_UUID+=("$(upper "$uuid")"); S_NAME+=("$RES_NAME"); S_LOC+=("$RES_LOC")
    S_X+=("$x"); S_Y+=("$y"); S_W+=("$w"); S_H+=("$h"); USED+=("")
  done < <(echo "$displays" | "$JQ" -r '.[] | "\(.uuid) \(.frame.x|floor) \(.frame.y|floor) \(.frame.w|floor) \(.frame.h|floor)"')
  n="${#S_UUID[@]}"
  if [ "$n" -eq 0 ]; then echo "yabai reports no screens — screens not arranged" >&2; return 0; fi
  have="$(sorted_words "${S_NAME[@]}")"

  while IFS= read -r line; do
    line="${line%%#*}"
    read -r kw loc align names <<<"$line"
    [ "$kw" = "arrange" ] || continue
    case " ${S_LOC[*]} " in *" $loc "*) ;; *) continue ;; esac
    # shellcheck disable=SC2086
    [ "$(sorted_words $names)" = "$have" ] || continue
    found=1; break
  done < "$ZONES_FILE"
  if [ -z "$found" ]; then
    echo "no arrange line for the connected screens (names: ${have% }; locations: ${S_LOC[*]})" >&2
    return 0
  fi

  # screen index per listed name, left to right (equal names take the next unused screen)
  # shellcheck disable=SC2086
  for kw in $names; do
    for ((j = 0; j < n; j++)); do
      if [ "${S_NAME[$j]}" = "$kw" ] && [ -z "${USED[$j]}" ]; then USED[j]=1; ORDER+=("$j"); break; fi
    done
  done

  local maxh=0 cx=0 NX=() NY=()
  for j in "${ORDER[@]}"; do [ "${S_H[$j]}" -le "$maxh" ] || maxh="${S_H[$j]}"; done
  for j in "${ORDER[@]}"; do
    NX[j]="$cx"; cx=$(( cx + S_W[j] ))
    case "$align" in
      top)    NY[j]=0 ;;
      center) NY[j]=$(( (maxh - S_H[j]) / 2 )) ;;
      *)      NY[j]=$(( maxh - S_H[j] )) ;;
    esac
  done

  local dp list cmdline rest arg id main="" ARGS=() NEW=()
  dp="$(command -v displayplacer || true)"
  if [ -z "$dp" ]; then echo "displayplacer is not installed — screens not arranged" >&2; return 0; fi
  list="$("$dp" list 2>/dev/null || true)"
  cmdline="$(printf '%s\n' "$list" | grep '^displayplacer "' | tail -n 1 || true)"
  rest="${cmdline#displayplacer }"
  while :; do
    case "$rest" in *'"'*'"'*) ;; *) break ;; esac
    rest="${rest#*\"}"; ARGS+=("${rest%%\"*}"); rest="${rest#*\"}"
  done
  if [ "${#ARGS[@]}" -eq 0 ]; then echo "displayplacer list gave no arrangement — screens not arranged" >&2; return 0; fi
  # asleep or locked screens are listed as "enabled:false"; applying that would switch them off
  case "${ARGS[*]}" in *enabled:false*) echo "a screen is reported disabled — screens not arranged" >&2; return 0 ;; esac

  # index of the screen for each displayplacer argument ("" if none)
  local AIDX=()
  for ((i = 0; i < ${#ARGS[@]}; i++)); do
    arg="${ARGS[$i]}"
    id="${arg#*id:}"; id="$(upper "${id%% *}")"
    AIDX[i]=""
    for ((j = 0; j < n; j++)); do [ "${S_UUID[$j]}" != "$id" ] || AIDX[i]="$j"; done
    if [ -z "${AIDX[$i]}" ]; then echo "displayplacer and yabai list different screens — screens not arranged" >&2; return 0; fi
    case "$arg" in *"origin:(0,0)"*) main="${AIDX[$i]}" ;; esac
  done
  if [ -z "$main" ]; then echo "displayplacer lists no main screen — screens not arranged" >&2; return 0; fi

  local dx=$(( -NX[main] )) dy=$(( -NY[main] )) same=1
  for j in "${ORDER[@]}"; do
    NX[j]=$(( NX[j] + dx )); NY[j]=$(( NY[j] + dy ))
    [ "${NX[$j]}" = "${S_X[$j]}" ] && [ "${NY[$j]}" = "${S_Y[$j]}" ] || same=""
  done
  if [ -n "$same" ]; then echo "already arranged"; return 0; fi

  for ((i = 0; i < ${#ARGS[@]}; i++)); do
    arg="${ARGS[$i]}"; j="${AIDX[$i]}"
    arg="$(printf '%s' "$arg" | sed -E "s/origin:\([^)]*\)/origin:(${NX[$j]},${NY[$j]})/")"
    NEW+=("$arg")
  done
  printf 'displayplacer'; printf ' "%s"' "${NEW[@]}"; echo
  "$dp" "${NEW[@]}"
}

# Echo the zones of layout $1 as grid specs (ROWS:COLS:X:Y:W:H), left -> right,
# else the "default" layout. COLS is fixed at 100 so percentages map to columns.
profile_for_name() {
  awk -v n="$1" '
    $1=="layout" && $2==n         { for (i=3;i<=NF && $i !~ /^#/;i++) sel[++s]=$i; got=1 }
    $1=="layout" && $2=="default" { for (i=3;i<=NF && $i !~ /^#/;i++) def[++d]=$i }
    END { x=0
      if (got) for (i=1;i<=s;i++) { printf "1:100:%d:0:%d:1\n", x, sel[i]; x+=sel[i] }
      else     for (i=1;i<=d;i++) { printf "1:100:%d:0:%d:1\n", x, def[i]; x+=def[i] }
    }' "$ZONES_FILE"
}

# Load display $1's zones into the ZONES array (bash 3.2-safe; falls back 50/50).
read_zones() {
  ZONES=()
  local line dj
  dj="$(disp_json "$1")"
  resolve_name "$(echo "$dj" | "$JQ" -r '.uuid')" "$(echo "$dj" | "$JQ" '.frame.w')" "$(echo "$dj" | "$JQ" '.frame.h')"
  while IFS= read -r line; do ZONES+=("$line"); done < <(profile_for_name "$RES_NAME")
  [ "${#ZONES[@]}" -gt 0 ] || ZONES=("1:100:0:0:50:1" "1:100:50:0:50:1")
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

# True when snapping left the window where it was: it can't shrink into its zone.
window_unmoved() {
  [ "$( { printf '%s' "$win"; "$YABAI" -m query --windows --window "$wid"; } | "$JQ" -s \
    '((.[0].frame.x - .[1].frame.x) | fabs) + ((.[0].frame.w - .[1].frame.w) | fabs) <= 1')" = "true" ]
}

# cross <east|west> <zone if it can't leave this display> <first|last zone over there>
cross() {
  local err ndi z=0
  if ! err="$("$YABAI" -m window "$wid" --display "$1" 2>&1)"; then
    note "window $wid ($app) --display $1 failed: $err"
    snap "$2"
    return 0
  fi
  ndi="$("$YABAI" -m query --windows --window "$wid" | "$JQ" '.display')"
  if [ "$ndi" = "$di" ]; then
    note "window $wid ($app) still on display $di after --display $1"
    snap "$2"
    return 0
  fi
  read_zones "$ndi"
  [ "$3" = "first" ] || z=$(( ${#ZONES[@]} - 1 ))
  snap "${ZONES[$z]}"
  "$YABAI" -m window --focus "$wid" || true
}

register_displays
mark_connected

case "$cmd" in
  fill)
    snap "$FILL_GRID"
    ;;
  right)
    read_zones "$di"; ci="$(current_zone_index)"; last=$(( ${#ZONES[@]} - 1 ))
    if [ "$ci" -eq -1 ]; then
      snap "${ZONES[$last]}"
      if window_unmoved; then cross east "${ZONES[$last]}" first; fi
    elif [ "$ci" -lt "$last" ]; then snap "${ZONES[$((ci + 1))]}"
    else cross east "${ZONES[$ci]}" first
    fi
    ;;
  left)
    read_zones "$di"; ci="$(current_zone_index)"
    if [ "$ci" -eq -1 ]; then
      snap "${ZONES[0]}"
      if window_unmoved; then cross west "${ZONES[0]}" last; fi
    elif [ "$ci" -gt 0 ]; then snap "${ZONES[$((ci - 1))]}"
    else cross west "${ZONES[$ci]}" last
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
  connected)
    update_connected_block
    connected_block | sed -e 's/^# //' -e 's/^#$//'                    # same thing, readable
    ;;
  arrange)
    arrange_screens
    ;;
  *)
    echo "usage: $(basename "$0") left|right|fill|extend-left|extend-right|connected|arrange" >&2; exit 1
    ;;
esac
