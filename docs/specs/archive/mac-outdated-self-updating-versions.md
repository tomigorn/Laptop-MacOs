# mac-outdated: version check for self-updating and managed apps

Date: 2026-11-20. Builds on [ETH-licensed apps + root-owned casks](2026-11-20-mac-outdated-eth-apps-root-casks-design.md) (finished and committed first, 1.3.0); this one is 1.4.0.

## Goal
Self-updating apps that brew doesn't manage (Signal, Chrome, Zoom, Docker, …) and managed-ID apps (`com.microsoft.*`, ETH/Jamf; not `com.apple.*`) get a real version check against the brew cask catalogue. Outdated ones go to "Open to update" with installed → latest; current ones are no longer named; apps without a cask are named once as not checkable.

## Facts found
- `check_unmanaged` already compares against casks (`cask_for_app`, local API cache, no network call per app), but skips `SELF_UPDATING` names and `MANAGED_IDS`.
- `load_cask_map` runs before `check_brew`'s `brew update`, so the map can be a day old.
- Real strings 2026-11-20: Brave `158.1.100.58` vs cask `1.100.58.0,200.58`; Word `16.115.1` vs `16.115.26111533`; Zoom `7.2.5 (90525)` vs `7.2.5.90525`; Docker `4.99.0` vs `4.99.0,245822`; Windows App `11.4.4` vs `11.4.5` (MAU not offering it yet).

## Done-list
**Which apps**
- [x] New source `self` ("Self-updating apps"): every app in the app folders that is not brew-installed, has no Sparkle framework, no `_MASReceipt`, and is a `SELF_UPDATING` name or has a managed ID other than `com.apple.*`.
- [x] An app MAU already lists as outdated appears only once (the MAU row wins).
- [x] `check_unmanaged` and `check_sparkle` unchanged for the apps they already cover.

**Comparison** (normalise both, then compare only the components both have; outdated only when the cask is strictly newer)
- [x] Cut at `,` and ` (`; drop trailing `.0`; a component with ≥ 6 digits is a build stamp, cut there; app with one more leading component than the cask and that component is a Chromium major (≥ 100, larger than the cask's first) → drop it (a plain `1.2` vs `2.0` stays a real difference).
- [x] Test cases: Signal 8.35.0 / 8.36.0 → outdated · Windows App 11.4.4 / 11.4.5 → outdated · Brave 158.1.100.58 / 1.100.58.0,200.58 → current · Brave 158.1.100.58 / 1.99.57 → current · Word 16.115.1 / 16.115.26111533 → current · Zoom 7.2.5 (90525) / 7.2.5.90525 → current · Docker 4.99.0 / 4.99.0,245822 → current · KeePassXC 2.8.0 / 2.8.0,2.8.0-1 → current · TeamViewer 15.83.3 / 15.82.6 → current.

**Output** (colours from `c()`, layout unchanged)
- [x] Progress row `Self-updating apps .... <n> checked, all current` in green when nothing is outdated.
- [x] Outdated app: yellow row under "Open to update", `installed → latest`, the section's existing "open them by hand" hint; counts in the summary under "open to update".
- [x] Apps without a cask: one dim line `not checkable (no upstream source): …` where today's "also update themselves on start: …" line was; that old line is gone; current apps not named anywhere.
- [x] brew missing: progress row red `check failed`, counted in the summary as failed. No API cache: falls back to `brew info` per app (local, like the other cask checks).
- [x] The cask map is reloaded after `brew update` in `check_brew`.

**Everywhere**
- [x] Tests in `software-updates/tests/mac-outdated.sh` for each item above (fixture apps with Info.plist, cask cache fixture).
- [x] `software-updates.md` updated (sources table, output example); version 1.4.0.
- [x] Verify: `tests/test-all.sh` passes; real `mac-outdated` on this Mac: Signal / Windows App shown as outdated if still behind, Brave/Word/Zoom/Docker not flagged, Defender/Cisco/Nudge etc. in the not-checkable line; checked by `verifier`.

## Untouched
- `--install`: no install attempt for these apps, nothing new in install mode.
- Other sources, summary layout, section layout, colours, log format.
- No network call per app; no new tools.

## Decisions (2026-11-20)
- Scope: `SELF_UPDATING` non-brew apps plus managed-ID apps (not `com.apple.*`), cask as second opinion next to MAU, deduplicated.
- Comparison rule as in the done-list.
- New source row in the progress list; failures are source-level only (brew/cache), never per app.
- Order: finish the ETH-apps feature first (1.3.0), then this one as 1.4.0.
- Built 2026-11-20 (real run): app found by name, else by a cask whose only `pkgutil` ID is the app's bundle ID (Windows App: pkg cask without an app name); a suite cask deleting several apps (Office) counts only for apps of the same major (Word 16 yes, Copilot Shim 0 and Defender 101 no: those were false hits); no `CFBundleShortVersionString` → `CFBundleVersion` (Steam).
- Built 2026-11-20: Chromium prefix only dropped when it is ≥ 100 (else `1.2` vs `2.0` would look equal); no API cache → per-app `brew info` fallback instead of a failure, same as `check_unmanaged`.
