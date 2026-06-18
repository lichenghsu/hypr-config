#!/bin/bash
# Window picker: search by title/class, jump to workspace and focus
selected=$(hyprctl clients -j | python3 -c "
import json, sys

clients = json.load(sys.stdin)
# Sort by workspace id (specials last)
def ws_sort(c):
    wid = c.get('workspace', {}).get('id', 0)
    return (1 if wid > 0 else 2, wid)
clients.sort(key=ws_sort)

for c in clients:
    wid = c.get('workspace', {}).get('id', 0)
    ws_label = f'WS {wid}' if wid > 0 else c.get('workspace', {}).get('name', f'WS {wid}')
    title = (c.get('title') or c.get('initialTitle') or '').strip()
    cls = (c.get('class') or '').strip()
    addr = c.get('address', '')
    display = f'[{ws_label}]  {title}  ({cls})'
    print(f'{display}\t{addr}')
" | tofi \
         --anchor center \
         --width 680 \
         --height 420 \
         --horizontal false \
         --font "JetBrainsMono Nerd Font" \
         --font-size 14 \
         --prompt-text "  " \
         --num-results 8 \
         --result-spacing 4 \
         --padding-top 16 \
         --padding-bottom 16 \
         --padding-left 20 \
         --padding-right 20 \
         --outline-width 0 \
         --border-width 2 \
         --border-color "#3a8fbfcc" \
         --corner-radius 12 \
         --background-color "#000000ee" \
         --text-color "#dddddd" \
         --prompt-color "#3a8fbf" \
         --selection-color "#ff4b30" \
         --selection-background "#ffffff11" \
         2>/dev/null)

[[ -z "$selected" ]] && exit 0

addr=$(echo "$selected" | awk -F'\t' '{print $2}')
[[ -z "$addr" ]] && exit 0

hyprctl eval "hl.dispatch(hl.dsp.focus({ window = 'address:$addr' }))"
