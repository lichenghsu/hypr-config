hl.config({
	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",
		follow_mouse = 1,
		sensitivity = 0,
		touchpad = {
			natural_scroll = true,
		},
	},
	-- 加入此區塊來解決游標自動隱藏與消失問題
	cursor = {
		no_hardware_cursors = true, -- 防止 3D 繪圖卡或 XWayland 渲染導致游標遺失
		inactive_timeout = 0,       -- 設為 0 代表「永遠不自動隱藏游標」
	},
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "horizontal", action = "move" })
hl.gesture({ fingers = 3, direction = "up", action = "close" })
hl.gesture({
	fingers = 3,
	direction = "down",
	action = function()
	hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
	hl.dispatch(hl.dsp.window.resize({ x = 850, y = 650, relative = false }))
	hl.dispatch(hl.dsp.window.center())
	end,
})

hl.device({
	name = "epic-mouse-v1",
	sensitivity = -0.5,
})
