#!/usr/bin/env bash
# Downloads the pinned Linux binaries in remote-binaries.conf into ~/.xxh/arch/<arch>/, each checked against its sha256 (fail closed).
# Installed versions go to ~/.xxh/arch/<arch>/VERSIONS (`tool version` per line); a tool whose version differs from the pin is fetched again.
#   terminal/remote-binaries.sh [--refresh]    --refresh: fetch every tool again
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONF=${REMOTE_BINARIES_CONF:-$SCRIPT_DIR/remote-binaries.conf}
ARCH_DIR=$HOME/.xxh/arch

ok()   { printf '   \033[32m✓\033[0m  %s\n' "$*"; }
skip() { printf '   \033[2m·\033[0m  %s (already done)\n' "$*"; }
info() { printf '   %s\n' "$*"; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

REFRESH=0
for a in "$@"; do
    case "$a" in
        --refresh) REFRESH=1 ;;
        *) die "unknown flag: $a" ;;
    esac
done

[[ -f "$CONF" ]] || die "pin file not found: $CONF"

# TERMINFO wrapper that the xxh entrypoint launches (fish-portable/bin/fish.sh)
write_fish_wrapper() {
    cat > "$1/fish.sh" <<'WRAP'
#!/bin/sh
export TERMINFO_DIRS=/lib/terminfo:/etc/terminfo:/usr/share/terminfo:$TERMINFO_DIRS
CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"
$CURRENT_DIR/fish "$@"
WRAP
    chmod +x "$1/fish.sh"
}

installed_version() {  # installed_version <VERSIONS file> <tool>
    [[ -f "$1" ]] || return 0
    awk -v t="$2" '$1 == t { print $2 }' "$1"
}

record_version() {  # record_version <VERSIONS file> <tool> <version>
    local tmp
    tmp=$(mktemp)
    if [[ -f "$1" ]]; then awk -v t="$2" '$1 != t' "$1" > "$tmp"; fi
    echo "$2 $3" >> "$tmp"
    mv "$tmp" "$1"
}

# fetch <tool> <repo> <tag> <arch> <asset> <binary> <sha256> <dest>
fetch() {
    local tool=$1 repo=$2 tag=$3 arch=$4 asset=$5 binary=$6 want=$7 dest=$8
    [[ "$want" =~ ^[0-9a-f]{64}$ ]] || die "no valid sha256 pinned for $tool $arch in $CONF"
    info "Fetching $repo $tag ($asset)..."
    local tmp got
    tmp=$(mktemp -d)
    if ! curl -fsSL -o "$tmp/$asset" "https://github.com/$repo/releases/download/$tag/$asset"; then
        rm -rf "$tmp"; die "download failed: $repo $tag $asset"
    fi
    got=$(shasum -a 256 "$tmp/$asset" | cut -d' ' -f1)
    if [[ "$got" != "$want" ]]; then
        rm -rf "$tmp"
        die "sha256 mismatch for $asset: expected $want, got $got (download deleted)"
    fi
    mkdir -p "$tmp/x"
    tar -xf "$tmp/$asset" -C "$tmp/x"
    [[ -f "$tmp/x/$binary" ]] || { rm -rf "$tmp"; die "$binary not found in $asset"; }
    mkdir -p "$(dirname "$dest")"
    mv "$tmp/x/$binary" "$dest"
    chmod +x "$dest"
    rm -rf "$tmp"
    ok "$tool ${tag#v} [$arch]"
}

while read -r tool repo tag arch asset binary sha extra; do
    [[ -z "$tool" || "$tool" == \#* ]] && continue
    [[ -z "${extra:-}" ]] || die "too many columns for $tool $arch in $CONF"
    store=$ARCH_DIR/$arch
    if [[ "$tool" == fish ]]; then dest=$store/fish-portable/bin/fish; else dest=$store/bin/$tool; fi
    version=${tag#v}
    if [[ "$REFRESH" -eq 0 && -f "$dest" && "$(installed_version "$store/VERSIONS" "$tool")" == "$version" ]]; then
        skip "$tool $version [$arch]"
    else
        fetch "$tool" "$repo" "$tag" "$arch" "$asset" "$binary" "$sha" "$dest"
        record_version "$store/VERSIONS" "$tool" "$version"
    fi
    if [[ "$tool" == fish ]]; then write_fish_wrapper "$(dirname "$dest")"; fi
done < "$CONF"
