# xxh tar-pipe transfer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut connect time on ETH hosts (which set `Compression no` in sshd) from ~4.1 s to ~1.6 s by compressing the upload ourselves via xxh's `++scp-command` hook.

**Architecture:** A drop-in replacement for `scp` that tar-pipes the payload through `zstd` (or `gzip`) and unpacks it remotely, falling back to the real `scp` on anything unexpected.

**Tech Stack:** bash wrapper script, xxh `++scp-command`, GNU/BSD tar, zstd/gzip.

**Testing note:** No unit-test framework here. Verification is live, against `root6`. The fallback path is today's exact behaviour, so a wrapper defect degrades rather than breaks.

---

### Task 1: The wrapper script

**Files:**
- Create: `terminal/.xxh/scp-wrapper.sh`

- [ ] **Step 1: Write the script**

Create `terminal/.xxh/scp-wrapper.sh` with exactly this content:

```bash
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
```

- [ ] **Step 2: Make it executable and check syntax**

```bash
chmod +x terminal/.xxh/scp-wrapper.sh
bash -n terminal/.xxh/scp-wrapper.sh && echo "syntax OK"
```
Expected: `syntax OK`.

- [ ] **Step 3: Verify the fallback path triggers on an unmodelled shape**

```bash
./terminal/.xxh/scp-wrapper.sh -P 2222 /etc/hosts nosuchhost:/tmp/ 2>&1 | head -2
```
Expected: an scp error (e.g. about resolving `nosuchhost`), NOT a bash error — proving `-P` routed to the real scp rather than crashing.

- [ ] **Step 4: Verify a local-only shape falls back**

```bash
./terminal/.xxh/scp-wrapper.sh /etc/hosts /tmp/_wraptest && echo "copied" && rm -f /tmp/_wraptest
```
Expected: `copied` — no colon in the destination, so it must delegate to scp.

- [ ] **Step 5: Real transfer against root6**

```bash
mkdir -p /tmp/_wrapsrc/build && echo hello > /tmp/_wrapsrc/build/marker.txt
chmod +x /tmp/_wrapsrc/build/marker.txt
./terminal/.xxh/scp-wrapper.sh -o ControlMaster=no -o ControlPath=none \
    -r -C /tmp/_wrapsrc/build root6:/tmp/_wraptest/
ssh -o ControlMaster=no -o ControlPath=none root6 \
    'cat /tmp/_wraptest/build/marker.txt; ls -l /tmp/_wraptest/build/marker.txt; rm -rf /tmp/_wraptest'
rm -rf /tmp/_wrapsrc
```
Expected: prints `hello`, and the listing shows the executable bit preserved (`-rwxr-xr-x`).

- [ ] **Step 6: Commit**

```bash
git add terminal/.xxh/scp-wrapper.sh
git commit -m "terminal: add tar-pipe scp wrapper for hosts refusing compression

The ETH fleet sets Compression no in sshd_config.d/90-eth.conf, so SSH
never compresses and the full 71.5 MB crosses the wire. Measured on
root6: 4.14 s raw, 2.06 s gzip, 1.58 s zstd.

This compresses the payload locally and unpacks it remotely via xxh's
++scp-command hook. Any unmodelled argv, a remote without tar, or a
pipeline failure execs the real scp -- the previous behaviour exactly."
```

---

### Task 2: Wire it in

**Files:**
- Modify: `terminal/.config/xxh/config.xxhc`
- Modify: `terminal/setup.sh`

- [ ] **Step 1: Point xxh at the wrapper**

In `terminal/.config/xxh/config.xxhc`, immediately after the `++copy-method: scp` line, add:
```yaml
    ++scp-command: ~/.xxh/scp-wrapper.sh
```

- [ ] **Step 2: Symlink and chmod it in setup.sh**

In `terminal/setup.sh`, after the existing `ssh-wrapper.sh` symlink and chmod lines (around line 72-73), add:
```bash
symlink "$SCRIPT_DIR/.xxh/scp-wrapper.sh"               ~/.xxh/scp-wrapper.sh
chmod +x ~/.xxh/scp-wrapper.sh
```

- [ ] **Step 3: Add zstd to the brew line**

`zstd` is currently only a transitive dependency, so `brew autoremove` could take it. In `terminal/setup.sh` line 43, change:
```bash
brew install fish starship fastfetch atuin bat pipx
```
to:
```bash
brew install fish starship fastfetch atuin bat pipx zstd
```

- [ ] **Step 4: Verify**

```bash
bash -n terminal/setup.sh && echo "setup.sh OK"
python3 -c "import yaml;d=yaml.safe_load(open('terminal/.config/xxh/config.xxhc'));print(d['hosts']['.*']['++scp-command'])"
bash terminal/setup.sh 2>&1 | grep -E "scp-wrapper|zstd|error"
ls -l ~/.xxh/scp-wrapper.sh
```
Expected: `setup.sh OK`; the config prints `~/.xxh/scp-wrapper.sh`; setup.sh reports the symlink; and the symlink exists and is executable.

- [ ] **Step 5: Commit**

```bash
git add terminal/.config/xxh/config.xxhc terminal/setup.sh
git commit -m "terminal: wire the tar-pipe scp wrapper into xxh and setup

Also pins zstd explicitly in the brew line -- it was only a transitive
dependency, so brew autoremove could have taken it out from under the
wrapper."
```

---

### Task 3: Live verification (requires a real remote)

**Files:** none.

- [ ] **Step 1: Time a connect**

```bash
echo exit | fish -l -c 'time xxhc root6'
```
Expected: connects normally, greeting renders with fastfetch output, prompt shows `(root6)`. Wall time ~1.6-2 s, down from ~4 s.

- [ ] **Step 2: Confirm history still round-trips and the remote is wiped**

```bash
ssh -o ControlMaster=no -o ControlPath=none root6 'ls -d ~/.xxh 2>&1'
```
Expected: `No such file or directory`.

- [ ] **Step 3: If anything regressed, revert just the wiring**

```bash
git revert --no-edit <task-2-commit-sha>
```
That single revert disables the wrapper and restores plain scp, leaving the script in the tree.

---

### Task 4: Docs and version bump

**Files:**
- Modify: `terminal/terminal.md`
- Modify: `terminal/SETUP_VERSION`

- [ ] **Step 1: Document the wrapper**

In `terminal/terminal.md`, in the config-flag table, after the `-o Compression=yes` row, add:
```markdown
| `++scp-command: ~/.xxh/scp-wrapper.sh` | Use the tar-pipe wrapper instead of plain scp | The ETH fleet sets `Compression no` in `/etc/ssh/sshd_config.d/90-eth.conf`, so SSH-level compression is refused and the full payload crosses the wire. The wrapper compresses locally and unpacks remotely: measured on root6, 4.14 s → 1.58 s. Falls back to real scp on any unmodelled argv, a remote without `tar`, or any pipeline error |
```

- [ ] **Step 2: Add a Performance subsection**

In `terminal/terminal.md`, at the end of the Performance section, append:
```markdown
**Why two compression mechanisms:** SSH-level `Compression=yes` covers hosts that
allow it (personal machines). The ETH fleet refuses it via a managed sshd drop-in,
so `scp-wrapper.sh` compresses the payload itself. Measured on root6 over office
ethernet — link ~17 MB/s, remote-side disk excluded by piping to `/dev/null`:

| approach | time | on the wire |
|---|---|---|
| raw | 4.14 s | 71.5 MB |
| gzip | 2.06 s | 27.2 MB |
| zstd | 1.58 s | ~24 MB |
```

- [ ] **Step 3: Update the ssh-wrapper file-tree annotation neighbourhood**

In the file tree around line 205, after the `ssh-wrapper.sh` line, add a matching line:
```
    scp-wrapper.sh                        tar-pipes the upload through zstd/gzip; falls back to scp
```

- [ ] **Step 4: Bump the version**

`terminal/SETUP_VERSION`: change `1.2.0` to `1.3.0`. New capability, so minor.

- [ ] **Step 5: Verify**

```bash
fish -l -i -c 'fish_greeting' 2>&1 | tail -2
grep -c "scp-wrapper" terminal/terminal.md
```
Expected: badge reads `v1.3.0`; at least 3 mentions of `scp-wrapper`.

- [ ] **Step 6: Commit**

```bash
git add terminal/terminal.md terminal/SETUP_VERSION
git commit -m "terminal: document the tar-pipe wrapper (v1.3.0)

Records why there are two compression mechanisms -- SSH-level for hosts
that allow it, the wrapper for the ETH fleet that does not -- with the
measured numbers, so the next reader does not remove one as redundant."
```

---

## Self-Review

**Spec coverage:** wrapper (T1), `++scp-command` + symlink + zstd dependency (T2), live verification (T3), docs + version (T4). All spec verification items map to a step.

**Placeholders:** none — the wrapper is given in full, every command has expected output.

**Consistency:** `scp-wrapper.sh` named identically throughout; version goes 1.2.0 → 1.3.0 in T4 only.

**Known gap:** Task 3 needs a live remote and cannot be completed by an agent.
