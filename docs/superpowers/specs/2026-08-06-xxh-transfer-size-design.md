# Reducing the xxh connect payload

**Date:** 2026-08-06
**Status:** approved, ready to implement

## Problem

Every `xxhc` connect uploads the full binary bundle over SCP, because the remote
is wiped on disconnect and there is nothing to reuse. The payload is currently
**79.4 MB**. On a fast campus link that is ~6 s; on slower links it reaches the
"tens of seconds" range, which is the complaint driving this work.

## Constraints (pre-existing, not up for negotiation here)

Two established decisions bound the solution space:

- **Wipe-on-disconnect stays.** The remotes include shared admin accounts used
  by multiple people; nothing may persist on them. This rules out caching
  binaries remotely, which would otherwise be the largest possible win.
- **SCP stays; rsync is out.** xxh's internal rsync invocation conflicts with
  SSH ControlMaster multiplexing. This rules out `rsync -z`.

Both are documented in `terminal/terminal.md`. The work below therefore
reduces *what is sent*, and compresses *how it is sent*, without touching either.

## Measurements

Payload composition (x86_64), and how it compresses:

| binary | raw | gzip -6 | strippable |
|---|---|---|---|
| atuin | 35.1 MB | — | 0 |
| fish | 14.7 MB | — | 0.7 MB |
| starship | 11.9 MB | — | 0 |
| fastfetch | 11.1 MB | — | **8.4 MB** |
| bat | 6.6 MB | — | 0 |
| **total** | **79.4 MB** | **30.3 MB (38%)** | 9.0 MB |

zstd -19 reaches 23.3 MB but needs `zstd` on the remote, which cannot be
assumed. zlib is what SSH already speaks, so it costs nothing to reach.

## Design

### 1. Enable SSH compression

Binaries compress to 38% with zlib. SSH can do this on the wire with no remote
tooling requirement, and degrades gracefully: if a server has `Compression no`,
negotiation simply yields no compression and the transfer still succeeds.

**The subtle part.** `xxhc` pre-creates a ControlMaster at `xxhc.fish:23`, and
every subsequent `ssh`/`scp` (including xxh's internal ones) is a *slave* that
reuses that already-established transport. Compression is negotiated once, at
transport setup. Setting `Compression=yes` only on a slave — or only in
`config.xxhc` — is therefore silently ineffective whenever the master exists,
which is the normal path.

It must be set in three places:

| location | why |
|---|---|
| `xxhc.fish:23` (master creation) | governs the real transport; this is the one that matters |
| `config.xxhc` `-o` list | covers the fallback where no master socket exists and xxh's scp connects directly |
| `.xxh/ssh-wrapper.sh` | deliberately sets `ControlMaster=no ControlPath=none`, so it bypasses multiplexing and needs its own flag |

**Correction (found during implementation).** The above is incomplete. `~/.ssh/config`
sets `ControlMaster auto` under `Host *`, and the `xxhc` call sites override only
`ControlPath` — so *every* ssh/scp call in `xxhc.fish` can create the master, not just
the `-fN` one. When line 23 fails (the case the yellow warning exists to report), the
`uname -m` call adopts the role and `ControlPersist` keeps it alive for the upload.
The flag is therefore set on all ten transport-creating calls. The four `-O check` /
`-O stop` control operations are correctly excluded: they act on an existing socket
and never create a transport.

The third table row is currently dormant (it is the `RSYNC_RSH` path, and rsync is
disabled), but is included so the setting is not missing if that path is ever
reached.

CPU cost is ~1.9 s to compress 79 MB on the Mac. Decompression on the remote is
cheaper still, so even the Raspberry Pi target is unaffected. On a link fast
enough that compression became the bottleneck, the change would be a wash rather
than a regression — and it is a one-line revert.

### 2. Switch fastfetch to the stripped upstream build

fastfetch is 11.1 MB, of which **8.4 MB is DWARF debug info** — it is the only
binary in the bundle shipped unstripped in a way that matters. (fish carries a
0.7 MB symbol table; not worth acting on.)

Upstream already publishes a stripped build as `-polyfilled`, for both
architectures. Verified: it reports `stripped`, and its maximum required symbol
version is `GLIBC_2.34` — **identical** to the build in use today. So this is
purely a size change, with no compatibility difference in either direction.

Two edits in `setup.sh`'s `build_arch_store`: the asset pattern
(`linux-<label>-polyfilled.tar.gz`) and the path inside the archive
(`fastfetch-linux-<label>-polyfilled/usr/bin/fastfetch`). Both were verified
against the live 2.67.0 release. The existing `gh_latest_url` grep still selects
uniquely, since `linux-amd64.tar.gz` is not a substring of
`linux-amd64-polyfilled.tar.gz`.

### Explicitly not doing

- **Remote binary cache** — would reduce repeat connects to ~0 MB, but violates
  the shared-admin-account constraint.
- **Dropping fastfetch/bat** — a further ~6.7 MB compressed, but it removes
  working features to solve a problem that compression already solves.
- **Stripping fish** — 0.7 MB, and would add a ~1.7 GB `llvm` build dependency
  to `setup.sh` for it. Not worth it.

## Result

| | payload |
|---|---|
| today | 79.4 MB |
| polyfilled fastfetch only | 71.5 MB |
| compression only | 30.3 MB |
| **both** | **27.2 MB** |

**2.9x smaller.** Measured, not estimated — by compressing the actual staged
payload with the actual polyfilled binary.

## Verification

1. `setup.sh` re-run fetches the polyfilled fastfetch for both arches; staged
   copies match the store.
2. New fastfetch is `stripped`, correct ELF arch per store, ~3.1 MB.
3. Staged payload on disk drops to ~71 MB.
4. A real `xxhc` connect to a live host still works: greeting renders,
   fastfetch output appears, history merges back, remote `~/.xxh` is gone after
   disconnect.
5. Connect wall-time compared before/after on the same host.

Step 4 is the one that cannot be verified locally — it needs a live remote.

## Documentation

`terminal/terminal.md` states the payload size in three places (the
wipe-on-disconnect rationale, the upload table, and the performance breakdown).
All must move to the new figures. The config-flag table also gains a
`Compression=yes` row, and the fastfetch source note should record why the
polyfilled asset is used — otherwise a future reader will "fix" it back to the
obvious-looking asset name.

`terminal/SETUP_VERSION` gets a minor bump: this changes connect behaviour, not
just docs.
