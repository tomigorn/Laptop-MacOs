# Network control

Control Center button that shows which connection carries your traffic. Being connected isn't enough: Ethernet behind a login page counts only if macOS really uses it.

| Icon | Title | Meaning |
|---|---|---|
| `wifi` | Wi-Fi | Wi-Fi is the connection in use |
| `cable.connector` | Ethernet | Ethernet is the connection in use |
| `network` | Other | only a VPN or other link |
| `network.slash` | Offline | no usable connection |

A VPN on top is skipped: the control shows the real connection below it.

**It doesn't update by itself.** Click the button to refresh; until then it can show the previous connection.

## Install

```sh
network-control/install.sh
```

Then add it: Control Center → Edit Controls → **Network in use**.

Needs Xcode and an Apple Development certificate. No sudo, daemon, LaunchAgent or login item. The app quits at once; only the extension runs, when macOS asks it for a value.

Remove: delete `~/Applications/NetworkControl.app`.

## Test

```sh
network-control/tests/network-use.sh
```
