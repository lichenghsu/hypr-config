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
	name = "wl-present-menu",
	match = { class = "^wl-present-menu$" },
	float = true,
	size = "480 260",
	center = true,
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
	size = "1200 1080",
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
	center = true,
	workspace = "special:note silent",
})

-- Dolphin: tile everything except its main window (title always ends in "... — Dolphin"),
-- so Properties/Copy/Preferences dialogs etc. tile like normal windows

hl.window_rule({
	name = "dolphin-main-float",
	match = { class = "^org.kde.dolphin$" },
	float = true,
	size = "850 650",
	center = true,
})

-- Remmina: same idea — only the main "Remmina Remote Desktop Client" window floats,
-- session/connection windows and dialogs tile
hl.window_rule({
	name = "remmina-tile",
	match = { class = "^org.remmina.Remmina$" },
	float = false,
})

hl.window_rule({
	name = "remmina-main-float",
	match = { class = "^org.remmina.Remmina$", title = "^Remmina Remote Desktop Client$" },
	float = true,
	size = "1000 700",
	center = true,
})

-- DBeaver CE: only the main window (title always "DBeaver <version> - ...") tiles,
-- dialogs (Preferences, New Connection Wizard, Progress Information, etc.) stay
-- floating via the catch-all "default-float" rule above.
hl.window_rule({
	name = "dbeaver-main-tile",
	match = {
		class = "^DBeaver$",
		title = "^DBeaver [0-9].*"
	},
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
	name = "filezilla",
	match = { class = "^filezilla$" },
	float = true,
	size = "850 650",
	center = true,
})

hl.window_rule({
	name = "firefox",
	match = { class = "^org.mozilla.firefox$" },
	float = false,
})

hl.window_rule({
	name = "brave",
	match = { class = "^brave-browser$" },
	float = false,
})

hl.window_rule({
	name = "chromium-browser",
	match = { class = "^chromium-browser$" },
	float = false,
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
-- Port names change depending on which cable/port the external monitor is
-- plugged into (HDMI-A-1 vs DP-1 etc.), so detect it by "not the laptop
-- panel" rather than hardcoding a specific port name (see workspaces.lua).
local LAPTOP_MONITOR = "eDP-1"
local function find_external_monitor()
	for _, m in ipairs(hl.get_monitors()) do
		if m.name ~= LAPTOP_MONITOR then
			return m.name
		end
	end
	return nil
end

local function apply_anydesk_monitor_rule()
	hl.window_rule({
		name = "anydesk-monitor",
		match = { class = "anydesk" },
		monitor = find_external_monitor() or LAPTOP_MONITOR,
	})
end

apply_anydesk_monitor_rule()
hl.on("monitor.added", apply_anydesk_monitor_rule)
hl.on("monitor.removed", apply_anydesk_monitor_rule)

-- VMS is an Xwayland app; Xwayland can only broadcast one global DPI
-- (matching the primary monitor), so pin it to eDP-1 to avoid rendering
-- 2x oversized on the external monitor.
hl.window_rule({
	name = "vms-monitor",
	match = { class = "Vms-desktop" },
	monitor = "eDP-1",
})
