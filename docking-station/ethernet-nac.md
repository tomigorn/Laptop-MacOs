# Dock Ethernet: MAC addresses, NAC (MAB) and 802.1X

How wired networking through docking stations is authenticated on the ETH ITET
network, why "MAC pass-through / spoofing" is **not** the right approach on this
MacBook, and how the dock MACs are registered in NAC.

Companion to [`docking-station-guide.md`](./docking-station-guide.md)
(that one covers display/Thunderbolt/USB-C hardware; this one covers network
identity).

---

## TL;DR

- This MacBook Air (Apple Silicon, M5) has **no built-in Ethernet**. The only
  built-in NIC is Wi-Fi. So there is **no "MacBook Ethernet MAC"** to pass
  through — the spoofing idea has no source address and doesn't apply.
- Each dock presents its **own burned-in Realtek MAC**. Two docks = two MACs.
- **Wi-Fi** authenticates with **802.1X EAP-TLS** (machine certificate).
- **Wired (dock)** is **not** doing 802.1X here — the switch ports admit us via
  **MAB (MAC Authentication Bypass)**, i.e. a MAC allowlist in NAC. So on the
  wire, identity = the dock's MAC.
- Fix for "consistent identity across docks" is **register each dock MAC in NAC**
  (short term) or **get EAP-TLS onto the wired ports** (long term) — **not** MAC
  spoofing, which is fragile on Apple Silicon and pointless under MAB.

---

## Hardware inventory

MacBook Air `Mac17,3`, Apple **M5** (arm64). No internal wired NIC.

| Device | Interface | MAC | Chipset / type | Notes |
|---|---|---|---|---|
| **Wi-Fi (built-in)** | `en0` | `aa:bb:cc:00:00:10` (factory); currently randomized to `aa:bb:cc:00:00:11` | Apple Wi-Fi | Private Wi-Fi Address is on. Auth = EAP-TLS. |
| **Monitor dock — HP E34m G4** | `en5` | `aa:bb:cc:00:00:01` | Realtek RTL8153 (USB `0x0bda`/`0x8153`) | RJ-45 is on the monitor; integrated USB-C dock. |
| **Standalone USB-C dock** | `en7` | `aa:bb:cc:00:00:02` | Realtek RTL8153 (USB `0x0bda`/`0x8153`) | Separate portable dock. |
| Virtual adapters | `en2`, `en3` | `aa:bb:cc:00:00:20/21` | software (locally-administered bit set) | Not physical; ignore. |
| Thunderbolt bridge | `en1`/`en4`/`bridge0` | `aa:bb:cc:00:00:30/34` | TB bridge | Ignore. |

> `en5`/`en7` numbering is per-MAC and persistent: macOS keeps an interface
> record for every USB-ethernet MAC it has *ever* seen. The standalone OWC TB3
> dock (see the dock guide) is a separate device with Thunderbolt-attached
> ethernet and is not one of these two.

### How the dock→MAC mapping was established

Hardware-confirmed three independent ways (don't trust labels, trust this):

1. Only the **USB-C dock** plugged in → `en7` = `aa:bb:cc:00:00:02` appeared.
2. Only the **monitor dock** plugged in → `en5` = `aa:bb:cc:00:00:01` appeared.
3. Both plugged, Ethernet cable in the monitor → `en5` (`aa:bb:cc:00:00:01`) is
   the active wired interface holding the IP / default route.

Adapters are detected at the driver level **even when the macOS network service
is disabled** in System Settings (the toggle only stops macOS from *using* the
adapter; the USB device still enumerates and its MAC is visible).

---

## How authentication actually works here

### Wi-Fi — 802.1X EAP-TLS (certificate)

- `eapolclient -i en0` runs whenever Wi-Fi is up.
- Config: `/Library/Preferences/SystemConfiguration/com.apple.network.eapolclient.configuration.plist`
  — every profile has `AcceptEAPTypes => [13]` (**EAP-TLS**). SSIDs `eth`,
  `eth-5`, `eth-6`.
- Machine identity **`ITET-ITS-100.example.com`** is present in the **System
  keychain** (`/Library/Keychains/System.keychain`) — i.e. usable by
  System-Mode auth that runs as root at link-up.

### Wired (dock) — MAB, not 802.1X (today)

- When a dock is plugged in, **no `eapolclient` spawns on `en5`/`en7`** — there
  is no EAP-TLS handshake. The interface just gets a DHCP lease.
- That means the switch port admits the dock via **MAB**: it matches the dock's
  MAC against a NAC allowlist and drops us onto the `ee-tik-dock` profile/VLAN.
- A **wired System-Mode 802.1X profile already exists** on the Mac
  (`SystemModeEthernetProfileID`, EAP-TLS, `TLSCertificateIsRequired = true`),
  and the cert is in place — but it never engages because the **switch ports
  don't challenge** (they're configured for MAB/open, not dot1x).

Observed wired addressing (varies by VLAN/lease):

- `203.0.113.184/24`, gw `203.0.113.1`, DNS `129.132.98.12` /
  `129.132.250.2`, search `d.ethz.ch ethz.ch` (public ETH range).
- Earlier observed `10.0.0.133/24`, gw `10.0.0.1` (private). The profile is
  the same (`ee-tik-dock`); the lease/subnet can differ.

---

## NAC (MAB) registrations

Self-service NAC portal → **MAB** tab. Current registrations (group `ee-tik`,
profile `ee-tik-dock`):

| MAC | Host ID | Beschreibung | Physical device (verified) |
|---|---|---|---|
| `aa:bb:cc:00:00:01` | `example-monitor-001-dock-monitor` | `Room 1.23: HP E34m G4 dock` | **HP E34m G4 monitor dock** (`en5`) |
| `aa:bb:cc:00:00:02` | `example-laptop-100-dock-usbc` | `MacBook jdoe – USB-C dock` | **standalone USB-C dock** (`en7`) |
| `aa:bb:cc:00:00:03` | `example-dock-usbc-001` | `Room 1.23: Lenovo ThinkPad Universal USB-C Dock (40AS)` | **Lenovo ThinkPad Universal USB-C Dock** — model `40AS`, s/n `SERIAL-EXAMPLE` (`en6`) |

All three MAC↔device assignments are hardware-verified (see the dock→MAC mapping
section above).

### Naming convention

The two entries deliberately use **different bases**, which is fine as long as
it's intentional:

- **USB-C dock** → named after the **laptop** (`example-laptop-100-…`): a personal,
  portable device that travels with the machine.
- **Monitor dock** → named after the **monitor + room**
  (`example-monitor-001`, "Room 1.23"): a fixed desk/location asset.

Side effect: the wired identity depends on which dock you're at (laptop-identity
at the USB-C dock, desk-identity at the monitor). Network access is identical
(both `ee-tik-dock`); only the DNS/log identity differs. If you instead wanted
**one identity regardless of dock**, name both under the laptop base
(`example-laptop-100-dock-mon` / `example-laptop-100-dock-usbc`). Host IDs must be unique per
MAC (each maps to a DNS name) and are DNS labels: lowercase, hyphens OK, no
underscores.

**Should an entry be deleted?** No — with two docks in use, MAB needs **one
entry per dock MAC**; deleting one disables that dock. Only delete when:

- you stop using one of the docks, or
- you migrate the wired ports to EAP-TLS (then **both** MAB entries become
  unnecessary).

---

## Why MAC spoofing / "pass-through" is the wrong fix here

1. **No source MAC exists.** Apple Silicon has no built-in wired NIC; the only
   built-in MAC is Wi-Fi's, and macOS randomizes even that. There is nothing to
   "pass through."
2. **Spoofing is unreliable on this hardware.** The Realtek RTL8153 runs under
   Apple's user-space DriverKit driver (`com.apple.DriverKit.AppleUserECM`).
   `ifconfig enX ether …` against these is frequently ignored and does **not**
   survive unplug/sleep/reboot (the interface is torn down and rebuilt, and the
   BSD name can shift). A LaunchDaemon to re-apply it is a maintenance trap.
3. **It fights our own NAC.** Admission is per-MAC MAB that we control via the
   portal. The clean move is to register each real MAC, not impersonate one dock
   as another.

---

## Recommendations

**Now (done):**
- Both dock MACs are registered → both docks work. ✅
- MAC↔device labels corrected (were swapped). ✅
- Host IDs unique per MAC, descriptions match the real hardware. ✅

**Long term (makes MAC irrelevant):**
- Ask netops to enable **802.1X (dot1x) EAP-TLS** on the `ee-tik-dock` switch
  ports. The Mac is already provisioned (System-Mode wired profile + cert in
  System keychain), so any dock would then authenticate by certificate and the
  MAB entries could be removed. To confirm whether a port can do dot1x, sniff
  for EAPOL during a replug: `sudo tcpdump -i en5 -c 20 -nn ether proto 0x888e`
  — EAP frames = port is dot1x-capable; silence = open/MAB only.

---

## Appendix — read-only diagnostics used

```sh
# Model / chip
sysctl -n machdep.cpu.brand_string; uname -m
system_profiler SPHardwareDataType | grep -E 'Model|Chip'

# Interfaces, MACs, link state
networksetup -listallhardwareports
ifconfig en0; ifconfig en5; ifconfig en7
route -n get default

# USB-ethernet chipset (works even if the service is disabled)
system_profiler SPEthernetDataType

# 802.1X state
pgrep -fl eapolclient                       # which interfaces are doing EAP
plutil -p /Library/Preferences/SystemConfiguration/com.apple.network.eapolclient.configuration.plist

# Cert available to System-Mode wired auth
security find-identity -v /Library/Keychains/System.keychain
```
