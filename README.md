# Mac Setup Guide (Personal Configuration)

- This Repo is a reproducible, step-by-step blueprint for configuring a Mac to match my preferences.

## Finder Settings
- General
  - New Finder windows show: user folder
  - [x] Open folders in tabs instead of new windows 
- Sidebar
  - Show these items in the sidebar
    - [ ] Recents
    - [x] Shared
  - Favorites
    - [x] Applications
    - [x] Desktop
    - [x] Documents
    - [x] Downloads
    - [ ] Movies
    - [ ] Music
    - [ ] Pictures
  - Locations
    - [x] iCloud Drive
    - [x] iCloud Storage
    - [x] {user directory}
    - [ ] {this laptop}
    - [x] Hard disks
    - [x] External disks
    - [x] CDs, DVDs, and iOS Devices
    - [x] AirDrop
    - [x] Bonjour computers
    - [x] Connected servers
    - [x] Trash
  - Tags
    - [ ] Recent tags
- Advanced
  - [x] Show all filename extensions
  - [x] Show warning before changing an extension
  - [x] Show warning before removing from iCloud Drive
  - [x] Show warning before emptying the Trash
  - [ ] Remove items from the Trash after 30 days
  - Keep folders on top:
    - [ ] In windows when sorting by name
    - [ ] On Desktop
  - When performing a search:
    - Search This Mac

## System Settings
- iCloud
  - Saved to iCloud -> See All
    - [x] Find My Mac
- Battery
  - Charging -> press on (i)
    - Charge Limit 80%
    - [ ] Optimized Battery Charging
  - Options
    -  [x] Slightly dim the display on battery
- Spotlight
  - [ ] Show Related Content
  - [ ] Help Apple Improve Search
  - Results from Apps (only turn on these)
    - [x] App Store
    - [x] System Settings
    - Results from System
    - [x] Apps
    - [x] Results from Clipboard
    - 8 hours
- Trackpad
  - Scroll & Zoom
    - [x] Natural scrolling
- Privacy & Security
  - Location Services
    - [x] Find My.app

## Mouse vs Trackpad: natural scrolling

### Trackpad
see above in system settings. configure natural scroll

### Mouse
- For Logitech mice install "Logi Options + app" and configure the mouse wheel for "Standard" scroll
- Alternative is the app [UnnaturalScrollWheels](https://github.com/ther0n/UnnaturalScrollWheels)

## Window Management
- [EasySnaps Window Manager](https://easysnaps.org/window-manager/) costs $7.99
- [Rectangle](https://rectangleapp.com/) as alternative. costs 7.98CHF

## System Monitoring
[iStat Menus](https://bjango.com/mac/istatmenus/) for showing an overview of system resource usage in the menu bar.

## Network Drives (Auto-Mounting Shares)
[ConnectMeNow v4](https://www.tweaking4all.com/macos/connectmenow-v4/) (Tweaking4All) for auto-mounting network drives so I don't have to manually reconnect to network shares every single time. Free, signed & notarized, Apple Silicon native. It's a **menu-bar helper** that mounts shares for you on demand and automatically, and unlike NFS Manager it's **multi-protocol: SMB, AFP, NFS, FTP, WebDAV, SSHFS, and SSH** — so it works with SMB shares (what most NAS boxes serve by default).

Why this over NFS Manager: ConnectMeNow handles SMB (NFS Manager is NFS-only), it's free, and it has first-class **roaming-laptop** features — auto-mount on network change (optionally gated to a specific gateway), remount on wake, ping/Wake-on-LAN, and fallback servers. The trade-off: mounting is driven by the running menu-bar app rather than the kernel-level `autofs` daemon NFS Manager configures, so the app needs to be running (it auto-starts at login). For pure-NFS, set-and-forget OS-level automounts, NFS Manager is still the better choice — see below.

### How to mount a drive
1. **Install** — download the Apple Silicon (ARM64) build from [tweaking4all.com](https://www.tweaking4all.com/macos/connectmenow-v4/), open the DMG, drag ConnectMeNow to `/Applications`. Launch it; it lives in the menu bar.
2. **Add a share** — menu → **Settings → Share Definitions** → **Create new share** (＋ bottom-left).
3. **Basic settings:**
   - **Share Type:** the protocol — **SMB** for a typical NAS, or NFS/AFP/WebDAV/etc.
   - **Server Address:** IP (recommended) or hostname, e.g. `192.168.1.10`. No protocol prefix or path here.
   - **Path:** the share name (SMB) or exported path (NFS), e.g. `media`. Leave blank and SMB/AFP will prompt for a share at mount time.
   - **Login:** username + password (stored encrypted). Leave the password blank to be prompted each mount.
   - Use the **Test Mount** button to confirm it works before saving.
4. **Auto-mount (Advanced tab)** — tick **Auto Mount when ConnectMeNow starts**, and for a roaming laptop also **Mount on Network Change** gated to your home router's **gateway MAC** (use *Detect Default Gateway*). Enable **Remount on wake from sleep** so shares come back after the lid reopens.
5. **Mount location** — on macOS 26 Tahoe, either mount into **`/Volumes`** using the **System Call (API)** style, **or** use a custom dir (e.g. `~/MountPoints`) with the **Command-line** mount style. Don't combine a custom path with the System API — Tahoe 26.4 broke that (triple permission/share dialogs), so the dev disabled it.
6. **Daily use** — click the share in the menu-bar menu to mount; click an active share for **Reveal in Finder** / **Unmount Share**.

> Roaming tip: this pairs naturally with the [homelab DNS auto-switcher](homelab-dns/homelab-dns.md) — both react to network changes, so arriving on the home LAN re-points DNS *and* remounts the NAS automatically.

### NFS-only alternative: NFS Manager
[NFS Manager](https://www.bresink.com/osx/NFSManager.html) by Bresink (commercial) is worth it only if you need **NFS** specifically and want true OS-level automounts that work even when no helper app is running. It's a front-end for macOS `autofs`: it edits `/etc/auto_master` + an autofs map (hence the admin password), then `automount -vc` reloads it and the share mounts on first access to the path. Useful NAS options: `resvport` (many NAS require a privileged source port or the mount silently fails), `rw`, `nobrowse`, and `soft,intr` so an off-LAN server fails fast instead of beachballing Finder.

## File Manager
[ForkLift](https://binarynights.com/) (Binary Nights) as a Finder replacement — a **dual-pane** file manager with the things macOS Finder still lacks: true two-pane copy/move, a proper path bar, batch rename, archive browsing, folder sync, and an app-deletion tool that also clears leftover support files. Paid (one-time license, also on [Setapp](https://setapp.com/)).

It overlaps with the Network Drives tools above: ForkLift has a **built-in remote browser** for SFTP, FTP, SMB, AFP, WebDAV, NFS, and cloud storage (S3, Backblaze B2, Google Drive, …), so for ad-hoc "connect, grab a file, disconnect" it often replaces mounting a share at all. Its **Disklet** feature can also surface a remote connection as a mounted volume in `/Volumes` for other apps to use.

How they divide up:
- **ConnectMeNow** — system-wide, persistent auto-mounts that survive across apps (the NAS is always *there*).
- **ForkLift** — interactive browsing/transfer inside the app; reach for it when you just need to poke at a server, not keep it mounted.

## Developer Setup
[Homebrew](https://brew.sh/)

## Terminal
fish + starship + atuin + xxh for portable remote shells. See [terminal/terminal.md](terminal/terminal.md). Setup: `terminal/setup.sh`.

## Virtualization (virt-manager / libvirt / QEMU)
GTK virt-manager running natively on macOS, launchable from Spotlight. See [virt-manager/virt-manager.md](virt-manager/virt-manager.md). Setup: `virt-manager/install.sh`.

## Git / GitHub / GitLab

setup for multiple git accounts to automatically use a certain user when cloning a repo into a specific directory:



```
~/
├── .gitconfig
├── .gitconfig-private
├── .gitconfig-work
├── .ssh/
│   ├── allowed_signers-private
│   ├── allowed_signers-work
│   ├── gitHub-Tomigorn
│   ├── gitHub-Tomigorn.pub
│   ├── gitLab-ETH
│   ├── gitLab-ETH.pub
└── development/
  ├── private/
  │   └── sample-1-private-repo/
  │   └── second-2-repo-from-private-github/
  └── work/
      └── 2-lots-of-work-repo/
      └── work-example-1-repo/
```

