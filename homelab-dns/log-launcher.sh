#!/usr/bin/env bash
# Opens this folder with the log link as a tab in a new VS Code window; the executable inside "ethernet wifi network log.app".
SCRIPT="$(readlink "$0" || echo "$0")"
FOLDER="$(cd "$(dirname "$SCRIPT")" && pwd)"
LOG_LINK="$FOLDER/homelab-dns.log"

open -n -b com.microsoft.VSCode --args --new-window "$FOLDER" "$LOG_LINK" 2>/dev/null \
    || open -n -a "Visual Studio Code" --args --new-window "$FOLDER" "$LOG_LINK"
