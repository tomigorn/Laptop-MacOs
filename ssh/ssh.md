# ssh — waking the sometimes-sleeping `beefy` host on connect

`beefy` (the homelab's power-hungry workstation) is kept **asleep / powered off**
to save power and only woken on demand. This makes `ssh beefy` "just work": the
SSH client fires a Wake-on-LAN request **before** it connects, then keeps retrying
the connection for ~2.5 min while beefy boots. No manual wake step, no proxy host
in the path.

## The problem

- A Wake-on-LAN "magic packet" is an **L2 broadcast** — it only reaches beefy if
  it originates *on the home LAN*. The Mac can't send it directly from a routed
  VPN (WireGuard/Tailscale-style tunnels don't carry broadcasts across the
  router), and even at home you'd need a WoL tool installed.
- beefy isn't listening on `:22` the instant the packet lands — it needs ~1 min
  to POST and boot. A single connection attempt would just fail.

## The approach

A small always-on **Beefy-Waker** service on `fastpi` (the Raspberry Pi that's
always up) does the LAN-side broadcasting. It exposes an HTTPS endpoint
`https://beefy-wol.fastpi.homelab/wake`; hitting it makes the Pi emit the magic
packet onto the LAN.

The Mac's `~/.ssh/config` then does two things on every `ssh beefy`:

1. **`Match … exec`** runs a `curl` POST to the wake endpoint *before* the
   connection is made (the `exec` runs at config-parse time).
2. **`ConnectionAttempts` + a short `ConnectTimeout`** make the client retry the
   TCP connection while beefy boots, instead of giving up after one try.

```sshconfig
Match host beefy exec "curl -fsSk -X POST https://beefy-wol.fastpi.homelab/wake"

Host beefy
    HostName beefy.homelab
    User buntu
    IdentityFile /Users/tmilata/.ssh/beefy.EthMac
    IdentitiesOnly yes
    ConnectTimeout 5
    ConnectionAttempts 30
```

## How it works, line by line

- **`Match host beefy exec "…"`** — when the target host is `beefy`, SSH runs the
  given shell command *during config parsing*, before connecting. The `Match`
  block has **no directives after it**, so it's used purely for the side effect
  (firing the wake). It must come **before** the `Host beefy` block so it's
  evaluated as part of resolving `beefy`.
- **`curl -fsSk -X POST …/wake`** — fire-and-forget wake request:
  - `-f` fail (exit non-zero) on HTTP errors, `-s` silent, `-S` still show real
    errors, `-k` accept the homelab's self-signed cert.
  - It returns immediately; the Pi sends the packet. If the endpoint is
    **unreachable** (you're on a foreign network, or beefy is already up), curl
    just fails quietly and SSH proceeds to connect anyway — so the wake is a
    best-effort prelude, never a hard dependency.
- **`HostName beefy.homelab`** — resolved by the homelab DNS to beefy's real LAN
  IP. Works at home and over VPN thanks to the
  [homelab DNS auto-switcher](../homelab-dns/homelab-dns.md).
- **`ConnectTimeout 5` + `ConnectionAttempts 30`** — each TCP attempt waits up to
  5 s, retried up to 30 times → ~2.5 min of patient retrying while beefy POSTs
  and brings up `sshd`. The first attempt that succeeds wins; nothing waits the
  full budget once beefy is up.
- **`IdentityFile` + `IdentitiesOnly`** — pin beefy's own key. Without them SSH
  falls through to the `Host *` default key and auth fails.

## Requirements

- The **Beefy-Waker** service running on `fastpi`, reachable at
  `https://beefy-wol.fastpi.homelab/wake`, with beefy's MAC baked in.
- **homelab DNS reachable** (home LAN or VPN) so `beefy.homelab` and
  `beefy-wol.fastpi.homelab` resolve — see
  [homelab-dns](../homelab-dns/homelab-dns.md).
- beefy's BIOS/NIC has **Wake-on-LAN enabled**.

## Why not the old `ProxyCommand`?

The previous config tunnelled through fastpi with
`ProxyCommand ssh fastpi …/wake-beefy-connect %h %p` — fastpi both woke beefy and
proxied the whole SSH session. That works but routes all traffic through the Pi
and hides beefy's real address. The `Match exec` approach decouples the two: the
Pi only sends the wake packet, while the SSH session connects **directly** to
beefy (`HostName beefy.homelab`) — lower latency, no proxy hop, and the real host
is visible in the config.
