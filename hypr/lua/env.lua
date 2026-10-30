hl.env("XCURSOR_THEME", "Skyrim-by-ru5tyshark-cursors")
hl.env("HYPRCURSOR_THEME", "Skyrim-by-ru5tyshark-cursors")
hl.env("XCURSOR_SIZE", "48")
hl.env("HYPRCURSOR_SIZE", "48")
hl.env("GDK_SCALE", "2")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")

-- Fedora's swappy.desktop Exec has "\\$", which quickshell's DesktopEntries scan warns about on every launch.
-- Quickshell has no per-file ignore, so mute the category here (covers manual `quickshell` restarts too).
hl.env("QT_LOGGING_RULES", "quickshell.desktopentry.warning=false")
