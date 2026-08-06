# xxh Transfer Size Reduction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut the per-connect xxh upload from 79.4 MB to ~27 MB by enabling SSH compression and switching fastfetch to its stripped upstream build.

**Architecture:** Two independent changes. (1) Turn on zlib compression at the SSH transport layer — critically, on the ControlMaster that `xxhc` pre-creates, since all other calls are slaves that reuse that transport and cannot negotiate their own compression. (2) Point `setup.sh` at fastfetch's `-polyfilled` release asset, which is the same binary stripped of 8.4 MB of DWARF debug info.

**Tech Stack:** fish shell functions, bash setup script, YAML xxh config, OpenSSH ControlMaster multiplexing.

**Note on testing:** This repo has no unit-test framework — it is dotfiles and shell config. "Tests" here are concrete measurement and inspection commands with stated expected output. Each task states what to run and what must come back. The one thing that cannot be verified locally is a live remote connect; that is Task 5 and requires the user.

---

### Task 1: Enable SSH compression on the ControlMaster and fallback paths

The payload is compiled binaries, which gzip to 38%. SSH speaks zlib already, so this needs nothing installed on any remote, and degrades gracefully to no-compression if a server refuses.

**Why three files:** `xxhc.fish:23` creates the ControlMaster. Every other `ssh`/`scp` in `xxhc.fish`, plus xxh's internal SCP, is a *slave* that reuses the master's already-established transport. Compression is negotiated once at transport setup, so a slave-only setting is silently ignored whenever the master exists — which is the normal path. `config.xxhc` covers the fallback where no socket exists. `ssh-wrapper.sh` explicitly opts out of multiplexing, so it needs its own flag.

**Files:**
- Modify: `terminal/.config/fish/functions/xxhc.fish:23`
- Modify: `terminal/.config/xxh/config.xxhc`
- Modify: `terminal/.xxh/ssh-wrapper.sh`

- [ ] **Step 1: Record the current baseline so the change is measurable**

```bash
du -sh ~/.xxh-homes/x86_64/.xxh/shells/xxh-shell-fish/build
```

Expected: `79M` (this is the raw staged payload today).

- [ ] **Step 2: Add compression to the ControlMaster creation**

In `terminal/.config/fish/functions/xxhc.fish`, line 23, change:

```fish
    ssh -o ControlMaster=auto -o ControlPath=$cm_path -fN -o ConnectTimeout=30 $target 2>/dev/null
```

to:

```fish
    ssh -o ControlMaster=auto -o ControlPath=$cm_path -o Compression=yes -fN -o ConnectTimeout=30 $target 2>/dev/null
```

- [ ] **Step 3: Add compression to the xxh config fallback path**

In `terminal/.config/xxh/config.xxhc`, add one entry to the `-o:` list so it reads:

```yaml
    -o:
      - ControlMaster=auto
      - ControlPath=~/.ssh/cm/xxh-%n
      - Compression=yes
      - ServerAliveInterval=15
      - ServerAliveCountMax=3
```

- [ ] **Step 4: Add compression to the rsync wrapper**

Replace the entire contents of `terminal/.xxh/ssh-wrapper.sh` with:

```bash
#!/bin/bash
exec ssh -o ControlMaster=no -o ControlPath=none -o Compression=yes "$@"
```

This path is currently dormant (`++copy-method: scp` means xxh never calls rsync), but the flag belongs here so the setting is not missing if it is ever reached.

- [ ] **Step 5: Verify the config is still valid YAML and the wrapper still executes**

```bash
python3 -c "import yaml,sys; d=yaml.safe_load(open('terminal/.config/xxh/config.xxhc')); print(d['hosts']['.*']['-o'])"
bash -n terminal/.xxh/ssh-wrapper.sh && echo "wrapper syntax OK"
fish -n terminal/.config/fish/functions/xxhc.fish && echo "xxhc syntax OK"
```

Expected: the `-o` list prints including `Compression=yes`, then `wrapper syntax OK`, then `xxhc syntax OK`.

- [ ] **Step 6: Confirm all three files carry the flag**

```bash
grep -rn "Compression=yes" terminal/ | sort
```

Expected: exactly three matches — one each in `xxhc.fish`, `config.xxhc`, `ssh-wrapper.sh`.

- [ ] **Step 7: Commit**

```bash
git add terminal/.config/fish/functions/xxhc.fish terminal/.config/xxh/config.xxhc terminal/.xxh/ssh-wrapper.sh
git commit -m "terminal: enable SSH compression for xxh uploads

The connect payload is compiled binaries, which gzip to 38%. zlib is
already spoken by SSH, so this needs nothing on the remote and falls
back to no compression if a server refuses.

Set on the ControlMaster in xxhc, not just config.xxhc: every other
ssh/scp call is a slave reusing the master's transport, and compression
is negotiated once at transport setup -- so a slave-only setting is
silently ignored on the normal path."
```

Note: `SETUP_VERSION` is intentionally NOT bumped here. Task 4 bumps it once for the whole change.

**Amended during execution:** Steps 2-4 above covered only `xxhc.fish:23`. Review found
that `Host *` in `~/.ssh/config` sets `ControlMaster auto`, so any ssh/scp call can
create the master. The flag was added to all nine remaining transport-creating calls
(lines 36, 75, 89, 106, 112, 113, 114, 142, 149) in a follow-up commit, and the
ControlMaster fallback warning at line 28 was corrected — it claimed reuse stops on
failure, which was never true.

---

### Task 2: Switch fastfetch to the stripped `-polyfilled` build

fastfetch is 11.1 MB, of which 8.4 MB is DWARF debug info — the only bundle binary shipped unstripped in a way that matters. Upstream publishes a stripped build as `-polyfilled` for both architectures.

Verified against the live 2.67.0 release: the polyfilled binary reports `stripped`, is 3.15 MB (amd64) / 2.95 MB (aarch64), and its maximum required symbol version is `GLIBC_2.34` — identical to the asset in use today. Size-only change, no compatibility difference.

**Files:**
- Modify: `terminal/setup.sh:153`

- [ ] **Step 1: Confirm the current line**

```bash
sed -n '153p' terminal/setup.sh
```

Expected:

```
    download_binary "$store/bin/fastfetch" "fastfetch-cli/fastfetch"  "linux-$ff_label.tar.gz" "fastfetch-linux-$ff_label/usr/bin/fastfetch"
```

- [ ] **Step 2: Point it at the polyfilled asset**

In `terminal/setup.sh`, replace that line with:

```bash
    # -polyfilled is the same build with debug info stripped (11.1 MB -> 3.1 MB),
    # same GLIBC_2.34 floor as the plain asset. Keep the suffix or the payload
    # silently grows by 8 MB per connect.
    download_binary "$store/bin/fastfetch" "fastfetch-cli/fastfetch"  "linux-$ff_label-polyfilled.tar.gz" "fastfetch-linux-$ff_label-polyfilled/usr/bin/fastfetch"
```

- [ ] **Step 3: Verify the asset pattern still resolves uniquely for both arches**

The `gh_latest_url` helper greps for the pattern as a substring. Confirm each new pattern matches exactly one asset, and that it is the polyfilled one:

```bash
for label in amd64 aarch64; do
  echo "-- $label"
  curl -fsSL "https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest" \
    | grep browser_download_url | grep "linux-$label-polyfilled.tar.gz" \
    | grep -vE 'sha256|\.sig|\.asc|-update' | cut -d'"' -f4
done
```

Expected: exactly one URL per label, each ending in `fastfetch-linux-<label>-polyfilled.tar.gz`.

- [ ] **Step 4: Verify bash syntax**

```bash
bash -n terminal/setup.sh && echo "setup.sh syntax OK"
```

Expected: `setup.sh syntax OK`.

- [ ] **Step 5: Commit**

```bash
git add terminal/setup.sh
git commit -m "terminal: use fastfetch's stripped -polyfilled build

fastfetch shipped 11.1 MB, of which 8.4 MB was DWARF debug info. The
-polyfilled asset is the same binary stripped: 3.1 MB, and the same
GLIBC_2.34 floor, so nothing about compatibility changes."
```

---

### Task 3: Re-fetch the binaries and verify the payload shrank

**Files:** none modified — this re-runs the existing installer.

- [ ] **Step 1: Remove only the fastfetch binaries so setup.sh re-fetches them**

`download_binary` skips when the destination exists, so the old copies must go. Remove *only* fastfetch — the other four are already current and re-downloading them wastes time.

```bash
rm -f ~/.xxh/arch/x86_64/bin/fastfetch ~/.xxh/arch/aarch64/bin/fastfetch
```

- [ ] **Step 2: Re-run the installer**

```bash
bash terminal/setup.sh 2>&1 | tail -25
```

Expected: `Fetching fastfetch-cli/fastfetch (linux-amd64-polyfilled.tar.gz)...` and the aarch64 equivalent, both followed by a `✓`, then the staging steps, then `All done.`

- [ ] **Step 3: Verify the new binaries are stripped, correct arch, and ~3 MB**

```bash
for a in x86_64:x86-64 aarch64:aarch64; do
  arch=${a%%:*}; want=${a##*:}
  f=~/.xxh/arch/$arch/bin/fastfetch
  printf "%-8s %5.1f MB  %s  %s\n" "$arch" "$(echo "scale=2;$(stat -f%z $f)/1048576"|bc)" \
    "$(file -b $f | grep -oE '(not )?stripped')" \
    "$(file -b $f | grep -oq "$want" && echo arch-ok || echo ARCH-WRONG)"
done
```

Expected: both ~3.1 MB / ~3.0 MB, both `stripped`, both `arch-ok`.

- [ ] **Step 4: Verify the staged copies match the store**

`xxhc` uploads from the per-arch homes, not the store, so a stale staging dir would silently keep shipping the old binary.

```bash
for a in x86_64 aarch64; do
  diff -q ~/.xxh/arch/$a/bin/fastfetch \
    ~/.xxh-homes/$a/.xxh/shells/xxh-shell-fish/build/bin/fastfetch && echo "$a staged OK"
done
diff -q ~/.xxh/arch/x86_64/bin/fastfetch ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/fastfetch \
  && echo "default build dir staged OK"
```

Expected: three lines, all `... staged OK`, no `differ` output.

- [ ] **Step 5: Measure the new raw payload**

```bash
du -sh ~/.xxh-homes/x86_64/.xxh/shells/xxh-shell-fish/build
```

Expected: ~`71M`, down from the `79M` baseline recorded in Task 1 Step 1.

- [ ] **Step 6: Measure what will actually go over the wire**

```bash
cd ~/.xxh/arch/x86_64
cat fish-portable/bin/fish bin/atuin bin/starship bin/fastfetch bin/bat \
  | gzip -6 -c | wc -c | awk '{printf "on-wire: %.1f MB\n", $1/1048576}'
cd -
```

Expected: `on-wire: 27.2 MB` (±0.3 MB), versus 79.4 MB today — a 2.9x reduction.

- [ ] **Step 7: No commit**

This task changes no tracked files; the binaries live outside the repo. Proceed to Task 4.

---

### Task 4: Update documentation and bump the version

`terminal.md` states the payload size in three separate places, all now wrong. The config-flag table needs the new option documented, and the fastfetch asset choice needs a note or a future reader will "fix" the odd-looking `-polyfilled` suffix back and silently re-add 8 MB per connect.

**Files:**
- Modify: `terminal/terminal.md` (lines 29, 106-117, 322, 324, and the config-flag table)
- Modify: `terminal/SETUP_VERSION`

- [ ] **Step 1: Update the wipe-on-disconnect cost figure (line 29)**

Change:

```
The remotes are shared admin accounts used by multiple people. Nothing should be left behind — no history, no binaries, no config. The cost is re-uploading ~73 MB on every connect.
```

to:

```
The remotes are shared admin accounts used by multiple people. Nothing should be left behind — no history, no binaries, no config. The cost is re-uploading the bundle on every connect — ~71 MB on disk, ~27 MB on the wire with SSH compression enabled.
```

- [ ] **Step 2: Add a fastfetch source note after the fish source note (line 106)**

Insert this paragraph immediately after the `**fish source:**` paragraph:

```markdown
**fastfetch source:** fastfetch is the official `linux-<arch>-polyfilled` release asset, **not** the plain `linux-<arch>` one. The two are the same build with the same `GLIBC_2.34` floor; the polyfilled variant is simply stripped of DWARF debug info, which takes it from 11.1 MB to 3.1 MB. Dropping the `-polyfilled` suffix silently re-adds ~8 MB to every connect.
```

- [ ] **Step 3: Update the upload table (lines 108-117)**

Change the heading `### What gets uploaded on connect (~79 MB every time)` to:

```markdown
### What gets uploaded on connect (~71 MB on disk, ~27 MB on the wire)
```

and change the `fastfetch` row from `| `fastfetch` | ~11 MB | System info greeting |` to:

```markdown
| `fastfetch` | ~3 MB | System info greeting (stripped `-polyfilled` build) |
```

Then add this sentence immediately after the table:

```markdown
SSH compression (`-o Compression=yes`) is enabled on the connection, so the ~71 MB on disk goes over the wire as roughly 27 MB — binaries compress to about 38% with zlib.
```

- [ ] **Step 4: Add the Compression row to the config-flag table**

Immediately after the `-o ControlPath=~/.ssh/cm/xxh-%n` row, insert:

```markdown
| `-o Compression=yes` | zlib-compress the transfer | Binaries compress to ~38%, taking the upload from ~71 MB to ~27 MB. Must also be set on the ControlMaster that `xxhc` creates — slaves reuse the master's transport and cannot negotiate their own compression, so setting it only here is silently ignored on the normal path |
```

- [ ] **Step 5: Update the performance breakdown (lines 322, 324)**

Change:

```
Breakdown: fish 15 MB + atuin 35 MB + starship 12 MB + fastfetch 11 MB + bat 7 MB = ~79 MB uploaded over SCP on every connect.
```

to:

```
Breakdown: fish 15 MB + atuin 35 MB + starship 12 MB + fastfetch 3 MB + bat 7 MB = ~71 MB on disk, which SSH compression takes to ~27 MB over the wire on every connect.
```

- [ ] **Step 6: Update the three remaining `~73 MB` figures elsewhere in the file**

These predate this work (they were already stale before it) but the Step 7 grep will fail until they are fixed. Make these exact replacements:

Line ~102, in the "Why a home per arch" paragraph — change:

```
and also drops the ~73 MB per-connect copy, so connects are a touch faster.
```

to:

```
and also drops the ~71 MB per-connect copy, so connects are a touch faster.
```

Line ~279, in the ControlMaster pre-setup bullet — change:

```
All subsequent SSH/SCP calls — including xxh's ~73 MB bundle upload — reuse this socket.
```

to:

```
All subsequent SSH/SCP calls — including xxh's bundle upload (~71 MB on disk, ~27 MB compressed on the wire) — reuse this socket.
```

Line ~462, in the usage example — change:

```
Uploads ~73 MB, drops into fish. On exit, merges remote history into local atuin.
```

to:

```
Uploads ~27 MB (compressed), drops into fish. On exit, merges remote history into local atuin.
```

- [ ] **Step 7: Verify no stale figures remain**

```bash
grep -n "73 MB\|79 MB\|~11 MB" terminal/terminal.md
```

Expected: no output. Any match is a figure that was missed.

- [ ] **Step 8: Bump SETUP_VERSION**

This changes connect behaviour, not just docs, so it is a minor bump. Change `terminal/SETUP_VERSION` from `1.1.2` to:

```
1.2.0
```

- [ ] **Step 9: Verify the greeting shows the new version**

```bash
fish -l -i -c 'fish_greeting' 2>&1 | tail -2
```

Expected: the badge reads `Tomigorn's macOS Terminal Setup — v1.2.0`.

- [ ] **Step 10: Commit**

```bash
git add terminal/terminal.md terminal/SETUP_VERSION
git commit -m "terminal: document compression + polyfilled fastfetch (v1.2.0)

Payload figures appeared in three places and were all stale. Also
records why the fastfetch asset carries the -polyfilled suffix, since
it looks like a mistake and reverting it silently costs 8 MB a connect."
```

---

### Task 5: Live connect verification (requires the user)

Everything above is verifiable locally except the thing that actually matters: that a real connect still works and is faster. This task cannot be completed by an agent — it needs a live remote host.

- [ ] **Step 1: Time a connect to a personal host**

```bash
time xxhc beefy
```

Expected: session starts normally; the greeting renders with fastfetch output present; the prompt shows `(beefy)`. Wall time should be noticeably lower than before on a slow link, and roughly unchanged on a fast one (where the link was never the bottleneck).

- [ ] **Step 2: Confirm history still round-trips**

Run a distinctive command in the remote session, then exit:

```bash
echo xxh-compression-canary
exit
```

Expected on disconnect: `History from beefy merged into local atuin`.

- [ ] **Step 3: Confirm the canary landed locally**

```bash
sqlite3 ~/.local/share/atuin/history.db \
  "select command, hostname from history where command like '%compression-canary%';"
```

Expected: one row, with the remote hostname.

- [ ] **Step 4: Confirm the remote was still wiped**

```bash
ssh beefy 'ls -d ~/.xxh 2>&1'
```

Expected: `No such file or directory`. The whole point of the design is that this stays true.

- [ ] **Step 5: If anything regressed, revert compression first**

Compression is the only change that touches the connection itself. To isolate:

```bash
git revert --no-edit <task-1-commit-sha>
```

The fastfetch change is inert by comparison — it only swaps which file is uploaded.

---

## Self-Review

**Spec coverage:**
- SSH compression, all three locations → Task 1 ✓
- fastfetch `-polyfilled` swap, pattern + archive path → Task 2 ✓
- Spec verification items 1-3 (re-fetch, stripped/arch check, staging match) → Task 3 ✓
- Spec verification item 5 (payload size) → Task 3 Steps 5-6 ✓
- Spec verification item 4 (live connect) → Task 5 ✓
- Spec documentation section (three figures, config table, fastfetch note) → Task 4 ✓
- Spec version bump → Task 4 Step 8 ✓

**Placeholder scan:** No TBDs. Every step has the literal text or command to run and its expected output.

**Consistency:** `ff_label` values (`amd64`, `aarch64`) match `build_arch_store`'s existing call sites. Version goes `1.1.2 → 1.2.0` consistently in Task 4 Steps 8-10. The 27.2 MB figure is used consistently and is measured, not estimated.

**Known gap:** Task 5 cannot be executed by an agent. It is called out as user-run rather than silently skipped.
