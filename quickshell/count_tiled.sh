#!/bin/bash
# Quickshell only signals this direct child on reload (and nothing at all on kill -9),
# so keep everything in one loop and clean up socat ourselves.

parent=$PPID
socat_pid=
trap '[ -n "$socat_pid" ] && kill "$socat_pid" 2>/dev/null' EXIT
trap 'exit 0' TERM INT HUP PIPE

update() {
    active_ws=$(hyprctl activeworkspace -j | jq -r .id)
    if [ -z "$active_ws" ] || [ "$active_ws" = "null" ]; then echo 0; return; fi
    hyprctl clients -j | jq -c '[.[] | select(.workspace.id == '"$active_ws"' and .floating == false)] | length'
}

last_val="-1"
do_update() {
    local val=$(update)
    if [ "$val" != "$last_val" ]; then
        echo "$val"
        last_val="$val"
    fi
}

do_update

exec 3< <(exec socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock 2>/dev/null)
socat_pid=$!

while true; do
    # quickshell died (kill -9) → we got reparented, stop instead of lingering
    read -r _ _ _ ppid _ < /proc/$$/stat
    [ "$ppid" = "$parent" ] || exit 0

    # wake on hyprland event (debounced) or every 0.5s as fallback
    read -t 0.5 -r -u 3 _
    rc=$?
    if [ $rc -eq 0 ]; then
        while read -t 0.05 -r -u 3 _; do :; done
    elif [ $rc -le 128 ]; then
        sleep 0.5  # socket closed; keep polling without spinning
    fi
    do_update
done
