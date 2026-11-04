-- cm = "srgb": the OLED panel advertises wide gamut, so the default cm = "auto"
-- turns it on, but AQ_NO_ATOMIC=1 (legacy DRM, see ~/.config/uwsm/env-hyprland)
-- can't switch the panel to 10-bit -> "wide color gamut is enabled but the display
-- is not in 10-bit mode" on every modeset. Drop this once the atomic path is back.
-- sdr_eotf / sdr_min_luminance: fullscreen windows go through Hyprland's shader
-- color conversion (render.non_shader_cm = 3), which with the defaults lifted the
-- OLED's blacks to ~0.2 nit and made fullscreen VSCode / Netflix look white-grey.
hl.monitor({
    output            = "eDP-1",
    mode              = "3840x2400@60",
    position          = "0x0",
    scale             = "1.5",
    cm                = "srgb",
    sdr_eotf          = "gamma22",
    sdr_min_luminance = 0,
})

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

