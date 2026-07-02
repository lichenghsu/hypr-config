#!/bin/bash
# Cycle through ~/.config/hypr/wallpaper via next/previous/random/set,
# applying through the existing set_wallpaper.sh backend.
WALLPAPER_DIR="$HOME/.config/hypr/wallpaper"
HYPRPAPER_CONF="$HOME/.config/hypr/hyprpaper.conf"
SET_SCRIPT="$HOME/.local/bin/set_wallpaper.sh"
CACHE_SCRIPT="$HOME/.local/bin/wallpaper_cache.sh"

mapfile -t WALLPAPERS < <(find "$WALLPAPER_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | sort)

current_wallpaper() {
    [ -f "$HYPRPAPER_CONF" ] || return 1
    grep -m1 '^wallpaper = ,' "$HYPRPAPER_CONF" | sed 's/^wallpaper = ,//'
}

apply() {
    local target="$1"
    [ -f "$target" ] || { echo "No such wallpaper: $target" >&2; exit 1; }
    "$SET_SCRIPT" "$target"
    "$CACHE_SCRIPT" "$target" &
}

index_of() {
    local target="$1" i
    for i in "${!WALLPAPERS[@]}"; do
        [ "${WALLPAPERS[$i]}" == "$target" ] && { echo "$i"; return 0; }
    done
    echo -1
}

[ ${#WALLPAPERS[@]} -eq 0 ] && { echo "No wallpapers found in $WALLPAPER_DIR" >&2; exit 1; }

case "$1" in
    --next|--previous)
        cur="$(current_wallpaper)"
        idx="$(index_of "$cur")"
        count=${#WALLPAPERS[@]}
        if [ "$1" == "--next" ]; then
            next=$(( (idx + 1) % count ))
        else
            next=$(( (idx - 1 + count) % count ))
        fi
        apply "${WALLPAPERS[$next]}"
        ;;
    --random)
        apply "${WALLPAPERS[$((RANDOM % ${#WALLPAPERS[@]}))]}"
        ;;
    --set)
        [ -z "$2" ] && { echo "--set requires a file path" >&2; exit 1; }
        apply "$2"
        ;;
    --get)
        current_wallpaper
        ;;
    *)
        echo "Usage: $(basename "$0") --next|--previous|--random|--set <file>|--get" >&2
        exit 1
        ;;
esac
