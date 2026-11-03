#!/opt/homebrew/bin/bash
# Runs every test in */tests/ (except the live concurrent-sessions.fish), then syntax-checks and shellchecks every script.
#   tests/test-all.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

pass=0; fail=0; skipped=0; failed=()
record() {  # record <name> <rc>
  if [ "$2" -eq 0 ]; then pass=$((pass + 1)); echo "ok    $1"
  else fail=$((fail + 1)); failed+=("$1"); echo "FAIL  $1"; fi
}

echo "== tests"
tmp="$(mktemp "${TMPDIR:-/tmp}/test-all.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
for t in */tests/*; do
  [ -f "$t" ] && [ -x "$t" ] || continue
  case "$(basename "$t")" in concurrent-sessions.fish) continue ;; esac
  if "$t" > "$tmp" 2>&1; then rc=0; else rc=$?; fi
  [ "$rc" -eq 0 ] || sed 's/^/      /' "$tmp"
  record "$t" "$rc"
done

echo "== syntax"
have_shellcheck=0; command -v shellcheck >/dev/null 2>&1 && have_shellcheck=1
while IFS= read -r f; do
  [ -f "$f" ] || continue
  shebang="$(head -n 1 "$f" 2>/dev/null | LC_ALL=C tr -d '\r' | grep -a '^#!' || true)"
  kind=""
  case "$shebang" in
    *fish*) kind=fish ;;
    *zsh*) kind=zsh ;;
    *bash*) kind=bash ;;
    "#!/bin/sh"*|"#!/usr/bin/env sh"*) kind="sh" ;;
  esac
  [ -z "$kind" ] && case "$f" in *.fish) kind=fish ;; esac
  [ -n "$kind" ] || continue
  case "$kind" in
    fish) fish -n "$f" 2>&1; rc=$? ;;
    zsh) zsh -n "$f" 2>&1; rc=$? ;;
    bash) /opt/homebrew/bin/bash -n "$f" 2>&1; rc=$? ;;
    sh) sh -n "$f" 2>&1; rc=$? ;;
  esac
  record "$kind -n $f" "$rc"
  if [ "$have_shellcheck" -eq 1 ] && [ "$kind" != fish ] && [ "$kind" != zsh ]; then
    if out="$(shellcheck -S error "$f" 2>&1)"; then rc=0; else rc=$?; echo "$out" | sed 's/^/      /'; fi
    record "shellcheck $f" "$rc"
  elif [ "$kind" = zsh ]; then
    skipped=$((skipped + 1))
  fi
done < <(git ls-files --cached --others --exclude-standard)

echo
echo "passed: $pass  failed: $fail  (shellcheck skipped for zsh scripts: $skipped$([ "$have_shellcheck" -eq 0 ] && echo ', shellcheck not installed'))"
if [ "$fail" -ne 0 ]; then printf 'failed: %s\n' "${failed[@]}"; exit 1; fi
