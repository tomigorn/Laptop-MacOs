#!/bin/bash
# Wrapper that makes virt-manager launchable from Spotlight / dock / Launchpad.
#
# When macOS launches a GUI app from outside a shell it sets a minimal env
# (no Homebrew PATH, no XDG_DATA_DIRS). virt-manager is a GTK app and refuses
# to start unless XDG_DATA_DIRS contains /opt/homebrew/share so it can find
# its GSettings schemas; some libvirt helpers it spawns also need the
# Homebrew bin dir on PATH. This wrapper sets both, then execs virt-manager.
#
# This file is symlinked into Virt-Manager.app/Contents/MacOS/virt-manager-launcher
# by build.sh, so edits here are live the next time the .app is launched.

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:${PATH}"
export XDG_DATA_DIRS="/opt/homebrew/share:${XDG_DATA_DIRS}"

exec /opt/homebrew/bin/virt-manager "$@"
