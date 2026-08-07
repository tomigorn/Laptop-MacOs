# Compressing the xxh upload ourselves, for hosts that refuse SSH compression

**Date:** 2026-08-07
**Status:** approved, ready to implement
**Follows:** `2026-08-06-xxh-transfer-size-design.md`

## Problem

The previous change enabled SSH compression and measured 79.4 MB → 27.2 MB. That
works — but only where the server agrees to compress. It does not on the ETH
fleet.

Verified on `root6`, live:

```
client (Mac) offers:  zlib@openssh.com,none      <- our flag is working
server offers:        none
negotiated:           none
```

The refusal comes from `/etc/ssh/sshd_config.d/90-eth.conf` containing
`Compression no`. The `90-eth` prefix marks it as a managed policy drop-in, so it
almost certainly applies fleet-wide — meaning the hosts used most for work are
exactly the ones getting no benefit. Personal hosts (`beefy`, `fastpi`) are not
subject to it and already benefit.

This is the graceful-degradation path working as designed: connections succeed,
they just carry the full payload. On `root6` the entire 71.5 MB crosses the wire,
and the only saving from the previous work is the 8 MB of stripped fastfetch.

## Measurements (against `root6`, over office ethernet)

Effective link throughput is ~17 MB/s. Piping the real payload to `/dev/null` on
the remote — so remote disk is excluded and only wire plus crypto is measured:

| approach | time | on the wire |
|---|---|---|
| raw, as today | **4.14 s** | 71.5 MB |
| gzip -6, gunzip remotely | **2.06 s** | 27.2 MB |
| zstd -3, unzstd remotely | **1.58 s** | ~24 MB |

71.5 MB ÷ 17.3 MB/s = 4.1 s, which matches the observed connect time almost
exactly. The wire is the bottleneck, not remote disk and not CPU.

`root6` has `gzip`, `tar`, `zstd` and `xz` all installed.

## Design

Compress the payload ourselves and decompress it remotely, using xxh's documented
`++scp-command` hook. No fork of xxh, no change to the wipe-on-disconnect or
SCP-not-rsync constraints.

### The interface, captured empirically

Rather than inferring scp's semantics, a logging wrapper captured the real
invocation:

```
-o StrictHostKeyChecking=accept-new  -o LogLevel=QUIET
-o ControlMaster=auto  -o ControlPath=/Users/tmilata/.ssh/cm/xxh-%n
-o Compression=yes  -o ServerAliveInterval=15  -o ServerAliveCountMax=3
-r  -C
/Users/tmilata/.xxh-homes/x86_64/.xxh/shells/xxh-shell-fish/build   <- source
root6:/home/tmil4ea/.xxh/.xxh/shells/xxh-shell-fish/                <- destination
```

So the shape is: `[-o k=v]... [-r] [-C] [-q] [-v] <src>... <host>:<path>`.
`scp -r SRC HOST:DST/` copies SRC *into* DST, i.e. the remote ends up with
`DST/build/`. The tar equivalent is `tar -C $(dirname SRC) -cf - $(basename SRC)`
unpacked with `tar -xf - -C DST`.

xxh calls the command a second time for prerun plugins, as
`<plugin_build_dir>/* <host>:<dst>/` — several sources, possibly files. Building
tar arguments as a repeated `-C <dirname> <basename>` sequence handles both
shapes with one code path.

### The wrapper

New file `terminal/.xxh/scp-wrapper.sh`, wired in via `config.xxhc`:

```yaml
++scp-command: ~/.xxh/scp-wrapper.sh
```

Logic:

1. Split argv into ssh options (`-o k=v`, `-v`) and positionals. Discard `-r`,
   `-C`, `-q` — they are scp-specific and meaningless to tar.
2. Last positional is the destination. If it contains no `:`, this is not a shape
   we handle — `exec` the real scp unchanged.
3. Probe the remote once: does it have `tar`, and does it have `zstd`? This is one
   round trip over the already-established ControlMaster, ~30-50 ms, against a
   2.5 s saving.
4. No `tar` remotely, or the probe fails → `exec` the real scp.
5. Otherwise stream: `tar -cf - <-C dir base>... | <compressor> | ssh <opts>
   <host> 'mkdir -p <dst> && <decompressor> | tar -xf - -C <dst>'`, with zstd
   preferred and gzip as fallback.
6. Any failure in the pipeline → fall back to the real scp, so a broken wrapper
   degrades to today's behaviour rather than breaking every connect.

Compression is applied by piping through `zstd`/`gzip` explicitly rather than
using tar's own `-z`/`-I` flags, because macOS ships bsdtar and the remotes ship
GNU tar, and their compression flags differ. `tar -cf -` / `tar -xf -` is common
to both.

tar preserves permission bits, so the uploaded binaries keep their executable
bit — which `scp -r` also does today, and which the session depends on.

### Why the probe rather than optimistic zstd

The stream format is fixed by the sender, so the receiver cannot adapt after the
fact. Sending zstd to a host without it means detecting the failure only after
transferring, then retransmitting. One cheap probe over an existing master is
simpler and predictable.

### Dependency

`zstd` is currently installed on the Mac only as a transitive Homebrew
dependency, so `brew autoremove` could take it. It must be added to `setup.sh`'s
explicit `brew install` line. The wrapper also degrades to gzip if the local zstd
is missing.

## Expected result

| host class | today | after |
|---|---|---|
| ETH fleet (`Compression no`) | 4.14 s | **~1.6 s** |
| personal hosts (SSH compression works) | already compressed | unchanged — wrapper still helps slightly, since zstd beats zlib |

## Risks

The wrapper sits on the critical path of every connect. A defect means no
connects. Mitigated by the fallback-to-scp on any error, and by the fact that the
fallback path is the current behaviour exactly.

Second-order: with the wrapper compressing, SSH's own `Compression=yes` would be
compressing already-compressed data on hosts that allow it — wasted CPU for no
gain. The previous change is still correct for anything that does not go through
the wrapper (the atuin history transfers in `xxhc`), so `Compression=yes` stays,
but this is worth revisiting if it measures badly on `beefy`.

## Verification

1. Wrapper handles the captured argv shape; unit-testable locally against a
   scratch directory over `localhost`-less loopback is not possible, so tests run
   against `root6`.
2. A real `xxhc root6` connect works: greeting renders, fastfetch output present,
   prompt shows `(root6)`.
3. Connect time drops from ~4 s to ~1.6-2 s.
4. Uploaded binaries are executable on the remote.
5. History still merges back on disconnect; remote `~/.xxh` is gone afterwards.
6. Forcing the fallback (e.g. pointing at a host without tar) still connects.

Steps 2-6 need a live remote.
