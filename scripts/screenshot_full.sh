#!/bin/bash
DATEDIR="/mnt/shared-data/ScreenShots/$(date +%Y-%m-%d)"
FILEPATH="$DATEDIR/$(date +%H%M%S).png"
mkdir -p "$DATEDIR"
grim "$FILEPATH" && drawing "$FILEPATH"
