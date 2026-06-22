hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name  = "no-gaps-wtv1",
    match = { float = false, workspace = "w[tv1]" },
    border_size = 0,
    rounding    = 0,
})

hl.window_rule({
    name  = "no-gaps-f1",
    match = { float = false, workspace = "f[1]" },
    border_size = 0,
    rounding    = 0,
})

hl.window_rule({
    name  = "blueberry",
    match = { class = "blueberry.py" },
    float = true,
    size  = "400 500",
    move  = "(monitor_w-410) 35",
})

hl.window_rule({
    name  = "calculator",
    match = { class = "org.gnome.Calculator" },
    float = true,
    size  = "400 500",
    move  = "(monitor_w-410) 95",
})

hl.window_rule({
    name  = "file-dialogs",
    match = { title = "^(Apri file|Open File|Salva come|Save As|Sfoglia|Library)$" },
    float = true,
    size  = "800 500",
    center = true,
})

hl.window_rule({
    name  = "portal-gtk",
    match = { class = "xdg-desktop-portal-gtk" },
    float = true,
    size  = "900 600",
    center = true,
})

hl.window_rule({
    name      = "line-main",
    match     = { class = "line.exe" },
    float     = true,
    size      = "1882 1170",
    center    = true,
    workspace = "special:line silent",
})

hl.window_rule({
    name      = "line-tray",
    match     = { class = "explorer.exe", title = "^$" },
    float     = true,
    size      = "44 571",
    move      = "(monitor_w - 506) (monitor_h - 886)",
    workspace = "special:line silent",
})

hl.window_rule({
    name      = "kontact",
    match     = { class = "org.kde.kontact" },
    float     = true,
    size      = "1200 800",
    center    = true,
    workspace = "special:kontact silent",
})

hl.window_rule({
    name      = "keepassxc",
    match     = { class = "org.keepassxc.KeePassXC" },
    float     = true,
    size      = "900 600",
    center    = true,
    workspace = "special:keepass silent",
})

hl.window_rule({
    name      = "kontact",
    match     = { class = "org.kde.kontact" },
    float     = true,
    size      = "1200 800",
    center    = true,
    workspace = "special:kontact silent",
})

hl.window_rule({
    name  = "spotify",
    match = { class = "^(Spotify|spotify)$" },
    float = true,
    size  = "800 600",
    center = true,
    workspace = "special:magic silent",
})

hl.window_rule({
    name  = "foot",
    match = { class = "^(foot|footclient)$" },
    float = true,
    size  = "850 650",
    center = true,
})

hl.window_rule({
    name   = "kitty",
    match  = { class = "^kitty$" },
    float  = true,
    size   = "850 650",
    center = true,
})

hl.window_rule({
    name   = "drawing",
    match  = { class = "^com.github.maoschanz.drawing$" },
    float  = true,
    size   = "1000 700",
    center = true,
})

hl.window_rule({
    name   = "openconnect-auth",
    match  = { class = "nm-openconnect-auth-dialog" },
    float  = true,
    size   = "500 400",
    center = true,
})
