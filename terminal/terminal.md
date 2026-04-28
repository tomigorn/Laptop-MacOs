# Terminal setup

Fish shell on the Mac, plus a portable environment that SSH-connects to any remote host with the same shell, prompt, and history — without installing anything on the remote and without leaving any trace when you disconnect.

---

## What this is

The setup has two parts:

**Local (Mac):** fish shell with starship prompt, fastfetch system info greeting, and atuin for searchable shell history.

**Remote (via xxh):** when you run `xxhc hostname`, the tool [xxh](https://github.com/xxh/xxh) uploads a self-contained bundle to the remote over SCP — portable fish binary, starship, fastfetch, atuin, and all config — starts a fish session inside it, and on disconnect removes everything. The remote host never gets a modified `.bashrc`, no binaries persist in `PATH`, and `~/.xxh/` is deleted the moment you exit. Remote shell history is merged back into your local atuin database before cleanup, tagged with the remote hostname so you can tell where each command ran.

---

## Architecture: why it works this way

**Why xxh instead of `ssh host bash`?**
Plain SSH gives you whatever shell the remote has, with none of your config. xxh carries the entire shell as a self-contained bundle, so you get the same experience everywhere regardless of what the host has installed.

**Why fish?**
Fish has excellent interactive features (completions, syntax highlighting, history) and a clean config model. The xxh-shell-fish plugin bundles a portable static fish binary, so it runs on any Linux host without being installed.

**Why SCP instead of rsync?**
SSH ControlMaster multiplexing (used for fast repeated connections) conflicts with how xxh calls rsync internally. Using SCP avoids this entirely.

**Why wipe on disconnect (`+hhr`)?**
The remotes are shared admin accounts used by multiple people. Nothing should be left behind — no history, no binaries, no config. The cost is re-uploading ~90 MB on every connect.

**Why symlinks for config files?**
All config lives in this git directory (`terminal/`). The real paths (`~/.config/starship.toml`, etc.) are symlinks pointing here. This means editing a file in the repo takes effect immediately with no copy step, and git is always the source of truth. Without symlinks you'd have two copies that drift apart.

**Why are binaries plain copies instead of symlinks?**
The Linux binaries in `~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/` are uploaded to remote Linux hosts. The sources in `~/.xxh/bin/` are also Linux ELF binaries (not macOS). There's no meaningful reason to symlink one Linux binary to another — they're the same file and a plain copy is clearer.

---

## Local setup (Mac)

**Tools** (all via Homebrew):
- `fish` — shell
- `starship` — prompt (macOS binary, local only)
- `fastfetch` — system info on every new shell (macOS binary locally, Linux binary on remote)
- `atuin` — shell history with fuzzy search; up arrow and Ctrl-R open the TUI

**`~/.config/fish/config.fish`:**
```fish
starship init fish | source
atuin init fish | source
```

**`~/.config/fish/functions/fish_greeting.fish`:**
```fish
function fish_greeting
    fastfetch
end
```
fastfetch shows OS, CPU, memory, uptime. It auto-detects the system and shows the correct distro name and logo whether running on macOS or any Linux distro.

**`~/.config/starship.toml`:**
Configures the prompt. Key design decisions:
- `hostname` is `ssh_only = true` — the `@ hostname` part only appears on SSH sessions, not locally
- `env_var.XXH_SSH_ALIAS` only renders when `$XXH_SSH_ALIAS` is set, which only happens via `xxhc` — so `(myserver)` never clutters the local prompt
- `git_status` uses full-word labels (`!modified`, `?untracked`, etc.) instead of symbols alone for clarity

---

## Remote setup via xxh

### What gets uploaded on connect (~90 MB every time)

| File | Size | Purpose |
|---|---|---|
| `fish-portable/` | ~39 MB | Self-contained fish shell binary, runs on any Linux |
| `atuin` | ~29 MB | Shell history with search |
| `starship` | ~12 MB | Prompt binary |
| `fastfetch` | ~10 MB | System info greeting |
| `xxh-config.fish`, `starship.toml`, entrypoint | <1 MB | Config and session bootstrap |

The upload happens on every connect because `+hhr` wipes the remote on every disconnect — there's nothing to reuse.

### What the remote session looks like

On connect the greeting prints:
```
  Connected in 15s

[fastfetch output — OS, CPU, memory, uptime, hostname, distro logo]

tomigorn @ remote-host (myserver) ~
›
```

| Prompt part | Meaning | Colour | When shown |
|---|---|---|---|
| `tomigorn` | username | green | always |
| `@ remote-host` | real hostname of the remote | yellow | SSH sessions only |
| `(myserver)` | SSH alias you typed | blue | via `xxhc` only |
| `~` | current directory | cyan | always |

### What gets cleaned up on disconnect

- `fish/generated_completions/` — removed by the fish_exit handler to avoid NFS stub file issues
- `~/.xxh/` — deleted by xxh's `+hhr` cleanup (runs `chmod -R u+w` then `rm -rf`)
- `/tmp/.xxh_atuin_*` — removed by `xxhc` after the history merge completes
- `.bashrc`, `.bash_profile`, `.profile` — never touched
- No binaries left in `PATH`, no background processes

If `~/.xxh/` cannot be removed (permissions, filesystem issue), `xxhc` detects this by SSH-ing back after the session and shows a red warning box with the manual fix command.

### Remote atuin history sync

History flows in both directions so each host accumulates its own history across sessions:

**On connect:**
`xxhc` checks for a per-host history file at `~/.xxh/history/<alias>.db` on the Mac. If it exists (from a previous session), it SCPs it to `remote:/tmp/` before calling xxh. The remote fish startup (`xxh-config.fish`) picks this up and uses it to seed the atuin database — so you immediately have history from all previous sessions on that host.

**On disconnect:**
Before the remote fish session exits, it copies its atuin database (main file + WAL + SHM) to `/tmp/`. atuin uses SQLite WAL mode, meaning recent writes live in the `-wal` file rather than the main `.db` — without the WAL, the DB appears empty. After `xxhc` returns, all three files are SCP'd back to the Mac, a `PRAGMA wal_checkpoint(FULL)` merges the WAL into the main file, and the result is merged into your local atuin database with `INSERT OR IGNORE` (no duplicates). A clean single-file copy is saved as `~/.xxh/history/<alias>.db` for the next connect's preseed.

The per-host files at `~/.xxh/history/` are not in git (personal history data). They grow over time and are the only persistent state on the Mac side of this system.

Each merged command is tagged with the remote hostname (e.g. `tomigorn@remote-host`), so locally you can distinguish them:

```fish
atuin search --format "{host} {command}" | grep remote-host
# or query the DB directly:
sqlite3 ~/.local/share/atuin/history.db \
  "SELECT command FROM history WHERE hostname LIKE '%remote-host%' ORDER BY timestamp DESC LIMIT 50"
```

The atuin TUI (Ctrl-R / up arrow) shows all history including remote commands; the host column identifies where each ran.

---

## File layout

All config lives in this directory and is **symlinked** from its real home path. Editing any file here takes effect immediately everywhere — no copy step needed.

```
terminal/
  terminal.md                             this file
  setup.sh                                automated setup for a new Mac

  .config/
    xxh/config.xxhc                       xxh connection settings (all hosts)
    starship.toml                         prompt config — local and remote
    fish/
      config.fish                         local Mac fish startup
      functions/
        fish_greeting.fish                fastfetch greeting
        xxhc.fish                         xxh connect wrapper + history sync

  .xxh/
    ssh-wrapper.sh                        forces ControlMaster=no for SCP compat
    xxh-config.fish                       fish session init on the remote
```

### Symlinks

Set up once by `setup.sh` (or manually), then completely transparent:

```
~/.config/xxh/config.xxhc                              → terminal/.config/xxh/config.xxhc
~/.config/starship.toml                                 → terminal/.config/starship.toml
~/.config/fish/config.fish                              → terminal/.config/fish/config.fish
~/.config/fish/functions/fish_greeting.fish             → terminal/.config/fish/functions/fish_greeting.fish
~/.config/fish/functions/xxhc.fish                      → terminal/.config/fish/functions/xxhc.fish
~/.xxh/ssh-wrapper.sh                                   → terminal/.xxh/ssh-wrapper.sh
~/.xxh/.xxh/shells/xxh-shell-fish/build/xxh-config.fish → terminal/.xxh/xxh-config.fish
~/.xxh/.xxh/shells/xxh-shell-fish/build/starship.toml   → terminal/.config/starship.toml
```

The last two symlinks point into the xxh build directory — the directory xxh uploads on every connect. This means editing `starship.toml` or `xxh-config.fish` in the repo is enough; the next `xxhc` connect picks up the change automatically.

### Not in git

```
~/.xxh/bin/starship          Linux x86-64 static binary (source)
~/.xxh/bin/fastfetch         Linux x86-64 static binary (source)
~/.xxh/bin/atuin             Linux x86-64 static binary (source)

~/.xxh/history/<alias>.db    per-host atuin history, grows across sessions

~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/starship    plain copy, uploaded to remote
~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/fastfetch   plain copy, uploaded to remote
~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/atuin       plain copy, uploaded to remote
```

---

## Config files explained

### `xxh/config.xxhc`

```yaml
hosts:
  ".*":
    +s: xxh-shell-fish
    ++pexpect-timeout: "30"
    ++copy-method: scp
    +if:
    +hhh: "~"
    +hhr:
    -o:
      - ControlMaster=no
      - ControlPath=none
```

| Option | Effect | Why |
|---|---|---|
| `+s: xxh-shell-fish` | Use the portable fish plugin | Carries fish to any Linux host |
| `++pexpect-timeout: "30"` | Wait up to 30 s during handshake | Some hosts are slow to respond |
| `++copy-method: scp` | Use SCP for uploads | rsync conflicts with ControlMaster |
| `+if:` | Always upload without prompting | `+hhr` wipes remote on disconnect, so xxh would ask "Install? [Y/n]" every time without this |
| `+hhh: "~"` | Set `HOME` to real remote home | Without this, `HOME` is set to `~/.xxh` and `cd ~` lands in the wrong place |
| `+hhr:` | Delete `~/.xxh` on disconnect | Zero footprint on shared hosts |
| `-o ControlMaster=no` | Disable SSH connection reuse | Prevents conflicts with SCP upload |

### `fish/functions/xxhc.fish`

```fish
function xxhc --description "xxh with SSH alias forwarded to remote prompt"
    set -l target $argv[1]
    set -l host_db ~/.xxh/history/$target.db
    set -l remote_preseed /tmp/.xxh_atuin_pre_$target.db
    set -l remote_db /tmp/.xxh_atuin_$target.db
    set -l local_db ~/.local/share/atuin/history.db
    set -l tmp_db /tmp/.xxh_atuin_$target\_local.db

    # Pre-seed remote with this host's accumulated history.
    # Validate it has a history table, then send a clean WAL-free single-file copy.
    if test -f $host_db
        set -l has_table (sqlite3 $host_db "SELECT name FROM sqlite_master WHERE type='table' AND name='history';" 2>/dev/null)
        if test "$has_table" = history
            set -l clean_preseed /tmp/.xxh_atuin_pre_clean_$target.db
            sqlite3 $host_db "VACUUM INTO '$clean_preseed';" 2>/dev/null
            and scp -q -o ControlMaster=no -o ControlPath=none $clean_preseed "$target:$remote_preseed" 2>/dev/null
            rm -f $clean_preseed
        end
    end

    set -l start (date +%s)
    env RSYNC_RSH=~/.xxh/ssh-wrapper.sh xxh $target \
        +e "XXH_SSH_ALIAS=$target" \
        +e "XXH_CONNECT_START=$start" \
        $argv[2..-1]

    # Retrieve remote atuin DB — fetch main file plus WAL files.
    # atuin uses SQLite WAL mode: recent writes live in the -wal file, not the
    # main .db file. Without the WAL files, the DB appears empty.
    if scp -q -o ControlMaster=no -o ControlPath=none "$target:$remote_db" $tmp_db 2>/dev/null
        scp -q -o ControlMaster=no -o ControlPath=none "$target:$remote_db-wal" $tmp_db-wal 2>/dev/null
        scp -q -o ControlMaster=no -o ControlPath=none "$target:$remote_db-shm" $tmp_db-shm 2>/dev/null

        # Checkpoint WAL into the main file so all data is in one place before
        # any further sqlite3 operations read the DB.
        sqlite3 $tmp_db "PRAGMA wal_checkpoint(FULL);" 2>/dev/null

        sqlite3 $local_db "
            ATTACH '$tmp_db' AS remote;
            INSERT OR IGNORE INTO main.history SELECT * FROM remote.history;
            DETACH remote;
        " 2>/dev/null
        and echo "  History from $target merged into local atuin"

        # Accumulate per-host history for the next connect's preseed.
        # VACUUM INTO creates a clean single-file DB (no WAL artifacts).
        mkdir -p ~/.xxh/history
        if test -f $host_db
            sqlite3 $host_db "
                ATTACH '$tmp_db' AS new_session;
                INSERT OR IGNORE INTO main.history SELECT * FROM new_session.history;
                DETACH new_session;
            " 2>/dev/null
        else
            sqlite3 $tmp_db "VACUUM INTO '$host_db';" 2>/dev/null
        end

        ssh -q -o ControlMaster=no -o ControlPath=none $target \
            "rm -f $remote_db $remote_db-wal $remote_db-shm $remote_preseed" 2>/dev/null
        rm -f $tmp_db $tmp_db-wal $tmp_db-shm
    end

    # Verify xxh cleaned up ~/.xxh — warn loudly if anything is left behind
    if ssh -q -o ControlMaster=no -o ControlPath=none -o ConnectTimeout=10 $target "test -d ~/.xxh" 2>/dev/null
        set_color --bold red
        echo ""
        echo "  ╔══════════════════════════════════════════════════════════════╗"
        echo "  ║                    CLEANUP FAILURE                          ║"
        echo "  ║  ~/.xxh was NOT removed on $target"
        echo "  ║  Other users on this shared host can see your files.        ║"
        echo "  ║  Fix now:  ssh $target \"rm -rf ~/.xxh\""
        echo "  ╚══════════════════════════════════════════════════════════════╝"
        echo ""
        set_color normal
    end
end
```

- `RSYNC_RSH` — ensures rsync bypasses ControlMaster if ever called internally by xxh
- `XXH_SSH_ALIAS` — the alias you typed; forwarded to the remote so the prompt shows `(myserver)`
- `XXH_CONNECT_START` — Unix timestamp before connecting; remote greeting subtracts it to show total connection time
- **Pre-seed**: before xxh runs, if `~/.xxh/history/<alias>.db` exists and has a history table, a clean WAL-free copy is SCP'd to `remote:/tmp/` for atuin to load at startup
- **WAL handling**: atuin uses SQLite WAL mode so recent writes are in `-wal` not the main file; all three files are fetched, then `PRAGMA wal_checkpoint(FULL)` merges WAL into main file before any reads
- **Host DB**: per-host history is accumulated in `~/.xxh/history/<alias>.db` and grows across sessions
- **Cleanup check**: after everything, SSHs back to verify `~/.xxh` is gone; shows a red warning box if not

### `xxh/xxh-config.fish`

The fish session init that runs on the remote. In order:

1. **PATH** — adds the uploaded `bin/` dir so starship, fastfetch, and atuin are all in PATH
2. **Starship** — sets `STARSHIP_CONFIG` and initialises the prompt
3. **Greeting** — defines `fish_greeting` to print connection time (from `XXH_CONNECT_START`) then run fastfetch
4. **Atuin** — if a preseed file exists at `/tmp/.xxh_atuin_pre_<alias>.db`, copies it into `$XDG_DATA_HOME/atuin/history.db` before atuin starts so previous session history is available immediately. Then writes a minimal config and initialises atuin.
5. **`fish_exit` handler** — on exit, copies the atuin DB and its WAL/SHM files to `/tmp/` so `xxhc` can retrieve them after the session ends. Also removes `fish/generated_completions` to prevent NFS stub files from blocking xxh's `+hhr` cleanup.

The atuin config written on each connect:
```toml
auto_sync = false
search_mode = "fuzzy"
```
`auto_sync = false` prevents atuin from contacting any external server — important on shared hosts where network behaviour is unpredictable.

**NFS cleanup note:** On NFS-mounted home directories (common in university/enterprise environments), fish generates shell completions asynchronously. When those files are open, deleting them creates invisible `.nfsXXXX` stub files that leave the directory non-empty. xxh's `+hhr` cleanup then fails with "Directory not empty". The `fish_exit` handler pre-emptively removes `$XDG_DATA_HOME/fish/` so xxh can cleanly `chmod -R u+w && rm -rf` the rest of `~/.xxh/`.

---

## Performance

Benchmarked on a local network:

```
time xxhc myserver +hc "echo ok"
→ ~15 seconds wall time
```

Breakdown: fish-portable 39 MB + atuin 29 MB + starship 12 MB + fastfetch 10 MB = ~90 MB uploaded over SCP on every connect. The session itself starts in under a second once files are in place. This cost is fundamental to `+hhr` — every connect is a cold upload.

---

## Setup on a new machine

**Automated (recommended):**
```sh
git clone <repo> ~/development/private/Laptop-MacOs
cd ~/development/private/Laptop-MacOs/terminal
./setup.sh
```

The script handles everything: Homebrew, local tools, xxh, all symlinks, downloading Linux static binaries, and staging them in the xxh build dir. Safe to re-run — already-done steps are skipped.

---

**Manual steps** (if you prefer to understand and run each step yourself):

### 1. Clone

```sh
git clone <repo> ~/development/private/Laptop-MacOs
```

### 2. Install local tools

```sh
brew install fish starship fastfetch atuin pipx
pipx ensurepath
# open a new shell or: export PATH="$HOME/.local/bin:$PATH"
```

### 3. Install xxh and the fish plugin

```sh
pipx install xxh-xxh
xxh +I xxh-shell-fish
```
`+I` installs the plugin locally into `~/.xxh/.xxh/shells/xxh-shell-fish/`. This must happen before the build-dir symlinks in step 5, since the directory doesn't exist yet.

### 4. Create symlinks for local config

```sh
BASE=~/development/private/Laptop-MacOs/terminal

mkdir -p ~/.config/xxh ~/.config/fish/functions ~/.xxh

ln -sf $BASE/.config/xxh/config.xxhc                    ~/.config/xxh/config.xxhc
ln -sf $BASE/.config/starship.toml                       ~/.config/starship.toml
ln -sf $BASE/.config/fish/config.fish                    ~/.config/fish/config.fish
ln -sf $BASE/.config/fish/functions/fish_greeting.fish   ~/.config/fish/functions/fish_greeting.fish
ln -sf $BASE/.config/fish/functions/xxhc.fish            ~/.config/fish/functions/xxhc.fish
ln -sf $BASE/.xxh/ssh-wrapper.sh                         ~/.xxh/ssh-wrapper.sh
chmod +x ~/.xxh/ssh-wrapper.sh
```

### 5. Create symlinks into the xxh build dir

These two symlinks mean changes to `starship.toml` and `xxh-config.fish` in the repo are picked up automatically on the next connect — no manual copy needed.

```sh
ln -sf $BASE/.xxh/xxh-config.fish  ~/.xxh/.xxh/shells/xxh-shell-fish/build/xxh-config.fish
ln -sf $BASE/.config/starship.toml ~/.xxh/.xxh/shells/xxh-shell-fish/build/starship.toml
```

### 6. Download Linux static binaries

These are the Linux x86-64 binaries that get uploaded to remote hosts. They are not in git (too large).

```sh
mkdir -p ~/.xxh/bin

# starship
curl -fsSL $(curl -fsSL https://api.github.com/repos/starship-rs/starship/releases/latest \
  | grep "browser_download_url.*x86_64-unknown-linux-musl.tar.gz" | head -1 | cut -d'"' -f4) \
  | tar -xz -C /tmp && mv /tmp/starship ~/.xxh/bin/starship

# fastfetch (binary is at usr/bin/fastfetch inside the archive)
curl -fsSL $(curl -fsSL https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest \
  | grep "browser_download_url.*linux-amd64.tar.gz" | head -1 | cut -d'"' -f4) \
  | tar -xz -C /tmp && mv /tmp/fastfetch-linux-amd64/usr/bin/fastfetch ~/.xxh/bin/fastfetch

# atuin (binary is at atuin/atuin inside the archive)
curl -fsSL $(curl -fsSL https://api.github.com/repos/atuinsh/atuin/releases/latest \
  | grep "browser_download_url.*x86_64-unknown-linux-musl.tar.gz" | head -1 | cut -d'"' -f4) \
  | tar -xz -C /tmp && mv /tmp/atuin-x86_64-unknown-linux-musl/atuin ~/.xxh/bin/atuin

chmod +x ~/.xxh/bin/starship ~/.xxh/bin/fastfetch ~/.xxh/bin/atuin
```

### 7. Stage binaries in the xxh build dir

The build dir is what xxh uploads on every connect. Binaries are plain copies (not symlinks) because the source files are also Linux ELF binaries — there's nothing meaningful to gain from symlinking one to the other.

```sh
mkdir -p ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin
cp ~/.xxh/bin/starship  ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/starship
cp ~/.xxh/bin/fastfetch ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/fastfetch
cp ~/.xxh/bin/atuin     ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/atuin
chmod +x ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/*
```

---

## Updating

**Config files** (`starship.toml`, `xxh-config.fish`, `config.xxhc`, `xxhc.fish`, etc.) — edit the file in this repo. Symlinks make the change live immediately. The remote picks it up on the next connect.

**Binaries** — when you download a newer version of starship, fastfetch, or atuin, re-copy it to the build dir:

```sh
cp ~/.xxh/bin/starship  ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/starship
cp ~/.xxh/bin/fastfetch ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/fastfetch
cp ~/.xxh/bin/atuin     ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/atuin
```

---

## Connecting

```sh
xxhc myserver
```

Uploads ~90 MB, drops into fish. On exit, merges remote history into local atuin.

Pass extra xxh flags after the host name as normal:
```sh
xxhc myserver +vv    # verbose upload
```

---

## Uninstall

**Remote** — just disconnect. `+hhr` deletes `~/.xxh` automatically.
If you connected without `+hhr`: `ssh <host> "rm -rf ~/.xxh"`

**Local:**
```sh
pipx uninstall xxh-xxh
rm -rf ~/.xxh ~/.config/xxh
rm ~/.config/fish/functions/xxhc.fish ~/.config/fish/functions/fish_greeting.fish
# The remaining symlinks (starship.toml, config.fish) point into this repo —
# replace them with plain files if you want to keep those configs independently.
```
