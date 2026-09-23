#!/bin/bash
# Lock dispatcher: caffeine on → hyprlock (screen stays on, no suspend),
# otherwise → Quickshell lock screen.
# No "already running" check: pidof sees lockers from other sessions/ttys,
# and Hyprland refuses a second session lock on its own.
RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
CAFFEINE_FLAG="$RUNTIME/caffeine"

if [ ! -e "$CAFFEINE_FLAG" ]; then
    exec /home/miles/.local/bin/qs-lock
fi

# hyprlock: blurred greyscale screenshot + ring with clock inside, per monitor.
# Written to a config that hypr/hyprlock.conf sources. Screenshots are captured
# at 20% for speed (hyprlock scales them up). Widget sizes below are logical px
# and get multiplied by the monitor scale, since hyprlock draws in physical px.
DIR="$RUNTIME/hyprlock"
CONF="$DIR/monitors.conf"
mkdir -p "$DIR"
rm -f "$DIR"/*.png
: > "$CONF"

px() { awk -v v="$1" -v s="$scale" 'BEGIN { printf "%d", v * s + (v < 0 ? -0.5 : 0.5) }'; }

while read -r out scale; do
    img="$DIR/$out.png"
    grim -o "$out" -s 0.2 -t ppm - \
        | magick - -blur 0x1 -colorspace Gray "$img" &
    cat >> "$CONF" <<CONF
background {
    monitor = $out
    path = $img
    color = rgba(0, 0, 0, 1.0)
}

# Ring = circular input-field (old swaylock-effects indicator-radius=120, thickness=8).
# hide_input: no dots; the ring flashes a colour per keystroke instead.
input-field {
    monitor = $out
    size = $(px 240), $(px 240)
    halign = center
    valign = center
    position = 0, 0
    rounding = -1
    outline_thickness = $(px 8)
    hide_input = true
    hide_input_base_color = rgba(255, 255, 255, 0.4)
    placeholder_text =
    fail_text =
    outer_color = rgba(255, 255, 255, 0.07)
    inner_color = rgba(0, 0, 0, 0.0)
    font_color = rgba(255, 255, 255, 0.6)
    check_color = rgba(136, 192, 208, 0.2)
    fail_color = rgba(191, 97, 106, 0.4)
    fade_on_empty = false
}

label {
    monitor = $out
    text = cmd[update:1000] date +%H:%M
    font_family = JetBrainsMono Nerd Font
    font_size = $(px 40)
    color = rgba(255, 255, 255, 0.6)
    halign = center
    valign = center
    position = 0, $(px 14)
}

label {
    monitor = $out
    text = cmd[update:60000] LC_TIME=C date '+%A, %B %d'
    font_family = JetBrainsMono Nerd Font
    font_size = $(px 11)
    color = rgba(255, 255, 255, 0.6)
    halign = center
    valign = center
    position = 0, $(px -30)
}

CONF
done < <(hyprctl monitors -j | jq -r '.[] | "\(.name) \(.scale)"')
wait

exec hyprlock
