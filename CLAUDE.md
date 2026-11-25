# Project rules
Global rules apply (`~/.claude/CLAUDE.md`). Only what is special here:

## Scripts that change the system
- `homelab-dns/install.sh`, `homelab-dns/uninstall.sh` (sudo, LaunchDaemons), `macos-settings/dock-add-spacer.sh` (defaults, killall), `window-manager/install.sh`, `window-manager/restart-launcher.sh` (LaunchAgents, osascript): edit and review only, I run them.

## Workflow
- Install step: `terminal/install.sh` for `terminal/`; `ssh/install.sh` for `ssh/`; `backdrop-carousel/install.sh` for `backdrop-carousel/`; `software-updates/install.sh` for `software-updates/`; `window-manager/install.sh` for `window-manager/` (I run it, see above).
- Try it: a new fish shell; for remote changes an `xxhc` connect.
- Tests: `tests/test-all.sh` (offline, all folders); also the smoke test after every change on this Mac.
- Live test: `terminal/tests/concurrent-sessions.fish <host>`, against a remote host; ask me which host.

## Config source
- yabai/skhd: `window-manager/config/` is the source, symlinked into `~/.config/yabai/`, `zones.conf` included. Only `connected.txt` is local.

## Version
- file: `terminal/SETUP_VERSION` (not `VERSION`: `version` is reserved in fish)
- tag: `terminal-X.Y.Z`, annotated (`terminal setup X.Y.Z`)
- bumps: only changes under `terminal/`
- extra steps: open a new fish shell, the greeting shows the version (also on every `xxhc` connect)

## Version (window-manager)
- file: `window-manager/VERSION`
- tag: `window-manager-X.Y.Z`, annotated (`window manager X.Y.Z`)
- bumps: only changes under `window-manager/`
- extra steps: none

## Version (backdrop-carousel)
- file: `backdrop-carousel/VERSION`
- tag: `backdrop-carousel-X.Y.Z`, annotated (`backdrop carousel X.Y.Z`)
- bumps: only changes under `backdrop-carousel/`
- extra steps: `~/bin/backdrop-sync.sh --version` shows it

## Version (mac-outdated)
- file: `software-updates/VERSION`
- tag: `mac-outdated-X.Y.Z`, annotated (`mac-outdated X.Y.Z`)
- bumps: only changes under `software-updates/`
- extra steps: `mac-outdated --version` shows it

## Version (homelab-dns)
- file: `homelab-dns/VERSION`
- tag: `homelab-dns-X.Y.Z`, annotated (`homelab dns X.Y.Z`)
- bumps: only changes under `homelab-dns/`
- extra steps: `homelab-dns/homelab-dns.sh --version` shows it; the owner runs `sudo homelab-dns/install.sh` to deploy it

## Version (ssh-why)
- file: `ssh/VERSION`
- tag: `ssh-why-X.Y.Z`, annotated (`ssh-why X.Y.Z`)
- bumps: only changes under `ssh/`
- extra steps: `ssh-why --version` in a new fish shell shows it

## Version (virt-manager)
- file: `virt-manager/VERSION`
- tag: `virt-manager-X.Y.Z`, annotated (`virt-manager X.Y.Z`)
- bumps: only changes under `virt-manager/`
- extra steps: none (`virt-manager/install.sh` prints it as its last line)
