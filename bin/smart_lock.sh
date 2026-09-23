#!/bin/bash
# Lock dispatcher: caffeine on → swaylock (screen stays on, no suspend),
# otherwise → Quickshell lock screen.
CAFFEINE_FLAG="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/caffeine"

if [ -e "$CAFFEINE_FLAG" ]; then
    pidof swaylock >/dev/null || swaylock -f
else
    /home/miles/.local/bin/qs-lock
fi
