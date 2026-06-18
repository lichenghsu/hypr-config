#!/bin/bash
WALLPAPER="$1"
[ -f "$WALLPAPER" ] || exit 1
printf "preload = %s\nwallpaper = ,%s\nsplash = false\nipc = on\n" "$WALLPAPER" "$WALLPAPER" > ~/.config/hypr/hyprpaper.conf
pgrep -x "hyprpaper" > /dev/null || { hyprpaper & sleep 1; }
hyprctl hyprpaper preload "$WALLPAPER" 2>/dev/null
hyprctl hyprpaper wallpaper ",$WALLPAPER" 2>/dev/null
