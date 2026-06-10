# Per-architecture binary selection for xxhc

**Date:** 2026-06-10
**Status:** Approved (design)

## Problem

`xxhc <host>` uploads a self-contained shell bundle (portable fish + starship,
atuin, bat, fastfetch) to a remote host and runs it there. Every bundled binary
is currently **Linux x86_64**. Connecting to an ARM host (Raspberry Pi 5,
`aarch64`) uploads fine over scp but every binary fails at exec time with
`cannot execute binary file: Exec format error` — the portable fish never
starts, so the session is broken.

Verified on `fastpi`:

- `uname -m` → `aarch64`, Debian 12 (bookworm)
- bundled `fish`/`starship`/`atuin`/`bat`/`fastfetch` → all `ELF x86-64`
- running the x86_64 `fish` on the Pi → exit 126, `Exec format error`

## Goal

Detect the remote architecture before connecting and upload binaries built for
that architecture. Support **x86_64** and **aarch64** (the two architectures in
use: existing Intel/AMD servers and the Pi 5). Unknown architectures abort with
a clear message rather than uploading binaries that cannot run.

## Key findings that shape the design

1. **Official fish 4.x ships portable static binaries for both arches.** The
   `fish-shell/fish-shell` releases include `fish-X.Y.Z-linux-x86_64.tar.xz`
   **and** `fish-X.Y.Z-linux-aarch64.tar.xz`. Each tarball is a **single,
   statically linked `fish` binary** (~14 MB) with functions/completions
   embedded — no separate `share/`/`etc/` tree. Verified: the aarch64 binary
   runs standalone on the Pi (`fish, version 4.7.1`, `set -gx` and `string`
   builtins work).

   This retires `xxh/fish-portable` (which only ever published x86_64, fish
   3.4.1). One upstream source now covers both arches, and it is a newer fish.

2. **All four tools publish aarch64 Linux builds** (verified live):
   - starship `aarch64-unknown-linux-musl`
   - atuin `aarch64-unknown-linux-musl`
   - bat `aarch64-unknown-linux-musl`
   - fastfetch `linux-aarch64`

3. **`xxhc` already opens a ControlMaster tunnel before xxh runs**
   (`xxhc.fish` line ~250). That is the natural place to run a one-shot
   `ssh … uname -m` (reuses the tunnel, effectively instant).

4. **The xxh-shell-fish entrypoint needs no change.** It launches
   `fish-portable/bin/fish.sh` (a 3-line `TERMINFO_DIRS` wrapper that execs
   `./fish`) and puts `fish-portable/bin` on `PATH`. As long as each arch store
   provides `fish-portable/bin/{fish,fish.sh}`, the entrypoint is satisfied.

## Decisions

- **D1 — fish source/version:** unify both arches on official fish 4.7.1
  (single source, symmetric, newer). Accepts a one-time fish 3.4.1 → 4.x
  config-compatibility test as the cost.
- **D2 — swap mechanism:** maintain per-arch stores and **copy** the matching
  binaries into the build dir just before connecting. Robust and simple; a
  local SSD copy of ~110 MB is sub-second versus the ~15 s upload. (Symlink
  swapping was rejected — risk that xxh's scp does not follow symlinked dirs as
  expected.)

## What does NOT change

- **`starship.toml`** — consumed by the starship binary; shell- and
  arch-agnostic. Only the starship *binary* is arch-specific.
- **Greeting function code** (`fish_greeting.fish` locally; the remote
  `fish_greeting` redefinition in `xxh-config.fish`). Syntax is valid under fish
  4.x; the only dependency is an arch-correct `fastfetch` binary, which
  fastfetch uses to auto-detect the host.
- **Binary vs config split (stated explicitly):** every *binary* (`fish`,
  `starship`, `atuin`, `bat`, `fastfetch`) must match the remote arch. Every
  *config file* (`starship.toml`, `xxh-config.fish`, atuin config) is shared.

## Components

### Component 1 — Per-arch binary stores (local, not in git)

Replace the single `~/.xxh/bin/` with two arch-keyed stores:

```
~/.xxh/arch/x86_64/
    fish-portable/bin/fish        official fish 4.7.1 x86_64 (single static binary)
    fish-portable/bin/fish.sh     3-line TERMINFO wrapper (entrypoint calls this)
    bin/starship                  x86_64-unknown-linux-musl
    bin/atuin                     x86_64-unknown-linux-musl
    bin/bat                       x86_64-unknown-linux-musl
    bin/fastfetch                 linux-amd64
~/.xxh/arch/aarch64/
    fish-portable/bin/{fish,fish.sh}   official fish 4.7.1 aarch64
    bin/starship                  aarch64-unknown-linux-musl
    bin/atuin                     aarch64-unknown-linux-musl
    bin/bat                       aarch64-unknown-linux-musl
    bin/fastfetch                 linux-aarch64
```

Rust tools use **musl static** builds (no glibc-version dependency — remote libc
is unknown). fastfetch dynamically links libc; the non-polyfilled
`linux-<arch>` variant matches the current x86_64 choice and works on the Pi's
recent glibc (final variant pinned during implementation/testing).

`fish.sh` is identical to the plugin's wrapper:

```sh
#!/bin/sh
export TERMINFO_DIRS=/lib/terminfo:/etc/terminfo:/usr/share/terminfo:$TERMINFO_DIRS
CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"
$CURRENT_DIR/fish "$@"
```

### Component 2 — Arch detection + swap in `xxhc.fish`

Immediately after the ControlMaster tunnel is established and before `xxh` is
invoked:

1. `set -l remote_uname (ssh <reuse cm socket> $target uname -m)`
2. Map to a canonical arch:
   - `x86_64` / `amd64` → `x86_64`
   - `aarch64` / `arm64` → `aarch64`
   - empty (detection failed) or anything else → print a clear red error, tear
     down the ControlMaster socket, `return 1` (no upload).
3. Verify `~/.xxh/arch/<arch>/` exists; if missing, error pointing at
   `setup.sh`, tear down socket, `return 1`.
4. Stage the binary payload into the build dir, leaving config symlinks
   (`xxh-config.fish`, `starship.toml`) and `entrypoint.sh` untouched:
   ```
   build=~/.xxh/.xxh/shells/xxh-shell-fish/build
   rm -rf  $build/fish-portable $build/bin
   cp -R   ~/.xxh/arch/<arch>/fish-portable $build/fish-portable
   cp -R   ~/.xxh/arch/<arch>/bin           $build/bin
   ```
5. Call `xxh` exactly as today.

### Component 3 — `setup.sh` and docs

- `setup.sh`: download both arch sets from upstream into the two stores. fish
  from `fish-shell/fish-shell` (`linux-x86_64` / `linux-aarch64`); the four
  tools from their existing repos in both `x86_64` and `aarch64` variants. Drop
  reliance on `xxh/fish-portable` / `build.sh` for the fish binary. The
  xxh-shell-fish plugin is still installed (`xxh +I xxh-shell-fish`) for the
  entrypoint and plugin framework; its bundled fish-portable is superseded by
  the staged store. Optionally pre-stage the x86_64 store into the build dir so
  a bare `xxh <host>` (without `xxhc`) still works by default.
- `terminal.md`: document multi-arch (detection step, per-arch stores, the
  fish 4.x change, updated "Not in git" paths and setup/update steps).

### Entrypoint

Unchanged (see finding 4).

## Risks / verification

- **fish 3.4.1 → 4.7.1 config compatibility** is the one real risk. After
  wiring up, test-connect to **both** an x86_64 host **and** the Pi and confirm,
  on each:
  - prompt renders (starship init under fish 4.x)
  - greeting prints connect-time + fastfetch (arch-correct fastfetch)
  - atuin seeds on connect and exports on disconnect; history merges locally
  - **both `--on-event fish_exit` handlers fire** (`_xxhc_export_history`,
    `_xxhc_cleanup_home`) and `~/.xxh` is removed cleanly
  - no "unknown terminal" / universal-variable / `status current-filename`
    warnings
- **Concurrent `xxhc` to different-arch hosts** races on the shared build dir.
  Documented as a known limitation (single-user interactive use makes it
  unlikely); no locking added (YAGNI).

## Out of scope

- 32-bit ARM (`armv7l`) and any architecture beyond x86_64 / aarch64.
- Locking for concurrent connects.
- Caching binaries on the remote (the wipe-on-disconnect model is unchanged).
