#!/bin/bash

REMOTE_URL="https://backdrop-carousel.holy-grail.ch"
LOCAL_DIR="$HOME/Pictures/BackdropCarousel"
BRAVE_IMAGES_DIR="$HOME/Library/Application Support/BraveSoftware/Brave-Browser/Default/sanitized_background_images"
BRAVE_PREFS="$HOME/Library/Application Support/BraveSoftware/Brave-Browser/Default/Preferences"

mkdir -p "$LOCAL_DIR"

remote_photos=$(curl -sf "$REMOTE_URL/" | python3 -c "import sys,json; [print(p['name']) for p in json.load(sys.stdin)]") || { echo "ERROR: Failed to fetch photo list from server"; exit 1; }

for name in $remote_photos; do
    if [ ! -f "$LOCAL_DIR/$name" ]; then
        curl -sf "$REMOTE_URL/photo/$name" -o "$LOCAL_DIR/$name"
    fi
done

for file in "$LOCAL_DIR"/*; do
    [ -f "$file" ] || continue
    name=$(basename "$file")
    if ! echo "$remote_photos" | grep -qxF "$name"; then
        rm "$file"
    fi
done

count=$(echo "$remote_photos" | wc -l | tr -d ' ')

if pgrep -q "Brave Browser"; then
    echo "Synced $count photos to wallpaper. Brave skipped (running)."
    exit 0
fi

if [ ! -d "$BRAVE_IMAGES_DIR" ] || [ ! -f "$BRAVE_PREFS" ]; then
    echo "Synced $count photos to wallpaper. Brave not installed."
    exit 0
fi

for name in $remote_photos; do
    if [ ! -f "$BRAVE_IMAGES_DIR/$name" ]; then
        cp "$LOCAL_DIR/$name" "$BRAVE_IMAGES_DIR/$name"
    fi
done

for file in "$BRAVE_IMAGES_DIR"/*; do
    [ -f "$file" ] || continue
    name=$(basename "$file")
    if ! echo "$remote_photos" | grep -qxF "$name"; then
        rm "$file"
    fi
done

python3 -c "
import json, sys

prefs_path = sys.argv[1]
photos = sys.argv[2:]

with open(prefs_path, 'r') as f:
    prefs = json.load(f)

ntp = prefs.setdefault('brave', {}).setdefault('new_tab_page', {})
ntp['custom_background_image_list'] = photos
ntp.setdefault('background', {})
ntp['background']['type'] = 'custom_image'
ntp['background']['random'] = True
if ntp['background'].get('selected_value', '') not in photos and photos:
    ntp['background']['selected_value'] = photos[0]

with open(prefs_path, 'w') as f:
    json.dump(prefs, f, separators=(',', ':'))
" "$BRAVE_PREFS" $remote_photos

echo "Synced $count photos to wallpaper + Brave."
