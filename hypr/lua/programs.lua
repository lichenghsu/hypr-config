local programs = {}

programs.terminal = "kitty"
programs.fileManager = "kitty yazi"
programs.menu = "/home/miles/.local/bin/smart_menu.sh"
programs.bar = 'quickshell --log-rules "quickshell.desktopentry.warning=false"'  -- mute swappy.desktop's "Illegal escape sequence" spam (Quickshell has no per-file ignore)
programs.rog = "rog-control-center"
programs.screenshot = '/home/miles/.local/bin/screenshot.sh'
programs.screenshot_full = '/home/miles/.local/bin/screenshot_full.sh'
programs.browser = "firefox"
programs.powermenu = "/home/miles/.local/bin/smart_powermenu.sh"
programs.lock = "/home/miles/.local/bin/smart_lock.sh"  -- caffeine → hyprlock (no fold); otherwise qs-lock
programs.note = "obsidian"
programs.dock = "/home/miles/.local/bin/smart_dock.sh"
programs.monitorLayout = "/home/miles/.local/bin/smart_monitorlayout.sh"

return programs
