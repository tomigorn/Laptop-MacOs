# Virt-Manager on macOS

Run [virt-manager](https://virt-manager.org/) — the GTK GUI for libvirt/QEMU
virtual machines — natively on macOS, launchable from Spotlight, Launchpad
or the dock.

This setup is partly derived from
[Arthur Koziel's guide](https://www.arthurkoziel.com/running-virt-manager-and-libvirt-on-macos/),
but updated to match what's actually needed on macOS 15 / Apple Silicon in
2025: virt-manager is in `homebrew/core` so the custom tap is no longer
required, and a small `.app` wrapper replaces the "launch from a terminal
with `--no-fork`" step from the blog.

---

## What's installed

| Component | Source | Why |
|---|---|---|
| `libvirt` | `brew` (homebrew/core) | Daemon + CLI for managing local QEMU VMs |
| `virt-manager` | `brew` (homebrew/core) | GTK GUI; talks to libvirt over `qemu:///session` |
| `~/Applications/Virt-Manager.app` | built by [`build.sh`](build.sh) | Spotlight/dock-launchable wrapper |
| Fish `XDG_DATA_DIRS` export | `terminal/.config/fish/config.fish` | Lets virt-manager find its GSettings schemas |

Dependencies pulled automatically by Homebrew: `qemu`, `gtk+3`, `gtk4`,
`gtksourceview4`, `gtk-vnc`, `spice-gtk`, `adwaita-icon-theme`, `gettext`,
`libvirt-glib`, `libvirt-python`.

Not installed (and not needed for the use cases here):
- `virt-viewer` — only needed if you want the standalone SPICE/VNC viewer
  instead of the one built into virt-manager. Install with
  `brew install virt-viewer` if you want it.
- `arthurk/virt-manager` tap — historically the blog used this tap to
  install virt-manager because homebrew/core didn't ship it. Today it does,
  so the tap is unused. If it's lingering on the machine, `brew untap
  arthurk/virt-manager` cleans it up.

---

## Architecture: why this works the way it does

**Why a `.app` wrapper?**
GUI apps launched from Spotlight/Finder/Launchpad inherit a minimal
environment — no Homebrew `PATH`, no `XDG_DATA_DIRS`. virt-manager is a GTK
app and aborts at startup unless `XDG_DATA_DIRS` includes
`/opt/homebrew/share` so it can find its compiled GSettings schemas. From a
fish terminal it works because [`terminal/.config/fish/config.fish`](../terminal/.config/fish/config.fish)
exports that var. The `.app` wrapper sets the same vars before `exec`-ing
the real binary, so Spotlight-launched virt-manager and fish-launched
virt-manager behave identically.

**Why `qemu:///session` instead of `qemu:///system`?**
The blog and the Linux defaults assume system-level libvirt running as
root. On macOS Homebrew runs libvirtd as the current user via a
`LaunchAgent`, so VMs live in the per-user session — `qemu:///session`. No
polkit, no socket-group dance, no `sudo`. This is also virt-manager's
default URI when no `-c` flag is passed.

**Why symlinks, not copies, inside the `.app`?**
`Virt-Manager.app/Contents/MacOS/virt-manager-launcher` and
`Virt-Manager.app/Contents/Info.plist` are symlinks back to the files in
this directory. Edits to [`launcher.sh`](launcher.sh) or
[`Info.plist`](Info.plist) in the repo take effect the next time the app
starts — same convention as `terminal/`. The icon (`AppIcon.icns`) is a
generated artifact and stays as a real file inside the bundle.

**Why is the libvirt service a per-user LaunchAgent?**
`brew services start libvirt` writes
`~/Library/LaunchAgents/homebrew.mxcl.libvirt.plist`, which runs
`/opt/homebrew/opt/libvirt/sbin/libvirtd` as you (not root) at login. The
session socket lands at `~/.cache/libvirt/libvirt-sock`, matching the
`qemu:///session` URI.

---

## File layout

```
virt-manager/
  virt-manager.md   this file
  install.sh        full setup for a new Mac (brew + service + .app)
  build.sh          (re)builds ~/Applications/Virt-Manager.app
  launcher.sh       sets env, execs virt-manager — symlinked into the .app
  Info.plist        bundle manifest — symlinked into the .app
```

### Symlinks created by `build.sh`

```
~/Applications/Virt-Manager.app/Contents/MacOS/virt-manager-launcher
    → virt-manager/launcher.sh
~/Applications/Virt-Manager.app/Contents/Info.plist
    → virt-manager/Info.plist
```

Edit the source files in the repo; no copy step needed.

### Generated artifacts (not symlinked)

```
~/Applications/Virt-Manager.app/Contents/Resources/AppIcon.icns
    built from /opt/homebrew/share/icons/hicolor/256x256/apps/virt-manager.png
~/Applications/Virt-Manager.app/Contents/PkgInfo
    static 8-byte file "APPL????"
```

### Managed by Homebrew (not by this repo)

```
~/Library/LaunchAgents/homebrew.mxcl.libvirt.plist   brew services
/opt/homebrew/etc/libvirt/*                          stock libvirt config, no edits
~/.cache/libvirt/libvirt-sock                        session socket
```

---

## Setup on a new Mac

**Automated:**
```sh
cd ~/development/private/Laptop-MacOs/virt-manager
./install.sh
```

The script:
1. Verifies Homebrew is installed
2. `brew install libvirt virt-manager`
3. `brew services start libvirt` (if not already running)
4. Smoke-tests `virsh --connect qemu:///session uri`
5. Warns if fish doesn't export `XDG_DATA_DIRS=/opt/homebrew/share`
   (run [`terminal/setup.sh`](../terminal/setup.sh) to set that up via symlink)
6. Runs `build.sh` to produce `~/Applications/Virt-Manager.app`

Safe to re-run — every step is idempotent.

**Manual:**
```sh
brew install libvirt virt-manager
brew services start libvirt

# ensure XDG_DATA_DIRS is exported in fish
echo 'set -gx --path XDG_DATA_DIRS /opt/homebrew/share $XDG_DATA_DIRS' \
    >> ~/.config/fish/config.fish

# build the Spotlight-launchable wrapper
cd ~/development/private/Laptop-MacOs/virt-manager
./build.sh
```

---

## Launching

| Where | How |
|---|---|
| Spotlight | type `virt` → Enter |
| Launchpad | open `Virt-Manager` |
| Dock | drag `~/Applications/Virt-Manager.app` once; right-click while running → Options → Keep in Dock |
| Finder | open `~/Applications/Virt-Manager.app` |
| Terminal (fish) | `virt-manager` |
| Terminal (non-fish) | `XDG_DATA_DIRS=/opt/homebrew/share /opt/homebrew/bin/virt-manager` |

---

## Verifying it works

```sh
# Service running?
brew services list | grep libvirt
# → libvirt  started   tmilata  ~/Library/LaunchAgents/homebrew.mxcl.libvirt.plist

# Session socket reachable?
virsh --connect qemu:///session uri
# → qemu:///session

# Any VMs defined?
virsh --connect qemu:///session list --all
```

---

## Updating

- **Packages:** `brew upgrade libvirt virt-manager` (followed by
  `brew services restart libvirt` if libvirt itself changed).
- **`.app` wrapper:** edit `launcher.sh` or `Info.plist` in this repo, then
  re-run `./build.sh`. Re-running is only required to re-register the
  bundle with Launch Services or rebuild the icon — the symlinks pick up
  source edits live.

---

## Uninstall

```sh
brew services stop libvirt
brew uninstall virt-manager libvirt
rm -rf ~/Applications/Virt-Manager.app
rm -rf ~/.cache/libvirt   # session socket and runtime state
# Optional, if it was tapped previously:
brew untap arthurk/virt-manager 2>/dev/null || true
```
