# Tests

| Command | What |
|---|---|
| `tests/test-all.sh` | every `*/tests/*` script (offline), then `-n` syntax check and shellcheck of all scripts; works from any cwd |
| `terminal/tests/concurrent-sessions.fish <host>` | live: needs a reachable remote host, about 90 s, not part of `test-all.sh` |

`test-all.sh` is also the smoke test after every change on this Mac. It prints `passed: N  failed: M` and exits 1 on any failure.

## Covered

| Folder | Tests |
|---|---|
| `backdrop-carousel/` | `sync.sh` |
| `homelab-dns/` | `homelab-dns.sh` |
| `software-updates/` | `mac-outdated.sh` |
| `ssh/` | `ssh-why.fish` |
| `terminal/` | `greeting.fish`, `xxhc.fish`, `wrappers.sh`, `starship.sh` |
| `virt-manager/` | `launcher.sh` |
| `window-manager/` | `arrange.sh`, `bottom.sh`, `install.sh`, `launcher.sh`, `make-icon.sh`, `model-fallback.sh` |

All stub external tools (ssh, curl, yabai, brew, sudo, ...) and use a temp `HOME`; nothing is installed or changed on the Mac.

## Adding a test

Put an executable script in `<folder>/tests/`; `test-all.sh` picks it up. Exit 0 = pass.
