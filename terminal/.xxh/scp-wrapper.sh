#!/bin/bash
# Drop-in replacement for scp, used by xxh via ++scp-command in config.xxhc.
#
# Why: the ETH fleet sets `Compression no` in /etc/ssh/sshd_config.d/90-eth.conf,
# so SSH-level compression is refused and the full ~71 MB payload crosses the
# wire. Measured on root6: 4.14 s raw, 2.06 s via gzip, 1.58 s via zstd.
# We therefore compress the payload ourselves and unpack it on the remote.
#
# Any unexpected argv shape, a remote without tar, or any pipeline failure falls
# back to the real scp -- which is exactly the previous behaviour, so a defect
# here degrades instead of breaking every connect.
#
# Every connect reports which of four transfer paths it took, best first:
#   1. tar-pipe + zstd            remote has tar and zstd          (fastest)
#   2. tar-pipe + gzip            remote has tar but no zstd
#   3. scp + SSH compression      fell back; server allows zlib
#   4. scp, uncompressed          fell back; server refuses zlib   (slowest)
set -uo pipefail

REAL_SCP=/usr/bin/scp
orig=( "$@" )

# The shebang is /bin/bash, which on macOS is 3.2 -- there, `set -u` makes
# "${arr[@]}" an error when arr is empty. This idiom expands to nothing instead.
ssh_opts=()
positionals=()

say() { printf '  \033[2mtransfer:\033[0m %b\n' "$1" >&2; }

report_fallback() {
    # Only this path needs to know whether SSH itself will compress, and it is
    # the rare path, so the extra round trip is acceptable here.
    local negotiated=""
    if [[ -n "${host:-}" ]]; then
        # ControlMaster=no/ControlPath=none are essential here, not incidental:
        # a mux slave performs no key exchange, so it prints no `compression:`
        # line at all and the answer would always come back blank.
        negotiated=$(ssh -v -o ControlMaster=no -o ControlPath=none \
            ${ssh_opts[@]+"${ssh_opts[@]}"} "$host" true 2>&1 \
            | grep -m1 'client->server cipher' | grep -o 'compression: [^ ]*')
    fi
    case "$negotiated" in
        *zlib*) say '\033[33mscp + SSH compression\033[0m \033[2m(wrapper fell back)\033[0m' ;;
        *none*) say '\033[31mscp, UNCOMPRESSED\033[0m \033[2m(wrapper fell back; server refuses compression)\033[0m' ;;
        *)      say '\033[33mscp\033[0m \033[2m(wrapper fell back)\033[0m' ;;
    esac
}

fallback() { report_fallback; exec "$REAL_SCP" "${orig[@]}"; }

# POSIX-safe single-quoting for paths interpolated into the remote shell.
squote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

while (( $# )); do
    case "$1" in
        -o) (( $# >= 2 )) || fallback; ssh_opts+=( -o "$2" ); shift 2 ;;
        -v) ssh_opts+=( -v ); shift ;;
        -r|-C|-q) shift ;;          # scp-specific; meaningless to tar
        --) shift ;;
        -*) fallback ;;             # an option we do not model
        *)  positionals+=( "$1" ); shift ;;
    esac
done

(( ${#positionals[@]} >= 2 )) || fallback

dest="${positionals[${#positionals[@]}-1]}"
srcs=( "${positionals[@]:0:${#positionals[@]}-1}" )

[[ "$dest" == *:* ]] || fallback
host="${dest%%:*}"
rpath="${dest#*:}"
[[ -n "$host" && -n "$rpath" ]] || fallback

# We unpack into the destination, so it must be a directory. scp treats a
# destination without a trailing slash as a literal target path -- `scp f h:/a/b`
# writes the FILE b. Handling that here would mkdir b instead, so hand those to
# the real scp. xxh always passes a trailing slash, so this costs us nothing.
[[ "$rpath" == */ ]] || fallback

for s in "${srcs[@]}"; do [[ -e "$s" ]] || fallback; done

# One round trip over the already-established ControlMaster (~30-50 ms) to learn
# what the remote can decompress. The stream format is fixed by the sender, so
# the receiver cannot adapt after the fact -- probing beats retransmitting.
probe=$(ssh ${ssh_opts[@]+"${ssh_opts[@]}"} "$host" \
    'command -v tar >/dev/null 2>&1 || exit 1
     if command -v zstd >/dev/null 2>&1; then echo zstd; else echo gzip; fi' 2>/dev/null) || fallback

case "$probe" in
    zstd) if command -v zstd >/dev/null 2>&1; then
              comp=( zstd -3 -T0 -c ); decomp='zstd -d -c'
              label='\033[32mtar-pipe + zstd\033[0m \033[2m(fastest)\033[0m'
          else
              comp=( gzip -6 -c ); decomp='gzip -d -c'
              label='\033[32mtar-pipe + gzip\033[0m \033[2m(no local zstd)\033[0m'
          fi ;;
    gzip) comp=( gzip -6 -c ); decomp='gzip -d -c'
          label='\033[32mtar-pipe + gzip\033[0m \033[2m(remote has no zstd)\033[0m' ;;
    *)    fallback ;;
esac

# scp -r SRC HOST:DST/ places SRC *inside* DST, so tar each source as
# `-C <dirname> <basename>`. This also covers xxh's plugin call, which passes
# several sources at once.
tar_args=()
for s in "${srcs[@]}"; do
    tar_args+=( -C "$(dirname -- "$s")" "$(basename -- "$s")" )
done

# -h (dereference) is REQUIRED, not an optimisation: setup.sh symlinks
# xxh-config.fish and starship.toml in the build dir back into this repo, and
# scp -r copies their *contents*. Without -h tar would ship the symlinks
# themselves, which dangle on the remote and leave the session with no config.
tar_flags=( -h )
# bsdtar otherwise writes AppleDouble ._ files onto the remote.
if tar --no-mac-metadata -cf /dev/null -T /dev/null 2>/dev/null; then
    tar_flags+=( --no-mac-metadata )
fi

rq=$(squote "$rpath")
if tar "${tar_flags[@]}" -cf - "${tar_args[@]}" \
     | "${comp[@]}" \
     | ssh ${ssh_opts[@]+"${ssh_opts[@]}"} "$host" "mkdir -p $rq && $decomp | tar -xf - -C $rq"
then
    say "$label"
else
    fallback
fi
