#!/bin/bash
WALLPAPER="$1"
[ -f "$WALLPAPER" ] || exit 1

JSON=$(~/.local/bin/matugen image "$WALLPAPER" --json hex --prefer=darkness 2>/dev/null)
if [ -z "$JSON" ]; then
    /home/miles/.local/bin/set_wallpaper.sh "$WALLPAPER"
    exit 0
fi

COLORS=$(python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    colors = d.get('colors', {})
    def get_color(name, fallback):
        c = colors.get(name, {})
        return c.get('dark', c.get('default', {})).get('color', fallback)
    bg     = get_color('background', '#1a1b26')
    fg     = get_color('on_background', '#e0e0e0')
    accent = get_color('primary', '#7aa2f7')
    print(f'{bg}|{fg}|{accent}')
except Exception as e:
    print('#1a1b26|#e0e0e0|#7aa2f7')
" <<< "$JSON")
IFS='|' read -r BG FG ACCENT <<< "$COLORS"

/home/miles/.local/bin/set_wallpaper.sh "$WALLPAPER"

hyprctl eval "hl.config({ general = { col = { active_border = 0xff${ACCENT#\#} } } })" 2>/dev/null || true

sed -i "s/^background-color =.*/background-color = ${BG}/" ~/.config/tofi/config
sed -i "s/^text-color =.*/text-color = ${FG}/" ~/.config/tofi/config
sed -i "s/^selection-color =.*/selection-color = ${ACCENT}/" ~/.config/tofi/config

pkill -SIGUSR2 waybar 2>/dev/null

QS_PID=$(ps -eo pid,stat,comm | awk '$2 !~ /T/ && $3 == "quickshell" {print $1; exit}')
[ -n "$QS_PID" ] && quickshell ipc --pid "$QS_PID" call qsIpc updateColors "$BG" "$FG" "$ACCENT"
