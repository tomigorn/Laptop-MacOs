#!/usr/bin/env bash
# Opens the network log in VS Code; the executable inside "ethernet wifi network log.app".
LOG_FILE="/var/log/homelab-dns.log"

open -b com.microsoft.VSCode "$LOG_FILE" 2>/dev/null \
    || open -a "Visual Studio Code" "$LOG_FILE"
