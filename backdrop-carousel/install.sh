#!/bin/zsh
# Symlinks sync.sh to ~/bin for the Shortcut (Control Center has trouble with deep paths) and builds backdrop-wallpaper into ~/bin.

set -e

SCRIPT_DIR="${0:A:h}"
SOURCE="$SCRIPT_DIR/sync.sh"
TARGET_DIR="$HOME/bin"
TARGET="$TARGET_DIR/backdrop-sync.sh"

mkdir -p "$TARGET_DIR"
ln -sf "$SOURCE" "$TARGET"

WALLPAPER="$TARGET_DIR/backdrop-wallpaper"
if ! command -v swiftc >/dev/null; then
    echo "swiftc not found (Xcode or Command Line Tools): backdrop-wallpaper not built"
    exit 1
fi
swiftc -O "$SCRIPT_DIR/wallpaper.swift" -o "$WALLPAPER"
echo "Built: $WALLPAPER"

echo "Symlink installed:"
echo "  $TARGET -> $SOURCE"
echo
echo "Point the Shortcut's 'Run Shell Script' action at:"
echo "  $TARGET"
echo "and set the shell to /bin/zsh."
echo
echo "If running from Control Center still fails, grant Full Disk Access to"
echo "Shortcuts.app and Finder in System Settings > Privacy & Security, then"
echo "log out and back in."
