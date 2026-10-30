#!/bin/bash
DATEDIR="/mnt/shared-data/ScreenShots/$(date +%Y-%m-%d)"
FILEPATH="$DATEDIR/$(date +%H%M%S).png"
mkdir -p "$DATEDIR"
# Freeze the screen before slurp so transient UI (right-click menus, popups)
# that closes once slurp grabs input still ends up in the shot.
hyprpicker -r -z &
FREEZE=$!
sleep 0.1
GEOM=$(slurp)
grim -g "$GEOM" "$FILEPATH" 2>/dev/null
STATUS=$?
kill $FREEZE 2>/dev/null
[ -n "$GEOM" ] && [ $STATUS -eq 0 ] && drawing "$FILEPATH"
