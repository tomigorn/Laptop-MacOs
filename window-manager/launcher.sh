#!/usr/bin/env bash
# Opens the yabai window-manager config folder in VS Code.
# This is the executable inside "yabai window manager.app" (Spotlight/Launchpad).
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/yabai"

# Refresh the "Currently connected" block at the top of zones.conf first, so the
# file you're about to edit already says which of the monitor lines are live.
# Done before opening (VS Code would otherwise show the stale block for a beat),
# but never allowed to stop the folder from opening.
"$CONFIG_DIR/yabai-snap.sh" connected >/dev/null 2>&1 || true

# Prefer bundle-id (works wherever VS Code is installed); fall back to app name.
open -b com.microsoft.VSCode "$CONFIG_DIR" 2>/dev/null \
    || open -a "Visual Studio Code" "$CONFIG_DIR"
