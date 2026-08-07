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
set -uo pipefail

REAL_SCP=/usr/bin/scp
orig=( "$@" )
fallback() { exec "$REAL_SCP" "${orig[@]}"; }

# POSIX-safe single-quoting for paths interpolated into the remote shell.
squote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

ssh_opts=()
positionals=()
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

for s in "${srcs[@]}"; do [[ -e "$s" ]] || fallback; done

# One round trip over the already-established ControlMaster (~30-50 ms) to learn
# what the remote can decompress. The stream format is fixed by the sender, so
# the receiver cannot adapt after the fact -- probing beats retransmitting.
probe=$(ssh "${ssh_opts[@]}" "$host" \
    'command -v tar >/dev/null 2>&1 || exit 1
     if command -v zstd >/dev/null 2>&1; then echo zstd; else echo gzip; fi' 2>/dev/null) || fallback

case "$probe" in
    zstd) if command -v zstd >/dev/null 2>&1; then
              comp=( zstd -3 -T0 -c ); decomp='zstd -d -c'
          else
              comp=( gzip -6 -c ); decomp='gzip -d -c'
          fi ;;
    gzip) comp=( gzip -6 -c ); decomp='gzip -d -c' ;;
    *)    fallback ;;
esac

# scp -r SRC HOST:DST/ places SRC *inside* DST, so tar each source as
# `-C <dirname> <basename>`. This also covers xxh's plugin call, which passes
# several sources at once.
tar_args=()
for s in "${srcs[@]}"; do
    tar_args+=( -C "$(dirname -- "$s")" "$(basename -- "$s")" )
done

rq=$(squote "$rpath")
tar -cf - "${tar_args[@]}" \
    | "${comp[@]}" \
    | ssh "${ssh_opts[@]}" "$host" "mkdir -p $rq && $decomp | tar -xf - -C $rq" \
    || fallback
