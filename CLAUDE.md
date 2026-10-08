# Project rules
Global rules apply (`~/.claude/CLAUDE.md`). Only what is special here:

## Scripts that change the system
- `homelab-dns/install.sh`, `homelab-dns/uninstall.sh` (sudo, LaunchDaemons), `add_dock_spacer.sh` (defaults, killall), `window-manager/install.sh`, `window-manager/restart-launcher.sh` (LaunchAgents, osascript): edit and review only, I run them.

## Workflow
- Install step: `terminal/setup.sh` for `terminal/`; `window-manager/install.sh` for `window-manager/` (I run it, see above).
- Try it: a new fish shell; for remote changes an `xxhc` connect.
- Tests: `terminal/tests/concurrent-sessions.fish <host>`, live against a remote host; ask me which host.

## Config source
- yabai/skhd: `window-manager/config/` is the source, symlinked into `~/.config/yabai/`. Only `zones.conf` is local.

## Version
- file: `terminal/SETUP_VERSION` (not `VERSION`: `version` is reserved in fish)
- tag: no
- bumps only for changes under `terminal/`
- extra step: open a new fish shell, the greeting shows the version (also on every `xxhc` connect)
