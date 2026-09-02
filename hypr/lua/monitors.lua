hl.monitor({ output = "eDP-1", mode = "3840x2400@60", position = "0x0", scale = "2" })

-- Any external monitor is handled by the wildcard rule below (preferred mode,
-- auto position/scale). Do NOT persist hardcoded per-port rules here -- a stale
-- one (e.g. an invalid "0x0@60" mode written while the panel was disconnected)
-- black-screens whatever plugs into that port. See monitor_tui.py guard.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
