# ssh — waking the sometimes-sleeping `beefy` and `tower` hosts on connect

`beefy` and `tower` (the homelab's power-hungry machines) are kept **asleep /
powered off** to save power and only woken on demand. This makes `ssh beefy` and
`ssh tower` "just work": the SSH client fires a Wake-on-LAN request **before** it
connects, then keeps retrying the connection for ~2.5 min while the box boots. No
manual wake step, no proxy host in the path.

Both hosts use the identical mechanism; only the endpoint and the credentials
differ. Everything below applies to both unless stated otherwise.

## The problem

- A Wake-on-LAN "magic packet" is an **L2 broadcast** — it only reaches the target
  if it originates *on the home LAN*. The Mac can't send it directly from a routed
  VPN (WireGuard/Tailscale-style tunnels don't carry broadcasts across the
  router), and even at home you'd need a WoL tool installed.
- The target isn't listening on `:22` the instant the packet lands — it needs
  ~1 min to POST and boot. A single connection attempt would just fail.

## The approach

A small always-on **Waker** service on `fastpi` (the Raspberry Pi that's always
up) does the LAN-side broadcasting. It exposes an HTTPS endpoint per host —
`https://beefy-wol.fastpi.homelab/wake` and `https://tower-wol.fastpi.homelab/wake`
— and hitting one makes the Pi emit the corresponding magic packet onto the LAN.

The Mac's `~/.ssh/config.d/private.config` then does two things on every connect:

1. **`Match … exec`** runs a `curl` POST to the wake endpoint *before* the
   connection is made (the `exec` runs at config-parse time).
2. **`ConnectionAttempts` + a short `ConnectTimeout`** make the client retry the
   TCP connection while the box boots, instead of giving up after one try.

```sshconfig
Match host beefy exec "nc -z -w 2 beefy.homelab 22 2>/dev/null || curl -fsSk -X POST https://beefy-wol.fastpi.homelab/wake"
Match host tower exec "nc -z -w 2 tower.homelab 22 2>/dev/null || curl -fsSk -X POST https://tower-wol.fastpi.homelab/wake"

Host beefy
    HostName            beefy.homelab
    User                buntu
    IdentityFile        ~/.ssh/beefy.EthMac
    IdentitiesOnly      yes
    ConnectTimeout      5
    ConnectionAttempts  30

Host tower
    HostName            tower.homelab
    User                root
    IdentityFile        ~/.ssh/tower
    IdentitiesOnly      yes
    ConnectTimeout      5
    ConnectionAttempts  30
```

## How it works, line by line

- **`Match host beefy exec "…"`** — when the target host is `beefy`, SSH runs the
  given shell command *during config parsing*, before connecting. The `Match`
  block has **no directives after it**, so it's used purely for the side effect
  (firing the wake). It must come **before** the `Host beefy` block so it's
  evaluated as part of resolving `beefy`.

  Match criteria are evaluated left to right and short-circuit, so `host beefy`
  is checked first and the `exec` never runs for any other host. Writing it the
  other way round (`Match exec … host …`) would run the curl on *every* ssh
  invocation on the machine.

- **The `nc` guard** — `nc -z -w 2 <host> 22 || curl …` fires the wake **only
  when port 22 is actually closed**. This is not an optimisation, it's load
  bearing: config parsing happens once per `ssh` invocation, and `xxhc` makes
  about ten of them per session (ControlMaster pre-dial, `-O check`, arch probe,
  staging-dir probe, history pre-seed `scp`, `xxh` itself, history retrieval ×3,
  cleanup ×2). Without the guard every one of those re-POSTs the wake and pays a
  curl round-trip. With it, once the host is up the cost is one fast local TCP
  probe.

- **`curl -fsSk -X POST …/wake`** — fire-and-forget wake request:
  - `-f` fail (exit non-zero) on HTTP errors, `-s` silent, `-S` still show real
    errors, `-k` accept the homelab's self-signed cert.
  - It returns immediately; the Pi sends the packet. If the endpoint is
    **unreachable** (you're on a foreign network), the name doesn't resolve, `nc`
    fails immediately, curl is attempted and fails quietly, and SSH proceeds to
    connect anyway — so the wake is a best-effort prelude, never a hard
    dependency.

- **`HostName beefy.homelab`** — resolved by the homelab DNS to the real LAN IP.
  Works at home and over VPN thanks to the
  [homelab DNS auto-switcher](../homelab-dns/homelab-dns.md).

- **`ConnectTimeout 5` + `ConnectionAttempts 30`** — each TCP attempt waits up to
  5 s, retried up to 30 times → ~2.5 min of patient retrying while the box POSTs
  and brings up `sshd`. The first attempt that succeeds wins; nothing waits the
  full budget once the host is up.

- **`IdentityFile` + `IdentitiesOnly`** — pin each host's own key.
  `IdentitiesOnly yes` stops the agent (which holds 5 keys) from offering all of
  them and hitting the server's `MaxAuthTries` limit before the right key is
  tried.

  Note there is deliberately **no** `IdentityFile` in the global `Host *` block.
  `IdentityFile` *accumulates* rather than being first-match-wins, and
  `IdentitiesOnly` does **not** suppress config-supplied keys — only agent-offered
  ones. A global default would therefore be appended to every host on the machine
  and burn one auth attempt everywhere, including on `git push`. See
  [ssh-config.md](ssh-config.md).

## Known wrinkle: `ConnectionAttempts` and `xxhc`

`xxhc` opens its ControlMaster with `-o ConnectTimeout=30`. That **replaces** the
`ConnectTimeout 5` above but leaves `ConnectionAttempts 30` in force. So a
genuinely dead host costs 30 × 30 s ≈ **15 minutes** before `xxhc` prints its
"ControlMaster pre-setup failed" warning, versus 30 × 5 s ≈ 2.5 min for a plain
`ssh`.

If that bites, the fix belongs in `xxhc.fish` rather than here — add
`-o ConnectionAttempts=1` to the pre-dial. That step is explicitly best-effort
(the function warns and carries on, and a later call establishes the tunnel), so
retrying it thirty times is wrong by design.

## Requirements

- The **Waker** service running on `fastpi`, reachable at
  `https://<host>-wol.fastpi.homelab/wake`, with each target's MAC baked in.
- **homelab DNS reachable** (home LAN or VPN) so `beefy.homelab`,
  `tower.homelab` and the `*-wol.fastpi.homelab` endpoints resolve — see
  [homelab-dns](../homelab-dns/homelab-dns.md).
- Wake-on-LAN enabled in each target's BIOS/NIC.

## Why not the old `ProxyCommand`?

The previous config tunnelled through fastpi with
`ProxyCommand ssh fastpi …/wake-beefy-connect %h %p` — fastpi both woke beefy and
proxied the whole SSH session. That works but routes all traffic through the Pi
and hides beefy's real address. The `Match exec` approach decouples the two: the
Pi only sends the wake packet, while the SSH session connects **directly** to the
target (`HostName beefy.homelab`) — lower latency, no proxy hop, and the real host
is visible in the config.
