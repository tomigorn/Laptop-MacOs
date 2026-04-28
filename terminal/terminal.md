# Terminal setup

Local Mac shell (fish + starship + fastfetch + atuin) plus a portable environment that carries fish, starship, and fastfetch to remote hosts over SSH without installing anything on them.

---

## Local setup (Mac)

Fish shell with starship prompt, fastfetch greeting, and atuin for shell history.

**Tools** (all via Homebrew):
- `fish` — shell
- `starship` — prompt (macOS binary, used locally only)
- `fastfetch` — system info greeting on shell open (macOS binary locally, Linux binary on remote)
- `atuin` — shell history with search (up arrow and Ctrl-R)

**Local fish config** (`.config/fish/config.fish`):
```fish
starship init fish | source
atuin init fish | source
```

**Greeting** (`.config/fish/functions/fish_greeting.fish`):
```fish
function fish_greeting
    fastfetch
end
```

Shows OS, CPU, memory, uptime on every new shell. Works identically on macOS locally and Linux remotely — fastfetch auto-detects the system and shows the correct distro logo and info. All fastfetch cache and config go to `$XDG_CACHE_HOME` / `$XDG_CONFIG_HOME`, which are redirected into `~/.xxh/` on remote and wiped on disconnect.

On remote sessions the greeting also prints the total time taken to connect and upload before the fastfetch output:

```
  Connected in 14.3s

[fastfetch output]
```

---

## Remote setup via xxh

[xxh](https://github.com/xxh/xxh) carries a self-contained shell to any SSH host without installing anything permanently. On connect it uploads a bundle via SCP, starts a fish session inside it, and on disconnect removes everything.

### What happens on connect (~61 MB uploaded every time)

- `~/.xxh/` is created on the remote
- Portable fish binary, static Linux starship and fastfetch binaries, starship config, and fish session config are uploaded
- `HOME` is your real remote home (e.g. `/home/tomigorn`) — nothing lands in it
- All XDG dirs (`XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`) are redirected into `~/.xxh/` so fish configs and history never touch the real home
- The SSH alias you typed (e.g. `myserver`) is forwarded as `$XXH_SSH_ALIAS` so the prompt can show it
- A start timestamp is forwarded as `$XXH_CONNECT_START` so the greeting can display total connection time

### What happens on disconnect

- `~/.xxh/` is deleted entirely
- `.bashrc`, `.bash_profile`, `.profile` are never touched
- No binaries left in `PATH`, no processes left running

### Prompt on the remote

```
tomigorn @ remote-host (myserver) ~
›
```

| Part | Meaning | When shown |
|---|---|---|
| `tomigorn` | username (green) | always |
| `@ remote-host` | real hostname (yellow) | SSH sessions only |
| `(myserver)` | SSH alias used to connect (blue) | via `xxhc` only |
| `~` | current directory | always |

---

## File layout

All config lives in this directory (`terminal/`) and is **symlinked** from its real home path. Editing any file here takes effect immediately — no copying needed.

```
terminal/
  terminal.md                        this file

  .config/
    xxh/config.xxhc                  xxh connection settings
    starship.toml                    starship prompt config
    fish/
      config.fish                    local Mac fish init
      functions/xxhc.fish            xxh connect wrapper
      functions/fish_greeting.fish   fastfetch greeting on shell open

  .xxh/
    ssh-wrapper.sh                   forces ControlMaster=no for SCP compat
    xxh-config.fish                  fish session init on the remote
```

**Symlinks** (set up once, then transparent):

```
~/.config/xxh/config.xxhc                              → terminal/.config/xxh/config.xxhc
~/.config/starship.toml                                 → terminal/.config/starship.toml
~/.config/fish/config.fish                              → terminal/.config/fish/config.fish
~/.config/fish/functions/xxhc.fish                      → terminal/.config/fish/functions/xxhc.fish
~/.config/fish/functions/fish_greeting.fish             → terminal/.config/fish/functions/fish_greeting.fish
~/.xxh/ssh-wrapper.sh                                   → terminal/.xxh/ssh-wrapper.sh
~/.xxh/.xxh/shells/xxh-shell-fish/build/xxh-config.fish → terminal/.xxh/xxh-config.fish
~/.xxh/.xxh/shells/xxh-shell-fish/build/starship.toml   → terminal/.config/starship.toml
```

The last two mean that editing `starship.toml` or `xxh-config.fish` here also immediately updates what gets uploaded to the remote on the next connect.

**Not in git** (Linux binaries, too large):
```
~/.xxh/bin/starship     static Linux x86-64 starship binary (source)
~/.xxh/bin/fastfetch    static Linux x86-64 fastfetch binary (source)
~/.xxh/bin/atuin        staged for future use

~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/starship    copied from source, uploaded to remote
~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/fastfetch   copied from source, uploaded to remote
```

The build dir binaries are plain copies — the one thing that needs a manual update when either binary changes (see [Updating](#updating)).

---

## xxh config explained

`.config/xxh/config.xxhc`:
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

| Option | Effect |
|---|---|
| `+s: xxh-shell-fish` | Use the portable fish shell plugin |
| `++pexpect-timeout: "30"` | Wait up to 30 s for the remote to respond during handshake |
| `++copy-method: scp` | Use SCP instead of rsync (rsync conflicts with ControlMaster) |
| `+if:` | Always upload without prompting — needed because `+hhr` wipes the remote on every disconnect, which would otherwise trigger an "Install? [Y/n]" prompt every time |
| `+hhh: "~"` | Set `HOME` to the real remote home, not `~/.xxh` |
| `+hhr:` | Delete `~/.xxh` on the remote after disconnect |
| `-o ControlMaster=no` | Prevent SSH multiplexing conflicts |

---

## xxhc wrapper explained

`.config/fish/functions/xxhc.fish`:
```fish
function xxhc
    set -l target $argv[1]
    set -l start $EPOCHREALTIME
    env RSYNC_RSH=~/.xxh/ssh-wrapper.sh xxh $target \
        +e "XXH_SSH_ALIAS=$target" \
        +e "XXH_CONNECT_START=$start" \
        $argv[2..-1]
end
```

- Sets `RSYNC_RSH` so rsync (if ever used) bypasses ControlMaster
- Records `$EPOCHREALTIME` before connecting and forwards it as `XXH_CONNECT_START` — the remote greeting subtracts this from the remote clock to show total connection time
- Passes the SSH alias as `XXH_SSH_ALIAS` so starship can display it
- Forwards any extra xxh flags: `xxhc myserver +vv` works as expected

---

## Performance

Benchmarked on local network with `time xxhc myserver +hc "echo ok"`:

```
Executed in   15.36 secs
```

Nearly all of that is the SCP upload (~61 MB: fish-portable 39 MB + starship 12 MB + fastfetch 10 MB). The session starts in under a second once files are in place. This cost is unavoidable with `+hhr` — every connect is a cold upload.

---

## Setup on a new machine

```sh
git clone <repo> ~/development/private/Laptop-MacOs
cd ~/development/private/Laptop-MacOs/terminal
./setup.sh
```

The script installs Homebrew if missing, then fish/starship/fastfetch/atuin/pipx via brew, xxh and the fish plugin, creates all symlinks, downloads the Linux static binaries (starship, fastfetch) into `~/.xxh/bin/`, and stages them in the xxh build dir. Safe to re-run.

<details>
<summary>Manual steps (if you prefer not to run the script)</summary>

```sh
# 1. clone
git clone <repo> ~/development/private/Laptop-MacOs

# 2. install local tools
brew install fish starship fastfetch atuin
pipx install xxh-xxh
xxh +I xxh-shell-fish

# 3. create symlinks
BASE=~/development/private/Laptop-MacOs/terminal

mkdir -p ~/.config/xxh ~/.config/fish/functions ~/.xxh

ln -sf $BASE/.config/xxh/config.xxhc          ~/.config/xxh/config.xxhc
ln -sf $BASE/.config/starship.toml             ~/.config/starship.toml
ln -sf $BASE/.config/fish/config.fish          ~/.config/fish/config.fish
ln -sf $BASE/.config/fish/functions/xxhc.fish          ~/.config/fish/functions/xxhc.fish
ln -sf $BASE/.config/fish/functions/fish_greeting.fish ~/.config/fish/functions/fish_greeting.fish
ln -sf $BASE/.xxh/ssh-wrapper.sh                       ~/.xxh/ssh-wrapper.sh

# 4. symlink into the xxh build dir (makes edits here apply to remote uploads instantly)
ln -sf $BASE/.xxh/xxh-config.fish  ~/.xxh/.xxh/shells/xxh-shell-fish/build/xxh-config.fish
ln -sf $BASE/.config/starship.toml ~/.xxh/.xxh/shells/xxh-shell-fish/build/starship.toml

# 5. download static Linux x86-64 binaries into ~/.xxh/bin/
#    starship  → github.com/starship/starship/releases    (starship-x86_64-unknown-linux-musl.tar.gz)
#    fastfetch → github.com/fastfetch-cli/fastfetch/releases  (fastfetch-linux-amd64.tar.gz, binary at usr/bin/fastfetch)
#    atuin     → github.com/atuinsh/atuin/releases
mkdir -p ~/.xxh/bin
chmod +x ~/.xxh/bin/starship ~/.xxh/bin/fastfetch ~/.xxh/bin/atuin

# 6. copy starship binary into the xxh build dir (uploaded to remote on connect)
mkdir -p ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin
cp ~/.xxh/bin/starship  ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/starship
cp ~/.xxh/bin/fastfetch ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/fastfetch
chmod +x ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/starship
chmod +x ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/fastfetch
```

</details>

---

## Updating

**Config files** (`starship.toml`, `xxh-config.fish`, `config.xxhc`, etc.): just edit the file in this directory. Symlinks make the change live immediately. The remote picks it up on the next connect.

**Binaries** (plain copies, not symlinks — update both when either changes):
```sh
cp ~/.xxh/bin/starship  ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/starship
cp ~/.xxh/bin/fastfetch ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/fastfetch
```

---

## Uninstall

**Remote** — just disconnect. `+hhr` deletes `~/.xxh` automatically.
If you connected without `+hhr`: `ssh <host> "rm -rf ~/.xxh"`

**Local:**
```sh
pipx uninstall xxh-xxh
rm -rf ~/.xxh ~/.config/xxh
rm ~/.config/fish/functions/xxhc.fish
# remove symlinks and restore starship.toml / config.fish to plain files if keeping them
```
