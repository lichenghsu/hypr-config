#!/bin/bash
# Kills swaylock before sleep/hibernate and relaunches it fresh after resume.
# Avoids "lockscreen app died" error caused by GPU context invalidation on resume.
# Placed in /usr/lib/systemd/system-sleep/
# systemd-sleep args: $1=operation (suspend/hibernate/...), $2=pre|post

USER="miles"
UID_NUM=1000
RUNTIME_DIR="/run/user/${UID_NUM}"

case "$2" in
  pre)
    if pgrep -u "${USER}" swaylock >/dev/null 2>&1; then
      pkill -u "${USER}" swaylock
      for _ in $(seq 20); do
        sleep 0.2
        pgrep -u "${USER}" swaylock >/dev/null 2>&1 || break
      done
    fi
    ;;
  post)
    su -s /bin/sh "${USER}" -c "
      export XDG_RUNTIME_DIR=${RUNTIME_DIR}
      export DBUS_SESSION_BUS_ADDRESS=unix:path=${RUNTIME_DIR}/bus
      systemctl --user start swaylock-resume.service
    "
    ;;
esac
