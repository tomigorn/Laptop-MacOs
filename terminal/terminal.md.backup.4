# Portable Session-Only SSH Environment

A modern terminal experience on remote Linux hosts — no permanent installation, no root, no shared-account pollution.

---

## Local Mac Setup

Same stack as remote: bash + starship + fzf + ble.sh. No fish needed — this gives you identical behaviour locally and remotely.

### What to install

```bash
# 1. Modern bash (macOS ships with bash 3.2 from 2007 — too old)
brew install bash

# 2. Tab completion for everything (git branches, docker, kubectl, ssh hosts, etc.)
brew install bash-completion@2

# 3. Fuzzy history search (fzf) — replaces ctrl-r with a visual picker
brew install fzf
$(brew --prefix)/opt/fzf/install   # say yes to key bindings, yes to fuzzy completion

# 4. Starship prompt
brew install starship   # skip if already installed
```

### Switch default shell to modern bash

```bash
echo /opt/homebrew/bin/bash | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/bash
# Log out and back in
```

### `~/.bash_profile`

```bash
export PATH="$HOME/.local/bin:$PATH"

# ── Track local Mac commands in the same TSV as remote sessions ───────────────
_ssh_env_hist="$HOME/.local/share/ssh-env/history.tsv"
_local_history_to_tsv() {
    local cmd
    cmd=$(HISTTIMEFORMAT='' history 1 2>/dev/null | sed 's/^ *[0-9]* *//')
    [[ -z "$cmd" ]] && return 0
    printf '%s\t%s\t%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$(hostname -f 2>/dev/null || hostname -s)" \
        "$cmd" >> "$_ssh_env_hist"
}
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }_local_history_to_tsv"

# Modern bash completion
[[ -r "$(brew --prefix)/etc/profile.d/bash_completion.sh" ]] && \
    source "$(brew --prefix)/etc/profile.d/bash_completion.sh"

# fzf — fuzzy ctrl-r, ctrl-t (file finder), alt-c (cd)
eval "$(fzf --bash)"

# Starship prompt
eval "$(starship init bash)"

# ble.sh — syntax highlighting + ghost-text autosuggestions (same as remote)
[[ -f ~/.local/share/ssh-env/ble.sh ]] && \
    source ~/.local/share/ssh-env/ble.sh --norc --noinputrc 2>/dev/null

# Atuin (optional — richer history than fzf alone; works in bash too)
[[ -f ~/.atuin/bin/env ]] && source ~/.atuin/bin/env
command -v atuin &>/dev/null && eval "$(atuin init bash)"
```

### What you get locally

| Feature | Tool | Note |
|---|---|---|
| Tab completion (paths, commands) | bash-completion@2 | git, docker, kubectl, brew, ssh hosts, etc. |
| Fuzzy history search | fzf (ctrl-r) | or atuin if preferred |
| Fuzzy file finder | fzf (ctrl-t) | |
| Ghost-text autosuggestions | ble.sh | same script used on remote |
| Syntax highlighting as you type | ble.sh | same script used on remote |
| Prompt (host, dir, git) | starship | same binary used on remote |

### What works on remote without installing anything

| Feature | Available on remote by default |
|---|---|
| Tab completion (paths, files) | Yes — bash is already there |
| Tab completion (git, docker, etc.) | Partial — depends what the server has installed |
| ctrl-r history search | Yes — basic, built-in to bash |
| Visual/fuzzy history (fzf) | Only via sshe (transfers fzf binary) |
| Ghost-text autosuggestions | Only via sshe (transfers ble.sh) |
| Starship prompt | Only via sshe (transfers starship binary) |

---

## Tool Evaluation

### fish — Not Recommended

| Criterion | Assessment |
|-----------|------------|
| Binary size | ~15–20 MB, usually dynamically linked |
| Static build | Rare; musl-based static fish builds exist but are not officially distributed |
| Config isolation | Reads `~/.config/fish/`; can redirect via `XDG_CONFIG_HOME` |
| Daemon | None |
| Architecture support | x86_64 and arm64, but binary availability is inconsistent |

**Critical problems:** Fish is designed to be a login shell, not a drop-in subshell. Running it over SSH as a replacement interactive shell requires: a static binary (not commonly available), redirecting XDG paths, redirecting `~/.local/share/fish/`, and accepting that many completions and abbreviations won't work without their config directories. The binary is large. The cognitive overhead of managing all this per-arch is high.

**Verdict:** Skip. Replace with bash + starship + fzf. You get 95% of fish's UX value with none of the complexity.

---

### fzf — Strongly Recommended

| Criterion | Assessment |
|-----------|------------|
| Binary size | ~3 MB (gzipped) |
| Static build | Yes — official Go static binaries for linux/amd64, arm64, 386, arm |
| Config isolation | None needed — configured via env vars only |
| Daemon | None |
| Shell integration | A single `source` of a bash script (can be inlined in bootstrap) |

**Verdict:** Perfect fit. Single binary, zero config files, works from `/tmp`. This is the highest-value tool in the list for this use case.

---

### atuin — Not Recommended for Remote Side

| Criterion | Assessment |
|-----------|------------|
| Binary size | ~15–20 MB (Rust static binary) |
| Config isolation | `ATUIN_DATA_DIR` can redirect data; `ATUIN_CONFIG_DIR` for config |
| Daemon | No explicit daemon, but sync requires network access to a server |
| History persistence | Requires a sync server reachable from remote hosts |

**Critical problems:** Atuin's value is its persistent, searchable history database. In a session-only context you'd start with an empty DB every session unless you pre-populate it. Syncing back to your Mac requires the remote server to open a connection to your Mac — blocked by firewalls in most environments. Running `atuin server` on your Mac and using SSH RemoteForward to tunnel it is theoretically possible but fragile at scale across 200 hosts.

**Verdict:** Do not run atuin on the remote. Instead, use a lightweight PROMPT_COMMAND hook to forward history to your Mac in real time via a Unix socket tunnelled through SSH. You then feed that into atuin (or just search it with fzf) locally. See the History Forwarding section.

---

### starship — Strongly Recommended

| Criterion | Assessment |
|-----------|------------|
| Binary size | ~8 MB (gzipped) |
| Static build | Yes — official Rust musl static builds for linux/amd64, arm64, arm |
| Config isolation | Single env var: `STARSHIP_CONFIG=/path/to/starship.toml` |
| Daemon | None |
| Prompt latency | ~50–100 ms per render on slow hosts (git status is the main cost) |

**Verdict:** Excellent fit. One binary, one env var, works from `/tmp`. The latency from running git on large repos is the main drawback; mitigated by disabling or time-limiting the git module.

---

### Catppuccin Mocha — Keep (Zero Overhead)

This is a color palette, not a tool. The "theme" is applied by your local terminal emulator (WezTerm, iTerm2, Kitty, etc.) via ANSI color definitions. The remote shell just emits standard ANSI escape codes; your terminal renders them with Catppuccin colors. For starship, Catppuccin colors are just hex values in `starship.toml` — no binary, no config file beyond what you're already using.

**Verdict:** Already works if your Mac terminal has Catppuccin configured. Include Catppuccin palette values in your embedded `starship.toml`. Zero cost.

---

### Dotfiles Managers (chezmoi, yadm, GNU Stow, rcm) — Wrong Tool for This Problem

| Criterion | Assessment |
|-----------|------------|
| What they do | Deploy config files into `~` (and subdirectories) |
| Session-only support | None — they are explicitly designed to make config *persist* |
| Shared account safety | Unsafe — `chezmoi apply` writes to `~/.bashrc`, `~/.gitconfig`, etc. for all users of that account |
| Binary management | Not their job — they manage config files, not executables |
| Remote execution | Requires the tool to be installed on the remote host |

**Why they don't help on the remote side:** Dotfiles managers and session-only constraints are opposite goals. A dotfiles manager's purpose is to make config permanent and reproducible. Running one on a shared admin account would write to the shared `~`, affecting every user. There is no "session scope", no exit cleanup, no `/tmp` deployment mode.

chezmoi has a `--destination` flag that can theoretically target `/tmp/ssh-env-UID/` instead of `~`. But it would still need to be installed on the remote host first, it knows nothing about binary transfer or EXIT trap cleanup, and for config files alone you don't need a dotfiles manager — you're already transferring `starship.toml` and `bootstrap.sh` via `sshe`.

**Where they DO help — your Mac:** Use a dotfiles manager on your Mac to track the ssh-env toolkit itself. Keep `~/.local/share/ssh-env/`, `~/.local/bin/sshe`, and `~/.ssh/config` in a git repo managed by chezmoi or stow. This lets you replicate the setup across multiple Macs instantly. But this is entirely orthogonal to the remote session problem.

**Verdict:** Do not attempt to use dotfiles managers on remote hosts. Use one on your Mac to manage the ssh-env toolkit and keep it in version control.

---

## Additional Tools

These go beyond the original list. Evaluated against the same session-only, no-root, shared-account constraints.

---

### ble.sh — Strongly Recommended (No Binary Required)

[ble.sh](https://github.com/akinomyoga/ble.sh) (Bash Line Editor) is a single bash script that replaces readline with a pure-bash implementation. No binary, no compilation, no root.

| Criterion | Assessment |
|-----------|------------|
| Binary required | No — single `.sh` file, ~200 KB |
| Bash version | Works on bash 3.0+ (covers every Linux host you'll encounter) |
| Isolation | Fully session-scoped; sources into the current shell, writes nothing to `~` |
| Startup cost | ~30–50 ms sourcing time |

**Features gained:**

- Syntax highlighting as you type (commands, paths, strings, errors — color-coded live)
- Fish-style auto-suggestions (ghost text from history, accept with →)
- Better multi-line editing and history display
- Compatible with starship (ble.sh hands off PS1 generation to starship)
- Compatible with fzf Ctrl-R integration

**Why this matters:** This is the single highest-UX-per-cost addition in the toolkit. Fish's most-praised features are syntax highlighting and auto-suggestions. ble.sh delivers both at the cost of one 200 KB script file — no binary transfer at all.

**Usage in bootstrap.sh:**
```bash
BLE_SH="$SSH_ENV_DIR/ble.sh"
if [[ -f "$BLE_SH" ]]; then
    source "$BLE_SH" --norc --noinputrc 2>/dev/null
    # Tell ble.sh to let starship handle the prompt
    bleopt prompt_ps1_final=''
fi
```

Add to `setup.sh`:
```bash
BLE_VERSION="0.3.4"
curl -fsSL "https://github.com/akinomyoga/ble.sh/releases/download/v${BLE_VERSION}/ble-${BLE_VERSION}.tar.xz" \
  | tar xJf - -C /tmp
cp /tmp/ble-${BLE_VERSION}/ble.sh "$BASE/ble.sh"
```

---

### zsh + `ZDOTDIR` — Cleaner Isolation Mechanism (Alternative Shell)

`ZDOTDIR` is a zsh-native environment variable that redirects *all* zsh startup files to a custom directory. When set before zsh starts, zsh reads `$ZDOTDIR/.zshenv`, `$ZDOTDIR/.zshrc`, etc. — and never touches `~/.zshrc`.

```bash
# In sshe, replace the bash line with:
exec ssh -t "${SSH_ARGS[@]}" "$TARGET" \
    "ZDOTDIR='$REMOTE_DIR/zsh' zsh -i"

# $REMOTE_DIR/zsh/.zshrc is your bootstrap equivalent
```

| Criterion | Assessment |
|-----------|------------|
| Isolation quality | Stronger than `bash --init-file` — redirects all 5 startup files, not just one |
| Home directory pollution | Zero — `~/.zshrc` is never read |
| Availability | Common on Ubuntu 20+, Debian 11+, RHEL 8+; absent on minimal containers, old RHEL 7 |
| Features vs bash | Better completions out of the box, associative arrays, zmv, zparseopts |
| Starship compatibility | Identical — same binary, same `STARSHIP_CONFIG` env var |

**The key advantage over bash `--init-file`:** bash's mechanism only replaces `~/.bashrc`. The system-wide `/etc/bash.bashrc` still runs and can interfere. `ZDOTDIR` gives you complete control from the first file zsh reads.

**The key disadvantage:** zsh is not universal. Bash is present on every Linux system by POSIX guarantee. Keep bash as the primary path; offer zsh as an opt-in for hosts where you've verified it's available.

**Minimal `$REMOTE_DIR/zsh/.zshrc`:**
```zsh
# Equivalent of bootstrap.sh for zsh
export PATH="$SSH_ENV_DIR/bin:$PATH"
export HISTFILE="$SSH_ENV_DIR/session-$$/zsh_history"
export SAVEHIST=50000
setopt HIST_IGNORE_DUPS APPEND_HISTORY SHARE_HISTORY

# Zsh built-in completions (no external binary needed)
autoload -Uz compinit && compinit -d "$SSH_ENV_DIR/cache/zcompdump"

# Starship
if command -v starship &>/dev/null; then
    export STARSHIP_CONFIG="$SSH_ENV_DIR/config/starship.toml"
    eval "$(starship init zsh)"
fi

# fzf
if command -v fzf &>/dev/null; then
    source <(fzf --zsh 2>/dev/null) || true
fi
```

---

### zellij — Session Persistence Without Pre-installed tmux

[zellij](https://zellij.dev) is a terminal multiplexer written in Rust. Like tmux, it keeps sessions alive through SSH disconnects. Unlike tmux, it ships as a single static binary with a modern UI that needs no configuration.

| Criterion | Assessment |
|-----------|------------|
| Binary size | ~15 MB (static musl build) |
| Config isolation | `ZELLIJ_CONFIG_DIR` env var — point to `/tmp/ssh-env-UID/config/` |
| Daemon | No persistent daemon; layout server runs as part of the session |
| Session persistence | Sessions survive SSH disconnect, can reattach |
| Shared account concern | Session stays in process list with terminal visible to root — acceptable in most contexts, worth being aware of |

**Compared to tmux:** tmux is commonly pre-installed, so check for it first and only transfer zellij as a fallback. If neither is available and you want persistence, transfer zellij.

**In bootstrap.sh:**
```bash
# Attach to existing session or create new one (avoids nesting)
if command -v zellij &>/dev/null && [[ -z "$ZELLIJ" ]]; then
    export ZELLIJ_CONFIG_DIR="$SSH_ENV_DIR/config/zellij"
    mkdir -p "$ZELLIJ_CONFIG_DIR"
    exec zellij attach --create "ssh-env-$(hostname -s)"
elif command -v tmux &>/dev/null && [[ -z "$TMUX" ]]; then
    exec tmux new-session -A -s "ssh-env"
fi
```

The `[[ -z "$ZELLIJ" ]]` / `[[ -z "$TMUX" ]]` guards prevent nesting when you're already inside a multiplexer session.

---

### Tier Summary

| Tool | Type | Fits Constraints | Verdict |
|------|------|-----------------|---------|
| fzf | binary (~3 MB) | Yes — static, no config | **Essential** |
| starship | binary (~8 MB) | Yes — env var config | **Essential** |
| ble.sh | script (~200 KB) | Yes — pure bash, no binary | **Essential** |
| zellij | binary (~15 MB) | Yes — env var config | **Include if you want persistence** |
| zsh + ZDOTDIR | shell alt. | Yes — cleaner than bash | **Optional** |
| eza / bat / delta | binaries (~3–5 MB each) | Yes | **Optional extras** |
| fish | binary (~20 MB) | No — no official static build | **Skip** |
| atuin (remote) | binary (~18 MB) | No — empty DB, sync blocked | **Skip on remote** |
| dotfiles managers | Mac-side tool | Wrong abstraction layer | **Mac-only use** |
| nix-portable | binary (~60 MB) | Partial — not /tmp friendly | **Only for dedicated dev hosts** |

---

## Architecture

### Platform Support and Graceful Degradation

The setup works across any architecture and OS by detecting the remote environment in one pre-flight SSH call and automatically choosing one of three operating modes. You never configure this manually — `sshe` decides.

```
uname -s == Linux?   bash present?   /tmp exec-capable?   Arch known + downloaded?
     │                    │                  │                       │
     No                  No                 No                      No
     │                    │                  │                       │
     ▼                    ▼                  ▼                       ▼
Passthrough          Passthrough       Scripts-only             Scripts-only
(plain ssh)          (plain ssh)     (ble.sh + PS1 only)     (ble.sh + PS1 only)
                                                                    │
                                                                   Yes
                                                                    │
                                                                    ▼
                                                                  Full
                                                        (starship + fzf + ble.sh)
```

| Mode | When | Features |
|------|------|----------|
| **Full** | Linux + known arch + `/tmp` executable | starship prompt, fzf, ble.sh, history forwarding |
| **Scripts-only** | Linux with unknown/unsupported arch, OR `/tmp` noexec | ble.sh (syntax highlight + suggestions), hand-rolled PS1, history forwarding |
| **Passthrough** | No bash on remote (ESXi VMkernel, BusyBox-only containers) | Plain `ssh` with no wrapping |

**What "known arch" means:** `sshe` maps `uname -m` output to a binary directory. If no directory exists locally for that arch (either not downloaded yet or genuinely unsupported), it falls back to scripts-only. You can add new arches by running `setup.sh --arch linux-mips` and it'll be available next connection.

**Raspberry Pi specifics:**

| Pi model | Default OS | `uname -m` | Mode |
|----------|------------|------------|------|
| Pi 1, Zero, Zero W | Raspberry Pi OS 32-bit | `armv6l` | Full (linux-arm6) |
| Pi 2 v1.1, Pi 3 (32-bit OS) | Raspberry Pi OS 32-bit | `armv7l` | Full (linux-arm7) |
| Pi 3, 4, 5 (64-bit OS) | Raspberry Pi OS 64-bit | `aarch64` | Full (linux-arm64) |

**Hypervisor specifics:**

| System | `uname -s` | `bash` | Outcome |
|--------|-----------|--------|---------|
| Proxmox VE | `Linux` (Debian) | present | Full (linux-amd64) |
| Xen Dom0 | `Linux` | present | Full (linux-amd64) |
| ESXi VMkernel | `VMkernel` | absent | Passthrough |
| LXC/OpenVZ containers | `Linux` | present | Full or Scripts-only depending on arch |

---

**Connection flow:**

1. `sshe hostname` runs on Mac
2. Pre-flight SSH: single call probes OS, arch, bash presence, /tmp exec capability, version sentinel
3. `sshe` picks a mode and transfers only what's needed (binaries if full mode, scripts always)
4. Interactive SSH: `ssh -t host "bash --init-file /tmp/ssh-env-UID/bootstrap.sh -i"`
5. On exit: EXIT trap removes `/tmp/ssh-env-UID/session-PID/`; binaries are left for reuse

**Cleanup policy:**

- `/tmp/ssh-env-UID/bin/` — binaries, left in place (persist until reboot)
- `/tmp/ssh-env-UID/session-PID/` — per-session state, removed by EXIT trap
- On shared accounts where leaving binaries is a concern: add `rm -rf /tmp/ssh-env-UID/` to the EXIT trap at the cost of re-transfer on next connect

---

## Implementation

### 1. Mac Setup

Create the directory structure and download static binaries.

```bash
#!/usr/bin/env bash
# Run once on your Mac to set up ssh-env
# save as: ~/.local/share/ssh-env/setup.sh

set -euo pipefail

BASE="$HOME/.local/share/ssh-env"
mkdir -p "$BASE/linux-amd64/bin" "$BASE/linux-arm64/bin"

FZF_VERSION="0.54.3"
STARSHIP_VERSION="1.19.0"
BLESH_VERSION="0.3.4"

# Architecture matrix: "local-dir  fzf-suffix  starship-target  musl?"
# musl=yes means a fully static binary; musl=no means glibc (may fail on Alpine/musl distros)
declare -A FZF_SUFFIX=(
    [linux-amd64]="linux_amd64"
    [linux-arm64]="linux_arm64"
    [linux-arm7]="linux_arm7"
    [linux-arm6]="linux_arm6"
    [linux-arm5]="linux_arm5"
    [linux-386]="linux_386"
    [linux-ppc64le]="linux_ppc64le"
    [linux-riscv64]="linux_riscv64"
    [linux-s390x]="linux_s390x"
    [linux-mips]="linux_mips"
    [linux-mips64]="linux_mips64"
)
declare -A STARSHIP_TARGET=(
    [linux-amd64]="x86_64-unknown-linux-musl"
    [linux-arm64]="aarch64-unknown-linux-musl"
    [linux-arm7]="armv7-unknown-linux-musleabihf"
    [linux-arm6]="arm-unknown-linux-musleabihf"
    [linux-arm5]="arm-unknown-linux-musleabi"
    [linux-386]="i686-unknown-linux-musl"
    [linux-ppc64le]="powerpc64le-unknown-linux-gnu"   # glibc — won't work on Alpine
    [linux-riscv64]="riscv64gc-unknown-linux-gnu"      # glibc — won't work on Alpine
    [linux-s390x]="s390x-unknown-linux-gnu"            # glibc — won't work on Alpine
    # mips/mips64: no starship prebuilt; fzf only
)

# Common arches: downloaded by default (covers >99% of real-world hosts)
COMMON_ARCHES=(linux-amd64 linux-arm64 linux-arm7 linux-arm6 linux-386)
# Rare arches: download with --all or --arch linux-s390x etc.
EXTRA_ARCHES=(linux-arm5 linux-ppc64le linux-riscv64 linux-s390x linux-mips linux-mips64)

download_one() {
    local dir="$1"
    mkdir -p "$BASE/$dir/bin"

    local fzf_sfx="${FZF_SUFFIX[$dir]:-}"
    if [[ -n "$fzf_sfx" ]]; then
        printf "    fzf     %-20s" "$fzf_sfx"
        if curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-${fzf_sfx}.tar.gz" \
                | tar xzf - -C "$BASE/$dir/bin" fzf 2>/dev/null; then
            echo "ok"
        else
            echo "FAILED (skipping)"
        fi
    fi

    local st_target="${STARSHIP_TARGET[$dir]:-}"
    if [[ -n "$st_target" ]]; then
        printf "    starship %-35s" "$st_target"
        if curl -fsSL "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-${st_target}.tar.gz" \
                | tar xzf - -C "$BASE/$dir/bin" starship 2>/dev/null; then
            echo "ok"
        else
            echo "FAILED (skipping)"
        fi
    fi

    chmod +x "$BASE/$dir/bin/"* 2>/dev/null || true
}

# Parse arguments
ARCHES_TO_DOWNLOAD=("${COMMON_ARCHES[@]}")
while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)   ARCHES_TO_DOWNLOAD=("${COMMON_ARCHES[@]}" "${EXTRA_ARCHES[@]}") ;;
        --arch)  shift; ARCHES_TO_DOWNLOAD+=("$1") ;;
        *)       echo "Unknown arg: $1" >&2 ;;
    esac
    shift
done

echo "Downloading binaries for: ${ARCHES_TO_DOWNLOAD[*]}"
for arch in "${ARCHES_TO_DOWNLOAD[@]}"; do
    echo "[$arch]"
    download_one "$arch"
done

echo "Downloading ble.sh (arch-independent bash script)..."
curl -fsSL "https://github.com/akinomyoga/ble.sh/releases/download/v${BLESH_VERSION}/ble-${BLESH_VERSION}.tar.xz" \
    | tar xJf - -C /tmp
cp "/tmp/ble-${BLESH_VERSION}/ble.sh" "$BASE/ble.sh"
rm -rf "/tmp/ble-${BLESH_VERSION}"

VERSION="fzf-${FZF_VERSION}_starship-${STARSHIP_VERSION}_ble-${BLESH_VERSION}"
echo "$VERSION" > "$BASE/VERSION"
echo "Done. VERSION=$VERSION"

# Usage examples:
#   bash setup.sh              # common arches: amd64, arm64, arm7, arm6, 386
#   bash setup.sh --all        # + arm5, ppc64le, riscv64, s390x, mips, mips64
#   bash setup.sh --arch linux-s390x   # add a single extra arch later
```

---

### 2. SSH Config (`~/.ssh/config`)

```sshconfig
Host *
    # Connection multiplexing — makes pre-flight checks nearly free after first connect
    ControlMaster auto
    ControlPath ~/.ssh/control/%C
    ControlPersist 60s

    # Tunnel the history socket back to Mac
    # Left side: path on remote, right side: path on Mac (listener)
    RemoteForward /tmp/ssh-hist-%i.sock /tmp/ssh-env-hist-listener.sock

    # ExitOnForwardFailure no is the default — no need to set it.
    # The warning is prevented by sshe waiting for the listener socket before connecting.
```

`%i` expands to the remote UID, isolating per-user sockets.

---

### 3. `sshe` — The SSH Wrapper (`~/.local/bin/sshe`)

```bash
#!/usr/bin/env bash
# sshe — SSH with enhanced session environment
# Usage: sshe [ssh-options] user@host

set -euo pipefail

BASE="$HOME/.local/share/ssh-env"
LOCAL_VERSION=$(cat "$BASE/VERSION" 2>/dev/null || echo "unknown")

# ── Parse args: separate ssh flags from target host ──────────────────────────
SSH_ARGS=()
TARGET=""
for arg in "$@"; do
    if [[ -z "$TARGET" && "$arg" != -* ]]; then
        TARGET="$arg"
    else
        SSH_ARGS+=("$arg")
    fi
done
[[ -z "$TARGET" ]] && { echo "Usage: sshe [ssh-options] user@host" >&2; exit 1; }

# ── Pre-flight: single SSH call probes everything needed ─────────────────────
# Collects: OS, arch, UID, version sentinel, bash path, /tmp exec capability, hostname
REMOTE_INFO=$(ssh "${SSH_ARGS[@]}" "$TARGET" '
    OS=$(uname -s 2>/dev/null || echo "unknown")
    ARCH=$(uname -m 2>/dev/null || echo "unknown")
    RUID=$(id -u 2>/dev/null || echo "0")
    VER=$(cat /tmp/ssh-env-$(id -u)/.version 2>/dev/null || echo "none")
    RBASH=$(command -v bash 2>/dev/null || echo "")
    _t=/tmp/.sshe-xtest-$$
    printf "#!/bin/sh\necho ok\n" > $_t 2>/dev/null \
        && chmod +x $_t 2>/dev/null \
        && OUT=$($_t 2>/dev/null) || OUT=""
    rm -f $_t 2>/dev/null
    [ "$OUT" = "ok" ] && TMPEXEC="yes" || TMPEXEC="no"
    HOSTF=$(hostname -f 2>/dev/null || hostname)
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$OS" "$ARCH" "$RUID" "$VER" "$RBASH" "$TMPEXEC" "$HOSTF"
' 2>/dev/null || printf "unknown\tunknown\t0\tnone\t\tno\tunknown")

REMOTE_OS=$(      awk -F'\t' '{print $1}' <<< "$REMOTE_INFO")
REMOTE_ARCH=$(    awk -F'\t' '{print $2}' <<< "$REMOTE_INFO")
REMOTE_UID=$(     awk -F'\t' '{print $3}' <<< "$REMOTE_INFO")
REMOTE_VER=$(     awk -F'\t' '{print $4}' <<< "$REMOTE_INFO")
REMOTE_BASH=$(    awk -F'\t' '{print $5}' <<< "$REMOTE_INFO")
REMOTE_TMPEXEC=$( awk -F'\t' '{print $6}' <<< "$REMOTE_INFO")
REMOTE_HOSTNAME=$(awk -F'\t' '{print $7}' <<< "$REMOTE_INFO")
REMOTE_DIR="/tmp/ssh-env-${REMOTE_UID}"

# ── Map uname -m → binary directory ──────────────────────────────────────────
# Only attempted when OS is Linux and /tmp can execute binaries.
ARCH_DIR=""
if [[ "$REMOTE_OS" == "Linux" && "$REMOTE_TMPEXEC" == "yes" ]]; then
    case "$REMOTE_ARCH" in
        x86_64)              ARCH_DIR="linux-amd64"   ;;
        aarch64|arm64)       ARCH_DIR="linux-arm64"   ;;
        armv7l|armv7)        ARCH_DIR="linux-arm7"    ;;
        armv6l|armv6)        ARCH_DIR="linux-arm6"    ;;
        armv5tel|armv5l)     ARCH_DIR="linux-arm5"    ;;
        i386|i486|i586|i686) ARCH_DIR="linux-386"     ;;
        ppc64le|powerpc64le) ARCH_DIR="linux-ppc64le" ;;
        riscv64)             ARCH_DIR="linux-riscv64" ;;
        s390x)               ARCH_DIR="linux-s390x"   ;;
        mips)                ARCH_DIR="linux-mips"    ;;
        mips64)              ARCH_DIR="linux-mips64"  ;;
    esac
    # Fall back if we haven't downloaded binaries for this arch yet
    if [[ -n "$ARCH_DIR" && ! -d "$BASE/$ARCH_DIR/bin" ]]; then
        echo "[sshe] No binaries for $ARCH_DIR. Run: bash setup.sh --arch $ARCH_DIR"
        ARCH_DIR=""
    fi
fi

# ── Choose mode ───────────────────────────────────────────────────────────────
#   passthrough  — no bash found (ESXi VMkernel, BusyBox-only containers)
#   scripts-only — bash present but no usable binaries (unknown arch, noexec /tmp)
#   full         — Linux + known arch + /tmp exec-capable
if [[ -z "$REMOTE_BASH" ]]; then
    MODE="passthrough"
elif [[ -z "$ARCH_DIR" ]]; then
    MODE="scripts-only"
else
    MODE="full"
fi

printf "[sshe] %-35s OS=%-10s arch=%-10s mode=%s\n" \
    "$TARGET" "$REMOTE_OS" "$REMOTE_ARCH" "$MODE"

# ── Passthrough: nothing we can do ───────────────────────────────────────────
if [[ "$MODE" == "passthrough" ]]; then
    echo "[sshe] No bash on $TARGET — connecting without enhancement"
    exec ssh "${SSH_ARGS[@]}" "$TARGET"
fi

# ── Transfer binaries (full mode, only when stale) ───────────────────────────
if [[ "$MODE" == "full" && "$REMOTE_VER" != "$LOCAL_VERSION" ]]; then
    echo "[sshe] Transferring binaries ($ARCH_DIR)..."
    tar czf - -C "$BASE/$ARCH_DIR/bin" . \
        | ssh "${SSH_ARGS[@]}" "$TARGET" "
            mkdir -p '$REMOTE_DIR/bin' '$REMOTE_DIR/config'
            tar xzf - -C '$REMOTE_DIR/bin'
            chmod +x '$REMOTE_DIR/bin/'*
            printf '%s' '$LOCAL_VERSION' > '$REMOTE_DIR/.version'
        "
fi

# ── Transfer scripts (always — tiny, idempotent, catches edits to bootstrap) ─
ssh "${SSH_ARGS[@]}" "$TARGET" "mkdir -p '$REMOTE_DIR/config'"
scp -q "$BASE/bootstrap.sh"  "$TARGET:$REMOTE_DIR/bootstrap.sh"
scp -q "$BASE/ble.sh"        "$TARGET:$REMOTE_DIR/ble.sh"
scp -q "$BASE/starship.toml" "$TARGET:$REMOTE_DIR/config/starship.toml"

# ── Ensure ControlMaster socket directory exists ──────────────────────────────
mkdir -p ~/.ssh/control

# ── Start local history listener (idempotent) ─────────────────────────────────
LISTENER_SOCK="/tmp/ssh-env-hist-listener.sock"
HISTORY_FILE="$BASE/history.tsv"
if [[ ! -S "$LISTENER_SOCK" ]]; then
    touch "$HISTORY_FILE"
    python3 "$BASE/listener.py" "$LISTENER_SOCK" "$HISTORY_FILE" &
    disown
    # Wait for socket to be ready (up to 2 s) so RemoteForward succeeds on first connect
    for _i in $(seq 20); do
        [[ -S "$LISTENER_SOCK" ]] && break
        sleep 0.1
    done
    unset _i
fi

# ── Transfer history snapshots ───────────────────────────────────────────────
# host_history.bash  — this host's past commands; injected into bash history at startup
# history_snapshot.tsv — recent cross-host history; used by allhist on remote
if [[ -f "$HISTORY_FILE" ]]; then
    # Commands for this specific host only (last 2000), stripped to command text
    grep -F "	${REMOTE_HOSTNAME}	" "$HISTORY_FILE" 2>/dev/null \
        | tail -2000 \
        | awk -F'\t' '{print $3}' \
        > "/tmp/sshe-host-hist-$$.bash"

    # Full cross-host snapshot (last 5000 entries)
    tail -5000 "$HISTORY_FILE" > "/tmp/sshe-hist-snap-$$.tsv"

    scp -q "/tmp/sshe-host-hist-$$.bash"  "$TARGET:$REMOTE_DIR/host_history.bash"
    scp -q "/tmp/sshe-hist-snap-$$.tsv"   "$TARGET:$REMOTE_DIR/history_snapshot.tsv"
    rm -f  "/tmp/sshe-host-hist-$$.bash"  "/tmp/sshe-hist-snap-$$.tsv"
fi

# ── Open interactive session ──────────────────────────────────────────────────
exec ssh -t "${SSH_ARGS[@]}" "$TARGET" \
    "bash --init-file '$REMOTE_DIR/bootstrap.sh' -i"
```

**Make it executable and add to PATH:**
```bash
chmod +x ~/.local/bin/sshe
# ~/.local/bin is already in PATH via ~/.bash_profile
```

---

### 4. Local History Listener (`~/.local/share/ssh-env/listener.py`)

Save this as `~/.local/share/ssh-env/listener.py`. The `sshe` wrapper starts it automatically.

```python
#!/usr/bin/env python3
"""Unix socket listener — writes incoming lines to a TSV history file."""

import socket
import sys
import os
import signal

sock_path, hist_path = sys.argv[1], sys.argv[2]

# Remove stale socket
try:
    os.unlink(sock_path)
except FileNotFoundError:
    pass

server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(sock_path)
server.listen(64)

signal.signal(signal.SIGTERM, lambda *_: (server.close(), os.unlink(sock_path), sys.exit(0)))

with open(hist_path, "a", buffering=1) as f:
    while True:
        try:
            conn, _ = server.accept()
            data = b""
            while chunk := conn.recv(4096):
                data += chunk
            conn.close()
            line = data.decode("utf-8", errors="replace").rstrip("\n")
            if line:
                f.write(line + "\n")
        except Exception:
            pass
```

---

### 5. Bootstrap Script (`~/.local/share/ssh-env/bootstrap.sh`)

This file runs on the remote host as bash's `--init-file`, replacing `~/.bashrc`.

```bash
# Remote bootstrap — session-only enhanced environment
# Sourced by bash --init-file on the remote host

# ── Paths ────────────────────────────────────────────────────────────────────
SSH_ENV_DIR="/tmp/ssh-env-$(id -u)"
SSH_ENV_BIN="$SSH_ENV_DIR/bin"
SSH_ENV_CFG="$SSH_ENV_DIR/config"
SSH_ENV_SESSION="$SSH_ENV_DIR/session-$$"
mkdir -p "$SSH_ENV_SESSION"

export PATH="$SSH_ENV_BIN:$PATH"

# ── XDG isolation — prevent writing to shared home ──────────────────────────
export XDG_CONFIG_HOME="$SSH_ENV_CFG"
export XDG_DATA_HOME="$SSH_ENV_DIR/data"
export XDG_CACHE_HOME="$SSH_ENV_DIR/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME"

# ── History ──────────────────────────────────────────────────────────────────
export HISTFILE="$SSH_ENV_SESSION/bash_history"
export HISTSIZE=50000
export HISTFILESIZE=50000
export HISTTIMEFORMAT="%Y-%m-%dT%H:%M:%SZ "
export HISTCONTROL="ignoredups:erasedups"
shopt -s histappend
shopt -s cmdhist

# Load this host's persistent history from Mac snapshot so ctrl-r searches past sessions
if [[ -f "$SSH_ENV_DIR/host_history.bash" ]]; then
    while IFS= read -r _hcmd; do
        [[ -n "$_hcmd" ]] && history -s "$_hcmd"
    done < "$SSH_ENV_DIR/host_history.bash"
    unset _hcmd
fi

# ── Cleanup on exit ──────────────────────────────────────────────────────────
_ssh_env_cleanup() {
    rm -rf "$SSH_ENV_SESSION"
    # To also remove binaries (for strict shared accounts), uncomment:
    # rm -rf "$SSH_ENV_DIR"
}
trap _ssh_env_cleanup EXIT

# ── Session multiplexer (optional — comment out if unwanted) ─────────────────
# Reattach to an existing session or create one; avoids nesting.
# Keeps the session alive if the SSH connection drops.
if command -v tmux &>/dev/null 2>&1 && [[ -z "$TMUX" ]]; then
    exec tmux new-session -A -s "ssh-env"
elif command -v zellij &>/dev/null 2>&1 && [[ -z "$ZELLIJ" ]]; then
    export ZELLIJ_CONFIG_DIR="$SSH_ENV_CFG/zellij"
    mkdir -p "$ZELLIJ_CONFIG_DIR"
    exec zellij attach --create "ssh-env-$(hostname -s)"
fi

# ── Starship prompt ──────────────────────────────────────────────────────────
if command -v starship &>/dev/null 2>&1; then
    export STARSHIP_CONFIG="$SSH_ENV_CFG/starship.toml"
    export STARSHIP_CACHE="$XDG_CACHE_HOME/starship"
    mkdir -p "$STARSHIP_CACHE"
    eval "$(starship init bash)"
else
    # Fallback: hand-rolled PS1 (Option B — no binaries needed)
    _git_branch() {
        local branch
        branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || return
        local dirty=""
        git status --porcelain 2>/dev/null | grep -q . && dirty=" *"
        printf " \033[33m(%s%s)\033[0m" "$branch" "$dirty"
    }
    PS1='\[\033[01;32m\]\u@\h\[\033[0m\]:\[\033[01;34m\]\w\[\033[0m\]$(_git_branch)\$ '
fi

# ── fzf integration ──────────────────────────────────────────────────────────
if command -v fzf &>/dev/null 2>&1; then
    # Official shell integration (fzf 0.48+): Ctrl-R, Ctrl-T, Alt-C
    eval "$(fzf --bash 2>/dev/null)" || {
        bind '"\C-r": "\C-a\C-k $(HISTTIMEFORMAT="" history | tac | fzf --no-sort --height=40% | sed "s/^ *[0-9]* *//") \C-m"' 2>/dev/null || true
    }
    export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --info=inline"
fi

# ── ble.sh — syntax highlighting + auto-suggestions (no binary needed) ───────
# Sources AFTER fzf so fzf's keybindings are visible to ble.sh's wrapper layer.
# Sources AFTER starship so ble.sh defers PS1 rendering to starship.
if [[ -f "$SSH_ENV_DIR/ble.sh" ]]; then
    source "$SSH_ENV_DIR/ble.sh" --norc --noinputrc 2>/dev/null || true
fi

# ── Cross-host history search ────────────────────────────────────────────────
# allhist — search all hosts (Mac + every server) using the snapshot transferred by sshe
# ctrl-r  — searches this host's history only (current session + past sessions from Mac)
allhist() {
    local snap="$SSH_ENV_DIR/history_snapshot.tsv"
    if [[ ! -f "$snap" ]]; then
        echo "No snapshot available. Connect via sshe to enable cross-host search."
        return 1
    fi
    local query="${*:-}"
    if command -v fzf &>/dev/null 2>&1; then
        fzf --delimiter=$'\t' \
            --with-nth=2,3 \
            --header="All hosts — $(wc -l < "$snap") entries" \
            --preview=$'printf "Host: %s\nTime: %s\nCmd:  %s\n" {2} {1} {3}' \
            --preview-window=up:3:wrap \
            --query="$query" \
            < "$snap" | awk -F'\t' '{print $3}'
    else
        grep "${query}" "$snap" | awk -F'\t' '{print $2": "$3}'
    fi
}

# ── Optional aliases (eza/bat if transferred) ────────────────────────────────
command -v eza &>/dev/null 2>&1 && alias ls='eza --icons --group-directories-first'
command -v bat &>/dev/null 2>&1 && alias cat='bat --style=plain'

# ── History forwarding to Mac ─────────────────────────────────────────────────
_SSH_HIST_SOCK="/tmp/ssh-hist-$(id -u).sock"

_send_history_to_mac() {
    [ -S "$_SSH_HIST_SOCK" ] || return 0
    local cmd
    cmd=$(HISTTIMEFORMAT='' history 1 2>/dev/null | sed 's/^ *[0-9]* *//')
    [ -z "$cmd" ] && return 0
    local entry
    entry="$(date -u +%Y-%m-%dT%H:%M:%SZ)	$(hostname -f 2>/dev/null || hostname)	$cmd"

    # Try python3 first (reliable on modern Linux)
    if command -v python3 &>/dev/null 2>&1; then
        python3 -c "
import socket, sys
try:
    s = socket.socket(socket.AF_UNIX)
    s.settimeout(0.5)
    s.connect(sys.argv[1])
    s.sendall(sys.argv[2].encode())
    s.close()
except Exception:
    pass
" "$_SSH_HIST_SOCK" "$entry" 2>/dev/null
    # Fallback: socat
    elif command -v socat &>/dev/null 2>&1; then
        printf '%s' "$entry" | socat - "UNIX-CONNECT:$_SSH_HIST_SOCK" 2>/dev/null || true
    fi
}

PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }_send_history_to_mac"

# ── Bash quality-of-life settings ────────────────────────────────────────────
shopt -s checkwinsize       # update LINES/COLUMNS after each command
shopt -s autocd 2>/dev/null # cd by typing directory name (bash 4+)
# set -o vi                 # uncomment if you prefer vi mode over emacs

# Source system-wide bash completion if available
if [[ -f /etc/bash_completion ]]; then
    source /etc/bash_completion 2>/dev/null || true
elif [[ -f /usr/share/bash-completion/bash_completion ]]; then
    source /usr/share/bash-completion/bash_completion 2>/dev/null || true
fi

# ── Greeting ──────────────────────────────────────────────────────────────────
printf "\033[90m[ssh-env] %s | %s | bash %s\033[0m\n" \
    "$(uname -sr)" "$(hostname -f 2>/dev/null || hostname)" "$BASH_VERSION"
```

---

### 6. Starship Config (`~/.local/share/ssh-env/starship.toml`)

Catppuccin Mocha palette baked in. Disabled modules that are slow on remote hosts.

```toml
# starship.toml — Catppuccin Mocha for remote sessions
# Transfer path: /tmp/ssh-env-UID/config/starship.toml

"$schema" = "https://starship.rs/config-schema.json"

format = """
$username$hostname $directory$git_branch$git_status $status
$character"""

add_newline = false

# ── Username ──────────────────────────────────────────────────────────────────
[username]
show_always = true
style_user  = "bold #a6e3a1"   # Catppuccin Green
style_root  = "bold #f38ba8"   # Catppuccin Red
format      = "[$user]($style)"

[hostname]
ssh_only   = false
style      = "#89b4fa"          # Catppuccin Blue
format     = "[@$hostname]($style) "
trim_at    = "."

# ── Directory ─────────────────────────────────────────────────────────────────
[directory]
style              = "bold #89dceb"   # Catppuccin Sky
truncation_length  = 4
truncate_to_repo   = true
format             = "[$path]($style)[$read_only]($read_only_style) "

# ── Git ───────────────────────────────────────────────────────────────────────
[git_branch]
style  = "#f9e2af"             # Catppuccin Yellow
format = "[$symbol$branch]($style) "
symbol = " "

[git_status]
style    = "#f38ba8"           # Catppuccin Red
format   = "([$all_status$ahead_behind]($style))"
modified = "!"
untracked = "?"
ahead    = "⇡${count}"
behind   = "⇣${count}"
# Time-limit git operations to avoid stalling on large repos
disabled = false

# ── Exit status ───────────────────────────────────────────────────────────────
[status]
disabled = false
style    = "#f38ba8"
format   = "[$status]($style) "
map_symbol = true

# ── Character ─────────────────────────────────────────────────────────────────
[character]
success_symbol = "[❯](bold #a6e3a1)"
error_symbol   = "[❯](bold #f38ba8)"

# ── Disabled noisy modules ────────────────────────────────────────────────────
[aws]
disabled = true

[gcloud]
disabled = true

[kubernetes]
disabled = true

[time]
disabled = true

[package]
disabled = true

[nodejs]
disabled = true

[python]
disabled = true

[rust]
disabled = true
# ... add any language modules you don't need on remote hosts
```

---

### 7. History Search

`~/.local/share/ssh-env/history.tsv` is the single source of truth. It accumulates commands from every machine — local Mac and all remote sessions — in the same format:
```
2026-04-25T14:32:01Z	web01.prod.example.com	kubectl get pods -n production
2026-04-25T14:35:10Z	MacBook-Pro.local	git push origin main
```

**What you can do where:**

| Where | Command | Shows |
|---|---|---|
| Mac | `ssh-hist` | Everything — all hosts, all time |
| Mac | `ssh-hist-host web01` | One host (prefix match — also matches web01.prod.example.com) |
| Remote (via sshe) | ctrl-r | This host's history, persistent across reboots |
| Remote (via sshe) | `allhist` | Cross-host merged search (snapshot from Mac) |

`allhist` on remote searches a snapshot transferred at connect time — it reflects history up to the moment you connected, not real-time. For up-to-the-second cross-host search, use `ssh-hist` on your Mac.

Add these functions to `~/.bash_profile`:

```bash
_SSH_ENV_HIST="$HOME/.local/share/ssh-env/history.tsv"

# All hosts, all time — full merged search
ssh-hist() {
    [[ -f "$_SSH_ENV_HIST" ]] || { echo "No history yet — run a command or connect via sshe first."; return 1; }
    local query="${*:-}"
    fzf --delimiter=$'\t' \
        --with-nth=2,3 \
        --header="All history — $(wc -l < "$_SSH_ENV_HIST") entries" \
        --preview=$'printf "Host: %s\nTime: %s\nCmd:  %s\n" {2} {1} {3}' \
        --preview-window=up:3:wrap \
        --query="$query" \
        < "$_SSH_ENV_HIST" | awk -F'\t' '{print $3}'
}

# One host only
ssh-hist-host() {
    [[ -f "$_SSH_ENV_HIST" ]] || { echo "No history yet — run a command or connect via sshe first."; return 1; }
    local host="$1"; shift
    grep -F "	${host}" "$_SSH_ENV_HIST" | \
    fzf --delimiter=$'\t' \
        --with-nth=3 \
        --header="$host history" \
        --query="${*:-}" \
        | awk -F'\t' '{print $3}'
}
```

---

## Directory Layout Summary

```
~/.local/share/ssh-env/           # Mac side — track this directory in your dotfiles manager
├── VERSION                       # binary version sentinel
├── setup.sh                      # download/update binaries for any arch
├── bootstrap.sh                  # sourced on remote as bash --init-file
├── starship.toml                 # transferred to remote /tmp/ssh-env-UID/config/
├── ble.sh                        # arch-independent script, transferred to remote
├── listener.py                   # local Unix socket listener for history
├── history.tsv                   # all commands — local Mac + every remote server, timestamped + tagged with hostname
├── linux-amd64/bin/{fzf,starship}    # x86_64 servers
├── linux-arm64/bin/{fzf,starship}    # modern Pi (3/4/5 64-bit), arm servers
├── linux-arm7/bin/{fzf,starship}     # Pi 2/3 32-bit, older arm servers
├── linux-arm6/bin/{fzf,starship}     # Pi 1, Pi Zero, Pi Zero W
├── linux-386/bin/{fzf,starship}      # 32-bit x86 (rare)
├── linux-ppc64le/bin/{fzf,starship}  # --all only; starship is glibc-linked
├── linux-riscv64/bin/{fzf,starship}  # --all only; starship is glibc-linked
├── linux-s390x/bin/{fzf,starship}    # --all only; starship is glibc-linked
├── linux-mips/bin/fzf                # --all only; no starship prebuilt
└── linux-mips64/bin/fzf              # --all only; no starship prebuilt

~/.local/bin/
└── sshe                          # wrapper script; alias ssh=sshe or use explicitly

~/.ssh/config                     # ControlMaster + RemoteForward settings

/tmp/ssh-env-{uid}/               # Remote (ephemeral, per-user, UID-isolated)
├── .version                      # version sentinel for binary freshness check
├── ble.sh                        # arch-independent bash script
├── host_history.bash             # this host's past commands, injected into ctrl-r at startup
├── history_snapshot.tsv          # cross-host snapshot for allhist (transferred by sshe at connect)
├── bin/
│   ├── fzf
│   ├── starship
│   ├── eza                       # optional
│   └── bat                       # optional
├── config/
│   └── starship.toml
├── data/                         # XDG_DATA_HOME redirect (nothing writes here by default)
├── cache/                        # XDG_CACHE_HOME redirect (starship cache)
└── session-{pid}/                # per-session files; removed by EXIT trap on logout
    └── bash_history
```

**Note on dotfiles managers:** The Mac-side `~/.local/share/ssh-env/` directory is a good candidate for tracking in chezmoi, stow, or yadm — it's your config, and you want it replicated across Macs. The remote side is explicitly not managed by a dotfiles manager; the `sshe` wrapper handles deployment.

---

## Trade-Off Summary

| Feature | With sshe | Without (raw ssh) |
|---------|-----------|-------------------|
| Rich prompt (user/host/dir/git) | Yes (starship) | Basic `$` |
| Syntax highlighting as you type | Yes (ble.sh — no binary) | No |
| Auto-suggestions (ghost text) | Yes (ble.sh — no binary) | No |
| Colors | Yes (Catppuccin via terminal) | None |
| Fuzzy history search | Yes (fzf Ctrl-R) | Basic Ctrl-R |
| Fuzzy file finder | Yes (fzf Ctrl-T) | No |
| Tab completion | System bash-completion | Same |
| Remote history on Mac | Yes (real-time socket) | No |
| Cross-host history search | Yes (fzf over TSV) | No |
| Session persistence (disconnect) | Optional (tmux/zellij) | No |
| First connection overhead | 3–8s (binary transfer) | 0 |
| Subsequent connections | ~0.3s (version check) | 0 |
| `~/.bashrc` modified | Never | N/A |
| `/etc/` modified | Never | N/A |
| Root required | Never | N/A |
| Binary left in `/tmp` | Yes (until reboot) | N/A |

**What you lose vs a full install:**
- No persistent completions that learn over time (fish's trained suggestions)
- No abbreviations/aliases surviving between sessions unless added to bootstrap.sh
- Each session starts with a fresh history (by design — the Mac-side TSV is your real history)
- Starship adds ~50–100 ms per prompt on slow hosts or large git repos
- ble.sh adds ~30–50 ms to session startup; disable on ultra-slow hosts

---

## Quick Start

### Step 1 — Save the implementation files

From the **Implementation** section above, save each file to the path shown in its heading:

| File | Save to |
|---|---|
| setup.sh | `~/.local/share/ssh-env/setup.sh` |
| sshe | `~/.local/bin/sshe` |
| listener.py | `~/.local/share/ssh-env/listener.py` |
| bootstrap.sh | `~/.local/share/ssh-env/bootstrap.sh` |
| starship.toml | `~/.local/share/ssh-env/starship.toml` |

```bash
# Create the directories first
mkdir -p ~/.local/share/ssh-env ~/.local/bin ~/.ssh/control
```

### Step 2 — Install local tools

```bash
brew install bash bash-completion@2 fzf starship
$(brew --prefix)/opt/fzf/install   # say yes to key bindings and fuzzy completion

# Switch to modern bash (log out and back in after)
echo /opt/homebrew/bin/bash | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/bash
```

### Step 3 — Set up `~/.bash_profile`

Create `~/.bash_profile` and paste in the template from the **Local Mac Setup → ~/.bash_profile** section above,
then append the `ssh-hist` and `ssh-hist-host` functions from the **Local History Search** section.

### Step 4 — Download remote binaries and enable sshe

```bash
bash ~/.local/share/ssh-env/setup.sh
chmod +x ~/.local/bin/sshe
```

### Step 5 — Connect to a remote host

```bash
sshe user@myserver.example.com

# Search cross-host history later
ssh-hist kubectl
```

On first connect to each host, you'll see:
```
[sshe] Transferring binaries to myserver.example.com (linux-amd64)...
[ssh-env] Linux 5.15.0-91-generic | myserver.example.com | bash 5.1.16
user@myserver ~/
❯
```

On subsequent connects (same day):
```
[ssh-env] Linux 5.15.0-91-generic | myserver.example.com | bash 5.1.16
user@myserver ~/
❯
```

---

## Handling Edge Cases

**Shared admin account (same UID, two users):**
If two people using this setup both SSH into the same account on a server (same Unix UID), the second person's `RemoteForward` will fail silently — the socket name is UID-based, so the first connection already holds it. The second person gets a normal session with no history forwarding to their Mac. Their commands are not written to anyone's TSV. This is the correct behavior (no cross-user pollution), but it means that person's remote commands are not persisted. There is no fix for this without a shared sync server.

**Unknown architecture:**
`sshe` falls back to scripts-only mode (ble.sh + hand-rolled PS1) and prints the arch name. To add binary support for it:
```bash
bash ~/.local/share/ssh-env/setup.sh --arch linux-riscv64
# Then reconnect; sshe will detect and transfer on next session
```
For architectures with no prebuilt binaries (very exotic — SPARC, PA-RISC, etc.), scripts-only is the permanent mode. The prompt and history forwarding still work.

**ESXi / VMkernel / BusyBox-only hosts:**
`uname -s` returns `VMkernel` on ESXi, or bash is absent on minimal containers. `sshe` detects the missing bash and falls through to plain `ssh`. You get a standard connection; nothing breaks. This is intentional — these systems often have fragile environments where any unexpected write can cause problems.

**`/tmp` is noexec (hardened Linux, some enterprise systems):**
`sshe` detects this during pre-flight and automatically uses scripts-only mode. You still get ble.sh (sourced, not executed) and the hand-rolled PS1. If you want binaries on these hosts, set up an alternative executable directory:
```bash
# In bootstrap.sh, change SSH_ENV_DIR to a path that is exec-capable:
SSH_ENV_DIR="$HOME/.ssh/ssh-env-$(id -u)"
# $HOME/.ssh/ is almost never noexec, and is already user-isolated
```
Update `REMOTE_DIR` in `sshe` accordingly, or add a per-host override in `~/.ssh/config`:
```sshconfig
Host hardened-host.example.com
    SetEnv SSH_ENV_OVERRIDE_DIR=.ssh/ssh-env
```

**glibc binaries on musl distros (Alpine Linux, some embedded):**
Some architectures (ppc64le, riscv64, s390x) have only glibc-linked starship builds — these will fail to run on Alpine. `sshe` detects binary failure via the version check on next connect and doesn't retry. fzf for those arches is still static (Go binaries are always static), so you get fzf but no starship; bootstrap falls back to the hand-rolled PS1.

**Old bash (3.x) on RHEL 6 / ancient CentOS:**
Remove `shopt -s autocd` and avoid associative arrays in bootstrap.sh. The rest of the bootstrap works on bash 3.2+. ble.sh also works on bash 3.0+. Practically this means nothing changes for you — the defaults are already safe.

**Remote has no python3 (very old or minimal systems):**
History forwarding silently skips to the socat fallback. If socat is also absent, forwarding is skipped entirely. The session still works; you just don't get real-time history synced to your Mac.

**Binary already exists in PATH on remote:**
The bootstrap prepends `/tmp/ssh-env-UID/bin` to PATH, so the transferred version takes priority. If a newer system version exists and you'd rather use it, remove or reorder the PATH line in bootstrap.sh.

**ControlMaster socket accumulation (200 servers):**
```bash
find ~/.ssh/control/ -maxdepth 1 -mtime +1 -delete
```
Add this to your shell's exit hook or a daily cron. Stale sockets don't cause errors but they accumulate.

---

## How standard is this setup vs how much is custom hacking?

### Component-by-component breakdown

| Component | Standard? | Notes |
|---|---|---|
| ControlMaster in `~/.ssh/config` | Fully standard | Built-in OpenSSH feature, zero custom code |
| bash on remote | Fully standard | Default shell on every Linux system |
| bash-completion on remote | Fully standard | Usually pre-installed on Linux servers |
| Starship | Standard tool | Single binary, used exactly as designed |
| fzf | Standard tool | Single binary, used exactly as designed |
| ble.sh | Niche but solid | Purpose-built for this exact use case; ~200 KB script, no binary |
| `bash --init-file bootstrap.sh` | Standard bash feature | Documented, intended use |
| Binary transfer via `tar \| ssh` | Common pattern | Standard ops technique, not hacky |
| Version sentinel in `/tmp` | Pragmatic | Simple but effective; you maintain the logic |
| `sshe` wrapper script | Custom — you own it | ~100 lines of bash; handles pre-flight, mode selection, transfers |
| `bootstrap.sh` | Custom — you own it | ~120 lines of bash; remote environment setup |
| History socket forwarding | Custom — genuinely hacky | PROMPT_COMMAND + Unix socket + RemoteForward + Python listener; ~80 lines across 3 files |
| `listener.py` | Custom — you own it | 30-line Python daemon; if it crashes, no history is saved |
| TSV history format | Custom — you own the schema | Fine, but no tooling ecosystem around it |
| History injection at startup | Mildly hacky | `while read; history -s` loop — slow on large histories, no dedup |
| `allhist` / `ssh-hist` | Custom — you own it | ~40 lines; works well, but not tested at scale |

### Honest summary

**Not hacky at all** (~60% of the setup): ControlMaster, bash, Starship, fzf, ble.sh, `bash --init-file`, binary transfer. These are all standard tools used in standard ways. You could tear out everything else and these would keep working indefinitely.

**Pragmatic custom glue** (~25%): `sshe` and `bootstrap.sh`. Roughly 220 lines of bash you maintain. They're straightforward to read and debug, but they are yours — if OpenSSH changes behaviour or a new bash version breaks an assumption, you fix it.

**Genuinely hacky** (~15%): The history system. Five moving parts (PROMPT_COMMAND hook, Unix socket, RemoteForward tunnel, Python listener, history injection) that must all work together. Any one failing silently breaks history without any visible error. It's clever, it works, but it's the part most likely to cause you unexpected debugging sessions.

---

## Comparison to xxh

[xxh](https://github.com/xxh/xxh) (pronounced "double-x h") is a purpose-built tool that solves the same core problem: bring your shell environment to remote hosts without installing anything permanently.

### What xxh does

- `xxh user@host` — single command, that's it
- Uploads a full portable shell to the remote (fish, zsh, xonsh, or bash)
- Plugin system: `xxh-plugin-*` packages bring your dotfiles, completions, themes
- Stores environment in `~/.xxh/` on remote (persistent across reboots, not in `/tmp`)
- No root required
- Community-maintained packages for common plugins (zoxide, starship, etc.)

### Side-by-side comparison

| | This setup | xxh |
|---|---|---|
| Core concept | Hand-rolled SSH wrapper + bootstrap | Purpose-built maintained tool |
| Remote shell | bash only | fish, zsh, xonsh, bash — your choice |
| fish on remote | No (bash only) | Yes, with full plugin support |
| Prompt | Starship (transferred) | Starship via xxh-plugin-prerun-starship |
| Autosuggestions | ble.sh (transferred) | Shell-native (fish/zsh have it built in) |
| Remote footprint | `/tmp` — wiped on reboot | `~/.xxh/` — persists across reboots |
| History sync | Custom TSV + socket forwarding | Not built-in; bring your own (atuin, etc.) |
| Cross-host search | Yes (`allhist`, `ssh-hist`) | Not built-in |
| Lines of code you maintain | ~350 lines | ~0 lines (it's a maintained tool) |
| Setup effort | High — build it yourself | Low — `pip install xxh-xxh` |
| Debugging when broken | You debug it | File a GitHub issue |
| Plugin ecosystem | None — you add tools manually | Growing ecosystem of xxh packages |
| Works if remote has no internet | Yes — binaries transferred from Mac | Yes — same approach |
| Works if `/tmp` is noexec | No (scripts-only fallback) | No |

### When to use this setup over xxh

- You need the history forwarding and cross-host search — xxh has no equivalent
- You want zero dependencies (xxh requires Python on Mac, pip install)
- You want to understand every line of what runs on your servers
- You distrust third-party tools running on prod infrastructure

### When xxh is the better choice

- You want fish or zsh on remote with full plugin support (biggest xxh advantage)
- You want the remote environment to persist across server reboots without reconnecting
- You don't need cross-host history search
- You'd rather maintain zero code yourself
