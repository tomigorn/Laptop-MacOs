# mac-outdated: ETH-licensed App Store apps, root-owned casks

Date: 2026-11-20. Trigger: `--install` run 2026-11-20 08:53 (log `2026-11-20-085336-install.log`): App Store failed (Bitwarden, ADAM ID 1352778147, plus an App Store pop-up "Redownload Unavailable"), brew failed (utm: `chown … Operation not permitted`, leftover backup in Caskroom).

## Goal
`mac-outdated` updates everything it can on its own. ETH-licensed App Store apps (Jamf/Self Service, receipt `ProductionVPP`) are never passed to `mas upgrade`; instead it says whether ETH Self Service already offers the update. A cask brew can't replace because the app is root-owned gets its leftover backup removed and one clear By-hand line.

## Facts found
- `mas outdated --json` / `mas list --json` carry `receiptType` (`ProductionVPP` for ETH), `receiptOrganizationDisplayName` (`ETH Zürich`), `bundleID`, `adamID`. Today: Bitwarden and Xcode are ETH-licensed; GarageBand, WireGuard are own Apple account.
- Self Service cache `~/Library/Application Support/com.jamfsoftware.selfservice.mac/CocoaAppCD.storedata` (Core Data XML, undocumented, refreshes when Self Service opens): `<object type="SSVPPMACAPP">` with `bundleid` and `version` = the version ETH offers. Today Bitwarden 2026.10.4 (App Store has 2026.11.0).
- brew already runs `sudo chown` on root-owned apps; macOS blocks it while the terminal lacks App Management permission. A failed cask upgrade leaves `Caskroom/<token>/<old>/<App>.app` (backup), which blocks the next upgrade.

## Done-list
**Check mode (`mac-outdated`)**
- [ ] ETH-licensed app, ETH offers a newer version than installed: listed as outdated, action `open ETH Self Service`, counts as outdated.
- [ ] ETH-licensed app, App Store newer but ETH not yet: a note `App Store has <v>, ETH Self Service not yet`, not counted as outdated.
- [ ] Cache missing or unreadable: note `ETH-licensed, App Store has <v>: Jamf / ETH Self Service updates it`, not counted, no check failure.
- [ ] Own-account App Store apps: unchanged.

**`--install`**
- [ ] `mas upgrade` gets only the IDs of non-ETH outdated apps; none left → App Store `up to date`, no sudo, no pop-up.
- [ ] ETH offers a newer version → By hand: `Bitwarden: ETH Self Service offers <v>, open ETH Self Service`.
- [ ] Cask upgrade fails with `Operation not permitted` / `Permission denied @ apply2files`: brew stays `failed`; By hand: `utm: macOS blocked replacing /Applications/UTM.app (owned by root): allow <terminal> in System Settings › Privacy & Security › App Management, then mac-outdated --install`.
- [ ] After that failure the leftover `Caskroom/<token>/<old>/<App>.app` is removed, only when `/Applications/<App>.app` still exists.
- [ ] A leftover backup from an earlier run (`It seems there is already an App at '<Caskroom>/<token>/<old>/X.app'`): removed under the same conditions, that cask retried once; the app missing from the app folders → backup kept, By hand: move it back.

**Everywhere**
- [ ] Tests in `tests/mac-outdated.sh` cover each item above with fixtures (mas JSON with VPP receipt, Self Service cache sample, brew failure output).
- [ ] `software-updates.md` updated (sources table, troubleshooting row for App Management, ETH-licensed apps); version bump to 1.3.0.
- [ ] Verify: `tests/test-all.sh` passes; real `mac-outdated` here shows Bitwarden as "ETH Self Service not yet"; you run `mac-outdated --install` after granting App Management: App Store no pop-up/no failure, UTM upgraded (or the By-hand line if Jamf blocks the permission).

## Untouched
- Other sources (Adobe, Microsoft, pipx, uv, VS Code, macOS), admin/sudo handling, summary format, log format.
- No `jamf` command, no sudo for the ETH check, no opening of Self Service by the script.
- Casks are not skipped up front by owner; brew still tries.

## Decisions (2026-11-20)
- ETH-licensed apps are detected by receipt (`ProductionVPP`), not by remembering failed IDs.
- Show the ETH-offered version by reading the Self Service cache; fall back to the receipt-only note when unreadable.
- Bitwarden stays the ETH copy (no switch to the `bitwarden` cask).
- Root-owned casks: owner grants App Management to the terminal once; the script cleans the leftover backup and prints the By-hand line.
- Leftover backups from earlier runs are cleaned too, with one retry of that cask (asked after the 09:57 run hit one).
