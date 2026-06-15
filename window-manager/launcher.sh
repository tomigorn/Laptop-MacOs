#!/usr/bin/env bash
# Opens the yabai window-manager config folder in VS Code.
# This is the executable inside "yabai window manager.app" (Spotlight/Launchpad).
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/yabai"
# Prefer bundle-id (works wherever VS Code is installed); fall back to app name.
open -b com.microsoft.VSCode "$CONFIG_DIR" 2>/dev/null \
    || open -a "Visual Studio Code" "$CONFIG_DIR"
