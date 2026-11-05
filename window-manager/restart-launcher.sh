#!/usr/bin/env bash
# Restarts the yabai + skhd services — the "it's bugged, fix it" button.
# This is the executable inside "yabai window manager - restart.app"
# (Spotlight/Launchpad): type "yabai" or "window manager", pick this one, Enter.
#
# Use it when a window won't move/snap (e.g. a fullscreen-video window yabai lost
# its Accessibility handle to) or when the keyboard shortcuts stop firing.

# Launch Services gives a minimal PATH; make the Homebrew bins findable
# (same problem yabai-snap.sh handles). Intel Homebrew lives in /usr/local.
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

# Restart with a start fallback, so this also works if a service was fully stopped.
yabai --restart-service 2>/dev/null || yabai --start-service 2>/dev/null || true
skhd  --restart-service 2>/dev/null || skhd  --start-service 2>/dev/null || true
sleep 1

down=""
pgrep -x yabai >/dev/null || down="yabai"
pgrep -x skhd >/dev/null || down="${down:+$down }skhd"

# The app has no window of its own: the notification is its only feedback.
if [ -z "$down" ]; then
  osascript -e 'display notification "yabai + skhd restarted" with title "Window manager reloaded"' >/dev/null 2>&1 || true
else
  osascript -e "display notification \"$down is not running, check Accessibility\" with title \"Window manager restart failed\"" >/dev/null 2>&1 || true
fi
