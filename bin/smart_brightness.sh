#!/bin/bash
ACTION=$1

case $ACTION in
    up)
        brightnessctl s 5%+
        ;;
    down)
        brightnessctl s 5%-
        ;;
esac

PCT=$(brightnessctl i | grep -oP '\(\K[^%]+')
QS_PID=$(ps -eo pid,stat,comm | awk '$2 !~ /T/ && $3 == "quickshell" {print $1; exit}')

if [ -n "$QS_PID" ]; then
    quickshell ipc --pid "$QS_PID" call qsIpc showOsd B "$PCT"
else
    echo "$PCT" > $XDG_RUNTIME_DIR/wob.fifo
fi
