#!/bin/bash
ACTION=$1

case $ACTION in
    up)
        wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 2%+
        ;;
    down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-
        ;;
    mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
esac

VAL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
if echo "$VAL" | grep -q "MUTED"; then
    PCT=0
else
    PCT=$(echo "$VAL" | LC_ALL=C awk '{print int($2 * 100)}')
fi
QS_PID=$(ps -eo pid,stat,comm | awk '$2 !~ /T/ && $3 == "quickshell" {print $1; exit}')

if [ -n "$QS_PID" ]; then
    quickshell ipc --pid "$QS_PID" call qsIpc showOsd V "$PCT"
else
    echo "$PCT" > $XDG_RUNTIME_DIR/wob.fifo
fi
