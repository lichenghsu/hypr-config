#!/bin/bash
QS_PID=$(ps -eo pid,stat,comm | awk '$2 !~ /T/ && $3 == "quickshell" {print $1; exit}')
if [ -n "$QS_PID" ]; then
    quickshell ipc --pid "$QS_PID" call qsIpc toggleWallpaperPicker
else
    ls ~/.config/hypr/wallpaper/*.jpg ~/.config/hypr/wallpaper/*.png 2>/dev/null \
        | xargs -n1 basename | sed 's/\.[^.]*$//' \
        | tofi --prompt-text " Wallpaper: " \
        | xargs -I{} sh -c 'f=$(find ~/.config/hypr/wallpaper -maxdepth 1 -name "{}.*" | head -1); [ -f "$f" ] && /home/miles/.local/bin/set_wallpaper.sh "$f"'
fi
