-- cm = "srgb": the OLED panel advertises wide gamut, so the default cm = "auto"
-- turns it on, but AQ_NO_ATOMIC=1 (legacy DRM, see ~/.config/uwsm/env-hyprland)
-- can't switch the panel to 10-bit -> "wide color gamut is enabled but the display
-- is not in 10-bit mode" on every modeset. Drop this once the atomic path is back.
-- Do NOT set sdr_eotf = "gamma22" / sdr_min_luminance = 0 here: tried 2026-11-04 to
-- fix grey fullscreen video, but once they apply to the whole output the entire
-- panel goes grey (2026-11-05). Keep the defaults, same as the external monitor.
hl.monitor({ output = "eDP-1", mode = "3840x2400@60", position = "0x0", scale = "1.5" })

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


-- cm_auto_hdr = 0: by default (1) a fullscreen app that tags its surface as HDR /
-- wide gamut (e.g. Brave fullscreen video) flips the monitor into HDR cm, which
-- re-triggers the same 10-bit warning under AQ_NO_ATOMIC. The panel can't do
-- real HDR on the legacy path anyway, so keep it sRGB. Revert with the cm line above.
hl.config({
    render = { cm_auto_hdr = 0 },
})
