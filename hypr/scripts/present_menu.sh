#!/bin/bash
# fzf TUI for wl-present screen mirroring controls

DEBUG_LOG="/tmp/present-menu-debug.log"
echo "[$(date '+%H:%M:%S')] script started, args: $*" >> "$DEBUG_LOG"

MIRROR_OUTPUT="eDP-1"
PRESENT_OUTPUT="HDMI-A-1"
PIPE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pipectl.1000.wl-present.pipe"

# A previous mirror session killed with Ctrl+C (instead of Stop Mirror) leaves
# this FIFO behind, which then blocks every future launch with "File exists".
if ! pgrep -x wl-mirror >/dev/null 2>&1; then
    rm -f "$PIPE"
fi

CHOICE=$(printf '%s\n' \
    "Mirror to $PRESENT_OUTPUT" \
    "Toggle Freeze" \
    "Fullscreen Output" \
    "Stop Mirror" \
    | fzf --prompt="wl-present> " --height=100% --border --header="Presentation Mirror")

echo "[$(date '+%H:%M:%S')] fzf exit=$? choice='$CHOICE'" >> "$DEBUG_LOG"

case "$CHOICE" in
    "Mirror to $PRESENT_OUTPUT")
        echo "[$(date '+%H:%M:%S')] launching mirror" >> "$DEBUG_LOG"
        setsid wl-present mirror "$MIRROR_OUTPUT" --fullscreen-output "$PRESENT_OUTPUT" --fullscreen \
            >/tmp/wl-present.log 2>&1 < /dev/null &
        ;;
    "Fullscreen Output")
        wl-present fullscreen-output "$PRESENT_OUTPUT"
        ;;
    "Toggle Freeze")
        /home/miles/.local/bin/smart_present_freeze.sh
        ;;
    "Stop Mirror")
        pkill -x wl-mirror || true
        ;;
    *)
        echo "[$(date '+%H:%M:%S')] no match for choice" >> "$DEBUG_LOG"
        ;;
esac

echo "[$(date '+%H:%M:%S')] script exiting" >> "$DEBUG_LOG"
sleep 1
