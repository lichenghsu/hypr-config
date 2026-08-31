local LAPTOP_MONITOR = "eDP-1"

local function find_external_monitor()
for _, m in ipairs(hl.get_monitors()) do
    if m.name ~= LAPTOP_MONITOR then
        return m
        end
        end
        return nil
        end

        local function apply_workspace_monitor_rules()
        local external = find_external_monitor()

        -- Assign workspaces 1–5 to the internal laptop screen
        for i = 1, 5 do
            hl.workspace_rule({
                workspace = tostring(i),
                              monitor = LAPTOP_MONITOR,
                              persistent = true,
            })
            end

            -- Assign workspaces 6–10 to the external screen (or fallback to laptop screen)
            local target_monitor = external and external.name or LAPTOP_MONITOR
            for i = 6, 10 do
                hl.workspace_rule({
                    workspace = tostring(i),
                                  monitor = target_monitor,
                                  persistent = true,
                })
                end

                -- Handling for external monitor presence
                if external then
                    local ws = hl.get_active_workspace(external)
                    -- If an out-of-range workspace (> 10) was created on the external display, switch focus to workspace 6
                    if ws and ws.id > 10 then
                        hl.dispatch(
                            hl.dsp.focus({ workspace = 6 })
                        )
                        end
                        end
                        end

                        -- Apply rules immediately on startup
                        apply_workspace_monitor_rules()

                        -- Re-apply dynamic rules on hotplug events
                        hl.on("monitor.added", apply_workspace_monitor_rules)
                        hl.on("monitor.removed", apply_workspace_monitor_rules)
