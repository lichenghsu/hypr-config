hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- blur behind the WindowOverview panel (quickshell layer namespace "qs-overview")
hl.layer_rule({
	name = "overview-blur",
	match = { namespace = "qs-overview" },
	blur = true,
	ignore_alpha = 0.0,
})

hl.window_rule({
	name = "default-float",
	match = { class = ".*" },
	float = true,
})

hl.window_rule({
	name = "zed-tile",
	match = { class = "dev.zed.Zed" },
	float = false,
})

hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },
	move = "20 monitor_h-120",
	float = true,
})

hl.window_rule({
	name = "blueberry",
	match = { class = "blueberry.py" },
	float = true,
	size = "400 500",
	move = "(monitor_w-410) 35",
})

hl.window_rule({
	name = "calculator",
	match = { class = "org.gnome.Calculator" },
	float = true,
	size = "400 500",
	move = "(monitor_w-410) 95",
})

hl.window_rule({
	name = "file-dialogs",
	match = { title = "^(Apri file|Open File|Salva come|Save As|Sfoglia|Library)$" },
	float = true,
	size = "800 500",
	center = true,
})

hl.window_rule({
	name = "portal-gtk",
	match = { class = "xdg-desktop-portal-gtk" },
	float = true,
	size = "900 600",
	center = true,
})

hl.window_rule({
	name = "line-main",
	match = { class = "line.exe" },
	float = true,
	size = "1882 1170",
	center = true,
	workspace = "special:line silent",
})

hl.window_rule({
	name = "line-tray",
	match = { class = "explorer.exe", title = "^$" },
	float = true,
	size = "48 48",
	move = "(monitor_w - 60) (monitor_h - 60)",
	workspace = "special:line silent",
	border_size = 0,
	rounding = 0,
})

hl.window_rule({
	name = "kontact",
	match = { class = "org.kde.kontact" },
	float = true,
	size = "1200 800",
	center = true,
	workspace = "special:kontact silent",
})

hl.window_rule({
	name = "keepassxc",
	match = { class = "org.keepassxc.KeePassXC" },
	float = true,
	size = "900 600",
	center = true,
	workspace = "special:keepass silent",
})

hl.window_rule({
	name = "kontact",
	match = { class = "org.kde.kontact" },
	float = true,
	size = "1200 800",
	center = true,
	workspace = "special:kontact silent",
})

hl.window_rule({
	name = "spotify",
	match = { class = "^(Spotify|spotify)$" },
	float = true,
	size = "1200 800",
	center = true,
	workspace = "special:magic silent",
})

hl.window_rule({
	name = "obsidian",
	match = { class = "^obsidian$" },
	float = false,
})

hl.window_rule({
	name = "foot",
	match = { class = "^(foot|footclient)$" },
	float = true,
	size = "850 650",
	center = true,
})

hl.window_rule({
	name = "kitty",
	match = { class = "^kitty$" },
	float = true,
	size = "850 650",
	center = true,
})

hl.window_rule({
	name = "remmina",
	match = { class = "^org%.remmina%.Remmina$" },
	float = true,
	size = "1000 700",
	center = true,
})

hl.window_rule({
	name = "drawing",
	match = { class = "^com.github.maoschanz.drawing$" },
	float = true,
	size = "1000 700",
	center = true,
})

hl.window_rule({
	name = "openconnect-auth",
	match = { class = "nm-openconnect-auth-dialog" },
	float = true,
	size = "500 400",
	center = true,
})

-- AnyDesk's renderer breaks on the HiDPI primary panel (eDP-1, scale 2.0),
-- but renders correctly on the 1.0-scale external monitor, so pin it there.
hl.window_rule({
	name = "anydesk-monitor",
	match = { class = "anydesk" },
	monitor = "HDMI-A-1",
})

-- VMS is an Xwayland app; Xwayland can only broadcast one global DPI
-- (matching the primary monitor), so pin it to eDP-1 to avoid rendering
-- 2x oversized on the external monitor.
hl.window_rule({
	name = "vms-monitor",
	match = { class = "Vms-desktop" },
	monitor = "eDP-1",
})
