# Concurrent xxhc Sessions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let several `xxhc` sessions to one host run at the same time, each with its own working environment and its own history, without any of them destroying another.

**Architecture:** Give each session its own remote xxh home (`~/.xxh-<sid>`) instead of the shared `~/.xxh`, so the binaries and the atuin DB are no longer a shared mutable path. Scope every cleanup, transfer filename and ControlMaster teardown to the session that owns it, and add a sweeper for homes left behind by killed sessions.

**Tech Stack:** fish 4.x (Mac side and remote session config), POSIX sh over SSH, sqlite3, xxh 0.8.14.

**Spec:** `docs/superpowers/specs/2026-09-07-xxh-concurrent-sessions-design.md`

---

## File Structure

| File | Responsibility |
|---|---|
| `terminal/.config/fish/functions/xxhc.fish` | Mac side: session id, per-session home + transfer names, ControlMaster refcount, retrieval/merge, cleanup verification |
| `terminal/.xxh/xxh-config.fish` | Remote side: owner marker, stale-home sweeper, per-session pre-seed name, session-scoped exit cleanup |
| `terminal/tests/concurrent-sessions.fish` | Live integration test: two overlapping sessions, plus the SIGKILL sweeper case |
| `terminal/terminal.md`, `README.md`, `terminal/SETUP_VERSION` | Docs kept in sync, version bumped |

`xxhc.fish` is already 263 lines and gains a helper. Keep the helper as a
separate top-level function next to `_xxhc_clock_skew` rather than growing the
body of `xxhc` further.

---

### Task 1: Failing integration test

**Files:**
- Create: `terminal/tests/concurrent-sessions.fish`

- [ ] **Step 1: Write the failing test**

```fish
#!/usr/bin/env fish
# Live test: two overlapping xxhc sessions to one host must not break each other.
#
#   terminal/tests/concurrent-sessions.fish root6
#
# Needs a reachable host. Session A runs long; session B starts while A is up
# and finishes first, so A's later commands run after B has connected AND after
# B has torn down — the two moments that used to destroy A.

set -l host $argv[1]
test -n "$host"; or begin; echo "usage: concurrent-sessions.fish <ssh-host>"; exit 2; end

set -l tmp (mktemp -d)
set -l fails 0

function check -a label condition
    if test "$condition" = ok
        echo "  PASS  $label"
    else
        echo "  FAIL  $label"
        set -g fails (math $fails + 1)
    end
end

echo "== running two overlapping sessions against $host =="

fish -c "xxhc $host +hc 'echo A_EARLY; atuin history list 2>&1 | tail -1; sleep 45; echo A_LATE; atuin history list 2>&1 | tail -1; echo A_END'" >$tmp/A.log 2>&1 &
set -l apid $last_pid
sleep 25
fish -c "xxhc $host +hc 'echo B_ONLY; atuin history list 2>&1 | tail -1; echo B_END'" >$tmp/B.log 2>&1
wait $apid

echo "== assertions =="

# A must still have a working environment after B connected and after B exited.
if grep -q 'command not found' $tmp/A.log
    check "A keeps its binaries while B runs" broken
else
    check "A keeps its binaries while B runs" ok
end

grep -q A_LATE $tmp/A.log; and check "A reaches its late command" ok; or check "A reaches its late command" broken
grep -q A_END  $tmp/A.log; and check "A exits cleanly" ok; or check "A exits cleanly" broken
grep -q B_END  $tmp/B.log; and check "B exits cleanly" ok; or check "B exits cleanly" broken

# Neither session may lose its history.
grep -q "History from $host merged" $tmp/A.log; and check "A's history merged" ok; or check "A's history merged" broken
grep -q "History from $host merged" $tmp/B.log; and check "B's history merged" ok; or check "B's history merged" broken

# No trace left on the remote.
set -l leftover (ssh -o BatchMode=yes $host 'ls -d ~/.xxh ~/.xxh-* 2>/dev/null | tr "\n" " "')
test -z "$leftover"; and check "no remote homes left behind" ok; or check "no remote homes left behind ($leftover)" broken

echo "== sweeper: a home whose owner is dead must be removed on next connect =="
ssh -o BatchMode=yes $host 'mkdir -p ~/.xxh-99999999-1 && echo 99999999 > ~/.xxh-99999999-1/.owner-pid' >/dev/null 2>&1
fish -c "xxhc $host +hc 'echo SWEEP_RUN'" >$tmp/C.log 2>&1
set -l swept (ssh -o BatchMode=yes $host 'ls -d ~/.xxh-99999999-1 2>/dev/null')
test -z "$swept"; and check "stale home swept" ok; or check "stale home swept" broken

echo
if test $fails -eq 0
    echo "ALL PASS  (logs in $tmp)"
    exit 0
else
    echo "$fails FAILED  (logs in $tmp)"
    exit 1
end
```

- [ ] **Step 2: Run it to confirm it fails against today's code**

Run: `chmod +x terminal/tests/concurrent-sessions.fish; terminal/tests/concurrent-sessions.fish root6`
Expected: FAIL on "A keeps its binaries while B runs", "A reaches its late
command", "A's history merged", and "stale home swept". This is the reproduction
from the spec, now automated.

- [ ] **Step 3: Commit**

```bash
git add terminal/tests/concurrent-sessions.fish
git commit -m "terminal: add a live test for concurrent xxhc sessions"
```

---

### Task 2: Per-session remote home

**Files:**
- Modify: `terminal/.config/fish/functions/xxhc.fish` (session id, `+hh`, cleanup, verification)

- [ ] **Step 1: Widen the session id and derive the home from it**

Replace the `sid` block (currently around lines 57-63) with:

```fish
    set -l target $argv[1]
    set -l host_db ~/.xxh/history/$target.db
    set -l local_db ~/.local/share/atuin/history.db
    set -l cm_path ~/.ssh/cm/xxh-$target
    set -l cm_users $cm_path.users
    # Unique per-session id. $fish_pid alone distinguishes terminals but is
    # recycled by the OS; the epoch suffix keeps a stale remote home from a
    # long-dead session out of a new session's way. Used for the remote home,
    # every transfer filename, and XXH_STAGE_ID.
    set -l sid $fish_pid-(date +%s)
    set -l tmp_db /tmp/.xxh_atuin_local_$target-$sid.db
    # Each session gets its OWN remote xxh home. A single shared ~/.xxh made the
    # binaries and the atuin DB a shared mutable path, so a second session's
    # install-force wipe and its exit cleanup destroyed the first session's
    # environment and unsaved history. Costs nothing extra: +if in config.xxhc
    # already forces a full re-upload on every connect.
    set -l remote_home .xxh-$sid
```

- [ ] **Step 2: Point xxh at that home**

In the `xxh` invocation, add `+hh` as the first option after the target:

```fish
    env RSYNC_RSH=~/.xxh/ssh-wrapper.sh xxh $target \
        +hh "~/$remote_home" \
        +lh $lxh \
```

- [ ] **Step 3: Scope the belt-and-suspenders removal to this session**

```fish
    # Belt-and-suspenders: remove this session's home if the fish_exit handler
    # didn't (e.g. fish was SIGKILL'd). Only ours — a peer session's home is none
    # of our business.
    ssh -q -o ControlMaster=auto -o ControlPath=$cm_path -o Compression=yes $target "rm -rf ~/$remote_home 2>/dev/null" 2>/dev/null
```

- [ ] **Step 4: Scope the cleanup verification to this session**

```fish
    set -l xxh_state (ssh -q -o ControlPath=$cm_path -o Compression=yes -o ConnectTimeout=10 $target \
        "test -d ~/$remote_home && echo PRESENT || echo ABSENT" 2>/dev/null)
```

and in the three report branches replace `~/.xxh` with `~/$remote_home`:

```fish
        echo "  ║  ~/$remote_home was NOT removed on $target"
        echo "  ║  Other users on this shared host can see your files."
        echo "  ║  Fix now:  ssh $target \"rm -rf ~/$remote_home\""
```
```fish
        echo "  ✓ Remote cleanup verified — ~/$remote_home removed from $target, no trace left behind."
```
```fish
        echo "    Check later with:  ssh $target \"ls -ld ~/$remote_home\""
```

- [ ] **Step 5: Verify the home is per-session**

Run: `fish -c 'xxhc root6 +hc "echo \$XXH_HOME"'`
Expected: prints `/home/<user>/.xxh-<pid>-<epoch>`, not `/home/<user>/.xxh`.

- [ ] **Step 6: Commit**

```bash
git add terminal/.config/fish/functions/xxhc.fish
git commit -m "terminal: give each xxhc session its own remote xxh home"
```

---

### Task 3: Session-scoped remote cleanup and stale-home sweeper

**Files:**
- Modify: `terminal/.xxh/xxh-config.fish`

- [ ] **Step 1: Record the owner and sweep dead peers**

Insert immediately after the `set -x TERM xterm-256color` line:

```fish
# ── Per-session home bookkeeping ────────────────────────────────────────────
# xxhc gives every session its own remote home (~/.xxh-<sid>), so concurrent
# sessions never share binaries or an atuin DB. Record which process owns this
# one, then remove homes whose owner is gone.
#
# The old fixed ~/.xxh was self-cleaning — the next session removed whatever the
# last one left. Per-session names give that up, so a session killed with
# SIGKILL (which never runs its fish_exit handler) would leak a directory
# forever. This sweep restores the property without reintroducing a shared path.
if set -q XXH_HOME; and test -n "$XXH_HOME"
    echo $fish_pid > $XXH_HOME/.owner-pid 2>/dev/null
    for d in (dirname $XXH_HOME)/.xxh-*
        test -d $d; or continue
        test "$d" = "$XXH_HOME"; and continue
        set -l owner (cat $d/.owner-pid 2>/dev/null | string trim)
        if string match -qr '^[0-9]+$' -- "$owner"
            # kill -0 only probes; it sends no signal. Owner still alive => leave it.
            command kill -0 $owner 2>/dev/null; or rm -rf $d 2>/dev/null
        else
            # No owner recorded: either a peer that is still uploading and has
            # not started its shell yet, or a home from before this scheme.
            # Only the clearly stale ones go.
            set -l stale (find $d -maxdepth 0 -mtime +1 2>/dev/null)
            test (count $stale) -gt 0; and rm -rf $d 2>/dev/null
        end
    end
end
```

- [ ] **Step 2: Make the exit cleanup remove only this session's home**

Replace `_xxhc_cleanup_home` (currently at the end of the file) with:

```fish
# Runs on both clean exit and SIGHUP (VPN drop, terminal crash, lost connection).
# Deletes THIS session's home immediately so other users can't see it even if
# local xxhc never runs. Safe to delete while running: open file descriptors
# hold the inodes alive until exit.
#
# It used to delete the fixed ~/.xxh, which on a concurrent session meant
# deleting a *peer's* live environment and its unexported history.
function _xxhc_cleanup_home --on-event fish_exit
    set -q XXH_HOME; or return
    test -n "$XXH_HOME"; or return
    # Refuse the values that would turn this into `rm -rf ~` or worse.
    test "$XXH_HOME" = /; and return
    test "$XXH_HOME" = "$HOME"; and return
    test "$XXH_HOME" = "$USER_HOME"; and return
    string match -qr '/\.xxh(-[0-9]+-[0-9]+)?$' -- "$XXH_HOME"; or return
    rm -rf $XXH_HOME 2>/dev/null
end
```

- [ ] **Step 3: Run the integration test**

Run: `terminal/tests/concurrent-sessions.fish root6`
Expected: "A keeps its binaries while B runs", "A reaches its late command", "A
exits cleanly", "B exits cleanly", "no remote homes left behind" and "stale home
swept" all PASS. The two "history merged" checks may still fail — Task 4 covers
those.

- [ ] **Step 4: Commit**

```bash
git add terminal/.xxh/xxh-config.fish
git commit -m "terminal: scope remote cleanup to the session that owns the home"
```

---

### Task 4: Per-session transfer filenames

**Files:**
- Modify: `terminal/.config/fish/functions/xxhc.fish` (pre-seed names)
- Modify: `terminal/.xxh/xxh-config.fish` (pre-seed name)

- [ ] **Step 1: Namespace the remote pre-seed and the local scratch copy**

In `xxhc.fish`, replace the pre-seed name and the VACUUM scratch file:

```fish
    set -l remote_preseed "$stage/xxh_atuin_pre_$target-$sid.db"
    set -l remote_db "$stage/xxh_atuin_$target-$sid.db"
```
```fish
            set -l clean_preseed /tmp/.xxh_atuin_pre_clean_$target-$sid.db
```

- [ ] **Step 2: Read the matching name on the remote**

In `xxh-config.fish`, replace the `preseed` assignment inside the atuin block:

```fish
    # Per-session filename (matches xxhc's $sid). A per-host name let one
    # session's teardown `rm -f` the pre-seed a concurrent session was about to
    # read.
    set -l preseed (_xxhc_stage_dir)/xxh_atuin_pre_$XXH_SSH_ALIAS
    test -n "$XXH_STAGE_ID"; and set preseed $preseed-$XXH_STAGE_ID
    set preseed $preseed.db
```

- [ ] **Step 3: Run the integration test**

Run: `terminal/tests/concurrent-sessions.fish root6`
Expected: all checks PASS, including both "history merged" checks.

- [ ] **Step 4: Commit**

```bash
git add terminal/.config/fish/functions/xxhc.fish terminal/.xxh/xxh-config.fish
git commit -m "terminal: namespace every history transfer file per session"
```

---

### Task 5: ControlMaster owned by the last session out

**Files:**
- Modify: `terminal/.config/fish/functions/xxhc.fish`

- [ ] **Step 1: Add the release helper above `function xxhc`**

```fish
# ── Shared ControlMaster, released by the last session out ──────────────────
# One multiplexed tunnel per host is what ControlMaster is for, so concurrent
# xxhc sessions share it. What they must not share is the teardown: a session
# ending used to `-O stop` the master a live peer was still using, pushing that
# peer's remaining transfers onto fresh ProxyJump connections. Each session
# claims the master with a file named after its $sid; only the session that
# removes the last claim stops it.
function _xxhc_release_master -a target cm_path cm_users sid \
        --description "drop this session's claim on the shared ControlMaster"
    rm -f $cm_users/$sid 2>/dev/null
    set -l still (ls -A $cm_users 2>/dev/null)
    if test (count $still) -eq 0
        ssh -q -o ControlPath=$cm_path -O stop $target 2>/dev/null
        rmdir $cm_users 2>/dev/null
    end
end
```

- [ ] **Step 2: Claim the master before creating it**

Replace the ControlMaster setup block:

```fish
    mkdir -p ~/.ssh/cm $cm_users
    # Claim before dialling, so a peer tearing down mid-connect can never see an
    # empty claim directory and stop the master out from under us.
    touch $cm_users/$sid
    # Create the master only when there isn't one. With ControlMaster=auto and a
    # socket already present, `-fN` attaches as a background *slave* that lingers
    # for the life of the master — one leaked ssh process per concurrent session.
    if not ssh -q -o ControlPath=$cm_path -O check $target 2>/dev/null
        ssh -o ControlMaster=auto -o ControlPath=$cm_path -o Compression=yes -fN -o ConnectTimeout=30 $target 2>/dev/null
    end
```

- [ ] **Step 3: Release instead of stopping, on all three exits**

Replace each of the three `ssh -q -o ControlPath=$cm_path -O stop $target 2>/dev/null` calls
(the unsupported-arch return, the missing-`$lxh` return, and the end of the function) with:

```fish
    _xxhc_release_master $target $cm_path $cm_users $sid
```

- [ ] **Step 4: Verify the master survives a peer's exit**

Run: `terminal/tests/concurrent-sessions.fish root6`
Then: `ls -A ~/.ssh/cm/ | grep -c 'xxh-root6.users'`
Expected: test all PASS, and `0` — the claim directory is removed once the last
session leaves.

- [ ] **Step 5: Commit**

```bash
git add terminal/.config/fish/functions/xxhc.fish
git commit -m "terminal: let the last xxhc session out stop the shared ControlMaster"
```

---

### Task 6: Stop losing history silently

**Files:**
- Modify: `terminal/.config/fish/functions/xxhc.fish`

- [ ] **Step 1: Warn when retrieval fails, and wait for the merge lock**

Add `PRAGMA busy_timeout=5000;` to both merges so two sessions disconnecting
together wait for each other instead of failing, silence the checkpoint's
`0|0|0` on stdout, and add an `else` branch to the retrieval `if`:

```fish
        sqlite3 $tmp_db "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null 2>&1
```
```fish
        sqlite3 $local_db "
            PRAGMA busy_timeout=5000;
            ATTACH '$tmp_db' AS remote;
            INSERT OR IGNORE INTO main.history ($cols) SELECT $cols FROM remote.history;
            DETACH remote;
        "
```
```fish
            sqlite3 $host_db "
                PRAGMA busy_timeout=5000;
                ATTACH '$tmp_db' AS new_session;
                INSERT OR IGNORE INTO main.history ($cols) SELECT $cols FROM new_session.history;
                DETACH new_session;
            "
```

and after the closing `end` of the retrieval block:

```fish
    else
        # Losing a session's history used to be completely silent: the `if scp`
        # simply fell through. That is how a concurrent session's history
        # disappeared without a word.
        set_color yellow
        echo "  ⚠ No history retrieved from $target — this session's commands were not merged."
        echo "    Expected the export at $target:$remote_db"
        set_color normal
    end
```

- [ ] **Step 2: Verify the warning appears when the export is missing**

Run: `fish -c 'xxhc root6 +hc "rm -f \$XXH_HOME/.local/share/atuin/history.db; echo GONE"'`
Expected: the yellow "No history retrieved from root6" warning, and no crash.

- [ ] **Step 3: Run the full test once more**

Run: `terminal/tests/concurrent-sessions.fish root6`
Expected: ALL PASS.

- [ ] **Step 4: Commit**

```bash
git add terminal/.config/fish/functions/xxhc.fish
git commit -m "terminal: report a failed history retrieval instead of dropping it"
```

---

### Task 7: Documentation and version

**Files:**
- Modify: `terminal/terminal.md` (lines 174, 235-239, 305, 318-329, 448-451, 498, 515 areas)
- Modify: `README.md`
- Modify: `terminal/SETUP_VERSION`

- [ ] **Step 1: Correct the concurrency claim**

`terminal.md:174` currently says concurrency is handled because `XXH_STAGE_ID`
namespaces the export file. Replace that paragraph with an accurate account:
each session gets its own remote home `~/.xxh-<sid>`; the binaries, `XDG_*` and
the atuin DB live inside it; the export, the pre-seed and the local scratch
files are all named with the same `$sid`; the ControlMaster is shared and
released by the last session out; a startup sweep removes homes whose owner
process is gone.

- [ ] **Step 2: Update every `~/.xxh` reference that now means the per-session home**

Search: `grep -n '~/\.xxh' terminal/terminal.md README.md`
Every reference to the *remote* home becomes `~/.xxh-<sid>`. References to the
*local* Mac paths (`~/.xxh/history/`, `~/.xxh/scp-wrapper.sh`,
`~/.xxh/ssh-wrapper.sh`, the local build dir symlinks) are unchanged — do not
rewrite those.

- [ ] **Step 3: Document the test**

Add a short "Tests" subsection to `terminal.md` pointing at
`terminal/tests/concurrent-sessions.fish`, saying it is a live test that needs a
reachable host and takes about 90 seconds.

- [ ] **Step 4: Bump the version**

```bash
echo 1.5.0 > terminal/SETUP_VERSION
```

Minor bump, not a patch: the remote layout changes.

- [ ] **Step 5: Verify the greeting shows the new version**

Run: `fish -c 'xxhc root6 +hc "echo \$XXH_SETUP_VERSION"'`
Expected: `1.5.0`

- [ ] **Step 6: Commit**

```bash
git add terminal/terminal.md README.md terminal/SETUP_VERSION
git commit -m "terminal: document per-session remote homes (v1.5.0)"
```

---

## Self-Review

**Spec coverage:** per-session home → Task 2; session-scoped cleanup + sweeper →
Task 3; per-session transfer names (remote pre-seed, local scratch, local
tmp_db) → Tasks 2 and 4; ControlMaster refcount and the `-fN` slave leak → Task
5; silent-failure warning, `busy_timeout`, `0|0|0` → Task 6; testing → Task 1;
docs → Task 7. No spec requirement is unclaimed.

**Naming consistency:** `$sid`, `$remote_home`, `$cm_users` and
`_xxhc_release_master` are used identically in every task that references them.
`$tmp_db` is defined once in Task 2 and used unchanged afterwards.

**Risk:** the `rm -rf` in `_xxhc_cleanup_home` runs on the remote against a
value derived from an env var. Task 3 Step 2 guards `/`, `$HOME`, `$USER_HOME`
and anything not matching the `.xxh` / `.xxh-<pid>-<epoch>` shape. Do not
weaken those guards.
