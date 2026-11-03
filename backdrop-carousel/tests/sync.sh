#!/opt/homebrew/bin/bash
# backdrop-carousel/sync.sh in a temp HOME with stubbed curl and pgrep; no network, no real Brave.
#   backdrop-carousel/tests/sync.sh
set -uo pipefail

SYNC="$(cd "$(dirname "$0")/.." && pwd)/sync.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/sync.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
export HOME="$WORK/home" PATH="$WORK/bin:$PATH" FIXTURE_LIST="$WORK/list.json" CURL_LOG="$WORK/curl.log"
mkdir -p "$HOME"

cat > "$WORK/bin/curl" <<'STUB'
#!/bin/sh
echo "curl $*" >> "$CURL_LOG"
[ -n "${CURL_FAIL:-}" ] && exit 22
url=""; out=""
while [ $# -gt 0 ]; do
  case "$1" in -o) out="$2"; shift 2 ;; -*) shift ;; *) url="$1"; shift ;; esac
done
case "$url" in
  */photo/*) printf 'bytes-of-%s' "${url##*/}" > "$out" ;;
  *) cat "$FIXTURE_LIST" ;;
esac
STUB
cat > "$WORK/bin/pgrep" <<'STUB'
#!/bin/sh
[ -n "${BRAVE_RUNNING:-}" ]
STUB
chmod +x "$WORK/bin/curl" "$WORK/bin/pgrep"

LOCAL="$HOME/Pictures/BackdropCarousel"
BRAVE="$HOME/Library/Application Support/BraveSoftware/Brave-Browser/Default"
IMAGES="$BRAVE/sanitized_background_images"

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
contains() { [[ "$1" == *"$2"* ]]; }
eq() { [ "$1" = "$2" ]; }

fresh() {  # fresh [with-brave]
  rm -rf "$HOME" "$CURL_LOG"; mkdir -p "$HOME"
  unset BRAVE_RUNNING CURL_FAIL
  printf '[{"name":"a.jpg"},{"name":"b.jpg"}]' > "$FIXTURE_LIST"
  if [ "${1:-}" = brave ]; then
    mkdir -p "$IMAGES"
    printf '{"brave":{"new_tab_page":{"show_background_image":true}},"other":1}' > "$BRAVE/Preferences"
  fi
}

# 1. no Brave: downloads, reports
fresh
out="$(/bin/zsh "$SYNC")"; rc=$?
check "no Brave: exit 0" test "$rc" -eq 0
check "no Brave: photos downloaded" test -f "$LOCAL/a.jpg" -a -f "$LOCAL/b.jpg"
check "no Brave: content from photo URL" eq "$(cat "$LOCAL/a.jpg")" "bytes-of-a.jpg"
check "no Brave: message" eq "$out" "Synced 2 photos to wallpaper. Brave not installed."
check "no Brave: list fetched from server root" contains "$(cat "$CURL_LOG")" "curl -sf https://backdrop-carousel.holy-grail.ch/"

# 2. existing local photos are not re-downloaded, stale ones are removed
fresh
mkdir -p "$LOCAL"; echo keep > "$LOCAL/a.jpg"; echo stale > "$LOCAL/old.jpg"
/bin/zsh "$SYNC" >/dev/null
check "existing photo kept untouched" eq "$(cat "$LOCAL/a.jpg")" keep
check "existing photo not fetched" test "$(grep -c 'photo/a.jpg' "$CURL_LOG")" -eq 0
check "missing photo fetched" test -f "$LOCAL/b.jpg"
check "stale local photo removed" test ! -e "$LOCAL/old.jpg"

# 3. server unreachable
fresh
out="$(CURL_FAIL=1 /bin/zsh "$SYNC" 2>&1)"; rc=$?
check "server error: exit 1" test "$rc" -eq 1
check "server error: message" eq "$out" "ERROR: Failed to fetch photo list from server"

# 4. Brave running: wallpaper only
fresh brave
out="$(BRAVE_RUNNING=1 /bin/zsh "$SYNC")"
check "Brave running: message" eq "$out" "Synced 2 photos to wallpaper. Brave skipped (running)."
check "Brave running: Brave images untouched" test -z "$(ls "$IMAGES")"

# 5. Brave present and closed: images and prefs updated
fresh brave
echo stale > "$IMAGES/old.jpg"
out="$(/bin/zsh "$SYNC")"
check "Brave: message" eq "$out" "Synced 2 photos to wallpaper + Brave."
check "Brave: images copied" test -f "$IMAGES/a.jpg" -a -f "$IMAGES/b.jpg"
check "Brave: stale image removed" test ! -e "$IMAGES/old.jpg"
prefs="$(python3 -c "
import json,sys
p=json.load(open(sys.argv[1]))
n=p['brave']['new_tab_page']
print(n['custom_background_image_list'], n['background']['type'], n['background']['random'], n['background']['selected_value'], p['other'], n['show_background_image'])
" "$BRAVE/Preferences")"
check "Brave: prefs set, other keys kept" eq "$prefs" "['a.jpg', 'b.jpg'] custom_image True a.jpg 1 True"

# 6. selected_value kept when still in the list
fresh brave
printf '{"brave":{"new_tab_page":{"background":{"selected_value":"b.jpg"}}}}' > "$BRAVE/Preferences"
/bin/zsh "$SYNC" >/dev/null
check "Brave: valid selected_value kept" contains "$(cat "$BRAVE/Preferences")" '"selected_value":"b.jpg"'

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
