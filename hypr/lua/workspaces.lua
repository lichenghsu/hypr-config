
-- Pin workspaces 1-5 to the laptop panel, 6-10 to the external monitor,
-- so numbered workspaces stop jumping between monitors on focus/creation.
hl.workspace_rule({ workspace = "1",  monitor = "eDP-1",    persistent = true })
hl.workspace_rule({ workspace = "2",  monitor = "eDP-1",    persistent = true, layout_opts = { direction = "right" } })
hl.workspace_rule({ workspace = "3",  monitor = "eDP-1",    persistent = true })
hl.workspace_rule({ workspace = "4",  monitor = "eDP-1",    persistent = true })
hl.workspace_rule({ workspace = "5",  monitor = "eDP-1",    persistent = true })
hl.workspace_rule({ workspace = "6",  monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "7",  monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "8",  monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "9",  monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "10", monitor = "HDMI-A-1", persistent = true })
