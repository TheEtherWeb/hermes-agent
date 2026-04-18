--!strict
-- Stack of transient notifications (success/error/info) fading out after 4s.

local UIUtil = require(script.Parent:WaitForChild("UIUtil"))

local NotificationUI = {}

local root: ScreenGui
local container: Frame

local COLORS = {
	success = Color3.fromRGB(55, 140, 75),
	error   = Color3.fromRGB(175, 50, 50),
	info    = Color3.fromRGB(70, 90, 160),
}

function NotificationUI.init()
	root = UIUtil.screenGui("MR_Notifications")
	container = UIUtil.frame(root, {
		Size = UDim2.new(0, 320, 0, 200),
		Position = UDim2.new(1, -332, 0, 12),
		BackgroundTransparency = 1,
	})
	UIUtil.listLayout(container, 6)
end

function NotificationUI.show(payload: any)
	if not container then return end
	local kind = tostring(payload and payload.kind or "info")
	local text = tostring(payload and payload.text or "")
	local entry = UIUtil.frame(container, {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = COLORS[kind] or COLORS.info,
		BackgroundTransparency = 0.1,
	})
	UIUtil.label(entry, text, {
		Position = UDim2.new(0, 8, 0, 4),
		Size = UDim2.new(1, -16, 1, -8),
		TextSize = 13,
	})
	task.delay(4, function()
		if entry then entry:Destroy() end
	end)
end

return NotificationUI
