local programs = {}

programs.terminal = "kitty"
programs.fileManager = "kitty yazi"
programs.menu = "/home/miles/.local/bin/smart_menu.sh"
programs.bar = "quickshell"
programs.rog = "rog-control-center"
programs.screenshot = 'mkdir -p "/mnt/shared-data/ScreenShots/$(date +%Y-%m-%d)" && flameshot gui -p "/mnt/shared-data/ScreenShots/$(date +%Y-%m-%d)"'
programs.screenshot_full = 'mkdir -p "/mnt/shared-data/ScreenShots/$(date +%Y-%m-%d)" && flameshot full -p "/mnt/shared-data/ScreenShots/$(date +%Y-%m-%d)"'
programs.browser = "zen-browser"
programs.powermenu = "/home/miles/.local/bin/smart_powermenu.sh"
programs.lock = "swaylock"
programs.note = "obsidian"
programs.dock = ""

return programs
