#!/bin/bash
# Kills hyprlock before sleep/hibernate and relaunches it fresh after resume.
# Avoids "lockscreen app died" error caused by GPU context invalidation on resume.
# Placed in /usr/lib/systemd/system-sleep/

USER="miles"
UID_NUM=1000
RUNTIME_DIR="/run/user/${UID_NUM}"
WAYLAND_DISPLAY="wayland-1"

case "$1" in
  pre)
    # Only kill hyprlock if it was manually started before sleep.
    # Wait for clean exit so ext-session-lock is properly released (no error screen).
    if pgrep -u "${USER}" hyprlock >/dev/null 2>&1; then
      pkill -u "${USER}" hyprlock
      for _ in $(seq 20); do
        sleep 0.2
        pgrep -u "${USER}" hyprlock >/dev/null 2>&1 || break
      done
    fi
    ;;
  post)
    # GPU needs time to fully reinitialize before hyprlock can render.
    sleep 3
    su -s /bin/sh "${USER}" -c "
      export XDG_RUNTIME_DIR=${RUNTIME_DIR}
      export WAYLAND_DISPLAY=${WAYLAND_DISPLAY}
      hyprlock
    " &
    ;;
esac
