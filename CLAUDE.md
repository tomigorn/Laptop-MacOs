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

## Version (mac-outdated)
- file: `software-updates/VERSION`
- tag: `mac-outdated-X.Y.Z`, annotated (`mac-outdated X.Y.Z`)
- bumps: only changes under `software-updates/`
- extra steps: `mac-outdated --version` shows it
