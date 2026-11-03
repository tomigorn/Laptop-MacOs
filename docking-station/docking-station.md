# Docking station

Buying guide for a dual-monitor dock on a MacBook Air M5, plus the ETH wired-network (NAC) notes for the docks in use.

| File | What |
|---|---|
| [docking-station-guide.md](docking-station-guide.md) | dock comparison, cables, KVM switches, what was bought |
| [ethernet-nac.md](ethernet-nac.md) | dock Ethernet MACs and their NAC (MAB) registration |
| `net-diag.sh` | dumps wired-dock network state to a file while the internet is down |

## net-diag.sh

Run it while the dock is active and the internet is broken, then switch back to Wi-Fi and read the file. No sudo.

```sh
sh docking-station/net-diag.sh          # dock interface en6
sh docking-station/net-diag.sh en7      # another interface
```

Writes `~/net-diag-<timestamp>.txt` and prints the path.

## Install / tests

None. `net-diag.sh` is syntax-checked by `tests/test-all.sh`.
