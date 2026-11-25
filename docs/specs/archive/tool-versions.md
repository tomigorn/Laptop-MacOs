# Versions for homelab-dns, ssh-why, virt-manager

## Goal
The last three tools without a version get one, like terminal, window-manager, backdrop-carousel and mac-outdated: `VERSION` file, annotated tag, `## Version` block in `CLAUDE.md`. homelab-dns also shows which version is installed in `/usr/local/sbin`, so a stale install is visible.

## Done-list
| # | Item | Verified by | ✓ |
|---|---|---|---|
| 1 | `homelab-dns/VERSION`, `ssh/VERSION`, `virt-manager/VERSION` = `1.0.0` | read | ✅ |
| 2 | `CLAUDE.md`: `## Version (homelab-dns)`, `## Version (ssh-why)`, `## Version (virt-manager)`; tags `homelab-dns-X.Y.Z` (`homelab dns X.Y.Z`), `ssh-why-X.Y.Z` (`ssh-why X.Y.Z`), `virt-manager-X.Y.Z` (`virt-manager X.Y.Z`); bumps only for changes in that folder | read | ✅ |
| 3 | `homelab-dns/install.sh` copies `VERSION` to `/usr/local/share/homelab-dns/VERSION` (root, 644) and writes one log line `installed <v>` | test (static check of install.sh) + owner's real install later | ✅ (real install: ✋ owner) |
| 4 | `homelab-dns.sh --version` prints `homelab-dns <installed>`; run from the repo and the repo `VERSION` differs: `homelab-dns <installed> (repo <x>)`; nothing installed: `homelab-dns ? (repo <x>)`; exit 0, no DNS change, no log line, no root needed | test + real `homelab-dns/homelab-dns.sh --version` (today: `? (repo 1.0.0)`, the copy predates this) | ✅ |
| 5 | `ssh-why --version` / `-V` prints `ssh-why <v>`, read next to the real file through the fish-functions symlink; missing `VERSION` → `ssh-why ?`; `--help` lists it | test + real command in a new fish shell | ✅ |
| 6 | ssh-why tab completion: `-c/--connect`, `-h/--help`, `-V/--version`, host names; `ssh/install.sh` links it | real `ssh-why -<Tab>` in a new fish shell | ✅ |
| 7 | `virt-manager/install.sh` ends with `virt-manager setup <v>` | test (grep of the last output line, brew faked) | ✅ |
| 8 | Docs: `homelab-dns.md`, `ssh.md`, `virt-manager.md` name VERSION, `--version` and the installed-copy check | read | ✅ |
| 9 | `tests/test-all.sh` passes | run | ✅ |
| 10 | Commits per tool, then annotated tags `homelab-dns-1.0.0`, `ssh-why-1.0.0`, `virt-manager-1.0.0` | `git tag -n` | ✅ |

## Result (2026-11-25)
homelab-dns 1.0.1 (1.0.0 + a no-behaviour cleanup), ssh-why 1.0.0, virt-manager 1.0.0; all tagged and signed; verifier: items 1–10 pass. `virt-manager/install.sh` not run for real (starts a brew service LaunchAgent); covered by its stubbed test.

## Untouched
- DNS switching, timer, control flow and the log format of normal runs in homelab-dns.
- `.app` bundles: `CFBundleShortVersionString` stays `1.0`.
- ssh-why output and its offline/`--connect` behaviour.
- No sudo, launchctl or install run by me: the owner runs `sudo homelab-dns/install.sh` later.

## Decisions (2026-11-25)
- Start at 1.0.0; tags use the tool name (`ssh-why-*`, as `mac-outdated-*` for `software-updates/`).
- homelab-dns: installed copy of `VERSION` in `/usr/local/share/homelab-dns/`, `--version` compares it to the repo, one log line per install (not per run).
- App bundle versions stay `1.0`, not kept in step.
- `ssh-why --version` with completion and help; virt-manager prints its version at the end of `install.sh`.
