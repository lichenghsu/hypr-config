#!/bin/sh
# 每 0.5 秒輸出一行：player|status|title|artist|artUrl|length|url
# Chromium/Brave 自己的 MPRIS 常沒有 artUrl（或指向很快被刪掉的 /tmp 暫存檔）也沒有 url，
# 這時用 plasma-browser-integration 擴充提供的資料補上（同一支影片）
while true; do
    out=$(playerctl metadata --format '{{playerName}}|{{status}}|{{title}}|{{artist}}|{{mpris:artUrl}}|{{mpris:length}}|{{xesam:url}}' 2>/dev/null)
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
        echo "$out"
    fi
    sleep 0.5
done
