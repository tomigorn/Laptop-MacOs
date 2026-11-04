#!/opt/homebrew/bin/bash
# mac-outdated check and --install against stubbed brew, msupdate, softwareupdate, sudo, PrivilegesCLI, ... with a temp HOME.
#   software-updates/tests/mac-outdated.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../mac-outdated"
FIXTURES="$HERE/fixtures"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/mac-outdated.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
BIN="$WORK/bin" FIX="$WORK/fix" APPS="$WORK/apps"
CALLS="$WORK/calls" ALLCALLS="$WORK/allcalls"
mkdir -p "$BIN" "$WORK/home"
touch "$ALLCALLS"

export HOME="$WORK/home"
export PATH="$BIN:/usr/bin:/bin"
export FIX CALLS ALLCALLS
export MAC_OUTDATED_TEST=1
export MAC_OUTDATED_PRIVILEGESCLI="$BIN/PrivilegesCLI"
export MAC_OUTDATED_MSUPDATE="$BIN/msupdate"
export MAC_OUTDATED_RUM="$BIN/RemoteUpdateManager"
export MAC_OUTDATED_APP_DIRS="$APPS"

# stub <name> <body>: every call is logged as "<name> <args>"; a file $FIX/fail-<name> makes install actions fail
stub() {
  printf '#!/bin/sh\necho "%s $*" | tee -a "$CALLS" >> "$ALLCALLS"\n%s\n' "$1" "$2" > "$BIN/$1"
  chmod +x "$BIN/$1"
}
stub brew '
case "$1" in
  --cache) echo "$FIX/brew-cache" ;;
  update) [ -f "$FIX/brew-update-stderr.txt" ] && cat "$FIX/brew-update-stderr.txt" >&2; [ -f "$FIX/fail-brew-update" ] && exit 1; exit 0 ;;
  outdated) [ -f "$FIX/brew-outdated-stderr.txt" ] && cat "$FIX/brew-outdated-stderr.txt" >&2; [ -f "$FIX/fail-brew-outdated" ] && { echo "Error: brew outdated failed" >&2; exit 1; }; cat "$FIX/brew-outdated.json" ;;
  list) cat "$FIX/brew-list-full.txt" 2>/dev/null ;;
  tap-info) [ -f "$FIX/brew-tap-info.json" ] || exit 1; cat "$FIX/brew-tap-info.json" ;;
  info)
    if [ "$4" = --installed ]; then cat "$FIX/brew-info-installed.json"; exit 0; fi
    [ -f "$FIX/brew-info-$4.json" ] || { echo "Error: Cask $4 is unavailable" >&2; exit 1; }
    cat "$FIX/brew-info-$4.json" ;;
  upgrade)
    if [ -f "$FIX/prompt-brew" ]; then
      printf "Proceed? "; i=0
      while [ ! -f "$FIX/go" ] && [ "$i" -lt 60 ]; do sleep 0.1; i=$((i + 1)); done; echo
    fi
    [ -f "$FIX/chown-brew" ] && for i in $(seq 300); do echo "chown: /Applications/Example.app/Contents/f$i: Operation not permitted"; done
    [ -f "$FIX/five-brew" ] && for i in 1 2 3 4 5; do echo "Warning: cask c$i: not upgraded"; done
    printf "==> Upgrading 1 outdated package\n50%%\r100%%\n"
    [ -f "$FIX/exit-brew" ] && exit "$(cat "$FIX/exit-brew")"; [ -f "$FIX/fail-brew" ] && exit 1; exit 0 ;;
esac'
stub msupdate '
case "$1" in
  --list) cat "$FIX/msupdate-list.txt" ;;
  --install) [ -f "$FIX/exit-msupdate" ] && exit "$(cat "$FIX/exit-msupdate")"; [ -f "$FIX/fail-msupdate" ] && exit 1; exit 0 ;;
esac'
stub RemoteUpdateManager '
case "$1" in
  --action=list) cat "$FIX/rum-list.txt" ;;
  --action=install) echo "Successfully installed (AdobeAcrobatDC)"; [ -f "$FIX/exit-rum" ] && exit "$(cat "$FIX/exit-rum")"; [ -f "$FIX/fail-rum" ] && exit 1; exit 0 ;;
esac'
stub mas '
case "$1" in
  outdated) [ "$2" = --json ] || exit 9; [ -f "$FIX/fail-mas-outdated" ] && { echo "Error: offline" >&2; exit 1; }; echo "Warning: Found a likely App Store app that is not indexed in Spotlight" >&2; cat "$FIX/mas-outdated.json" ;;
  upgrade) [ -f "$FIX/fail-mas" ] && exit 1; exit 0 ;;
esac'
stub softwareupdate '
case "$1" in
  --list) [ -f "$FIX/fail-softwareupdate-list" ] && { echo "Cannot connect to the Apple Software Update server." >&2; exit 1; }; cat "$FIX/softwareupdate-list.txt" >&2 ;;
  --install) echo "Restart is required to complete installation"; [ -f "$FIX/fail-softwareupdate" ] && exit 1; exit 0 ;;
esac'
stub sw_vers 'echo 27.2'
stub pipx '
case "$1" in
  list) cat "$FIX/pipx-list.json"; [ -f "$FIX/fail-pipx-list" ] && exit 1; exit 0 ;;
  runpip) f="$FIX/pip-index-$2.txt"; [ -f "$f" ] || exit 1; cat "$f"; grep -q ERROR "$f" && exit 1; exit 0 ;;
  upgrade-all) [ -f "$FIX/fail-pipx" ] && exit 1; exit 0 ;;
esac'
stub code '
case "$1" in
  --list-extensions) cat "$FIX/code-extensions.txt" ;;
  --update-extensions) [ -f "$FIX/fail-code" ] && exit 1; exit 0 ;;
esac'
stub curl '
for a; do url=$a; done
case "$url" in
  https://example.com/*) cat "$FIX/appcast.xml" ;;
  *) exit 6 ;;
esac'
cat > "$BIN/sudo" <<'EOF'
#!/bin/sh
if [ "$1" = -v ]; then echo "sudo -v" | tee -a "$CALLS" >> "$ALLCALLS"; exit 0; fi
n=$(basename "$1"); shift
echo "sudo $n $*" | tee -a "$CALLS" >> "$ALLCALLS"
exec "$(dirname "$0")/$n" "$@"
EOF
chmod +x "$BIN/sudo"
# $FIX/privileges-expire-after N: admin for the first N --status calls, afterwards $FIX/privileges-status-later.txt or standard
stub PrivilegesCLI '
[ "$1" = --status ] || exit 0
n=$(($(cat "$FIX/privileges-count" 2>/dev/null || echo 0) + 1)); echo "$n" > "$FIX/privileges-count"
if [ -f "$FIX/privileges-expire-after" ] && [ "$n" -gt "$(cat "$FIX/privileges-expire-after")" ]; then
  cat "$FIX/privileges-status-later.txt" 2>/dev/null || cat "$FIX/privileges-status-standard.txt"
else
  cat "$FIX/privileges-status.txt"
fi'

# make_app <name> <bundle id> <version> [feed] [sparkle|mas]
make_app() {
  local app="$APPS/$1.app"
  mkdir -p "$app/Contents"
  {
    printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0"><dict>\n'
    printf '<key>CFBundleIdentifier</key><string>%s</string>\n<key>CFBundleShortVersionString</key><string>%s</string>\n' "$2" "$3"
    [ -n "${4:-}" ] && printf '<key>SUFeedURL</key><string>%s</string>\n' "$4"
    printf '</dict></plist>\n'
  } > "$app/Contents/Info.plist"
  case "${5:-}" in
    sparkle) mkdir -p "$app/Contents/Frameworks/Sparkle.framework" ;;
    mas) mkdir -p "$app/Contents/_MASReceipt" ;;
  esac
}
# cask_like <token> <app name> <version>: a brew info fixture for a cask that installs <app name>.app
cask_like() {
  jq --arg a "$2.app" --arg v "$3" \
    '.casks[0].version = $v | .casks[0].artifacts = [{app: [$a]}]' \
    "$FIXTURES/brew-info-keepassxc.json" > "$FIX/brew-info-$1.json"
}

# fixtures_outdated / fixtures_current: a fresh $FIX and app folder for each run
fixtures_outdated() {
  rm -rf "$FIX" "$APPS"; mkdir -p "$FIX" "$APPS"
  cp "$FIXTURES"/* "$FIX/"
  jq --arg k token '.casks |= map({($k): (.name[0] | ascii_downcase | gsub(" "; "-")), auto_updates: (.name[0] == "Discord")} + .)' \
    "$FIXTURES/brew-info-installed.json" > "$FIX/brew-info-installed.json"
  cp "$FIX/pip-index-fail.txt" "$FIX/pip-index-example-tool.txt"
  cp "$FIX/pip-index-xxh.txt" "$FIX/pip-index-xxh-xxh.txt"
  make_app Fork com.example.fork 2.70.2 https://example.com/fork/appcast.xml sparkle
  make_app Current com.example.current 2.71.1 https://example.com/current/appcast.xml sparkle
  make_app Broken com.example.broken 1.0 https://unreachable.example.org/appcast.xml sparkle
  make_app Ghostty com.mitchellh.ghostty 1.0 https://example.com/ghostty/appcast.xml sparkle
  make_app KeePassXC org.keepassxc.keepassxc 2.7.9
  make_app "Microsoft Word" com.microsoft.Word 16.114.3
  make_app "Google Chrome" com.google.Chrome 150.0
  make_app Telegram ru.keepcoder.Telegram 13.1.0 "" mas
  make_app "ETH Self Service" com.jamfsoftware.selfservice.mac 11.0
  make_app NoCask com.example.nocask 1.0
  make_app Discord com.hammerandchisel.discord 0.0.389
  make_app "iStat Menus" com.bjango.istatmenus 7.0
  cask_like microsoft-word "Microsoft Word" 99.0
  cask_like google-chrome "Google Chrome" 999.0
  cask_like telegram Telegram 99.0
  cask_like eth-self-service "ETH Self Service" 99.0
}
fixtures_current() {
  fixtures_outdated
  rm -rf "$APPS"; mkdir -p "$APPS"
  cp "$FIX/brew-outdated-none.json" "$FIX/brew-outdated.json"
  cp "$FIX/msupdate-none.txt" "$FIX/msupdate-list.txt"
  cp "$FIX/rum-none.txt" "$FIX/rum-list.txt"
  : > "$FIX/mas-outdated.json"
  cp "$FIX/softwareupdate-none.txt" "$FIX/softwareupdate-list.txt"
  printf 'xxh-xxh (0.8.14)\n' > "$FIX/pip-index-xxh-xxh.txt"
  printf 'example-tool (0.1.0)\n' > "$FIX/pip-index-example-tool.txt"
}
# admin_setup <status: admin|standard> <minutes left, "none" = no expiry line>
admin_setup() {
  cp "$FIX/privileges-status-$1.txt" "$FIX/privileges-status.txt"
  if [ "$1" = admin ]; then
    case $2 in
      none) sed -i '' '/expire in/d' "$FIX/privileges-status.txt" ;;
      1) sed -i '' 's/expire in 19 minutes/expire in 1 minute/' "$FIX/privileges-status.txt" ;;
      *) sed -i '' "s/expire in 19 minutes/expire in $2 minutes/" "$FIX/privileges-status.txt" ;;
    esac
  fi
}

out="" rc=0
run() { : > "$CALLS"; rm -f "$FIX/privileges-count"; "$SCRIPT" "$@" > "$WORK/out" 2>&1 < /dev/null; rc=$?; out="$(tr -s ' ' < "$WORK/out")"; }
run_input() { local input="$1"; shift; : > "$CALLS"; rm -f "$FIX/privileges-count"; "$SCRIPT" "$@" > "$WORK/out" 2>&1 <<< "$input"; rc=$?; out="$(tr -s ' ' < "$WORK/out")"; }
calls() { cat "$CALLS"; }
install_calls() { grep -E '^(sudo|softwareupdate --install|RemoteUpdateManager --action=install|brew (update|upgrade)|msupdate --install|mas upgrade|pipx upgrade-all|code --update-extensions)' "$CALLS"; }

fails=0
check() {  # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fails=$((fails + 1)); fi
}
contains() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }
equals() { [ "$1" = "$2" ]; }
has() { grep -qE "$2" <<< "$1"; }
no_match() { ! grep -qE "$2" <<< "$1"; }
only_allowed_sudo() {
  local bad
  bad=$(grep '^sudo ' <<< "$1" | grep -vE '^sudo (-v|softwareupdate --install --all|RemoteUpdateManager --action=install|mas upgrade)$')
  [ -z "$bad" ]
}

# ── check mode: parsers ──────────────────────────────────────────────────────
fixtures_outdated
run
check "check: something outdated -> exit 1" equals "$rc" 1
check "brew: formula, last installed version" contains "$out" "aom 3.15.2 → 3.15.3"
check "brew: formula" contains "$out" "bash 5.3.15 → 5.3.20"
check "brew: cask" contains "$out" "ghostty 1.3.1 → 1.4.0"
check "brew: pinned formula skipped" lacks "$out" "node@20"
check "brew: update first" equals "$(grep -E '^brew (update|outdated)' "$CALLS" | head -1 | cut -d' ' -f1-2)" "brew update"
check "msupdate: Word with installed app version" contains "$out" "Microsoft Word 16.114.3 → 16.115.26110212"
check "msupdate: Excel without app" contains "$out" "Microsoft Excel ? → 16.115.26110212"
check "adobe: product update" contains "$out" "PHSP ? → 27.1"
check "adobe: second product" contains "$out" "AEFT ? → 26.0.1"
check "adobe: Acrobat update" contains "$out" "AcrobatDC ? → update"
check "mas: app update" contains "$out" "Xcode 27.2 → 27.3"
check "mas: second app, 10-digit id" contains "$out" "Telegram 13.1.0 → 13.2.0"
check "mas: no stray empty entry" no_match "$out" "^ +\? → |^ + ? →"
check "mas: stderr warning not parsed" lacks "$out" "Spotlight"
check "progress: mas outdated count" has "$out" "App Store \.+ 2 outdated"
check "macOS: update with restart note" contains "$out" "macOS Golden Gate 27.2.1 27.2 → 27.2.1 (restart required)"
check "macOS: other update" contains "$out" "Command Line Tools for Xcode ? → 27.2"
check "pipx: outdated package" contains "$out" "xxh-xxh 0.8.14 → 0.8.15"
check "pipx: lookup failure is a note" contains "$out" "example-tool: latest version lookup failed"
check "pipx: local path install not looked up" no_match "$out" "local-tool"
check "vscode: extension count on the progress line" has "$out" "VS Code extensions \.+ 3 extensions, updated during --install"
check "sparkle: outdated app, newest non-beta" contains "$out" "Fork 2.70.2 → 2.71.1"
check "sparkle: current app not listed" lacks "$out" "Current "
check "sparkle: unreachable appcast is a note" contains "$out" "Broken: appcast not reachable"
check "sparkle: brew-managed app skipped" lacks "$out" "open Ghostty"
check "unmanaged: cask with same app" contains "$out" "KeePassXC 2.7.9 → 2.8.0"
check "unmanaged: Microsoft app excluded" lacks "$out" "--cask --force microsoft-word"
check "unmanaged: self-updater excluded" lacks "$out" "--cask --force google-chrome"
check "unmanaged: App Store app excluded" lacks "$out" "--cask --force telegram"
check "unmanaged: Jamf app excluded" lacks "$out" "--cask --force eth-self-service"
check "unmanaged: no cask, no line" lacks "$out" "NoCask"
check "self-updating listed once" equals "$(grep -c 'also update themselves on start' <<< "$out")" 1
check "self-updating names the app" has "$out" "also update themselves on start:.*Google Chrome"
check "self-updating: iStat Menus listed" has "$out" "also update themselves on start:.*iStat Menus"
check "self-updating: iStat Menus has no updater warning" lacks "$out" "iStat Menus 7.0"
check "self-updating: brew-managed Discord left out" lacks "$(grep 'also update themselves on start' <<< "$out")" "Discord"
check "self-updating: old wording gone" lacks "$out" "updates itself on launch"
check "open to update: section" contains "$out" "Open to update · 1"
check "open to update: says why" contains "$out" "These apps update themselves on start: open them by hand."
check "open to update: sparkle app in it" has "$(sed -n '/Open to update/,/Summary/p' <<< "$out")" "Fork 2.70.2 → 2.71.1"
check "open to update: no per-item hint" lacks "$out" "open Fork to update"
check "open to update: Fork listed once" equals "$(grep -c "Fork 2.70.2" <<< "$out")" 1
check "open to update: Sparkle section only for its note" contains "$out" "Sparkle apps · 1 note"
check "open to update: also-line after the rows" has "$(sed -n '/Fork 2.70.2/,/Summary/p' <<< "$out")" "also update themselves on start"
check "unmanaged: install hint under the item replaces the older app" contains "$out" "brew install --cask --force keepassxc"
check "brew: formulae group" has "$out" "^ formulae$"
check "brew: casks group" has "$out" "^ casks$"
check "brew: cask listed after casks header" has "$(sed -n '/^ casks$/,$p' <<< "$out")" "ghostty 1.3.1"
check "progress: one line per source" equals "$(grep -cE '^ (brew|Microsoft AutoUpdate|Adobe|App Store|macOS|pipx|VS Code extensions|Sparkle apps|Apps without an updater) \.+ ' <<< "$out")" 9
check "progress: brew outdated count" has "$out" "brew \.+ 4 outdated"
check "progress: msupdate outdated count" has "$out" "Microsoft AutoUpdate \.+ 2 outdated"
check "progress: sparkle count" has "$out" "Sparkle apps \.+ 1 to open$"
check "progress: no carriage returns" no_match "$(cat "$WORK/out")" $'\r'
check "progress: no escape sequences without colour" no_match "$(cat "$WORK/out")" $'\033'
check "sections: brew" contains "$out" "brew · 4 outdated"
check "sections: up-to-date source has none" lacks "$out" "Sparkle apps · 2"
check "summary: header" contains "$out" "Summary"
check "summary: total split" has "$out" "total 16 14 via --install · 2 by hand"
check "summary: brew row" has "$out" "brew 4 mac-outdated --install"
check "summary: open to update row" has "$out" "^ open to update 1 open the app \\(updates on start\\)$"
check "summary: no Sparkle apps row" no_match "$out" "^ Sparkle apps [0-9]"
check "summary: install hint" contains "$out" "next: mac-outdated --install"
check "check runs no install command" equals "$(install_calls | grep -v '^brew update')" ""
check "stamp written" grep -qE '^[0-9]{10}$' "$HOME/.local/state/mac-outdated/last-check"
stamp_age=$(( $(date +%s) - $(cat "$HOME/.local/state/mac-outdated/last-check" 2>/dev/null || echo 0) ))
check "stamp is now" test "$stamp_age" -le 5

# log file: full output without colour, newest 20 kept
LOGS="$HOME/.local/state/mac-outdated/logs"
logpath() { tail -n 1 "$WORK/out" | sed -n 's/^log: //p'; }
MAC_OUTDATED_COLOR=always run
log=$(logpath)
check "log: last line names it" has "$(tail -n 1 "$WORK/out")" "^log: $LOGS/[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}-check\\.log$"
check "log: created" test -s "$log"
check "log: terminal keeps colours" grep -q $'\033\\[' "$WORK/out"
check "log: no colour codes" no_match "$(cat "$log" 2>/dev/null)" $'\033'
check "log: has the summary" contains "$(cat "$log" 2>/dev/null)" "next: mac-outdated --install"
check "log: has the progress" has "$(cat "$log" 2>/dev/null)" "brew \\.+ 4 outdated"
mkdir -p "$LOGS"; for i in $(seq -w 1 25); do : > "$LOGS/2000-01-01-0000$i-check.log"; done
run
check "log: pruned to 20" equals "$(find "$LOGS" -name '*.log' | wc -l | tr -d ' ')" 20
check "log: oldest deleted" test ! -e "$LOGS/2000-01-01-000001-check.log"
check "log: newest kept" test -s "$(logpath)"

# msupdate "Name (version)" layout
printf 'Updates available:\n\tMicrosoft Outlook (16.115.26110212)\n' > "$FIX/msupdate-list.txt"
run
check "msupdate: name (version) layout" contains "$out" "Microsoft Outlook ? → 16.115.26110212"

# Adobe without admin
cp "$FIX/rum-noadmin.txt" "$FIX/rum-list.txt"
run
check "adobe: checked during install on the progress line" has "$out" "Adobe \.+ checked during --install"
check "adobe: no admin text left" lacks "$out" "needs admin"
check "adobe: no summary row" lacks "$out" "listing needs admin"
check "adobe: no unknown count" lacks "$out" "Adobe ?"

# pipx list exits non-zero but still prints JSON (a broken venv)
touch "$FIX/fail-pipx-list"
run
check "pipx broken venv: still lists outdated" contains "$out" "xxh-xxh 0.8.14 → 0.8.15"
check "pipx broken venv: note" contains "$out" "pipx reports a broken package: run pipx reinstall-all"
check "pipx broken venv: not a failed check" no_match "$out" "pipx \\.+ check failed"
echo "Error: something broke" > "$FIX/pipx-list.json"
run
check "pipx no JSON: check failed" has "$out" "^ pipx \\.+ check failed$"
rm -f "$FIX/fail-pipx-list"
run
check "pipx no JSON, exit 0: check failed" has "$out" "^ pipx \\.+ check failed$"
cp "$FIXTURES/pipx-list.json" "$FIX/pipx-list.json"

# brew update failing
touch "$FIX/fail-brew-update"
run
check "brew: update failure is a note" contains "$out" "brew update failed"
check "brew: still lists outdated" contains "$out" "bash 5.3.15 → 5.3.20"

# untrusted tap: brew ignores its formulae, a by-hand item
printf 'Warning: The following taps are not trusted:\n  asmvik/formulae\nRun brew trust to trust them.\n' > "$FIX/brew-outdated-stderr.txt"
printf 'aom\nbash\nkoekeishiya/formulae/skhd\nkoekeishiya/formulae/yabai\nother/tap/foo\n' > "$FIX/brew-list-full.txt"
printf '[{"name":"asmvik/formulae","formula_names":["asmvik/formulae/krp","asmvik/formulae/skhd","asmvik/formulae/yabai"]}]\n' > "$FIX/brew-tap-info.json"
run
check "untrusted tap: note with trust command" contains "$out" "brew ignores untrusted tap asmvik/formulae (its formulae get no updates): brew trust --formula asmvik/formulae/skhd asmvik/formulae/yabai"
check "untrusted tap: not-installed formula left out" lacks "$out" "asmvik/formulae/krp"
check "untrusted tap: other taps left out" lacks "$out" "other/tap/foo"
check "untrusted tap: counted by hand" has "$out" "total 13 10 via --install · 3 by hand"
check "untrusted tap: summary row" has "$out" "brew by hand 1 brew trust"
check "untrusted tap: progress" has "$out" "brew \\.+ 4 outdated · 1 by hand"
MAC_OUTDATED_COLOR=always run
check "untrusted tap: note yellow" grep -q $'\033\\[33mbrew ignores untrusted tap' "$WORK/out"
rm -f "$FIX/brew-tap-info.json"
printf 'asmvik/formulae/yabai\nbash\n' > "$FIX/brew-list-full.txt"
mv "$FIX/brew-outdated-stderr.txt" "$FIX/brew-update-stderr.txt"
run
check "untrusted tap from brew update, no tap-info: full-name prefix" contains "$out" "brew trust --formula asmvik/formulae/yabai"
rm -f "$FIX/brew-update-stderr.txt" "$FIX/brew-list-full.txt"
run
check "no untrusted tap: no note" lacks "$out" "untrusted tap"

# casks: the real app version decides; auto-updating casks are updated by the app itself
jq '.casks += [
  {name: "utm", installed_versions: ["4.7.5"], current_version: "5.0.8", pinned: false},
  {name: "discord", installed_versions: ["0.0.389"], current_version: "0.0.421", pinned: false},
  {name: "betterdisplay", installed_versions: ["4.2.3"], current_version: "5.2.1", pinned: false}]' "$FIXTURES/brew-outdated.json" > "$FIX/brew-outdated.json"
make_app UTM com.utmapp.UTM 5.0.8
make_app Discord com.hammerandchisel.discord 0.0.420
make_app BetterDisplay pro.betterdisplay.BetterDisplay 4.2.3
run
check "stale cask: dim note" contains "$out" "utm: app already at 5.0.8 (brew's record is stale)"
check "stale cask: no row" lacks "$out" "utm 4.7.5"
check "auto-updating cask: not in the casks group" lacks "$(sed -n '/^ casks$/,/updates itself/p' <<< "$out")" "discord"
check "auto-updating cask: under Open to update" has "$(sed -n '/Open to update/,/Summary/p' <<< "$out")" "Discord 0.0.420 → 0.0.421"
check "auto-updating cask: no per-item hint" lacks "$out" "open Discord to update"
check "open to update: Sparkle and cask together" contains "$out" "Open to update · 2"
check "open to update: sorted by name" equals "$(sed -n '/Open to update/,/Summary/p' <<< "$out" | grep -oE '^ +(Discord|Fork) ' | tr -d ' ' | tr '\n' ' ')" "Discord Fork "
check "older non-auto cask: row" contains "$out" "betterdisplay 4.2.3 → 5.2.1"
check "casks: brew progress without the auto-updating cask" has "$out" "brew \\.+ 5 outdated$"
check "casks: brew section without by hand" contains "$out" "brew · 5 outdated"
check "casks: no brew by hand row" lacks "$out" "brew by hand"
check "stale cask: in the brew section" has "$(sed -n '/brew · 5 outdated/,/Open to update/p' <<< "$out")" "utm: app already at 5.0.8"
check "casks: total" has "$out" "total 14 11 via --install · 3 by hand"
check "casks: open to update row" has "$out" "^ open to update 2 open the app"
MAC_OUTDATED_COLOR=always run
check "stale cask: note dim" grep -q $'\033\\[2mutm: app already at' "$WORK/out"
admin_setup admin 20
run --install
check "casks install: formulae without --greedy" contains "$(calls)" "brew upgrade --formula"
check "casks install: only older non-auto casks" contains "$(calls)" "brew upgrade --cask ghostty betterdisplay"
check "casks install: no greedy upgrade" lacks "$(calls)" "--greedy"
jq '.casks = [{name: "utm", installed_versions: ["4.7.5"], current_version: "5.0.8", pinned: false}]' "$FIXTURES/brew-outdated.json" > "$FIX/brew-outdated.json"
run --install
check "casks install: nothing to upgrade, no cask call" lacks "$(calls)" "brew upgrade --cask"
rm -rf "$APPS/UTM.app" "$APPS/BetterDisplay.app"
make_app Discord com.hammerandchisel.discord 0.0.389
cp "$FIXTURES/brew-outdated.json" "$FIX/brew-outdated.json"

# downgrade marker
jq '.formulae[0].current_version = "3.0.0" | .formulae[0].installed_versions = ["3.15.2_1"]' "$FIXTURES/brew-outdated.json" > "$FIX/brew-outdated.json"
run
check "downgrade: marked" has "$out" "aom 3.15.2_1 → 3.0.0 \\(older version: brew moved to the 3.0 line\\)"
check "downgrade: upgrade not marked" lacks "$out" "bash 5.3.15 → 5.3.20 (older version"
jq '.formulae[0].current_version = "3.15.2" | .formulae[0].installed_versions = ["3.15.2_1"]' "$FIXTURES/brew-outdated.json" > "$FIX/brew-outdated.json"
run
check "downgrade: revision only is not one" lacks "$out" "(older version"
jq '.formulae[0].current_version = "1.9.3b" | .formulae[0].installed_versions = ["1.9.3"]' "$FIXTURES/brew-outdated.json" > "$FIX/brew-outdated.json"
run
check "downgrade: 1.9.3 -> 1.9.3b is not one" lacks "$out" "(older version"
cp "$FIXTURES/brew-outdated.json" "$FIX/brew-outdated.json"

# colours
MAC_OUTDATED_COLOR=always run
check "colour: forced escape sequence" grep -q $'\033\\[' "$WORK/out"
check "colour: outdated count yellow" grep -q $'\033\\[33m4 outdated' "$WORK/out"
check "colour: outdated name yellow" grep -q $'\033\\[33mghostty' "$WORK/out"
check "colour: new version yellow" grep -q $'\033\\[33m1\\.4\\.0' "$WORK/out"
check "colour: new version not green" no_match "$(cat "$WORK/out")" $'\033\\[32m[0-9]'
check "colour: old version dim" grep -q $'\033\\[2m1\\.3\\.1' "$WORK/out"
check "colour: informational dim" grep -q $'\033\\[2mchecked during --install' "$WORK/out"
check "colour: open to update line yellow" grep -q $'\033\\[33mThese apps update themselves on start' "$WORK/out"
check "colour: to open yellow" grep -q $'\033\\[33m1 to open' "$WORK/out"
check "colour: install hint yellow" grep -q $'\033\\[33mbrew install --cask --force keepassxc' "$WORK/out"
check "colour: note dim" grep -q $'\033\\[2mbrew update failed' "$WORK/out"
check "colour: summary count yellow" grep -qE $'brew +\033\\[33m4\033' "$WORK/out"
NO_COLOR=1 run
check "colour: NO_COLOR none" no_match "$(cat "$WORK/out")" $'\033'

# ── check mode: nothing outdated ─────────────────────────────────────────────
fixtures_current
rm -f "$HOME/.local/state/mac-outdated/last-check"
run
check "nothing outdated -> exit 0" equals "$rc" 0
check "nothing outdated: up to date" contains "$out" "everything up to date"
check "nothing outdated: progress" has "$out" "Microsoft AutoUpdate \\.+ up to date"
check "nothing outdated: no total" lacks "$out" "total"
check "nothing outdated: no install hint" lacks "$out" "next:"
check "nothing outdated: stamp written" test -f "$HOME/.local/state/mac-outdated/last-check"
MAC_OUTDATED_COLOR=always run
check "colour: up to date green" grep -q $'\033\\[32mup to date' "$WORK/out"
check "colour: everything up to date green" grep -q $'\033\\[32meverything up to date' "$WORK/out"
make_app "Google Chrome" com.google.Chrome 150.0
run
check "nothing outdated: self-updating line still shown" has "$out" "also update themselves on start: Google Chrome"
check "nothing outdated: no Open to update section" lacks "$out" "Open to update"
check "nothing outdated with self-updating apps: exit 0" equals "$rc" 0
rm -rf "$APPS/Google Chrome.app"

# only an auto-updating cask and a stale record: brew itself is up to date
jq '.casks = [
  {name: "utm", installed_versions: ["4.7.5"], current_version: "5.0.8", pinned: false},
  {name: "discord", installed_versions: ["0.0.389"], current_version: "0.0.421", pinned: false}]' "$FIXTURES/brew-outdated-none.json" > "$FIX/brew-outdated.json"
make_app UTM com.utmapp.UTM 5.0.8
make_app Discord com.hammerandchisel.discord 0.0.420
run
check "open only: exit 1" equals "$rc" 1
check "open only: brew progress up to date" has "$out" "^ brew \\.+ up to date$"
check "open only: no brew section" lacks "$out" "brew · "
check "open only: stale note still shown" contains "$out" "utm: app already at 5.0.8 (brew's record is stale)"
check "open only: Discord to open" has "$(sed -n '/Open to update · 1/,/Summary/p' <<< "$out")" "Discord 0.0.420 → 0.0.421"
check "open only: summary row" has "$out" "^ open to update 1 open the app \\(updates on start\\)$"
check "open only: no brew row" no_match "$out" "^ brew [0-9]"
check "open only: stale not by hand" has "$out" "^ total 1 0 via --install · 1 by hand$"
check "open only: no install hint" lacks "$out" "next:"
MAC_OUTDATED_COLOR=always run
check "open only: brew up to date green" grep -qE $'brew \\.+ \033\\[32mup to date' "$WORK/out"
cp "$FIX/brew-outdated-none.json" "$FIX/brew-outdated.json"
rm -rf "$APPS/UTM.app" "$APPS/Discord.app"

# a self-updating app reported by another source goes to Open to update too
printf '{"adamID":1,"bundleID":"org.mozilla.firefox","name":"Firefox","newVersion":"151.0","version":"150.0"}\n' > "$FIX/mas-outdated.json"
run
check "self-updating from another source: in Open to update" has "$(sed -n '/Open to update · 1/,/Summary/p' <<< "$out")" "Firefox 150.0 → 151.0"
check "self-updating from another source: not counted for its source" has "$out" "^ App Store \\.+ up to date$"
check "self-updating from another source: by hand" has "$out" "^ total 1 0 via --install · 1 by hand$"
: > "$FIX/mas-outdated.json"

# ── check mode: failed checks ────────────────────────────────────────────────
touch "$FIX/fail-brew-outdated"
rm -f "$HOME/.local/state/mac-outdated/last-check"
run
check "brew check failing: exit 1" equals "$rc" 1
check "brew check failing: progress" has "$out" "^ brew \\.+ check failed$"
check "brew check failing: summary row" has "$out" "^ brew ! check failed$"
check "brew check failing: total" has "$out" "^ total 0 1 check failed$"
check "brew check failing: not up to date" lacks "$out" "everything up to date"
check "brew check failing: no stamp" test ! -e "$HOME/.local/state/mac-outdated/last-check"
MAC_OUTDATED_COLOR=always run
check "brew check failing: red" grep -q $'\033\\[31mcheck failed' "$WORK/out"
rm -f "$FIX/fail-brew-outdated"

# offline: the App Store and macOS lists fail, the others still count
fixtures_outdated
touch "$FIX/fail-mas-outdated" "$FIX/fail-softwareupdate-list"
run
check "offline: exit 1" equals "$rc" 1
check "offline: App Store check failed" has "$out" "^ App Store \\.+ check failed$"
check "offline: macOS check failed" has "$out" "^ macOS \\.+ check failed$"
check "offline: macOS summary row" has "$out" "^ macOS ! check failed$"
check "offline: total" has "$out" "^ total 12 10 via --install · 2 by hand · 2 checks failed$"
check "offline: no stamp" test ! -e "$HOME/.local/state/mac-outdated/last-check"

# ── check mode: missing tools ────────────────────────────────────────────────
fixtures_outdated
SAVED_PATH=$PATH
mkdir -p "$WORK/empty"
ln -sf "$BIN/curl" "$BIN/sw_vers" "$WORK/empty/"
PATH="$WORK/empty:/usr/bin:/bin" MAC_OUTDATED_MSUPDATE="$WORK/none/msupdate" MAC_OUTDATED_RUM="$WORK/none/rum" run
PATH=$SAVED_PATH
check "missing tools: no crash" equals "$rc" 1
check "missing brew: note" contains "$out" "skipped (brew not installed)"
check "missing mas: note" contains "$out" "skipped (mas not installed)"
check "missing msupdate: note" contains "$out" "skipped (msupdate not installed)"
check "missing RemoteUpdateManager: note" contains "$out" "skipped (RemoteUpdateManager not installed)"
check "missing softwareupdate: note" contains "$out" "skipped (softwareupdate not found)"
check "missing pipx: note" contains "$out" "skipped (pipx not installed)"
check "missing code: note" contains "$out" "skipped (code not found)"
check "missing tools: sparkle still checked" contains "$out" "Fork 2.70.2 → 2.71.1"

# ── check mode: casks found by app name in Homebrew's API cache ─────────────
# cask_cache <payload json>: the signed API file of current brew (internal/packages.*.jws.json)
cask_cache() {
  mkdir -p "$FIX/brew-cache/api/internal"
  jq -c '{payload: tojson, signatures: []}' <<< "$1" > "$FIX/brew-cache/api/internal/packages.arm64_test.jws.json"
}
CASKS='{"formulae": {}, "casks": {
  "bambu-studio": {"version": "02.08.02.61,20260820225108", "raw_artifacts": [[":app", ["BambuStudio.app"]], [":zap", {":trash": "~/x"}]]},
  "logi-options+": {"version": "2.9.9", "auto_updates": true, "raw_artifacts": [[":installer", {}], [":uninstall", {":delete": ["/Applications/logioptionsplus.app", "/Library/Logi"]}]]},
  "keepassxc": {"version": "2.8.0,2.8.0-1", "raw_artifacts": [[":app", ["KeePassXC.app"]]]},
  "foo-bar@beta": {"version": "9.0", "raw_artifacts": [[":app", ["Foo Bar.app"]]]},
  "foo-bar": {"version": "2.0", "raw_artifacts": [[":app", ["Foo Bar.app"]]]},
  "old-thing": {"version": "5.0", "disable_args": {":date": "2025-01-01"}, "raw_artifacts": [[":app", ["Old Thing.app"]]]},
  "self-app": {"version": "3.0", "auto_updates": true, "raw_artifacts": [[":app", ["SelfApp.app"]]]},
  "microsoft-word": {"version": "99.0", "raw_artifacts": [[":app", ["Microsoft Word.app"]]]},
  "telegram": {"version": "99.0", "raw_artifacts": [[":app", ["Telegram.app"]]]},
  "google-chrome": {"version": "999.0", "auto_updates": true, "raw_artifacts": [[":app", ["Google Chrome.app"]]]}
}}'
fixtures_outdated
cask_cache "$CASKS"
make_app BambuStudio com.bambulab.bambu-studio 02.07.01.57
make_app logioptionsplus com.logi.optionsplus 2.9.1
make_app "Foo Bar" com.example.foobar 1.0
make_app "Old Thing" com.example.oldthing 1.0
make_app SelfApp com.example.selfapp 3.0
run
check "cask cache: app name differs from the token" contains "$out" "BambuStudio 02.07.01.57 → 02.08.02.61"
check "cask cache: install hint with the real token" contains "$out" "brew install --cask --force bambu-studio"
check "cask cache: still finds same-name apps" contains "$out" "KeePassXC 2.7.9 → 2.8.0"
check "cask cache: app from uninstall delete, auto-updating -> Open to update" has "$(sed -n '/Open to update/,/Summary/p' <<< "$out")" "logioptionsplus 2.9.1 → 2.9.9"
check "cask cache: auto-updating app has no install hint" lacks "$out" "--force logi-options+"
check "cask cache: plain token preferred over @variant" contains "$out" "brew install --cask --force foo-bar"$'\n'
check "cask cache: @variant not used" lacks "$out" "foo-bar@beta"
check "cask cache: disabled cask ignored" lacks "$out" "Old Thing"
check "cask cache: current auto-updating app not listed" lacks "$out" "SelfApp"
check "cask cache: Microsoft app still excluded" lacks "$out" "--cask --force microsoft-word"
check "cask cache: App Store app still excluded" lacks "$out" "--cask --force telegram"
check "cask cache: self-updater still excluded" lacks "$out" "--cask --force google-chrome"
check "cask cache: no brew info per app" no_match "$(calls)" '^brew info --cask --json=v2 [^-]'
check "cask cache: progress" has "$out" "Apps without an updater \.+ 3 outdated$"
# older brew: api/cask.jws.json, payload is the cask array
rm -rf "$FIX/brew-cache"; mkdir -p "$FIX/brew-cache/api"
jq -nc --arg b bambu-studio --arg l logi-options+ '{payload: ([{token: $b, version: "02.08.02.61,2026", artifacts: [{app: ["BambuStudio.app"], target: "/Applications/BambuStudio.app"}]},
  {token: $l, version: "2.9.9", auto_updates: true, artifacts: [{uninstall: [{delete: "/Applications/logioptionsplus.app"}]}]}] | tojson)}' > "$FIX/brew-cache/api/cask.jws.json"
run
check "cask cache, old layout: app name differs from the token" contains "$out" "BambuStudio 02.07.01.57 → 02.08.02.61"
check "cask cache, old layout: uninstall delete" contains "$out" "logioptionsplus 2.9.1 → 2.9.9"
rm -rf "$FIX/brew-cache"
run
check "no cask cache: falls back to the app name" contains "$out" "KeePassXC 2.7.9 → 2.8.0"
check "no cask cache: name differing from the token not found" lacks "$out" "BambuStudio"

# Sparkle apps without SUFeedURL: the cask decides
fixtures_outdated
cask_cache '{"casks": {
  "vlc": {"version": "3.0.24", "auto_updates": true, "raw_artifacts": [[":app", ["VLC.app"]]]},
  "teamviewer": {"version": "15.82.6", "auto_updates": true, "raw_artifacts": [[":pkg", ["TeamViewer.pkg"]], [":uninstall", {":delete": ["/Applications/TeamViewer.app"]}]]},
  "plain-app": {"version": "2.0", "raw_artifacts": [[":app", ["Plain.app"]]]}
}}'
make_app VLC org.videolan.vlc 3.0.20 "" sparkle
make_app TeamViewer com.teamviewer.TeamViewer 15.83.3 "" sparkle
make_app Plain com.example.plain 1.0 "" sparkle
make_app NoFeed com.example.nofeed 1.0 "" sparkle
run
check "sparkle without feed: auto-updating cask -> Open to update" has "$(sed -n '/Open to update/,/Summary/p' <<< "$out")" "VLC 3.0.20 → 3.0.24"
check "sparkle without feed: app newer than the cask not listed" lacks "$out" "TeamViewer"
check "sparkle without feed: other cask, install hint" has "$(sed -n '/Sparkle apps ·/,/Open to update/p' <<< "$out")" "Plain 1.0 → 2.0"
check "sparkle without feed: hint text" contains "$out" "brew install --cask --force plain-app"
check "sparkle without feed: no cask, no line" lacks "$out" "NoFeed"
check "sparkle without feed: not under apps without an updater" no_match "$out" "Apps without an updater · "
check "sparkle without feed: open count" contains "$out" "Open to update · 2"
rm -rf "$FIX/brew-cache"
cask_like vlc VLC 3.0.24
jq '.casks[0].auto_updates = true' "$FIX/brew-info-vlc.json" > "$FIX/x" && mv "$FIX/x" "$FIX/brew-info-vlc.json"
run
check "sparkle without feed, no cache: cask named like the app" has "$(sed -n '/Open to update/,/Summary/p' <<< "$out")" "VLC 3.0.20 → 3.0.24"

# ── test hooks: path overrides only with MAC_OUTDATED_TEST=1 ─────────────────
paths() { /opt/homebrew/bin/bash -c 'source "$1"; printf "%s\n" "$PRIVILEGESCLI" "$MSUPDATE" "$RUM" "$APP_DIRS"' _ "$SCRIPT"; }
check "hooks: overrides used in tests" equals "$(paths)" "$BIN/PrivilegesCLI
$BIN/msupdate
$BIN/RemoteUpdateManager
$APPS"
check "hooks: overrides ignored without MAC_OUTDATED_TEST=1" equals "$(MAC_OUTDATED_TEST='' paths)" "/Applications/Privileges.app/Contents/MacOS/PrivilegesCLI
/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app/Contents/MacOS/msupdate
/usr/local/bin/RemoteUpdateManager
/Applications:$HOME/Applications"
check "hooks: sourcing runs nothing" equals "$(: > "$CALLS"; paths >/dev/null; calls)" ""

# ── usage ────────────────────────────────────────────────────────────────────
run --help
check "--help: exit 0" equals "$rc" 0
check "--help: usage" contains "$out" "usage: mac-outdated [--install]"
run --bogus
check "unknown option: exit 2" equals "$rc" 2

# ── install ──────────────────────────────────────────────────────────────────
fixtures_outdated
admin_setup standard 0
run --install
check "not admin: exit 2" equals "$rc" 2
check "not admin: message" contains "$out" "Click Privileges (lock icon in the menu bar), then rerun mac-outdated --install"
check "not admin: nothing run" equals "$(install_calls)" ""

printf 'User jane has standard user privileges\nStandard user privileges have been assigned by your administrator\n' > "$FIX/privileges-status.txt"
run --install
check "standard assigned by administrator: exit 2" equals "$rc" 2
check "standard assigned by administrator: nothing run" equals "$(install_calls)" ""
check "standard assigned by administrator: not admin" contains "$out" "Click Privileges (lock icon in the menu bar)"

printf 'Administrator privileges have been assigned\n' > "$FIX/privileges-status.txt"
run_input y --install
check "managed admin wording: counts as admin" equals "$rc" 0
check "managed admin wording: asks for unknown time" contains "$out" "admin time left unknown"

admin_setup admin 20
run --install
expected="sudo -v
sudo RemoteUpdateManager --action=install
RemoteUpdateManager --action=install
sudo mas upgrade
mas upgrade
brew update
brew upgrade --formula
brew upgrade --cask ghostty
msupdate --install --wait 600
pipx upgrade-all
code --update-extensions
sudo softwareupdate --install --all
softwareupdate --install --all"
check "admin 20 min: exit 0" equals "$rc" 0
check "admin 20 min: sudo -v once, short sudo steps first, macOS last" equals "$(install_calls)" "$expected"
check "admin 20 min: admin re-checked before each sudo step" equals "$(grep -c '^PrivilegesCLI --status' "$CALLS")" 4
check "admin 20 min: no password-once promise" lacks "$out" "password once"
check "admin 20 min: sudo prompts named" contains "$out" "sudo may ask for your password at the start, during brew (some casks), and again for later steps"
check "admin 20 min: restart required shown" contains "$out" "restart required"
check "admin 20 min: summary" has "$out" "pipx \\.+ installed"
check "admin 20 min: header" has "$out" "^mac-outdated --install · [0-9-]+ [0-9:]+"
check "admin 20 min: subheader per source" contains "$out" "── brew"
check "admin 20 min: summary section" contains "$out" "Summary"
check "admin 20 min: summary total" has "$out" "total 7 installed"
check "admin 20 min: tool output indented" has "$out" "^ +==> Upgrading 1 outdated package"
check "admin 20 min: carriage return becomes a new indented line" has "$out" "^ +100%"
check "admin 20 min: no carriage returns in install output" no_match "$(cat "$WORK/out")" $'\r'
check "admin 20 min: softwareupdate runs on the terminal, not through a pipe" grep -q '^Restart is required to complete installation' "$WORK/out"
check "admin 20 min: restart need read from softwareupdate --list before installing" equals "$(grep -E '^softwareupdate --(list|install)' "$CALLS" | cut -d' ' -f2)" "--list
--install"
check "admin: time read from PrivilegesCLI --status" contains "$(calls)" 'PrivilegesCLI --status'
log=$(logpath)
check "install log: named install" has "$log" "[0-9]{6}-install\\.log$"
check "install log: softwareupdate output captured" contains "$(cat "$log" 2>/dev/null)" "Restart is required to complete installation"
check "install log: has the summary" has "$(cat "$log" 2>/dev/null)" "total +7 installed"
check "install log: log line last on the terminal" has "$(tail -n 1 "$WORK/out")" "^log: "

cp "$FIX/softwareupdate-none.txt" "$FIX/softwareupdate-list.txt"
run --install
check "no restart update: no restart line" lacks "$out" "restart required"
check "no macOS update: up to date" has "$out" "macOS \\.+ up to date"
check "no macOS update: no install" lacks "$(calls)" "softwareupdate --install"
check "no macOS update: no admin check for it" equals "$(grep -c '^PrivilegesCLI --status' "$CALLS")" 3
check "no macOS update: total" has "$out" "total 6 installed · 1 up to date"
cp "$FIX/msupdate-none.txt" "$FIX/msupdate-list.txt"
run --install
check "no Microsoft update: --list first" contains "$(calls)" "msupdate --list"
check "no Microsoft update: --install never called" lacks "$(calls)" "msupdate --install"
check "no Microsoft update: up to date" has "$out" "Microsoft AutoUpdate \\.+ up to date"
cp "$FIXTURES/msupdate-list.txt" "$FIX/msupdate-list.txt"
echo 3 > "$FIX/privileges-expire-after"
run --install
rm -f "$FIX/privileges-expire-after"
check "admin gone, no macOS update: exit 0" equals "$rc" 0
check "admin gone, no macOS update: up to date" has "$out" "macOS \\.+ up to date"
touch "$FIX/fail-softwareupdate-list"
run --install
rm -f "$FIX/fail-softwareupdate-list"
check "macOS list failing: exit 1" equals "$rc" 1
check "macOS list failing: failed" has "$out" "macOS \\.+ failed \\(exit 1\\)"
check "macOS list failing: no install" lacks "$(calls)" "softwareupdate --install"
cp "$FIXTURES/softwareupdate-list.txt" "$FIX/softwareupdate-list.txt"

# repetitive tool output: more than 5 similar lines fold on the terminal, the log keeps them
touch "$FIX/chown-brew"
run --install
rm -f "$FIX/chown-brew"
term=$(cat "$WORK/out")
check "fold: first 3 lines shown" contains "$term" "Example.app/Contents/f3: Operation not permitted"
check "fold: 4th line hidden" lacks "$term" "Example.app/Contents/f4: "
check "fold: last line hidden" lacks "$term" "Example.app/Contents/f300: "
check "fold: message" contains "$term" "… 297 more similar lines (full output in log)"
check "fold: message before the next line" has "$(grep -A1 '297 more similar' <<< "$term")" "==> Upgrading 1 outdated package"
check "fold: log keeps every line" equals "$(grep -c 'chown: /Applications/Example.app' "$(logpath)")" 600
check "fold: log has the message" contains "$(cat "$(logpath)")" "297 more similar lines"
touch "$FIX/five-brew"
run --install
rm -f "$FIX/five-brew"
check "fold: 5 similar lines all shown" contains "$(cat "$WORK/out")" "Warning: cask c5: not upgraded"
check "fold: 5 similar lines no message" lacks "$(cat "$WORK/out")" "more similar lines"

# a prompt without a newline shows while the tool waits for an answer
touch "$FIX/prompt-brew"
: > "$CALLS"
"$SCRIPT" --install > "$WORK/out" 2>&1 < /dev/null &
pid=$!
seen=0
for _ in $(seq 40); do grep -q 'Proceed?' "$WORK/out" && { seen=1; break; }; sleep 0.1; done
touch "$FIX/go"
wait "$pid"
check "prompt without newline shows while waiting" equals "$seen" 1
rm -f "$FIX/prompt-brew" "$FIX/go"

admin_setup admin 10
run --install
check "10 min left: exit 2" equals "$rc" 2
check "10 min left: message" contains "$out" "only 10 min of admin left, need 15: revert and click Privileges again"
check "10 min left: nothing run" equals "$(install_calls)" ""

admin_setup admin none
run_input n --install
check "unknown time + n: exit 2" equals "$rc" 2
check "unknown time: message" contains "$out" "admin time left unknown"
check "unknown time: asks" contains "$out" "Continue anyway? [y/N]"
check "unknown time + n: nothing run" equals "$(install_calls)" ""

run_input y --install
check "unknown time + y: exit 0" equals "$rc" 0
check "unknown time + y: runs" equals "$(install_calls)" "$expected"

admin_setup admin 1
run --install
check "1 minute left (singular): exit 2" equals "$rc" 2
check "1 minute left (singular): message" contains "$out" "only 1 min of admin left, need 15: revert and click Privileges again"

admin_setup admin 15
run --install
check "15 min left: exit 0" equals "$rc" 0

admin_setup admin 20
touch "$FIX/fail-brew"
run --install
check "brew failing: exit 1" equals "$rc" 1
check "brew failing: later sources still run" contains "$(calls)" "code --update-extensions"
check "brew failing: step line" has "$out" "brew \\.+ failed \\(exit 1\\)"
check "brew failing: others installed" has "$out" "Microsoft AutoUpdate \\.+ installed"
check "brew failing: total" has "$out" "total 6 installed · 1 failed"
rm -f "$FIX/fail-brew"

# Ctrl-C: a step ending with 130 stops the run
echo 130 > "$FIX/exit-brew"
run --install
rm -f "$FIX/exit-brew"
check "step exit 130: exit 130" equals "$rc" 130
check "step exit 130: later steps not run" no_match "$(calls)" "^(msupdate --install|pipx upgrade-all|code --update-extensions|sudo softwareupdate|softwareupdate)"
check "step exit 130: earlier steps ran" contains "$(calls)" "mas upgrade"
check "step exit 130: message" contains "$out" "interrupted — remaining steps not run"
check "step exit 130: summary so far" has "$out" "App Store installed"
check "step exit 130: interrupted step" has "$out" "^ brew interrupted$"
check "step exit 130: remaining steps listed as not run" has "$out" "^ macOS not run$"

# Ctrl-C while a step runs: the step finishes, nothing after it runs
touch "$FIX/prompt-brew"
: > "$CALLS"
set -m
"$SCRIPT" --install > "$WORK/out" 2>&1 < /dev/null &
pid=$!
set +m
for _ in $(seq 40); do grep -q 'Proceed?' "$WORK/out" && break; sleep 0.1; done
kill -INT "$pid"
touch "$FIX/go"
wait "$pid"; rc=$?
out="$(tr -s ' ' < "$WORK/out")"
rm -f "$FIX/prompt-brew" "$FIX/go"
check "Ctrl-C: exit 130" equals "$rc" 130
check "Ctrl-C: later steps not run" no_match "$(calls)" "^(msupdate --install|pipx upgrade-all|code --update-extensions|softwareupdate --install)"
check "Ctrl-C: message" contains "$out" "interrupted — remaining steps not run"
check "Ctrl-C: summary" contains "$out" "Summary"
check "Ctrl-C: log complete" contains "$(cat "$(logpath)" 2>/dev/null)" "interrupted — remaining steps not run"

# Adobe exit 2: some updates could not be installed, a warning, not a plain failure
echo 2 > "$FIX/exit-rum"
run --install
check "Adobe exit 2: exit 1" equals "$rc" 1
check "Adobe exit 2: some updates failed" has "$out" "Adobe \\.+ some updates failed \\(Adobe exit 2: often an open Adobe app; see Adobe's RUM log\\)"
check "Adobe exit 2: not a plain failure" lacks "$out" "failed (exit 2)"
check "Adobe exit 2: later steps still run" contains "$(calls)" "code --update-extensions"
MAC_OUTDATED_COLOR=always run --install
check "Adobe exit 2: yellow" grep -q $'\033\\[33msome updates failed' "$WORK/out"
echo 1 > "$FIX/exit-rum"
run --install
check "Adobe exit 1: failed" has "$out" "Adobe \\.+ failed \\(exit 1\\)"
MAC_OUTDATED_COLOR=always run --install
check "Adobe exit 1: red" grep -q $'\033\\[31mfailed (exit 1)' "$WORK/out"
rm -f "$FIX/exit-rum"

# a real exit 3 from a tool is a failure, not a skip
echo 3 > "$FIX/exit-msupdate"
run --install
rm -f "$FIX/exit-msupdate"
check "tool exit 3: exit 1" equals "$rc" 1
check "tool exit 3: failed, not skipped" has "$out" "Microsoft AutoUpdate \\.+ failed \\(exit 3\\)"
check "tool exit 3: total" has "$out" "total 6 installed · 1 failed"

touch "$FIX/fail-softwareupdate"
run --install
check "macOS failing: exit 1" equals "$rc" 1
check "macOS failing: no restart line" lacks "$out" "restart required"
check "macOS failing: Adobe still runs" contains "$(calls)" "RemoteUpdateManager --action=install"
rm -f "$FIX/fail-softwareupdate"

# admin runs out after Adobe: the later sudo steps are skipped, the rest still runs
echo 2 > "$FIX/privileges-expire-after"
run --install
rm -f "$FIX/privileges-expire-after"
check "admin expired: exit 1" equals "$rc" 1
check "admin expired: Adobe still installed" contains "$(calls)" "RemoteUpdateManager --action=install"
check "admin expired: mas upgrade not run" lacks "$(calls)" "mas upgrade"
check "admin expired: macOS not installed" lacks "$(calls)" "softwareupdate --install"
check "admin expired: non-sudo steps still run" contains "$(calls)" "code --update-extensions"
check "admin expired: App Store step skipped" has "$out" "App Store \\.+ skipped \\(admin expired: click Privileges and rerun\\)"
check "admin expired: macOS step skipped" has "$out" "macOS \\.+ skipped \\(admin expired: click Privileges and rerun\\)"
check "admin expired: total" has "$out" "total 5 installed · 2 skipped"

# admin about to run out before the sudo steps: under 2 min left is skipped, 2 min or unknown still runs
echo 1 > "$FIX/privileges-expire-after"
printf 'User jane has administrator privileges\nAdministrator privileges expire in 1 minute\n' > "$FIX/privileges-status-later.txt"
run --install
check "1 min left before a sudo step: exit 1" equals "$rc" 1
check "1 min left before a sudo step: Adobe not run" lacks "$(calls)" "RemoteUpdateManager --action=install"
check "1 min left before a sudo step: macOS not run" lacks "$(calls)" "softwareupdate --install"
check "1 min left before a sudo step: Adobe skipped" has "$out" "Adobe \\.+ skipped \\(admin expires in 1 min: click Privileges and rerun\\)"
check "1 min left before a sudo step: brew still runs" contains "$(calls)" "brew upgrade --formula"
printf 'User jane has administrator privileges\nAdministrator privileges expire in 2 minutes\n' > "$FIX/privileges-status-later.txt"
run --install
check "2 min left before a sudo step: exit 0" equals "$rc" 0
check "2 min left before a sudo step: macOS runs" contains "$(calls)" "softwareupdate --install"
printf 'User jane has administrator privileges\n' > "$FIX/privileges-status-later.txt"
run --install
check "unknown time before a sudo step: exit 0" equals "$rc" 0
check "unknown time before a sudo step: Adobe runs" contains "$(calls)" "RemoteUpdateManager --action=install"
rm -f "$FIX/privileges-expire-after" "$FIX/privileges-status-later.txt"

# a missing tool is skipped, not a failure
mkdir -p "$WORK/nomas"
for f in "$BIN"/*; do [ "$(basename "$f")" = mas ] || ln -sf "$f" "$WORK/nomas/"; done
PATH="$WORK/nomas:/usr/bin:/bin" run --install
check "mas missing: install exit 0" equals "$rc" 0
check "mas missing: skipped" has "$out" "App Store \\.+ skipped \\(mas not installed\\)"

mkdir -p "$WORK/asroot"
for f in "$BIN"/*; do ln -sf "$f" "$WORK/asroot/"; done
printf '#!/bin/sh\necho 0\n' > "$WORK/asroot/id"; chmod +x "$WORK/asroot/id"
PATH="$WORK/asroot:/usr/bin:/bin" run --install
check "root: exit 2" equals "$rc" 2
check "root: says what to run instead" contains "$out" "run mac-outdated --install as your own user"
check "root: says it asks for the password itself" contains "$out" "asks for your password itself"

# ── safety, over every run above ─────────────────────────────────────────────
all="$(cat "$ALLCALLS")"
check "PrivilegesCLI only ever --status" no_match "$all" '^PrivilegesCLI .*(--add|--remove)'
check "brew never via sudo" no_match "$all" '^sudo brew'
check "brew upgrade never greedy" no_match "$all" '^brew upgrade .*--greedy'
check "only sudo -v, macOS, Adobe and mas upgrade via sudo" only_allowed_sudo "$all"
check "softwareupdate never restarts" no_match "$all" '^softwareupdate .*(-R|--restart|--reboot)'

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
