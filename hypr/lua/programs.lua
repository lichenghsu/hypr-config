local programs = {}

programs.terminal = "footclient"
programs.fileManager = "footclient yazi"
programs.menu = "/home/miles/.local/bin/smart_menu.sh"
programs.bar = "quickshell"
programs.rog = "rog-control-center"
programs.screenshot = 'mkdir -p "/mnt/shared-data/ScreenShots/$(date +%Y-%m-%d)" && grim -g "$(slurp)" - | satty --filename - --output-filename "/mnt/shared-data/ScreenShots/%Y-%m-%d/%H%M%S.png"'
programs.screenshot_full = 'mkdir -p "/mnt/shared-data/ScreenShots/$(date +%Y-%m-%d)" && grim - | satty --filename - --output-filename "/mnt/shared-data/ScreenShots/%Y-%m-%d/%H%M%S.png"'
programs.browser = "zen-browser"
programs.powermenu = "/home/miles/.local/bin/smart_powermenu.sh"
programs.lock = "hyprlock"
programs.note = "obsidian"
programs.dock = ""

return programs
