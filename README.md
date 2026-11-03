# Mac Setup (Personal Configuration)

Reproducible blueprint for configuring a Mac to my preferences. One folder per topic.

| Topic | Folder | What |
|---|---|---|
| macOS settings | [macos-settings/](macos-settings/macos-settings.md) | Finder, System Settings, mouse/trackpad, network drives, file manager, git identities, dock spacer, [shortcuts](macos-settings/keyboard-shortcuts.md) |
| Window management | [window-manager/](window-manager/window-manager.md) | yabai + skhd zones and launcher |
| Terminal | [terminal/](terminal/terminal.md) | fish, starship, atuin, xxh for portable remote shells. Setup: `terminal/setup.sh` |
| SSH | [ssh/](ssh/ssh.md) | ssh config, `ssh-why`, waking the sleeping homelab host. Setup: `ssh/setup.sh` |
| Homelab DNS | [homelab-dns/](homelab-dns/homelab-dns.md) | DNS auto-switcher for home LAN and VPN |
| USB-C docking station | [docking-station/](docking-station/docking-station-guide.md) | dock guide, [ethernet NAC](docking-station/ethernet-nac.md), `net-diag.sh` |
| Virtualization | [virt-manager/](virt-manager/virt-manager.md) | virt-manager / libvirt / QEMU, launchable from Spotlight. Setup: `virt-manager/install.sh` |
| Obsidian | [obsidian/](obsidian/obsidian.md) | CSS snippet for completed tasks |
| Backdrop carousel | [backdrop-carousel/](backdrop-carousel/) | sync script for a Shortcut. Setup: `backdrop-carousel/setup.sh` |
| Git multi-account | [multiple-git-accounts/](multiple-git-accounts/) | templates; explained in [macos-settings.md](macos-settings/macos-settings.md) |

Tests: `./test-all.sh`
