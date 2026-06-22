# homelab-dns — per-network DNS on macOS

Use the homelab DNS server (`192.168.1.2`) as the resolver on **every** network
interface (Wi-Fi, Ethernet, USB / Thunderbolt adapters) **when the homelab is
reachable**, and fall back to DHCP everywhere else — automatically, on every
network change.

## The problem

- The homelab runs its own DNS (`192.168.1.2`) serving local domains like
  `*.homelab`. Over the **VPN** this works because the VPN pushes that DNS down
  the tunnel.
- At **home** the Mac doesn't use it: the ISP router's DHCP advertises its own
  DNS, and the ISP router is locked down so its DHCP can't be changed.
- macOS has **no per-SSID / per-network DNS setting** — DNS is global per
  interface. A static DNS on an interface would also break every *other* network
  you join on it (and macOS can't mix "static primary + DHCP fallback" on one
  interface).
- Reading the current SSID from scripts is blocked behind Location Services on
  recent macOS, so SSID-based detection is unreliable.

## The approach

Three parts, run by two `LaunchDaemon`s:

- **[`homelab-dns-watch.sh`](homelab-dns-watch.sh)** — a long-running watcher
  that blocks on `route -n monitor` and only reacts when the network *path*
  changes (Wi-Fi join/leave, VPN up/down, gateway change). It does **not** poll
  and is idle (zero CPU) on a stable network. On each change it debounces, waits
  a few seconds for things to settle, then calls the actor.
- **[`homelab-dns.sh`](homelab-dns.sh)** — the actor: probes the homelab DNS for
  a dedicated name (`probe.homelab`) and checks it returns an exact **sentinel**
  answer (`198.51.100.53`), then updates the DNS on the network services (Wi-Fi,
  Ethernet, USB / Thunderbolt adapters — discovered at runtime, so docking or
  swapping adapters needs no config change). It's deliberately asymmetric: when
  reachable it takes over **enabled** services only; when away it reverts **every**
  service it owns, **including disabled/parked ones** — see *Set enabled, revert
  everything* below.
- A **5-minute timer** ([`com.tmilata.homelab-dns-timer.plist`](com.tmilata.homelab-dns-timer.plist))
  re-runs the actor every 300s as a safety net (see *Why a timer too?* below). It's
  silent unless it actually changes the DNS, so a stable network stays quiet.

| Probe result                     | Meaning            | Action                              |
| -------------------------------- | ------------------ | ----------------------------------- |
| returns the sentinel IP          | home or on VPN     | every interface's DNS → `192.168.1.2` |
| anything else (or 1s timeout)    | away               | revert our interfaces → DHCP (`empty`) |

This is self-validating (no SSID / IP guessing), there's no per-lookup timeout
penalty (one 1s probe per network change, not per query), and on the way *out*
it only ever reverts DNS it set itself — a resolver something else configured on
an interface is left untouched. (When the homelab *is* reachable it does take
over each interface's DNS — that's the whole point.)

**Why a sentinel, not just "an IP came back"?** The probe queries
`@192.168.1.2` directly, and `192.168.1.0/24` is the most common home subnet —
so on a *foreign* network you may well hit some other device at `.2`. A resolver
that hijacks NXDOMAIN or wildcards every name would hand back an IP-shaped answer
and fool a naive "did it answer?" check, pointing your DNS at a stranger's box.
Requiring the **exact** RFC 5737 TEST-NET value (`198.51.100.53`) — which is
never a real host and which only *your* AdGuard rewrite produces — turns the
probe into "did the homelab answer?" rather than "did something answer?".

> **Setup:** add a DNS rewrite in AdGuard Home: `probe.homelab → 198.51.100.53`.
> The two `fastpi.homelab` rewrites stay as-is; the probe gets its own name so the
> real records keep their real meaning and the secret can change independently.

### Set enabled, revert everything (the parked-dock landmine)

macOS stores DNS **per network service and keeps it even when the service is
disabled or its adapter is unplugged**. That cuts two ways, so the actor is
deliberately asymmetric:

- **Setting** `192.168.1.2` only ever touches **enabled** services. Writing it
  onto a *disabled* adapter (a dock you've unplugged) would lie dormant and then
  blackhole all DNS the instant that adapter is re-enabled on a network that
  can't reach the homelab — e.g. plugging the dock in at the office and making it
  the primary service.
- **Reverting** to DHCP touches **every** service still set to our DNS,
  **including disabled ones**, precisely to defuse any such stale entry before
  the adapter is reactivated away from home.

> An earlier version skipped disabled services in *both* directions. A dock that
> picked up `192.168.1.2` while docked at home then kept it after undocking, and
> killed internet when later activated on a foreign network (DNS pointed at an
> unreachable `192.168.1.2`). The revert path now sweeps disabled services too,
> so the stale entry is cleared on the next away-from-home run.

### Why a timer too?

The watcher reacts only to *route changes* — its one blind spot is the homelab
being unreachable *at the moment of a change*. If you join Wi-Fi while the Pi is
mid-reboot, the probe fails once, DNS reverts to DHCP, and (without a timer) you'd
stay on DHCP until the **next** route change, which on a stable network could be
hours. The 5-minute timer re-probes regardless of route events, so recovery is
bounded to ≤5 min. It's a **separate** daemon (not folded into the watcher) so it
keeps re-evaluating even if the watcher ever wedges, and so the watcher keeps its
zero-CPU, event-only purity. Timer runs that change nothing are not logged.

### Why not `WatchPaths`?

The first version watched `/etc/resolv.conf` and the SystemConfiguration
directory. VPN/DNS daemons rewrite those files *constantly* even when the
network hasn't changed, so the job fired every few seconds. `route -n monitor`
is a true network-change event source — verified to emit **0 events in 25 s** on
a network where file-watching fired every 5 s.

## Install

```sh
sudo ./install.sh
```

Installs the scripts to `/usr/local/sbin/` and two daemons to
`/Library/LaunchDaemons/` (`com.tmilata.homelab-dns.plist`, the watcher, and
`com.tmilata.homelab-dns-timer.plist`, the 5-min safety net), then loads both.
Runs at boot, on every network change, and every 5 minutes. Safe to re-run.

## Verify / operate

```sh
# what's active now, per enabled service:
networksetup -listallnetworkservices | tail -n +2 | grep -v '^\*' | while IFS= read -r s; do
    printf '%-28s %s\n' "$s" "$(networksetup -getdnsservers "$s" | paste -sd, -)"
done

tail -f /var/log/homelab-dns.log           # one line per network change
sudo launchctl kickstart -k system/com.tmilata.homelab-dns   # force a run
```

### Debug log

Every evaluation writes one line, e.g.:

```
2026-05-29 15:01:44  change  iface=en0 gw=10.113.253.86  homelab=reachable  changed=[Wi-Fi]set->192.168.1.2 [Thunderbolt Ethernet Slot 1]set->192.168.1.2
```

- first field — why it ran: `boot` (daemon start), `change` (network change), `timer` (5-min safety net — only logs when it changed DNS), `manual`
- `iface` / `gw` — interface + gateway of the default route (which network you're on)
- `homelab`      — probe result: `reachable` / `unreachable`
- `changed`      — the services actually modified this run, each `[service]set->…` or
  `[service]revert->dhcp`; `none` if nothing needed changing (services already in
  the right state, or carrying a DNS that isn't ours, are not listed)

The log self-rotates at 64 KB to `homelab-dns.log.1` (capped ~128 KB total),
so it never grows unbounded — no `newsyslog`/logrotate needed.

## Uninstall

```sh
sudo ./uninstall.sh
```

Unloads + deletes **both** daemons (watcher + 5-min timer) and both scripts, then
reverts every interface's DNS to DHCP — but **only the ones still set to the
`192.168.1.2` we set**. Any interface that's already DHCP, or that something else
has since pointed at a custom resolver, is left untouched. Safe to re-run. (Leaves
`/var/log/homelab-dns.log` in place.)

## Tunables (top of `homelab-dns.sh`)

- `DNS_SERVER`   — homelab DNS IP (`192.168.1.2`)
- `PROBE_NAME`   — dedicated probe name resolved by the homelab DNS (`probe.homelab`)
- `PROBE_EXPECT` — exact sentinel A record the probe must return (`198.51.100.53`)

(The interfaces to manage are no longer a tunable — every enabled network service
is discovered at runtime via `networksetup -listallnetworkservices`.)
