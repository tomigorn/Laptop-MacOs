I've read all five files and verified the macOS specifics on your machine (dig present at /usr/bin/dig, all binaries in the default launchd PATH, route -n monitor emitted 0 events in 3s confirming the zero-poll claim, and networksetup -getdnsservers Wi-Fi currently returns 192.168.1.2).

Overall: this is genuinely good work. The architecture is sound, the comments explain why (not what), error handling is deliberate (set -u without set -e in the actor is correct), and the "only revert DNS we set" guard shows real care. Most scripts in this category are far sloppier. Here's where an expert eye finds real problems.

## Real bugs / correctness risks

1. ✅ RESOLVED (2026-05-29) — The probe trusts any answer from whatever box sits at 192.168.1.2 — wildcard/NXDOMAIN-hijack false positive. This is the one I'd actually fix. homelab-dns.sh:40-45 treats "got an A record for fastpi.homelab" as proof you're home. But 192.168.1.0/24 is the single most common home subnet on earth. Join a friend's / Airbnb / hotel network that also uses 192.168.1.x with a resolver at .2 that wildcards or hijacks NXDOMAIN (lots of consumer CPE and captive portals do exactly this), and the probe gets an IP back → you point your Wi-Fi DNS at a stranger's box and route all your DNS through it. The self-validating name defends the common case but not against a wildcard resolver.

Cheap hardening: don't just check that an answer is shaped like an IP — check that it's the expected IP. e.g.


EXPECT_IP="192.168.1.7"   # the real A record fastpi.homelab points to
ans=$(dig +time=1 +tries=1 +short "@${DNS_SERVER}" "${PROBE_NAME}" 2>/dev/null | head -1)
[ "${ans}" = "${EXPECT_IP}" ] && reachable=1 || reachable=0
Even better is a TXT record holding a secret token (dig TXT + compare), which a hijacker can't guess. That turns "something answered" into "the homelab answered."

   Fix shipped — stronger than the snippet above. Instead of matching the real fastpi.homelab IP, added a dedicated probe name with a sentinel value that no real host or captive portal would ever return:
   - AdGuard Home: added DNS rewrite probe.homelab → 198.51.100.53 (RFC 5737 TEST-NET-2, guaranteed never a live host — acts as a shared secret).
   - homelab-dns.sh:18-22 — PROBE_NAME="probe.homelab", PROBE_EXPECT="198.51.100.53".
   - homelab-dns.sh:42-47 — exact-match compare ([ "${ans}" = "${PROBE_EXPECT}" ]) instead of the "looks like an IP" regex.
   - homelab-dns.md — updated probe table, "why a sentinel" rationale, AdGuard setup note, and tunables.
   AdGuard can't do TXT rewrites, so the sentinel-IP approach is the strongest option achievable with this stack and closes the same hole the TXT-token idea would. Verified: dig @192.168.1.2 probe.homelab returns exactly 198.51.100.53; both scripts pass sh -n.
   Remaining action (operational, not a code gap): re-run sudo ./install.sh so the live /usr/local/sbin copy picks up the change.

2. ✅ RESOLVED (2026-05-29) — No periodic re-evaluation — a staleness window. The daemon only acts on route-table changes (homelab-dns-watch.sh:25). If you join Wi-Fi while the Pi is mid-reboot, the probe fails once, you revert to DHCP, and you stay on DHCP until the next route change — which on a stable home network might be hours. This is the inherent cost of the (otherwise excellent) zero-poll design. If that bothers you, a cheap safety net is a low-frequency StartInterval (say 300s) on a separate lightweight job, or accept the tradeoff and document it. Right now the README implies it self-heals; it only self-heals on the next path change.

   Fix shipped — added a separate 5-min timer daemon (chosen over folding read -t into the watcher, which is fragile in /bin/sh and would couple the heartbeat to the watcher's health):
   - com.tmilata.homelab-dns-timer.plist — new LaunchDaemon, StartInterval=300, runs homelab-dns.sh timer. Separate job (not StartInterval on the watcher, which is KeepAlive so an interval is meaningless there) → independent failure domain + watcher keeps its zero-CPU purity. No RunAtLoad, so it doesn't double-fire against the watcher's boot eval.
   - homelab-dns.sh:15 + tail — new REASON "timer"; a timer run that changes nothing exits without logging, so a stable network stays quiet (no ~288 no-op lines/day) while real recoveries are still recorded.
   - install.sh / uninstall.sh — install, (re)load, and remove both daemons.
   - homelab-dns.md — new "Why a timer too?" section, three-parts/two-daemons description, install + debug-log legend updated.
   Recovery window after a missed change is now bounded to ≤5 min. Verified: all four scripts pass sh -n, both plists pass plutil -lint, silent-on-no-op logic checks out.
   Remaining action (operational): sudo ./install.sh to load the new timer daemon on the machine.

3. ✅ RESOLVED (2026-05-29) — uninstall.sh clobbers a user's own DNS unconditionally. uninstall.sh:54 runs networksetup -setdnsservers Wi-Fi empty no matter what. The actor is scrupulous about "only revert DNS that WE set" (homelab-dns.sh:59-65) — but uninstall throws that philosophy away. If the current value isn't 192.168.1.2, leave it alone:


cur=$(networksetup -getdnsservers Wi-Fi 2>/dev/null)
[ "${cur}" = "192.168.1.2" ] && networksetup -setdnsservers Wi-Fi empty || skip "DNS not ours, left as-is"

   Fix shipped — uninstall now mirrors the actor's "only revert what WE set" rule:
   - uninstall.sh:19-20 — added SERVICE + DNS_SERVER vars (matching the actor).
   - uninstall.sh:60-75 — reverts to DHCP only if current Wi-Fi DNS == 192.168.1.2; otherwise leaves it untouched, distinguishing "already DHCP" from "a custom resolver something else set" (reusing the actor's locale-proof *[!0-9.\ ]* test for nicer messaging).
   - Full uninstall confirmed complete: both daemons (watcher + the timer schedule from issue 2) are unloaded + deleted, both /usr/local/sbin scripts removed, header comment + README updated.
   Verified against four current-DNS states: ours (192.168.1.2) → reverts; empty/DHCP → skip; single foreign IP (8.8.8.8) → skip; multi-DNS (1.1.1.1 9.9.9.9) → skip. All scripts pass bash -n and sh -n.

## Worth knowing (design scope, not bugs)

4. ✅ RESOLVED (2026-05-29) — Wi-Fi-only, hardcoded. homelab-dns.sh:18 only ever touches the Wi-Fi service, yet the watcher logs the active iface/gw which may be Ethernet or a utun VPN. Dock via Ethernet at home → homelab is reachable but only Wi-Fi's DNS gets set (and Wi-Fi may be off). For a laptop that lives on Wi-Fi this is fine; just know it's not "the active interface," it's literally Wi-Fi.

   Promoted from "design scope" to a real fix — the user has Ethernet + Thunderbolt/USB adapters, so Wi-Fi-only was wrong. Now interface-agnostic:
   - homelab-dns.sh — dropped the hardcoded SERVICE="Wi-Fi". The probe stays a single global check (follows the default route); the apply step now fans out over EVERY enabled service from `networksetup -listallnetworkservices`, skipping the header line and disabled ('*'-prefixed) services. Iterates with IFS=newline (not a `| while read` pipe, whose subshell would lose the accumulator) so service names with spaces ("Thunderbolt Ethernet Slot 1") work.
   - Asymmetry preserved (issue-3 philosophy): reachable → take over each service's DNS; unreachable → revert ONLY services still on our DNS_SERVER, leaving foreign/DHCP configs alone. Verified in a real sh harness: a service on 8.8.8.8 gets taken over when home but left untouched when away; DHCP services left alone on revert.
   - Log line changed: wifi_dns=…/action=… → changed=[svc]set->… / [svc]revert->dhcp / none. Timer-silence (issue 2) now keys off changed=none.
   - uninstall.sh — reverts across all services (only those still == DNS_SERVER), not just Wi-Fi.
   - homelab-dns.md — title/problem/approach/table/log-legend/verify/uninstall/tunables all updated for multi-interface; removed the SERVICE tunable.
   Confirmed against the real machine: 7 enabled services enumerated correctly, disabled USB-C Dock filtered, header skipped. All scripts pass sh -n / bash -n.

5. **IPv4-only probe → possible IPv6 DNS leak** — `homelab-dns.sh` (probe + apply)
   The probe only checks an A record, and the tool only ever sets an IPv4 resolver. If a
   network hands out IPv6 DNS via RA/DHCPv6, macOS can still send queries there in parallel —
   so "homelab DNS active" isn't airtight against IPv6 leakage.
   → **Status: OPEN, by choice.** Minor for a home setup; revisit only if `*.homelab`
   resolution ever seems flaky or you care about IPv6 leak-prevention.

## Cosmetic / minor

These four are nitpicks, not bugs. Reviewed #6–#9 on 2026-05-29 and consciously
chose to leave #6, #7, #9 as-is (#8 is obsolete). Reasoning below so future-me
doesn't re-litigate. Note the issue-2 5-min timer is now a global backstop: anything
the watcher mis-handles is re-evaluated within 5 min regardless, which lowers the
stakes on every watcher-level nitpick here.

6. **`MIN_GAP` can drop a real event** — `homelab-dns-watch.sh:34`
   A legitimate path change landing within 4s of the *previous* evaluation's completion
   is silently coalesced away. It's measured from end-of-run, not start-of-burst, so a
   slow `networksetup` extends the dead window.
   → **Decision: WON'T FIX.** Not really a defect — "after handling an event, ignore
   further events for 4s to let the dust settle" is exactly the intent. The only loss is
   a distinct transition inside that 4s window, which the 5-min timer recovers. Changing
   it would just swap one debounce shape for another, no clearer.

7. **`route -n monitor` matching is substring-loose** — `homelab-dns-watch.sh:29`
   `*RTM_ADD*` matches the token anywhere on the line, not anchored to the message type.
   → **Decision: WON'T FIX.** The `case` is a whitelist, so loose matching can only make
   it react to *more* lines (an extra idempotent, gap-limited probe) — never *miss* an
   event. Worst case is "slightly over-eager," never wrong. Anchoring (`*RTM_ADD:*`) is
   defensible polish for a non-problem; only worth it if already editing this file.

8. **`cur_str` vs `current` — two representations of the same value**
   Originally the decision used raw `current` while the log used a massaged `cur_str`,
   with no comment that the `case` was log-only.
   → **Status: ✅ OBSOLETE.** The single-service block (including `cur_str`) was deleted
   in the issue-4 rewrite; the per-service loop no longer has this split. Nothing to do.

9. **Log errors are swallowed** — `homelab-dns.sh:30`
   `>> "${LOG}" 2>/dev/null` — if `/var/log` ever isn't writable, you get total silence
   with no clue why.
   → **Decision: WON'T FIX.** Only bites if `/var/log` isn't writable, but the daemon runs
   as root, where it always is. The one surprise is running the script by hand as non-root
   (no log) — but the documented path is `sudo`, and a stderr fallback would just add noise
   to the normal case.

---

## Status summary

- **Resolved:** #1 (probe hardening), #2 (5-min timer), #3 (uninstall guard), #4 (all interfaces).
- **Won't fix (reviewed, not bugs):** #6, #7, #9.
- **Open, future option:** #5 (IPv6 leak) — only if it ever causes trouble.
- **Obsolete:** #8 (code removed in the #4 rewrite).
- **To go live:** `sudo ./install.sh` re-copies the scripts and loads the timer daemon.