# Network Log rename + icon, Network Stop / Start

## Apps (~/Applications, built by homelab-dns/build-log-launcher.sh, no sudo)
| App | Does | Icon symbol |
|---|---|---|
| Network Log | as today: folder + log in new VS Code window | list.bullet.rectangle |
| Network Stop | creates the flag, notifies | stop.fill |
| Network Start | removes the flag, notifies | play.fill |

- Old `ethernet wifi network log.app` is removed and unregistered by the build.
- Try to keep `ethernet`/`wifi` findable via CFBundleName; check with mdls, drop if it does not work.
- Icons: blue family from window-manager/make-icon.sh (not edited; output moved), committed .icns copied into Resources.
- Notification: `osascript -e 'display notification'` only (user approved). State dir missing: notify to run install.

## Flag
- `/usr/local/var/homelab-dns/stopped`. Dir created by install.sh, owned by $SUDO_USER, 755. Survives reboot.

## Daemons
- New LaunchDaemon `com.tomigorn.homelab-dns-control`: WatchPaths on the state dir, runs `/usr/local/sbin/homelab-dns-control.sh` = net-priority.sh control, then homelab-dns.sh control.
- Flag + reason control:
  - actor: no probe, revert every service on 192.168.1.2 to DHCP (existing revert path), log `homelab=stopped tries=0`.
  - priority: no probe, every en* service except Wi-Fi that sits below Wi-Fi moves directly above it, disabled and address-less ones too. bridge0 and VPN entries stay. Log a line.
- Flag + any other reason (boot, change, timer, manual): touch nothing, no log line, no probe. Re-check flag after the probe / before writing the order (a run in flight when Stop lands).
- No flag + control (Start): normal evaluation of both, logged.

## Install / uninstall
- install.sh: state dir, third script, third daemon. uninstall.sh: removes them, including the state dir.

## Tests (stubbed, tests/test-all.sh picks them up)
- homelab-dns.sh, net-priority.sh: the four flag cases above.
- control launcher: stop creates flag, start removes it, notification text, missing dir.
- build: bundle names, plist icon key, icons present, old app removed (temp HOME, lsregister overridable).

## Not run by me
install.sh and uninstall.sh are edit-only. Daemon behaviour on the real Mac is verified by the user after install.
