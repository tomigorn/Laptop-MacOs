# Roadmap

## mac-outdated
- 📋 GitHub-release check for apps without a cask (today none actionable: the 5 not-checkable apps are Jamf-managed or Fusion); spec not written yet

## backdrop-carousel
- none open

## terminal
- 🔨 xxhc latency benchmark: built and committed; next: itet-ifa-comp01 baseline row, then 3.3.0 bump → [specs/xxhc-benchmark.md](specs/xxhc-benchmark.md)
- 📋 Bluetooth battery in the greeting: battery % of connected Bluetooth devices (batch backlog)

## window-manager
- none open

## homelab-dns, ssh, virt-manager
- none open

## Open questions
- ❓ Bluetooth battery in the greeting: which devices? Options: all connected devices with a battery value ⭐ (nothing to maintain, new devices show up by themselves) · a fixed list (e.g. only mouse and keyboard; quieter, but a new device needs a config change).
- ❓ Bluetooth battery in the greeting: format? Options: `Magic Mouse 64%`, one line per device ⭐ (matches fastfetch's own `Battery` line) · all on one line `Mouse 64% · Keyboard 80%` (shorter, gets long with many devices).
- ❓ Bluetooth battery in the greeting: warning colour? Options: red below 20% ⭐ (low battery stands out) · another threshold · always the same colour (calmer, easy to miss a low device).

## By hand
- ✋ homelab-dns reinstall, now (1.0.1): on the Mac, `~/development/private/Laptop-MacOs`: `sudo homelab-dns/install.sh`, then `homelab-dns/homelab-dns.sh --version` shows `homelab-dns 1.0.1`. Why: the installed copy (2026-11-05) misses the stop-flag fix from 2026-11-06.
- ✋ Before the itet-ifa-comp01 baseline: on the Mac (any folder) `ssh-add` the ETH server key (`~/.ssh/keys/eth/<user>.4la.ethServers`). Why: the key isn't in the agent, so every connect gets `Permission denied (publickey)`.
- ✋ xxhc 3.2.2 live check: in a new Ghostty tab, `xxhc itet-ifa-comp01` (or root6); the remote greeting must show `Terminal: ghostty 1.4.0`, no tar warnings, no xxh "First time…" lines, and no `timeout` box on exit. Why: the Terminal line fix could only be tested against the Mac's fastfetch, not on Linux.
- ✋ backdrop-wallpaper, display and wake: plug a display in (new photo within ~2 s) and out (same photo, rescaled); sleep the Mac past 10 min and wake it (new photo after unlock). Why: needs hardware and sleep, not testable here.

## Done
- ✅ mac-outdated: ETH-licensed App Store apps and root-owned casks, 1.3.0 → [specs/archive/mac-outdated-eth-apps-root-casks.md](specs/archive/mac-outdated-eth-apps-root-casks.md)
- ✅ mac-outdated: version check for self-updating and managed apps, 1.4.0 → [specs/archive/mac-outdated-self-updating-versions.md](specs/archive/mac-outdated-self-updating-versions.md)
- ✅ window-manager: yabai-snap skips placeholder screens, `arrange Home` fixed, 1.3.1
- ✅ terminal: xxhc tar warnings, xxh chatter, timeout box, remote Terminal line, 3.2.1–3.2.2
- ✅ mac-outdated: colours inside the --install blocks, brew result per package, 1.5.0 → [specs/archive/mac-outdated-install-colours.md](specs/archive/mac-outdated-install-colours.md)
- ✅ mac-outdated: versions on self-updating cask lines in --install, 1.5.1 → [specs/archive/mac-outdated-self-updating-cask-versions.md](specs/archive/mac-outdated-self-updating-cask-versions.md)
- ✅ backdrop-carousel: VERSION file and --version, 1.0.0 → [specs/archive/backdrop-versioning.md](specs/archive/backdrop-versioning.md)
- ✅ backdrop-carousel: one photo on all displays and Spaces (backdrop-wallpaper), 1.1.0; window-manager 1.4.0 → [specs/archive/backdrop-single-photo.md](specs/archive/backdrop-single-photo.md)
- ✅ homelab-dns, ssh, virt-manager: versions (homelab-dns 1.0.1 with installed-copy check, ssh-why 1.0.0, virt-manager 1.0.0) → [specs/archive/tool-versions.md](specs/archive/tool-versions.md)
- ✅ mac-outdated: apps to open in --install (Sparkle, self-updating, no-updater), 1.6.0 → [specs/archive/mac-outdated-install-open-apps.md](specs/archive/mac-outdated-install-open-apps.md)
- ✅ mac-outdated: badges and section bars, both modes, 1.7.0 → [specs/archive/mac-outdated-badges.md](specs/archive/mac-outdated-badges.md)
- ✅ mac-outdated: Summary bar tinted by outcome, By hand bar yellow, no comma after INSTALLED, 1.7.1–1.7.2
