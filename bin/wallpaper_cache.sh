#!/bin/bash
# Generates a small cached thumbnail (.sqre) per wallpaper, keyed by sha1 hash,
# so the picker UI can load thumbnails instead of decoding full-size images.
WALLPAPER_DIR="$HOME/.config/hypr/wallpaper"
CACHE_DIR="$HOME/.cache/wallpaper/thumbs"
mkdir -p "$CACHE_DIR"

cache_one() {
    local wall="$1"
    [ -f "$wall" ] || return 1
    local hash thumb
    hash=$(sha1sum "$wall" | cut -d' ' -f1)
    thumb="$CACHE_DIR/$hash.sqre"
    [ -f "$thumb" ] && return 0
    magick "$wall[0]" -strip -thumbnail 300x300^ -gravity center -extent 300x300 "$thumb.tmp" \
        && mv "$thumb.tmp" "$thumb"
}

if [ "$1" == "--all" ]; then
    find "$WALLPAPER_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | while read -r f; do
        cache_one "$f"
    done
else
    cache_one "$1"
fi
