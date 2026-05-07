# MacBook Air M5 Docking Station Guide

A comprehensive comparison of docking stations for running **2 external monitors in extended (non-mirrored) mode** on a MacBook Air M5, focused on options available in Switzerland.

---

## Table of Contents

- [Why this is harder than it should be](#why-this-is-harder-than-it-should-be)
- [Why DisplayLink sucks](#why-displaylink-sucks)
- [Why USB-C docks have the mirror problem on Mac](#why-usb-c-docks-have-the-mirror-problem-on-mac)
- [Why Thunderbolt docks work properly](#why-thunderbolt-docks-work-properly)
- [How to identify a real Thunderbolt dock](#how-to-identify-a-real-thunderbolt-dock)
- [USB-C Cable Guide](#usb-c-cable-guide)
- [The complete comparison table](#the-complete-comparison-table)
- [Top 5 recommendations](#top-5-recommendations)
- [Final recommendation](#final-recommendation)
- [What I actually bought (confirmed working)](#what-i-actually-bought-confirmed-working)

---

## Why this is harder than it should be

You'd think connecting two monitors to a Mac via a docking station would be simple. It isn't. The market is flooded with cheap docks that **technically work** with a Mac (one monitor, peripherals fine) but **fail at dual extended monitors** because of how Apple Silicon handles video output.

There are three classes of multi-monitor docks on the market:

1. **USB-C docks with MST** — Cheap, plentiful, and they only mirror displays on Mac. Avoid.
2. **DisplayLink docks** — Work for multi-monitor on Mac, but rely on driver software that has serious downsides. Avoid if possible.
3. **Thunderbolt docks** — The right answer. Native dual-monitor support, no drivers needed, full image quality.

The catch: USB-C and Thunderbolt docks use the same physical connector, and lazy product listings often blur the distinction. Many "Thunderbolt 3/4 compatible" docks are actually USB-C with MST.

---

## Why DisplayLink sucks

DisplayLink is a **software compositing technology** that lets you drive extra displays via USB by rendering everything on the CPU and streaming compressed video frames to the dock. It "works" on Mac, but the trade-offs are real:

### Image quality compromises
- **Compression artifacts** — DisplayLink compresses video before transmission. Even on a static desktop, you can sometimes see subtle banding or blockiness on gradients.
- **No HDCP support** — DRM-protected content (Netflix, Apple TV+, Disney+, etc.) **will not play** on DisplayLink monitors. The screen goes black.
- **No HDR** — DisplayLink monitors can't display HDR content.
- **Limited color depth** — Most DisplayLink connections are limited to 8-bit color.

### Performance compromises
- **CPU usage** — DisplayLink uses your laptop's CPU/GPU to render and compress every frame for the external displays. This can cause noticeable battery drain and fan noise.
- **Input lag** — Mouse cursors and window dragging often feel slightly laggy on DisplayLink monitors. Imperceptible for office work, painful for gaming or video scrubbing.
- **Frame stutter** — Smooth scrolling and video playback can show micro-stutters.

### Reliability compromises
- **Driver dependency** — You must install DisplayLink Manager from displaylink.com. It's not bundled with macOS.
- **macOS update breakage** — When Apple ships a new macOS version, DisplayLink drivers often break temporarily. Wait for an updated driver, or stay on the old macOS.
- **Permission management** — DisplayLink Manager needs Screen Recording permission in System Settings every time, and can sometimes lose it after updates.
- **Wake-from-sleep issues** — Common reports of monitors not coming back after the Mac sleeps.

### When DisplayLink is acceptable
DisplayLink is a fine fallback **only when you've exhausted Thunderbolt options** — for example, if you're trying to run 3+ monitors on an M5 Air (which natively supports only 2). For 2 monitors, you never need it.

---

## Why USB-C docks have the mirror problem on Mac

This is the trap most people fall into. A typical USB-C dock costing CHF 80–150 will advertise "dual 4K HDMI" or "triple display support" and have a small footnote like *"MacBooks only support mirroring mode"* buried in the description.

Here's why:

### How USB-C video alt-mode works
A single USB-C cable using DisplayPort Alt Mode carries **one DisplayPort stream**. To split it across multiple monitor outputs, the dock uses a technology called **Multi-Stream Transport (MST)** — essentially a "DisplayPort splitter" inside the dock that creates virtual sub-streams for each connected display.

### Why MST fails on Apple Silicon
Apple Silicon Macs (M1/M2/M3/M4/M5) **do not support MST**. Apple made this design choice and never reversed it. When a Mac sees an MST-based dock with multiple monitors connected, it does one of three things:

1. **Mirrors the displays** — same image on all monitors
2. **Uses only one monitor** — the second connection appears unrecognized
3. **Fails entirely** — no displays work

### How to spot an MST dock before buying
- Lists "MST" anywhere in the spec sheet
- Marketing claims "triple display" or "quad display" at low prices (under CHF 200)
- Mac compatibility note in the fine print like *"MacBook supports DP-SST mode"* or *"Mac only supports mirroring"*
- Resolution drops on Mac vs Windows ("4K@60Hz Windows / 4K@30Hz Mac" is a giveaway)
- Brand names like Vention, generic Amazon brands, and many UGREEN models

### The architectural alternative: DisplayLink
A few USB-C docks use DisplayLink instead of MST to drive multiple monitors. These do work for extended displays on Mac, but with all the trade-offs listed above. They're software-based, not hardware-based.

---

## Why Thunderbolt docks work properly

Thunderbolt is a different protocol from USB-C, even though they share the same physical connector. The crucial difference for multi-monitor setups:

### Each Thunderbolt connection carries multiple independent DisplayPort streams
A single Thunderbolt 4 connection has enough bandwidth (40 Gbps) to carry **two independent DisplayPort 1.4 streams plus PCIe data plus USB data** simultaneously. Inside a Thunderbolt dock, each video output port is wired to its own dedicated DisplayPort stream — no splitting, no compression, no software involved.

### What this means for you
- **Native dual extended displays** on Mac, plug-and-play, no drivers
- **Full image quality** — uncompressed DisplayPort 1.4 signal to each monitor
- **HDCP and HDR work** — Netflix, Apple TV+, HDR content all play normally
- **Zero CPU overhead** — the Mac's GPU drives both displays directly via Thunderbolt
- **No driver installation** — works the moment you plug it in

### The two architectures of Thunderbolt docks
Thunderbolt docks for Mac come in two valid layouts, both of which work for dual extended monitors:

**Layout A: Built-in HDMI/DP + Thunderbolt downstream port**
- Monitor 1 → built-in HDMI or DisplayPort
- Monitor 2 → Thunderbolt downstream port via USB-C cable (or USB-C-to-HDMI/DP adapter)
- Examples: CalDigit TS3 Plus, CalDigit TS4, OWC 14-Port Thunderbolt Dock, Sonnet Echo 20

**Layout B: Multiple Thunderbolt downstream ports only**
- Monitor 1 → Thunderbolt port via USB-C cable
- Monitor 2 → Thunderbolt port via USB-C cable
- Examples: Sonnet Echo 11, OWC Thunderbolt 4 Hub, CalDigit Element Hub

Both layouts deliver native dual-monitor support. Layout A is more convenient if your monitors have HDMI/DP inputs; Layout B is cleaner if your monitors have USB-C inputs.

---

## How to identify a real Thunderbolt dock

Before buying any dock, verify it's truly Thunderbolt:

### Green flags ✅
- Listed as **"Thunderbolt 3"**, **"Thunderbolt 4"**, or **"Thunderbolt 5 Certified"**
- Price typically **CHF 150 or higher** (Thunderbolt controllers cost real money)
- Brands with strong Mac track records: **CalDigit, OWC, Sonnet, Plugable, Kensington**
- Spec sheet mentions Intel Thunderbolt chipsets like JHL6540, JHL7440, JHL8440
- No mention of MST or DisplayLink in spec or compatibility notes

### Red flags ❌
- Says **"Thunderbolt 3/4 compatible"** rather than "Thunderbolt 4 certified"
- Sub-CHF 150 price for a "triple/quad display" dock
- Spec sheet mentions **MST hub chip** (e.g., Synaptics VMM6210)
- Compatibility note like *"Mac only supports mirror mode"* or *"DP-SST mode"*
- Resolution caps differ between Mac and Windows in the spec
- Generic or no-name brand

---

## USB-C Cable Guide

### How USB-C-to-HDMI/DP cables work

A USB-C-to-HDMI or USB-C-to-DisplayPort cable is not a video cable in the traditional sense — it's an adapter cable that uses **DisplayPort Alternate Mode (DP Alt Mode)**.

The flow:
1. The Mac sends a real DisplayPort video signal out of its USB-C port using DP Alt Mode
2. The cable carries that DisplayPort signal through the USB-C connector
3. At the other end, a small chip converts DisplayPort to HDMI (for USB-C→HDMI cables), or simply rewires the pins to a DisplayPort connector (for USB-C→DP cables)

The video signal originates as DisplayPort inside the Mac's GPU.

### The four variants of USB-C cables

All four variants use identical connectors — same plug, often similar packaging. You cannot tell them apart by looking at them.

1. **Charging-only** — carry power and basic USB 2.0 data only. No video. The cable from an iPhone box is typically this kind.
2. **USB 3.x without DP Alt Mode** — carry data at 5 or 10 Gbps but don't carry video. Cheap "USB-C to USB-C" cables under CHF 15 are often this kind.
3. **USB-C with DP Alt Mode** — carry DisplayPort signals plus power and data. These are what you need for monitor connections.
4. **Thunderbolt 3/4** — carry Thunderbolt protocol (which includes DisplayPort, USB, PCIe). Work for video but overkill for simple monitor connections.

### What to look for when buying

**Look for cables that explicitly mention:**
- "Supports DP Alt Mode" or "DisplayPort Alternate Mode"
- "4K @ 60Hz" support (or higher)
- "Thunderbolt 3 / Thunderbolt 4 compatible"
- "Compatible with MacBook Pro / MacBook Air"
- A specific HDMI version: HDMI 2.0 for 4K@60Hz, HDMI 2.1 for 4K@120Hz
- A specific DisplayPort version: DP 1.2 for 4K@60Hz, DP 1.4 for 4K@120Hz with HDR

**Avoid cables that:**
- Just say "USB-C to HDMI" with no resolution or version specs
- Cost under CHF 10
- Come from no-name brands with limited reviews
- Are advertised as "universal charging cables that also support video"

### Mac compatibility

There's no "Mac-specific" cable. Every Thunderbolt 4 port on the M5 MacBook Air supports DP Alt Mode at full DisplayPort 1.4 bandwidth. Any reputable USB-C-to-HDMI or USB-C-to-DP cable rated for 4K@60Hz will work. The "Mac compatibility" listings in product descriptions are mostly marketing — they mean "we tested with Macs and it doesn't have weird firmware bugs."

### Recommended cables

**Club3D** is the gold standard for video adapter cables in Europe, available at Digitec. **Delock** is a solid German alternative at similar prices, also at Digitec.

| Use case | Cable | Approximate price |
|---|---|---|
| USB-C/Thunderbolt port → HDMI monitor (4K@60Hz) | Club3D CAC-1587 | ~CHF 30 |
| USB-C/Thunderbolt port → HDMI monitor (4K@120Hz, HDMI 2.1) | Club3D CAC-1588 | ~CHF 40 |
| USB-C/Thunderbolt port → DisplayPort monitor (4K@60Hz) | Club3D CAC-1557 | ~CHF 30 |
| USB-C/Thunderbolt port → DisplayPort monitor (8K@60Hz, DP 1.4) | Club3D CAC-1567 | ~CHF 40 |

For **Mini-DP outputs** (relevant for the OWC 14-Port dock), use an **active** Mini-DP-to-HDMI adapter for 4K@60Hz. The Club3D CAC-1170 is an active Mini-DP-to-HDMI adapter (~CHF 35). "Active" means the adapter has a chip that does signal conversion — passive adapters just rewire pins and fail at 4K@60Hz on Mini DP.

### Cables you don't need to overthink

- **Regular HDMI cable** (for a built-in HDMI port on a dock): any decent HDMI 2.0 or HDMI 2.1 cable works — KabelDirekt, Amazon Basics are fine. The HDMI signal is fully formed by the dock; the cable just carries it.
- **Regular DisplayPort cable** (for a built-in DP port on a dock): any branded DP 1.2 or DP 1.4 cable works.
- **Don't buy 5-meter cables** — at long lengths, signal degradation can cause flicker. Stick to 1.5–2 meter cables for desk setups.

### Decision tree for the recommended docks

**OWC 14-Port TB3 Dock (CHF 149):**
- Monitor 1 → Mini-DP-to-HDMI adapter cable (Club3D CAC-1170, ~CHF 35) or Mini-DP-to-DP cable (~CHF 15)
- Monitor 2 → USB-C-to-HDMI (Club3D CAC-1587, ~CHF 30) or USB-C-to-DP (Club3D CAC-1557, ~CHF 30)

**CalDigit TS3 Plus (CHF 169 used / 191 new):**
- Monitor 1 → regular DisplayPort cable if monitor has DP input (~CHF 15), OR active DP-to-HDMI adapter (Club3D CAC-1080, ~CHF 30) if monitor is HDMI-only
- Monitor 2 → USB-C-to-HDMI/DP cable (~CHF 30)

**Sonnet Echo 11:**
- Both monitors → USB-C-to-HDMI or USB-C-to-DP cables (~CHF 30 each)

**Sonnet Echo 20:**
- Monitor 1 → regular HDMI cable into the built-in HDMI 2.1 port
- Monitor 2 → USB-C-to-HDMI or USB-C-to-DP cable (~CHF 30)

In all cases, budget around **CHF 50–70 total for cables** on top of the dock cost.

### Bottom line

Be careful when buying USB-C cables, but no Mac-specific cable is needed. Buy a Club3D or Delock USB-C-to-HDMI/DP cable rated for 4K@60Hz from Digitec, and it'll work. Avoid generic Amazon cables under CHF 15 — those are often USB-only and won't carry video.

---

## The Complete Comparison Table

### Legend
- ✅ Reviewed in detail and confirmed working for MacBook Air M5 dual-monitor use case
- ❓ Specs match but not reviewed in detail
- ❌ Confirmed will NOT work (or unavailable in Switzerland)

| Status | Dock | Price (CHF) | Driver-free? | HDMI | DisplayPort | TB Downstream | Max Display Resolution | USB-A | USB-C | Ethernet | SD/microSD | Charging | TB Version | Where to Buy |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ✅ | **OWC 14-Port TB3 Dock** (new) | **149** | ✅ Plug-and-play | – | 1× Mini DP 1.2 | 1× TB3 | Dual 4K @ 60Hz, or single 5K @ 60Hz | 5× (5 Gbps) | 1× (10 Gbps) | 1 GbE | SD + microSD (one at a time) | 85 W | TB3 | [Digitec](https://www.digitec.ch/de/s1/product/owc-thunderbolt-3-dock-thunderbolt-14-ports-dockingstation-usb-hub-10259168) (in stock, ships tomorrow) |
| ✅ | **CalDigit TS3 Plus** (used) | **169** | ✅ Plug-and-play | – | 1× DP 1.2 | 1× TB3 | Dual 4K @ 60Hz, or single 5K @ 60Hz | 5× | 1× (10 Gbps) | 1 GbE | SD (UHS-II) | 87 W | TB3 | [Digitec used marketplace](https://www.digitec.ch/de/s1/product/caldigit-ts3-plus-thunderbolt-1-port-dockingstation-usb-hub-15827031) (seller bruno-zysset) |
| ✅ | **CalDigit TS3 Plus** (new) | **191** | ✅ Plug-and-play | – | 1× DP 1.2 | 1× TB3 | Dual 4K @ 60Hz, or single 5K @ 60Hz | 5× | 1× (10 Gbps) | 1 GbE | SD (UHS-II) | 87 W | TB3 | [Amazon.de](https://www.amazon.de/gp/product/B07CVP5HMP/ref=as_li_tl?ie=UTF8&camp=1638&creative=6742&creativeASIN=B07CVP5HMP&linkCode=as2&tag=caldigitsite-de-21&linkId=b05b64f7712ea5eb1c8f34a67634ec2b) (sold by CalDigit) |
| ✅ | **Sonnet Echo 11 TB4** (new) | **231** | ✅ Plug-and-play | – | – | 3× TB4 | Dual 4K @ 60Hz, or single 8K @ 30Hz | 4× (10 Gbps) | – | 1 GbE | SD (UHS-II) | 90 W | TB4 | [Digitec marketplace](https://www.digitec.ch/de/s1/product/sonnet-echo-11-thunderbolt-11-ports-dockingstation-usb-hub-16097792) (JACOB DE, ~2 weeks) |
| ✅ | **Sonnet Echo 20 SuperDock** (used) | **259** | ✅ Plug-and-play | 1× HDMI 2.1 | – | 2× TB4 | Dual 4K @ 60Hz; single 4K @ 120Hz on HDMI 2.1, or single 8K @ 30Hz | 4× (10 Gbps) | 4× (10 Gbps) | 2.5 GbE | SD | 100 W | TB4 | [Digitec used marketplace](https://www.digitec.ch/de/s1/product/sonnet-echo-20-thunderbolt-4-superdock-thunderbolt-20-ports-dockingstation-usb-hub-33099944) (seller midmidmid) |
| ❌ | CalDigit SOHO Dock | ~110 | ✅ But mirror only on Mac | 1× HDMI 2.0b | 1× DP 1.4 | – | Dual 4K @ 60Hz mirrored only on Mac (no extended) | 1× | 2× (10 Gbps) | – | SD + microSD (UHS-II) | 90 W passthrough | USB-C | CalDigit confirms: dual extended NOT supported on Mac |
| ❓ | CalDigit Mini Dock | ~150 | ✅ Plug-and-play | 1× HDMI/DP (varies by SKU) | varies | – | Dual 4K @ 60Hz | 1× | – | 1 GbE | – | Bus-powered (no charging) | TB3 | Not reviewed in detail |
| ❓ | CalDigit Element Hub (TB4) | 1189 ⚠️ overpriced | ✅ Plug-and-play | – | – | 4× TB4 | Dual 4K @ 60Hz, or single 8K @ 30Hz | 4× (10 Gbps) | – | – | – | 60 W | TB4 | Digitec (anomalous price; market is ~CHF 220–260) |
| ❓ | CalDigit TS4 | 828 ⚠️ overpriced | ✅ Plug-and-play | – | 1× DP 1.4 | 3× TB4 | Dual 6K @ 60Hz (with DSC), or dual 4K @ 60Hz | 5× (10 Gbps) | 3× (10 Gbps) | 2.5 GbE | SD + microSD (UHS-II) | 98 W | TB4 | Digitec (anomalous price; market is ~CHF 400) |
| ❓ | CalDigit TS5 | 435 (sale) / 377 | ✅ Plug-and-play | – | – | 4× TB5 | Dual 6K/8K @ 60Hz, or dual 4K @ 240Hz (Mac caps at 2 displays on M5 Air) | 2× | 3× (10 Gbps) | 2.5 GbE | SD + microSD | 140 W | TB5 (overkill for M5 Air) | [Digitec](https://www.digitec.ch/en/s1/product/caldigit-ts5-thunderbolt-station-5-with-1m-thunderbolt-5-cable-thunderbolt-15-ports-docking-stations-61978447) or [Amazon.de](https://www.amazon.de/-/en/CalDigit-Thunderbolt-Station-Cable-CD-TS5TBT5-TS5-EU-AMZ-gray/dp/B0F2G9CMN1) |
| ❓ | CalDigit TS5 Plus | 599 / 503 | ✅ Plug-and-play | – | 1× DP 2.1 | 3× TB5 | Dual 6K/8K @ 60Hz, or dual 4K @ 240Hz (Mac caps at 2 displays on M5 Air) | 5× (10 Gbps) | 5× (10 Gbps) | **10 GbE** | SD | 140 W | TB5 (overkill for M5 Air) | [Digitec](https://www.digitec.ch/de/s1/product/caldigit-ts5-plus-thunderbolt-20-ports-dockingstation-usb-hub-61978446) or [Amazon.de](https://www.amazon.de/-/en/CalDigit-TS5-Plus-Thunderbolt-Charging-gray/dp/B0F2FV86LY) |
| ❌ | Plugable TBT4-UDX1 | ~EUR 270 | ✅ But not available in CH | 1× HDMI 2.0 | – | 2× TB4 | Dual 4K @ 60Hz | 4× (10 Gbps) | 1× (10 Gbps) | 2.5 GbE | SD | 100 W | TB4 | Not available in Switzerland |

---

### Notes on the Max Display Resolution column

- **Resolution numbers reflect the dock's hardware capability**, not what your MacBook Air M5 will actually use. Your M5 Air caps at **2 external displays maximum**, regardless of how many video ports the dock has.
- For **dual extended monitor work on your M5 Air**, every "✅" dock will deliver dual 4K @ 60 Hz comfortably — that's the practical reality.
- The **TS4 / TS5 / TS5 Plus** list higher theoretical resolutions (6K, 8K, 4K @ 240Hz), but those specs are aspirational for future MacBook Pro Max-chip systems. Your M5 Air won't use them.
- The **Sonnet Echo 20's HDMI 2.1 port** is the only entry that can drive 4K @ 120 Hz on a single output. This matters only if you have a high-refresh monitor.
- **DSC (Display Stream Compression)** is required for resolutions beyond 4K @ 60 Hz on TB4 docks. The Mac and monitor both need to support it. For a typical 4K @ 60 Hz dual-monitor setup, DSC is irrelevant.
- 
---


## Top 5 Recommendations

| Rank | Dock | Price (CHF) | Why | Trade-off |
|---|---|---|---|---|
| 🥇 | **OWC 14-Port TB3 Dock** | **149** | Cheapest, new, in stock at Digitec, 5-year warranty | Mini DisplayPort needs adapter cable for HDMI/full-DP monitor (~CHF 20) |
| 🥈 | **CalDigit TS3 Plus (used)** | **169** | Excellent seller (96% positive, 29 sales), full-size DP, 2.5 years warranty left | Used (5 months old) |
| 🥉 | **CalDigit TS3 Plus (new)** | **191** | Brand new, sold by CalDigit on Amazon, 30-day returns | Slightly more than the used Digitec one |
| 4th | **Sonnet Echo 11 TB4** | **231** | True Thunderbolt 4 (newer than TB3) | Both monitors need USB-C-to-HDMI/DP cables; ~2-week delivery |
| 5th | **Sonnet Echo 20 SuperDock (used)** | **259** | TB4, HDMI 2.1 built in, 2.5 GbE, 8 USB ports, internal NVMe slot | Used, smaller seller (2 sales), only ~14 months warranty left |

---

## Final Recommendation

**Buy the OWC 14-Port TB3 Dock at Digitec for CHF 149.**

Three reasons:

1. **Cheapest option** that actually works for dual extended monitors on Mac
2. **In stock at Digitec, ships tomorrow** — no marketplace seller delays
3. **New with 5-year warranty** — beats every other option on coverage

The only minor catch is the Mini DisplayPort, which means you'll need a Mini-DP-to-HDMI or Mini-DP-to-DisplayPort cable from Digitec (~CHF 15–25) for Monitor 1. Even with the cable, total cost is around CHF 165–175 — still cheapest, newest, and best-warrantied.

If your Monitor 1 has DisplayPort input directly, the **CalDigit TS3 Plus used at CHF 169** is a tie — full-size DP means you skip the adapter, and the brand has slightly stronger Mac reputation. Either choice ends the search.

### Don't overspend
For a MacBook Air M5 running 2 monitors + USB peripherals + Ethernet, **TB3 vs TB4 makes no practical difference**. Your Mac caps at 2 external displays anyway. Spending CHF 400+ on a CalDigit TS4 or CHF 600+ on a TS5 Plus only makes sense if you're planning to upgrade to a MacBook Pro with M-series Pro/Max chips that can drive 3+ monitors.

### Cable notes
- **Monitor 1 with DisplayPort input** → use a regular DP cable (or Mini-DP-to-DP for the OWC)
- **Monitor 1 with HDMI input** → use an active DP-to-HDMI adapter (passive adapters fail at 4K)
- **Monitor 2 via Thunderbolt port** → use a USB-C-to-HDMI or USB-C-to-DP cable (Club3D CAC-1587 for HDMI, CAC-1557 for DP, both ~CHF 30 from Digitec)
- **Avoid sub-CHF 15 cables from Amazon** — they're often USB 3.x only and won't carry DisplayPort signals reliably at 4K60

---

## What I Actually Bought (Confirmed Working)

This is the exact setup purchased and confirmed working for dual extended monitors on a MacBook Air M5. Very cost-effective.

| # | Product | Purpose | Price (CHF) | Link |
|---|---|---|---:|---|
| 1 | **OWC Thunderbolt 3 Dock** — Thunderbolt, 14 Ports | The dock | 148.00 | [Digitec](https://www.digitec.ch/de/s1/product/owc-thunderbolt-3-dock-thunderbolt-14-ports-dockingstation-usb-hub-10259168) · [OWC](https://www.owc.com/solutions/thunderbolt-3-dock-14-port) |
| 2 | **InLine Mini DisplayPort – DisplayPort** — 2 m | Monitor 1 (Mini DP out → DP monitor) | 9.40 | [Digitec](https://www.digitec.ch/de/s1/product/inline-mini-displayport-displayport-2-m-videokabel-13109819) |
| 3 | **Sonero USB C – HDMI** — 2 m | Monitor 2 (TB3 downstream port → HDMI monitor) | 20.70 | [Digitec](https://www.digitec.ch/de/s1/product/sonero-usb-c-hdmi-2-m-videokabel-38926798) |
| 4 | **Tech-Protect USB C — USB C** — 2 m, USB 4.0, 240 W | MacBook to dock connection | 15.90 | [Digitec](https://www.digitec.ch/de/s1/product/tech-protect-usb-c-usb-c-2-m-usb-40-240-w-usb-kabel-46448271) |
| | | **Total** | **194.00** | |

### Monitors

| Position | Monitor | Resolution | Connection |
|---|---|---:|---|
| Left | [Dell G2724D](https://www.digitec.ch/de/s1/product/dell-g2724d-2560-x-1440-pixel-27-monitor-36881128) — 27" | 2560 × 1440 (1440p) | InLine Mini DP → DP cable (dock Mini DP out) |
| Right | [Dell P2219H](https://www.digitec.ch/de/s1/product/dell-p2219h-1920-x-1080-pixel-22-monitor-9107180) — 22" | 1920 × 1080 (1080p) | Sonero USB-C → HDMI cable (dock TB3 downstream) |

### How it's wired

```
MacBook Air M5, 13 inch, 32GB RAM, 1TB SSD (Model A3449, Model Identifier Mac17,3)
    │
    │  Tech-Protect USB-C → USB-C (USB 4.0, 240W, 2m)
    │
    ▼
OWC TB3 Dock (14 ports)
    │
    ├── Mini DisplayPort
    │       │  InLine Mini DP → DP (2m)
    │       ▼
    │       Dell G2724D — 27" 1440p  [LEFT]
    │
    └── TB3 downstream
            │  Sonero USB-C → HDMI (2m)
            ▼
            Dell P2219H — 22" 1080p  [RIGHT]
```

### Product details

**1. OWC Thunderbolt 3 Dock — 14 Ports**
- 5× USB-A 3.0, 1× USB-C (10 Gbps), 1× Mini DisplayPort 1.2, 1× TB3 downstream, 1× RJ-45 (1 GbE), 1× SD + 1× microSD, 3.5mm audio, optical S/PDIF
- 85 W charging to MacBook, dual 4K @ 60 Hz capable, 5-year warranty
- macOS + Windows compatible

**2. InLine Mini DisplayPort – DisplayPort — 2 m**
- Mini DP (male) → DisplayPort (male), DP 1.2, max 4K @ 60 Hz (3840 × 2160)
- Fully shielded, gold-plated contacts

**3. Sonero USB C – HDMI — 2 m**
- USB-C (male) → HDMI (male), HDMI 2.0, max 4K @ 60 Hz (3840 × 2160)
- Braided aluminium cable, made in Germany

**4. Tech-Protect USB C — USB C — 2 m, USB 4.0, 240 W**
- USB-C (male) → USB-C (male), USB 4.0, 40 Gbps data, 240 W Power Delivery
- This is what carries the Thunderbolt signal from the MacBook to the dock; the high wattage also fully charges the MacBook through the dock

---

*Last updated: 7 May 2026*
