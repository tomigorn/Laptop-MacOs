# Terminal setup

Fish shell on the Mac, plus a portable environment that SSH-connects to any remote host with the same shell, prompt, and history — without installing anything on the remote and without leaving any trace when you disconnect.

---

## What this is

The setup has two parts:

**Local (Mac):** fish shell with starship prompt, fastfetch system info greeting, and atuin for searchable shell history.

**Remote (via xxh):** when you run `xxhc hostname`, the tool [xxh](https://github.com/xxh/xxh) uploads a self-contained bundle to the remote over SCP — portable fish binary, starship, fastfetch, atuin, bat, and all config — starts a fish session inside it, and on disconnect removes everything. The remote host never gets a modified `.bashrc`, no binaries persist in `PATH`, and `~/.xxh/` is deleted the moment you exit. Remote shell history is merged back into your local atuin database before cleanup, tagged with the remote hostname so you can tell where each command ran.

---

## Architecture: why it works this way

**Why xxh instead of `ssh host bash`?**
Plain SSH gives you whatever shell the remote has, with none of your config. xxh carries the entire shell as a self-contained bundle, so you get the same experience everywhere regardless of what the host has installed.

**Why fish?**
Fish has excellent interactive features (completions, syntax highlighting, history) and a clean config model. We upload a portable static fish binary (official fish 4.x `linux-<arch>` build — a single self-contained executable with functions/completions embedded), so it runs on any Linux host without being installed.

**Why SCP instead of rsync?**
SSH ControlMaster multiplexing (used for fast repeated connections) conflicts with how xxh calls rsync internally. Using SCP avoids this entirely.

**Why wipe on disconnect?**
The remotes are shared admin accounts used by multiple people. Nothing should be left behind — no history, no binaries, no config. The cost is re-uploading ~73 MB on every connect.

**Why symlinks for config files?**
All config lives in this git directory (`terminal/`). The real paths (`~/.config/starship.toml`, etc.) are symlinks pointing here. This means editing a file in the repo takes effect immediately with no copy step, and git is always the source of truth. Without symlinks you'd have two copies that drift apart.

**Why per-architecture binary stores?**
The bundled binaries are native Linux ELF executables. An x86_64 binary cannot run on an ARM host (Raspberry Pi) and vice versa — it fails at exec time with `Exec format error`, even though the scp upload itself succeeds. So we keep one store per architecture under `~/.xxh/arch/<arch>/` (`x86_64`, `aarch64`), each holding fish plus starship/atuin/bat/fastfetch built for that arch. On connect, `xxhc` runs `uname -m` on the remote (over the ControlMaster tunnel) and copies the matching store into the upload directory before xxh sends it. See "Multi-architecture support" below.

**Why are binaries plain copies instead of symlinks?**
The binaries in `~/.xxh/.xxh/shells/xxh-shell-fish/build/` are staged copies of the arch-specific sources in `~/.xxh/arch/<arch>/`. They're the same Linux ELF files; `xxhc` overwrites them on every connect with the arch matching the remote, so a plain copy (not a symlink) is the natural fit.

---

## Local setup (Mac)

**Tools** (all via Homebrew):
- `fish` — shell
- `starship` — prompt (macOS binary, local only)
- `fastfetch` — system info on every new shell (macOS binary locally, Linux binary on remote)
- `atuin` — shell history with fuzzy search; up arrow and Ctrl-R open the TUI
- `bat` — syntax-highlighting file viewer (`cat` replacement); macOS binary locally, Linux binary on remote

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
- `custom.local` shows a bold yellow label (currently `!! local MacOS !!`) only when `$SSH_CONNECTION` is unset — appears on the Mac, invisible on every remote host, making it immediately clear where you are
- `hostname` is `ssh_only = true` — the `@ hostname` part only appears on SSH sessions, not locally
- `env_var.XXH_SSH_ALIAS` only renders when `$XXH_SSH_ALIAS` is set, which only happens via `xxhc` — so `(myserver)` never clutters the local prompt
- `git_status` uses full-word labels (`!modified`, `?untracked`, etc.) instead of symbols alone for clarity

---

## Remote setup via xxh

### Multi-architecture support

The uploaded binaries are native Linux executables, so they must match the remote CPU. `xxhc` handles this automatically:

1. After establishing the ControlMaster tunnel, it runs `uname -m` on the remote (reuses the tunnel, effectively instant).
2. It maps the result to a supported architecture — `x86_64`/`amd64` → `x86_64`, `aarch64`/`arm64` → `aarch64`.
3. It copies the matching store from `~/.xxh/arch/<arch>/` into the xxh upload directory, replacing the previous arch's binaries. The config symlinks (`xxh-config.fish`, `starship.toml`) are left untouched.
4. xxh then uploads and runs as usual.

An unknown or undetectable architecture aborts with a clear message and **no upload** — better than shipping binaries that die with `Exec format error` on the remote.

**Binary vs config:** every *binary* (`fish`, `starship`, `atuin`, `bat`, `fastfetch`) is architecture-specific and lives in the per-arch store. Every *config file* (`starship.toml`, `xxh-config.fish`, atuin config) is shared across all hosts and architectures.

**fish source:** fish is the official `fish-shell` 4.x `linux-<arch>` release — a single self-contained binary (functions/completions embedded, no `share/` tree), available for both `x86_64` and `aarch64`. This replaced `xxh/fish-portable`, which only ever published x86_64.

**Known limitation:** the upload directory is shared, so running `xxhc` to two different-architecture hosts *simultaneously* can race on staging. Single-user interactive use makes this unlikely; no locking is in place.

### What gets uploaded on connect (~73 MB every time)

| File | Size | Purpose |
|---|---|---|
| `fish-portable/bin/fish` | ~14 MB | Single self-contained fish 4.x binary, runs on any Linux |
| `atuin` | ~30 MB | Shell history with search |
| `starship` | ~12 MB | Prompt binary |
| `fastfetch` | ~10 MB | System info greeting |
| `bat` | ~7 MB | Syntax-highlighting file viewer |
| `xxh-config.fish`, `starship.toml`, entrypoint | <1 MB | Config and session bootstrap |

The upload happens on every connect because the remote is always wiped on disconnect — there's nothing to reuse.

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
| `!! local MacOS !!` | local machine indicator | bold yellow | local only (hidden on SSH) |
| `tomigorn` | username | green | always |
| `@ remote-host` | real hostname of the remote | yellow | SSH sessions only |
| `(myserver)` | SSH alias you typed | blue | via `xxhc` only |
| `~` | current directory | cyan | always |

### What gets cleaned up on disconnect

- `fish/generated_completions/` — removed by the `fish_exit` handler to avoid NFS stub file issues
- `~/.xxh/` — deleted by the `_xxhc_cleanup_home` `fish_exit` handler on the remote (see below); `xxhc` also runs an explicit `rm -rf ~/.xxh` via SSH after the session as a backup
- `/tmp/.xxh_atuin_*` — removed by `xxhc` after the history merge completes
- `.bashrc`, `.bash_profile`, `.profile` — never touched
- No binaries left in `PATH`, no background processes

**Why two cleanup paths for `~/.xxh/`?** The `_xxhc_cleanup_home` fish handler is the primary cleanup: it runs on both clean exit and SIGHUP (VPN drop, terminal crash, lost connection), because the remote sshd sends SIGHUP to the fish process as soon as it detects the connection is dead. `xxhc` also runs an explicit `ssh … "rm -rf ~/.xxh"` after the session returns as a fallback for the rare case where fish is SIGKILL'd without firing `fish_exit`. Note: previously xxh's `+hhr` flag was used for a second pass, but it ran its own `chmod -R u+w ~/.xxh && rm -rf` *after* the fish handler had already deleted the directory, producing a spurious `chmod: cannot access … No such file or directory` error on every exit.

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
# per-architecture binary stores (sources) — one set per remote arch
~/.xxh/arch/x86_64/fish-portable/bin/{fish,fish.sh}      official fish 4.x, x86_64
~/.xxh/arch/x86_64/bin/{starship,atuin,bat,fastfetch}    x86_64 static binaries
~/.xxh/arch/aarch64/fish-portable/bin/{fish,fish.sh}     official fish 4.x, aarch64
~/.xxh/arch/aarch64/bin/{starship,atuin,bat,fastfetch}   aarch64 static binaries

~/.xxh/history/<alias>.db    per-host atuin history, grows across sessions

# xxh upload directory — xxhc overwrites these on every connect with the
# arch matching the remote (uname -m). Plain copies of the store above.
~/.xxh/.xxh/shells/xxh-shell-fish/build/fish-portable/bin/{fish,fish.sh}
~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/{starship,atuin,bat,fastfetch}
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
    -o:
      - ForwardAgent=yes
      - ControlMaster=auto
      - ControlPath=~/.ssh/cm/xxh-%n
      - ServerAliveInterval=15
      - ServerAliveCountMax=3
```

| Option | Effect | Why |
|---|---|---|
| `+s: xxh-shell-fish` | Use the portable fish plugin | Carries fish to any Linux host |
| `++pexpect-timeout: "30"` | Wait up to 30 s during handshake | Some hosts are slow to respond |
| `++copy-method: scp` | Use SCP for uploads | rsync conflicts with ControlMaster |
| `+if:` | Always upload without prompting | `xxhc` wipes `~/.xxh` on disconnect, so xxh would ask "Install? [Y/n]" every time without this |
| `+hhh: "~"` | Set `HOME` to real remote home | Without this, `HOME` is set to `~/.xxh` and `cd ~` lands in the wrong place |
| `-o ForwardAgent=yes` | Forward the local ssh-agent to the remote session | Without it `$SSH_AUTH_SOCK` is empty on the remote, so onward hops (e.g. `ssh opennebula`) and key-dependent commands re-prompt for the key passphrase every time. Must also be set on the pre-created ControlMaster tunnel — all sessions multiplex over it |
| `-o ControlMaster=auto` | Reuse existing ControlMaster socket | `xxhc` pre-creates the socket before xxh runs, so xxh's internal SCP reuses the already-established tunnel — critical for hosts behind ProxyJump |
| `-o ControlPath=~/.ssh/cm/xxh-%n` | Dedicated socket path for xxh connections | Uses a separate path from regular SSH sockets (which use `%r@%h:%p`) to avoid conflicts |
| `-o ServerAliveInterval=15` | Local SSH client probes server every 15 s | Detects dead connections on flaky networks; causes the local client to exit within 45 s rather than hanging indefinitely |
| `-o ServerAliveCountMax=3` | Give up after 3 unanswered probes (45 s) | Works with `ServerAliveInterval` to bound how long a broken session idles before the local side gives up |

### `fish/functions/xxhc.fish`

```fish
function xxhc --description "xxh with SSH alias forwarded to remote prompt"
    set -l target $argv[1]
    set -l host_db ~/.xxh/history/$target.db
    set -l remote_preseed /tmp/.xxh_atuin_pre_$target.db
    set -l remote_db /tmp/.xxh_atuin_$target.db
    set -l local_db ~/.local/share/atuin/history.db
    set -l tmp_db /tmp/.xxh_atuin_$target\_local.db
    set -l cm_path ~/.ssh/cm/xxh-$target

    # Establish a ControlMaster tunnel before anything else.
    # This handles ProxyJump (and any other SSH config) once upfront so all
    # subsequent SSH/SCP calls — including xxh's own bundle upload — reuse the
    # same connection. Without this, every operation creates a fresh tunnel
    # through the jump host, which is slow and can fail for hosts behind ProxyJump.
    mkdir -p ~/.ssh/cm
    # ForwardAgent=yes so the remote session (and onward hops) can use the local
    # ssh-agent. All multiplexed sessions ride this master, so forwarding must be
    # enabled here or $SSH_AUTH_SOCK stays empty on the remote.
    ssh -o ForwardAgent=yes -o ControlMaster=auto -o ControlPath=$cm_path -fN -o ConnectTimeout=30 $target 2>/dev/null

    # Pre-seed remote with this host's accumulated history.
    # Validate it has a history table, then send a clean WAL-free single-file copy.
    if test -f $host_db
        set -l has_table (sqlite3 $host_db "SELECT name FROM sqlite_master WHERE type='table' AND name='history';" 2>/dev/null)
        if test "$has_table" = history
            set -l clean_preseed /tmp/.xxh_atuin_pre_clean_$target.db
            sqlite3 $host_db "VACUUM INTO '$clean_preseed';" 2>/dev/null
            and scp -q -o ControlMaster=auto -o ControlPath=$cm_path $clean_preseed "$target:$remote_preseed" 2>/dev/null
            rm -f $clean_preseed
        end
    end

    set -l start (date +%s)
    env RSYNC_RSH=~/.xxh/ssh-wrapper.sh xxh $target \
        +e "TERM=xterm-256color" \
        +e "XXH_SSH_ALIAS=$target" \
        +e "XXH_CONNECT_START=$start" \
        $argv[2..-1]

    # Belt-and-suspenders: remove ~/.xxh if the fish_exit handler didn't (e.g. fish was SIGKILL'd).
    ssh -q -o ControlMaster=auto -o ControlPath=$cm_path $target "rm -rf ~/.xxh 2>/dev/null" 2>/dev/null

    # Retrieve remote atuin DB — fetch main file plus WAL files.
    # atuin uses SQLite WAL mode: recent writes live in the -wal file, not the
    # main .db file. Without the WAL files, the DB appears empty.
    if scp -q -o ControlMaster=auto -o ControlPath=$cm_path "$target:$remote_db" $tmp_db 2>/dev/null
        scp -q -o ControlMaster=auto -o ControlPath=$cm_path "$target:$remote_db-wal" $tmp_db-wal 2>/dev/null
        scp -q -o ControlMaster=auto -o ControlPath=$cm_path "$target:$remote_db-shm" $tmp_db-shm 2>/dev/null

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

        ssh -q -o ControlMaster=auto -o ControlPath=$cm_path $target \
            "rm -f $remote_db $remote_db-wal $remote_db-shm $remote_preseed" 2>/dev/null
        rm -f $tmp_db $tmp_db-wal $tmp_db-shm
    end

    # Verify ~/.xxh was removed — warn loudly if anything is left behind
    if ssh -q -o ControlMaster=auto -o ControlPath=$cm_path -o ConnectTimeout=10 $target "test -d ~/.xxh" 2>/dev/null
        set_color --bold red
        echo ""
        echo "  ╔══════════════════════════════════════════════════════════════╗"
        echo "  ║                    CLEANUP FAILURE                           ║"
        echo "  ║                                                              ║"
        printf "  ║  ~/.xxh was NOT removed on %-34s║\n" "$target "
        echo "  ║  Other users on this shared host can see your files.         ║"
        echo "  ║                                                              ║"
        printf "  ║  Fix now:  ssh %s \"rm -rf ~/.xxh\"\n" $target
        echo "  ║                                                              ║"
        echo "  ╚══════════════════════════════════════════════════════════════╝"
        echo ""
        set_color normal
    end

    # Tear down the ControlMaster now that all operations are done
    ssh -q -o ControlPath=$cm_path -O stop $target 2>/dev/null

    # Print the local greeting so it's unmistakable you're back on the Mac
    # (the remote session shows the remote's fastfetch; this shows the local one).
    if functions -q fish_greeting
        echo ""
        fish_greeting
    end
end
```

- **ControlMaster pre-setup**: before anything else, `xxhc` creates a ControlMaster tunnel (`ssh -fN`) to the target at `~/.ssh/cm/xxh-<alias>`. This handles ProxyJump (and any SSH config) once upfront. All subsequent SSH/SCP calls — including xxh's ~73 MB bundle upload — reuse this socket. Without this, each operation creates a fresh jump-host connection, which is slow and can fail silently for hosts behind ProxyJump.
- `TERM=xterm-256color` — set via `+e` so the remote fish process sees the correct terminal type *before it starts*, preventing the "unknown terminal type" warning. Ghostty (and other modern terminals) export a `$TERM` value the remote has no terminfo for; fish checks this at startup, before any config file runs, so setting it inside `xxh-config.fish` is too late.
- `RSYNC_RSH` — ensures rsync bypasses ControlMaster if ever called internally by xxh
- `XXH_SSH_ALIAS` — the alias you typed; forwarded to the remote so the prompt shows `(myserver)`
- `XXH_CONNECT_START` — Unix timestamp before connecting; remote greeting subtracts it to show total connection time
- **Pre-seed**: before xxh runs, if `~/.xxh/history/<alias>.db` exists and has a history table, a clean WAL-free copy is SCP'd to `remote:/tmp/` for atuin to load at startup
- **WAL handling**: atuin uses SQLite WAL mode so recent writes are in `-wal` not the main file; all three files are fetched, then `PRAGMA wal_checkpoint(FULL)` merges WAL into main file before any reads
- **Host DB**: per-host history is accumulated in `~/.xxh/history/<alias>.db` and grows across sessions
- **Cleanup check**: after everything, SSHs back to verify `~/.xxh` is gone; shows a red warning box if not
- **ControlMaster teardown**: at the very end, `ssh -O stop` closes the ControlMaster socket cleanly
- **Local greeting on return**: after teardown, `fish_greeting` (local fastfetch) is printed so it's unmistakable you're back on the Mac — the remote session shows the remote's banner, this shows the local one

### `xxh/xxh-config.fish`

The fish session init that runs on the remote. In order:

1. **TERM override** — sets `TERM=xterm-256color` as a fallback for direct `xxh` use. When connecting via `xxhc`, `TERM` is already set correctly via `+e` before fish starts (see `xxhc.fish`), so this line is a no-op in normal usage.
2. **PATH** — adds the uploaded `bin/` dir so starship, fastfetch, atuin, and bat are all in PATH
3. **Starship** — sets `STARSHIP_CONFIG` and initialises the prompt
4. **Greeting** — defines `fish_greeting` to print connection time (from `XXH_CONNECT_START`) then run fastfetch
5. **Atuin** — if a preseed file exists at `/tmp/.xxh_atuin_pre_<alias>.db`, copies it into `$XDG_DATA_HOME/atuin/history.db` before atuin starts so previous session history is available immediately. Then writes a minimal config and initialises atuin.
6. **`fish_exit` handlers** — two handlers registered in definition order:
   - `_xxhc_export_history`: copies the atuin DB and its WAL/SHM files to `/tmp/` so `xxhc` can retrieve them after the session ends; also removes `fish/generated_completions` to prevent NFS stub files from interfering with `_xxhc_cleanup_home`
   - `_xxhc_cleanup_home`: removes `~/.xxh/` immediately so other users on the shared host cannot see it even if the local machine is completely gone (VPN drop, terminal crash, etc.). Safe to delete while running: open file descriptors hold the inodes alive until fish actually exits, so no binary is interrupted mid-execution.

The atuin config written on each connect:
```toml
auto_sync = false
search_mode = "fuzzy"
```
`auto_sync = false` prevents atuin from contacting any external server — important on shared hosts where network behaviour is unpredictable.

**NFS cleanup note:** On NFS-mounted home directories (common in university/enterprise environments), fish generates shell completions asynchronously. When those files are open, deleting them creates invisible `.nfsXXXX` stub files that leave the directory non-empty, which would cause `rm -rf ~/.xxh` to fail. The `_xxhc_export_history` handler pre-emptively removes `$XDG_DATA_HOME/fish/` while fish is still running (so the stubs are created and immediately owned by the same process) before `_xxhc_cleanup_home` removes `~/.xxh/`.

---

## Performance

A cold connect is dominated by the SCP upload. On a fast campus link this is ~6 s; on slower links closer to ~15 s.

Breakdown: fish 14 MB + atuin 30 MB + starship 12 MB + fastfetch 10 MB + bat 7 MB = ~73 MB uploaded over SCP on every connect. The session itself starts in under a second once files are in place. Every connect is a cold upload (the remote is wiped on disconnect).

**Why fish 4.x sped this up beyond the size drop:** the old `xxh/fish-portable` was a *directory tree of hundreds of small files* (`share/fish/completions/*`, `functions/*`, …). SCP transfers those one at a time, and the per-file round-trips dominated the upload. The official fish 4.x build is a **single self-contained binary**, so fish now uploads as one ~14 MB transfer instead of hundreds of tiny ones — fewer bytes *and* far fewer round-trips.

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

### 6. Download Linux static binaries (per architecture)

`setup.sh` does this automatically for both `x86_64` and `aarch64`, downloading fish (official `fish-shell` 4.x `linux-<arch>` single-binary build) plus starship/atuin/bat/fastfetch into `~/.xxh/arch/<arch>/`. The binaries are not in git (too large).

To do it by hand, run the `build_arch_store` helper from `setup.sh` for each arch, or replicate its layout:

```
~/.xxh/arch/<arch>/fish-portable/bin/fish        # from fish-shell release linux-<arch>.tar.xz (single binary)
~/.xxh/arch/<arch>/fish-portable/bin/fish.sh     # the 3-line TERMINFO wrapper the entrypoint launches
~/.xxh/arch/<arch>/bin/starship                  # starship/starship, <triple>.tar.gz
~/.xxh/arch/<arch>/bin/atuin                     # atuinsh/atuin, atuin-<triple>.tar.gz
~/.xxh/arch/<arch>/bin/bat                        # sharkdp/bat, <triple>.tar.gz (version in dir name)
~/.xxh/arch/<arch>/bin/fastfetch                  # fastfetch-cli/fastfetch, linux-<label>.tar.gz
```

where `<arch>`/`<triple>`/`<label>` are `x86_64`/`x86_64-unknown-linux-musl`/`amd64` and `aarch64`/`aarch64-unknown-linux-musl`/`aarch64`. The `fish.sh` wrapper is:

```sh
#!/bin/sh
export TERMINFO_DIRS=/lib/terminfo:/etc/terminfo:/usr/share/terminfo:$TERMINFO_DIRS
CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"
$CURRENT_DIR/fish "$@"
```

### 7. Stage a default arch in the xxh build dir

`xxhc` overwrites the build dir with the correct arch on every connect (see "Multi-architecture support"), but staging one arch as a default keeps a bare `xxh <host>` (without `xxhc`) working:

```sh
build=~/.xxh/.xxh/shells/xxh-shell-fish/build
rm -rf "$build/fish-portable" "$build/bin"
cp -R ~/.xxh/arch/x86_64/fish-portable "$build/fish-portable"
cp -R ~/.xxh/arch/x86_64/bin "$build/bin"
```

---

## Updating

**Config files** (`starship.toml`, `xxh-config.fish`, `config.xxhc`, `xxhc.fish`, etc.) — edit the file in this repo. Symlinks make the change live immediately. The remote picks it up on the next connect.

**Binaries** — re-run `setup.sh`. It skips binaries that already exist, so to pick up a newer version first delete the ones you want refreshed (e.g. `rm ~/.xxh/arch/*/bin/starship`), then run `setup.sh` again. It repopulates both architecture stores; `xxhc` stages the right one on the next connect.

---

## Connecting

```sh
xxhc myserver
```

Uploads ~73 MB, drops into fish. On exit, merges remote history into local atuin.

Pass extra xxh flags after the host name as normal:
```sh
xxhc myserver +vv    # verbose upload
```

---

## Uninstall

**Remote** — just disconnect. `xxhc` deletes `~/.xxh` automatically (via the remote fish handler and an explicit SSH cleanup). If cleanup fails for any reason: `ssh <host> "rm -rf ~/.xxh"`

**Local:**
```sh
pipx uninstall xxh-xxh
rm -rf ~/.xxh ~/.config/xxh
rm ~/.config/fish/functions/xxhc.fish ~/.config/fish/functions/fish_greeting.fish
# The remaining symlinks (starship.toml, config.fish) point into this repo —
# replace them with plain files if you want to keep those configs independently.
```
