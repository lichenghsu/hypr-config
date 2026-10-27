#!/bin/sh
# 每 0.5 秒輸出一行：player|status|title|artist|artUrl|length|url|album|instance
# Chromium/Brave 自己的 MPRIS 常沒有 artUrl（或指向很快被刪掉的 /tmp 暫存檔）也沒有 url，
# 這時用 plasma-browser-integration 擴充提供的資料補上（同一支影片）
# 跟哪個 player：優先正在播放的；都沒在播就黏著上一個，它不見了才退回第一個
# 選中的 instance 寫到 $XDG_RUNTIME_DIR/qs-mpris-player，給 shell.qml 的 position 輪詢共用
sel="${XDG_RUNTIME_DIR:-/tmp}/qs-mpris-player"
cur=""
while true; do
    list=$(playerctl -a metadata --format '{{playerInstance}}|{{status}}' 2>/dev/null)
    p=$(printf '%s\n' "$list" | awk -F'|' '$2 == "Playing" { print $1; exit }')
    if [ -z "$p" ]; then
        if [ -n "$cur" ] && printf '%s\n' "$list" | cut -d'|' -f1 | grep -qxF "$cur"; then
            p=$cur
        else
            p=$(printf '%s\n' "$list" | head -n1 | cut -d'|' -f1)
        fi
    fi
    if [ "$p" != "$cur" ]; then
        cur=$p
        printf '%s\n' "$cur" > "$sel"
    fi
    out=""
    [ -n "$p" ] && out=$(playerctl -p "$p" metadata --format '{{playerName}}|{{status}}|{{title}}|{{artist}}|{{mpris:artUrl}}|{{mpris:length}}|{{xesam:url}}|{{xesam:album}}' 2>/dev/null)
    if [ -z "$out" ]; then
        echo 'offline||||0'
    else
        art=$(printf '%s' "$out" | cut -d'|' -f5)
        url=$(printf '%s' "$out" | cut -d'|' -f7)
        f=${art#file://}
        if [ -z "$art" ] || { [ "$f" != "$art" ] && [ ! -e "$f" ]; }; then
            alt=$(playerctl -p plasma-browser-integration metadata mpris:artUrl 2>/dev/null)
            [ -n "$alt" ] && out=$(printf '%s' "$out" | awk -F'|' -v OFS='|' -v a="$alt" '{$5=a; print}')
        fi
        if [ -z "$url" ]; then
            alt=$(playerctl -p plasma-browser-integration metadata xesam:url 2>/dev/null)
            [ -n "$alt" ] && out=$(printf '%s' "$out" | awk -F'|' -v OFS='|' -v u="$alt" '{$7=u; print}')
        fi
        echo "$out|$p"
    fi
    sleep 0.5
done
