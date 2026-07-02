#!/bin/bash
QS_PID=$(ps -eo pid,stat,comm | awk '$2 !~ /T/ && $3 == "quickshell" {print $1; exit}')
if [ -n "$QS_PID" ]; then
    quickshell ipc --pid "$QS_PID" call qsIpc toggleWallpaperPicker
else
    find ~/.config/hypr/wallpaper -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null \
        | xargs -n1 basename | sed 's/\.[^.]*$//' \
        | tofi --prompt-text " Wallpaper: " \
        | xargs -I{} sh -c 'f=$(find ~/.config/hypr/wallpaper -name "{}.*" | head -1); [ -f "$f" ] && /home/miles/.local/bin/set_wallpaper.sh "$f"'
fi
