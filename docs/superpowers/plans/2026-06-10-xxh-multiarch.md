# xxh Multi-Architecture Binary Selection — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `xxhc <host>` detect the remote CPU architecture and upload binaries built for it, so connecting to an aarch64 host (Raspberry Pi 5) works as well as to an x86_64 host.

**Architecture:** Keep two local per-arch binary stores (`~/.xxh/arch/{x86_64,aarch64}/`), each holding a portable fish 4.7.1 plus starship/atuin/bat/fastfetch for that arch. `xxhc` detects `uname -m` over its existing ControlMaster tunnel, then copies the matching store into the xxh build dir before xxh uploads it. The xxh-shell-fish entrypoint is unchanged.

**Tech Stack:** fish shell, bash (`setup.sh`), xxh, GitHub release tarballs. No test framework exists in this repo — verification is by running the real binaries and real connects (the Pi `fastpi` is available for live testing).

**Spec:** `docs/superpowers/specs/2026-06-10-xxh-multiarch-design.md`

---

## File Structure

- **Modify** `terminal/setup.sh` — build two per-arch stores instead of one flat `~/.xxh/bin/`; add a fish downloader; stage x86_64 as the build-dir default.
- **Modify** `terminal/.config/fish/functions/xxhc.fish` — add arch detection + store-staging just after the ControlMaster tunnel, before xxh is called.
- **Modify** `terminal/terminal.md` — document multi-arch (detection, stores, fish 4.x, updated paths/steps).

Binaries themselves are **not** in git (too large); only the scripts that fetch/select them are. `setup.sh` populates the stores locally.

---

## Task 1: Rework `setup.sh` into per-arch stores

**Files:**
- Modify: `terminal/setup.sh` (helpers at lines 83–111; steps 6–7 at lines 79–129)

- [ ] **Step 1: Generalize `download_binary` to take a destination path**

Replace the existing `download_binary` function (lines 83–111) with this dest-based version:

```bash
download_binary() {
    local dest=$1 repo=$2 pattern=$3 binary_in_archive=$4
    if [[ -f "$dest" ]]; then
        skip "$(basename "$dest") [$(basename "$(dirname "$(dirname "$dest")")")]"
        return
    fi
    mkdir -p "$(dirname "$dest")"
    info "Fetching $repo ($pattern)..."
    local url
    url=$(gh_latest_url "$repo" "$pattern")
    [[ -z "$url" ]] && die "Could not find download URL for $repo $pattern"
    local tmp
    tmp=$(mktemp -d)
    curl -fsSL "$url" | tar -xz -C "$tmp"
    if [[ "$binary_in_archive" == "find:"* ]]; then
        # Some archives (e.g. bat) embed the version in the directory name.
        local find_name=${binary_in_archive#find:}
        local found
        found=$(find "$tmp" -name "$find_name" -type f | head -1)
        [[ -z "$found" ]] && die "Could not find $find_name in archive"
        mv "$found" "$dest"
    else
        mv "$tmp/$binary_in_archive" "$dest"
    fi
    chmod +x "$dest"
    rm -rf "$tmp"
    ok "$dest"
}
```

- [ ] **Step 2: Add a `download_fish` helper**

Insert directly after the `download_binary` function:

```bash
# fish 4.x ships a single self-contained binary per arch (functions/completions
# embedded — no share/ tree). dest_dir is <store>/fish-portable/bin.
download_fish() {
    local dest_dir=$1 fish_arch=$2
    if [[ -f "$dest_dir/fish" ]]; then
        skip "fish [$fish_arch]"
    else
        mkdir -p "$dest_dir"
        info "Fetching fish-shell ($fish_arch)..."
        local url
        url=$(gh_latest_url "fish-shell/fish-shell" "linux-$fish_arch.tar.xz")
        [[ -z "$url" ]] && die "Could not find fish download URL for $fish_arch"
        local tmp
        tmp=$(mktemp -d)
        curl -fsSL "$url" | tar -xJf - -C "$tmp"
        mv "$tmp/fish" "$dest_dir/fish"
        chmod +x "$dest_dir/fish"
        rm -rf "$tmp"
        ok "fish [$fish_arch]"
    fi
    # TERMINFO wrapper that the xxh entrypoint launches (fish-portable/bin/fish.sh)
    cat > "$dest_dir/fish.sh" <<'WRAP'
#!/bin/sh
export TERMINFO_DIRS=/lib/terminfo:/etc/terminfo:/usr/share/terminfo:$TERMINFO_DIRS
CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"
$CURRENT_DIR/fish "$@"
WRAP
    chmod +x "$dest_dir/fish.sh"
}
```

- [ ] **Step 3: Replace step 6 (lines 79–116) with the per-arch store builder**

```bash
# ── 6. Per-architecture binary stores (uploaded to remote on connect) ─────────
step "Per-architecture binary stores"

build_arch_store() {
    local arch=$1 triple=$2 ff_label=$3
    local store=~/.xxh/arch/$arch
    info "── $arch ──"
    download_fish   "$store/fish-portable/bin" "$arch"
    download_binary "$store/bin/starship"  "starship-rs/starship"     "$triple.tar.gz"         "starship"
    download_binary "$store/bin/atuin"     "atuinsh/atuin"            "$triple.tar.gz"         "atuin-$triple/atuin"
    download_binary "$store/bin/bat"       "sharkdp/bat"              "$triple.tar.gz"         "find:bat"
    download_binary "$store/bin/fastfetch" "fastfetch-cli/fastfetch"  "linux-$ff_label.tar.gz" "fastfetch-linux-$ff_label/usr/bin/fastfetch"
}

build_arch_store x86_64  "x86_64-unknown-linux-musl"  "amd64"
build_arch_store aarch64 "aarch64-unknown-linux-musl" "aarch64"
```

- [ ] **Step 4: Replace step 7 (lines 118–129) with default-arch staging**

```bash
# ── 7. Stage default (x86_64) binaries in xxh build dir ──────────────────────
# xxhc swaps in the correct arch per connect (see xxhc.fish). This default keeps
# a bare `xxh <host>` (without xxhc) working on x86_64 remotes.
step "Stage default x86_64 binaries for xxh uploads"
build=~/.xxh/.xxh/shells/xxh-shell-fish/build
rm -rf "$build/fish-portable" "$build/bin"
cp -R ~/.xxh/arch/x86_64/fish-portable "$build/fish-portable"
cp -R ~/.xxh/arch/x86_64/bin "$build/bin"
ok "x86_64 store staged into build dir"
```

- [ ] **Step 5: Run setup.sh and verify both stores are populated with correct-arch binaries**

Run:
```bash
bash ~/development/private/Laptop-MacOs/terminal/setup.sh
echo "=== x86_64 store ==="; for f in ~/.xxh/arch/x86_64/fish-portable/bin/fish ~/.xxh/arch/x86_64/bin/*; do file "$f" | cut -d: -f1,2 | cut -d, -f1; done
echo "=== aarch64 store ==="; for f in ~/.xxh/arch/aarch64/fish-portable/bin/fish ~/.xxh/arch/aarch64/bin/*; do file "$f" | cut -d: -f1,2 | cut -d, -f1; done
```
Expected: every x86_64 file reports `x86-64`; every aarch64 file reports `ARM aarch64`. `fish.sh` exists in both `fish-portable/bin/` dirs.

- [ ] **Step 6: Commit**

```bash
git add terminal/setup.sh
git commit -m "setup: build per-arch binary stores (x86_64 + aarch64)

Source fish from official fish-shell releases (single-binary 4.x, both
arches) and the four tools per-arch. Replaces the single flat ~/.xxh/bin
store. Stages x86_64 into the build dir as the default for bare xxh use."
```

---

## Task 2: Add arch detection + staging to `xxhc.fish`

**Files:**
- Modify: `terminal/.config/fish/functions/xxhc.fish` (insert after the ControlMaster tunnel line `ssh ... -fN ... $target`, before the pre-seed block)

- [ ] **Step 1: Insert the detection + staging block**

Immediately after the line:
```fish
    ssh -o ControlMaster=auto -o ControlPath=$cm_path -fN -o ConnectTimeout=30 $target 2>/dev/null
```
add:

```fish
    # ── Detect remote architecture and stage matching binaries ──────────────────
    # The bundle ships native binaries; uploading the wrong arch fails at exec
    # time ("Exec format error"). Detect over the ControlMaster tunnel, then copy
    # the matching store into the xxh build dir before xxh uploads it.
    set -l remote_uname (ssh -o ControlMaster=auto -o ControlPath=$cm_path -o ConnectTimeout=10 $target uname -m 2>/dev/null)
    set -l arch
    switch $remote_uname
        case x86_64 amd64
            set arch x86_64
        case aarch64 arm64
            set arch aarch64
        case '*'
            set_color --bold red
            if test -z "$remote_uname"
                echo "  xxhc: could not detect remote architecture on $target (connection failed?)."
            else
                echo "  xxhc: unsupported remote architecture '$remote_uname' on $target."
                echo "  Supported: x86_64, aarch64."
            end
            echo "  Aborting — no binaries uploaded."
            set_color normal
            ssh -q -o ControlPath=$cm_path -O stop $target 2>/dev/null
            return 1
    end

    set -l store ~/.xxh/arch/$arch
    set -l build ~/.xxh/.xxh/shells/xxh-shell-fish/build
    if not test -d $store/bin; or not test -f $store/fish-portable/bin/fish
        set_color --bold red
        echo "  xxhc: binary store for $arch is missing or incomplete at $store"
        echo "  Run terminal/setup.sh to populate it."
        set_color normal
        ssh -q -o ControlPath=$cm_path -O stop $target 2>/dev/null
        return 1
    end

    # Replace the build dir's binary payload; config symlinks (xxh-config.fish,
    # starship.toml) and entrypoint.sh are left untouched.
    rm -rf $build/fish-portable $build/bin
    cp -R $store/fish-portable $build/fish-portable
    cp -R $store/bin $build/bin
```

- [ ] **Step 2: Syntax-check the function**

Run:
```bash
fish -n ~/development/private/Laptop-MacOs/terminal/.config/fish/functions/xxhc.fish && echo "syntax OK"
```
Expected: `syntax OK` (no parse errors).

- [ ] **Step 3: Verify the abort path on an unsupported arch (mocked)**

Run (simulates detection returning a bogus arch by checking the switch logic in isolation):
```bash
fish -c 'set remote_uname riscv64; switch $remote_uname; case x86_64 amd64; echo x86_64; case aarch64 arm64; echo aarch64; case "*"; echo ABORT; end'
```
Expected: `ABORT`.

- [ ] **Step 4: Commit**

```bash
git add terminal/.config/fish/functions/xxhc.fish
git commit -m "xxhc: detect remote arch and stage matching binaries

Run uname -m over the existing ControlMaster tunnel, map to x86_64/aarch64,
and copy the matching store into the build dir before xxh uploads. Unknown
or undetectable arch aborts cleanly with no upload."
```

---

## Task 3: Update `terminal.md`

**Files:**
- Modify: `terminal/terminal.md` (Architecture section ~L34; "Not in git" ~L184-197; setup steps 6–7 ~L442-483; Updating ~L491-498; add a multi-arch subsection)

- [ ] **Step 1: Update the "Why are binaries plain copies" rationale (around L34-35)**

Replace that Q&A paragraph so it explains the per-arch store + per-connect staging model: binaries live in `~/.xxh/arch/<arch>/`, and `xxhc` copies the arch matching the remote's `uname -m` into the build dir before each connect. Note fish is now the official 4.x single-binary portable build (both arches), replacing `xxh/fish-portable` (x86_64-only).

- [ ] **Step 2: Add a "Multi-architecture support" subsection under "Remote setup via xxh"**

Document: detection via `uname -m` on the ControlMaster tunnel; supported arches (x86_64, aarch64); unsupported → clean abort; the five binaries are all arch-specific while all config is shared; the fish 4.x single-binary change (no `share/`/`etc/`).

- [ ] **Step 3: Update "Not in git" paths (L184-197)**

Replace `~/.xxh/bin/<tool>` and the single `build/bin/*` list with the per-arch store layout:
```
~/.xxh/arch/x86_64/fish-portable/bin/{fish,fish.sh}
~/.xxh/arch/x86_64/bin/{starship,atuin,bat,fastfetch}
~/.xxh/arch/aarch64/fish-portable/bin/{fish,fish.sh}
~/.xxh/arch/aarch64/bin/{starship,atuin,bat,fastfetch}
```
Keep the `~/.xxh/history/<alias>.db` entry.

- [ ] **Step 4: Update manual setup steps 6–7 and the "Updating" section**

Replace the single-arch download/stage commands with the per-arch `build_arch_store` approach (mirror the final `setup.sh`), and update "Updating → Binaries" to note re-running `setup.sh` refreshes both stores. Remove references to `xxh +I` building the x86_64 fish-portable as the source of fish.

- [ ] **Step 5: Commit**

```bash
git add terminal/terminal.md
git commit -m "docs: document multi-arch binary selection in terminal.md"
```

---

## Task 4: End-to-end verification on real hosts

**Files:** none (verification only)

- [ ] **Step 1: Connect to the Pi (aarch64) — the new path**

Run: `xxhc fastpi`
Expected: connects into fish; prompt renders via starship; greeting prints `Connected in Ns` then fastfetch (correct Pi CPU/distro/logo); no "unknown terminal" or universal-variable warnings.

- [ ] **Step 2: Exercise the session, then exit**

Inside the session run a few commands (`ls`, `cd /tmp`, `bat /etc/os-release`), confirm `bat` highlights, then `exit`.
Expected on local side after exit: `History from fastpi merged into local atuin`; **no** red "CLEANUP FAILURE" box.

- [ ] **Step 3: Confirm remote cleanup and history merge**

Run:
```bash
ssh fastpi 'test -d ~/.xxh && echo LEFTOVER || echo clean'
sqlite3 ~/.local/share/atuin/history.db "SELECT count(*) FROM history WHERE hostname LIKE '%fastpi%';"
```
Expected: `clean`; a non-zero count that includes the commands you just ran.

- [ ] **Step 4: Verify fastfetch variant on the Pi**

If Step 1's greeting showed a fastfetch error instead of system info, switch the aarch64 fastfetch asset to the `-polyfilled` variant: in `setup.sh` `build_arch_store aarch64` change the fastfetch pattern to `linux-aarch64-polyfilled.tar.gz` and `binary_in_archive` to `fastfetch-linux-aarch64-polyfilled/usr/bin/fastfetch`, delete `~/.xxh/arch/aarch64/bin/fastfetch`, re-run `setup.sh`, reconnect, and commit the fix. Otherwise mark done.

- [ ] **Step 5: Connect to an x86_64 host — regression check for the fish 4.x bump**

> Requires an x86_64 host alias. If you have one, run `xxhc <that-host>` and repeat Steps 1–3's checks there (prompt, greeting, history merge, clean exit). If no x86_64 host is available, note this as untested and rely on the identical code path plus the local fish-4.x smoke already done.

- [ ] **Step 6: Finalize**

Use the finishing-a-development-branch skill to merge `xxh-multiarch` into `main` (or open a PR), now that both arches are verified.

---

## Self-Review

- **Spec coverage:** Component 1 (per-arch stores) → Task 1. Component 2 (detection + swap in xxhc) → Task 2. Component 3 (setup.sh + docs) → Tasks 1 & 3. Entrypoint unchanged → confirmed (no task needed). Risk/verification (fish 4.x compat on both arches, exit handlers, fastfetch variant) → Task 4. All covered.
- **Placeholders:** none — every code step has full content; the one conditional (fastfetch variant, Task 4 Step 4) has exact fallback commands.
- **Consistency:** store path `~/.xxh/arch/<arch>/{fish-portable/bin,bin}`, build dir `~/.xxh/.xxh/shells/xxh-shell-fish/build`, and arch tokens `x86_64`/`aarch64` are used identically in `setup.sh`, `xxhc.fish`, and `terminal.md`. `download_binary`'s dest-based signature in Task 1 Step 1 matches every call in Step 3.
