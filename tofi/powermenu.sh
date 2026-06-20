#!/usr/bin/env bash
options="Shutdown\nLock\nSuspend\nReboot\nLogout"

# DEVE usare solo il config, senza aggiungere colori a mano qui!
choice=$(echo -e "$options" | tofi --config ~/.config/tofi/configpowermenu)

case "$choice" in
    "Shutdown") systemctl poweroff ;;
    "Lock") hyprlock ;;
    "Suspend") systemctl suspend ;;
    "Reboot") systemctl reboot ;;
    "Logout") hyprctl dispatch "hl.dsp.exit()" ;;
esac