#!/bin/sh
# Executable of Network Stop.app and Network Start.app; which one it is comes from the name it runs under.
STATE_DIR="/usr/local/var/homelab-dns"
FLAG="${STATE_DIR}/stopped"

# The apps have no window: the notification is their only feedback.
notify() {
    osascript -e "display notification \"$1\" with title \"Network switcher\"" >/dev/null 2>&1 || true
}

if [ ! -w "${STATE_DIR}" ]; then
    notify "Not installed, run sudo ./install.sh in homelab-dns"
    exit 1
fi

case "$(basename "$0")" in
    network-stop)
        if [ -e "${FLAG}" ]; then
            notify "Already stopped"
        else
            touch "${FLAG}" && notify "Stopped, DNS and adapter order go back"
        fi
        ;;
    network-start)
        if [ -e "${FLAG}" ]; then
            rm -f "${FLAG}" && notify "Started, checking the network"
        else
            notify "Already running"
        fi
        ;;
    *) exit 2 ;;
esac
