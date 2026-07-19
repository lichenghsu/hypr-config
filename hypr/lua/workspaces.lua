
-- Pin workspaces 1-5 to the laptop panel, 6-10 to the external monitor,
-- so numbered workspaces stop jumping between monitors on focus/creation.
-- When no external monitor is plugged in, 6-10 fall back to the laptop panel
-- too, instead of staying pinned to a disconnected output.
local LAPTOP_MONITOR = "eDP-1"

-- Port names change depending on which cable/port the external monitor is
-- plugged into (HDMI-A-1 vs DP-1 etc.), so detect it by "not the laptop
-- panel" rather than hardcoding a specific port name.
local function find_external_monitor()
    for _, m in ipairs(hl.get_monitors()) do
        if m.name ~= LAPTOP_MONITOR then
            return m.name
        end
    end
    return nil
end

local function apply_workspace_monitor_rules()
    local secondHalf = find_external_monitor() or LAPTOP_MONITOR
    hl.workspace_rule({ workspace = "1",  monitor = LAPTOP_MONITOR, persistent = true })
    hl.workspace_rule({ workspace = "2",  monitor = LAPTOP_MONITOR, persistent = true, layout_opts = { direction = "right" } })
    hl.workspace_rule({ workspace = "3",  monitor = LAPTOP_MONITOR, persistent = true })
    hl.workspace_rule({ workspace = "4",  monitor = LAPTOP_MONITOR, persistent = true })
    hl.workspace_rule({ workspace = "5",  monitor = LAPTOP_MONITOR, persistent = true })
    hl.workspace_rule({ workspace = "6",  monitor = secondHalf, persistent = true })
    hl.workspace_rule({ workspace = "7",  monitor = secondHalf, persistent = true })
    hl.workspace_rule({ workspace = "8",  monitor = secondHalf, persistent = true })
    hl.workspace_rule({ workspace = "9",  monitor = secondHalf, persistent = true })
    hl.workspace_rule({ workspace = "10", monitor = secondHalf, persistent = true })
end

apply_workspace_monitor_rules()
hl.on("monitor.added", apply_workspace_monitor_rules)
hl.on("monitor.removed", apply_workspace_monitor_rules)
