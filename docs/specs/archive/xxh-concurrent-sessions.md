# Concurrent xxhc sessions to one host

**Date:** 2026-09-07
**Status:** approved, ready to implement
**Follows:** `2026-08-07-xxh-tar-pipe-transfer-design.md`

## Problem

Opening a second `xxhc` session to a host while the first is still live breaks
the first session and silently destroys its history. Reproduced live on `root6`
on 2026-09-07: session A connected, session B connected 25 s later, and A's next
command produced

```
== A: late history ==
atuin: command not found
ls: cannot access '/home/tmil4ea/.xxh/.local/share/atuin/': No such file or directory
```

A never printed `History from root6 merged into local atuin`. Everything A typed
was lost.

### Root cause

The remote xxh home is one fixed path, `~/.xxh`, shared by every session to that
host. `+hhh: "~"` puts `HOME` at the real home, but leaves `XDGPATH` defaulted to
`XXH_HOME`, so the entrypoint derives

```
XDG_DATA_HOME=~/.xxh/.local/share      -> atuin DB at ~/.xxh/.local/share/atuin/history.db
XDG_CONFIG_HOME=~/.xxh/.config
PATH=~/.xxh/.xxh/shells/xxh-shell-fish/build/bin:...   -> fish, atuin, starship, bat, fastfetch
```

One path holds every session's binaries *and* every session's mutable state.
Three separate destructive collisions follow:

1. **Install-force wipes live binaries.** `+if` in `config.xxhc` makes every
   connect run `rm -rf ~/.xxh/.xxh` and re-upload. B's connect deletes the
   binaries A is executing. Both session logs show `Remove
   root6:/home/tmil4ea/.xxh/.xxh` followed by `First time upload using scp`.

2. **Exit cleanup wipes the other session.** `rm -rf ~/.xxh` runs twice on exit —
   `_xxhc_cleanup_home` on the remote and the belt-and-suspenders line in
   `xxhc.fish`. B's exit removes A's environment and A's unexported atuin DB.

3. **Pre-seed overwrites a live SQLite file.** `cp $preseed
   $XDG_DATA_HOME/atuin/history.db` replaces, in place, the file A's atuin has
   open, while A's `-wal`/`-shm` sidecars survive alongside it. The salt in the
   WAL no longer matches the new DB header, so both sessions get SQLite errors
   from atuin. This is the "history is just an error message" symptom.

### Why the existing concurrency note is wrong

`terminal.md` claims concurrent sessions are handled because `XXH_STAGE_ID`
namespaces the export file. That is true and it is the one file that matters
least. The live DB, the pre-seed, the binaries and the cleanup are all still
keyed by host alone. The specification is wrong, not just the code.

### Secondary collisions in the same class

- `$tmp_db` = `/tmp/.xxh_atuin_$target_local.db` and `$clean_preseed` =
  `/tmp/.xxh_atuin_pre_clean_$target.db` are per-host, so two sessions
  disconnecting or connecting together corrupt each other's transfer file.
- The remote pre-seed `$stage/xxh_atuin_pre_$target.db` is per-host; A's teardown
  `rm -f` can delete it out from under B's starting session.
- A's teardown runs `ssh -O stop` on the shared ControlMaster that B is using.
- `ssh -fN` against an already-existing master leaves a stray background slave.
- History retrieval failure is silent: `if scp ...` simply skips the merge, which
  is exactly how A's history vanished without a word.

## Requirements

Multiple simultaneous `xxhc` sessions to one host must each work normally and
must each get their history home. Live history sharing between concurrent
sessions is explicitly **not** required — merge on disconnect is sufficient. The
existing no-trace-on-disconnect property must be preserved.

## Design

### Per-session remote xxh home

`xxhc` passes `+hh ~/.xxh-<sid>` so each session owns its whole tree. Every
collision above is a consequence of one shared mutable path; giving each session
its own path removes the shared path rather than coordinating access to it.

`sid` becomes `<local fish pid>-<epoch seconds>` — unique across terminals and
across PID reuse. It continues to serve as `XXH_STAGE_ID`.

The entrypoint derives `XXH_HOME` by walking four levels up from its own build
dir, so `XDG_*`, `PATH` and the atuin DB follow the new home with no entrypoint
change. `+hhh: "~"` still puts `HOME` at the real home, so nothing the user sees
moves.

**This costs no extra transfer.** `+if` already forces a full ~71 MB re-upload on
every connect, so a fresh per-session directory uploads exactly what a shared one
did.

**Why `$HOME` and not the runtime dir.** Measured on `root6`: home is local ext4
with 17 G free, while `$XDG_RUNTIME_DIR` is a 388 M tmpfs on a 3.8 G-RAM box.
Three concurrent sessions would put 213 M of a 388 M tmpfs into RAM. The home
directory is also where the home lives today, so this is the minimal change.

### Cleanup, scoped to the session that owns it

- `_xxhc_cleanup_home` removes `$XXH_HOME`, not `~/.xxh`, guarded to refuse an
  empty value, `/`, or `$HOME` itself.
- `xxhc`'s belt-and-suspenders removal and its `PRESENT`/`ABSENT` verification
  both target `~/.xxh-<sid>`.

### Sweeping homes left by killed sessions

A fixed `~/.xxh` was self-cleaning: the next session removed whatever the last
one left. Per-session names lose that, so a session killed with SIGKILL would
leak a directory.

Each session writes its own remote fish PID to `$XXH_HOME/.owner-pid` at startup.
At startup a session also sweeps the *other* `~/.xxh-*` homes, removing any whose
recorded owner is no longer alive (`kill -0`). A home with no `.owner-pid` is
removed only when older than one day, which covers a peer that is still uploading
and has not started its shell yet.

### Remaining per-session names

- remote pre-seed: `$stage/xxh_atuin_pre_$target-$sid.db`, read by the session as
  `..._$XXH_SSH_ALIAS-$XXH_STAGE_ID.db`
- local: `/tmp/.xxh_atuin_local_$target-$sid.db`, `/tmp/.xxh_atuin_pre_clean_$target-$sid.db`
  (leading `local_` rather than a trailing one, so fish does not read `$sid_local` as a name)

### ControlMaster shared, torn down by the last session out

A multiplexed tunnel per host is what ControlMaster is for, so it stays shared.
What changes is ownership: `xxhc` registers `~/.ssh/cm/xxh-$target.users/$sid` at
connect and removes it at teardown, and only issues `-O stop` when that directory
is left empty. The master is created only when `-O check` says none exists, which
also removes the stray `-fN` slave.

### Failures stop being silent

When the history file cannot be retrieved, `xxhc` warns that the session's
history was not merged instead of skipping quietly. The stray `0|0|0` that
`PRAGMA wal_checkpoint` prints to stdout gets redirected, since that line is
being touched anyway.

Both local merges gain `PRAGMA busy_timeout=5000` so two sessions disconnecting
at once wait for each other's lock rather than failing.

## Testing

The reproduction is the test: session A long-running, session B overlapping it,
both logged. Before the change A reports `atuin: command not found` and no merge
line. After it, both sessions must report their own history and both must print
the merge line, and `~/.xxh-*` must be empty on the remote afterwards. A
SIGKILL-then-reconnect case verifies the sweeper.

## Out of scope

Live history sharing between concurrent sessions. Reducing the per-connect
upload by keeping a shared home across sessions — that trades away the
no-trace-on-disconnect property and is a separate decision.
