--!strict
-- Blacksmith panel toggled with [B]. Lets the player pick blade/hilt/guard/
-- pommel/rune and forge; server validates materials.

local UIUtil = require(script.Parent:WaitForChild("UIUtil"))
local Remotes: any = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local WeaponComponents: any = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("WeaponComponents"))

local CraftingUI = {}

local selection = { blade = "IronLongblade", hilt = "LeatherBoundHilt", guard = "SteelCrossguard", pommel = "StonePommel", rune = nil, name = "Bonded Weapon" }

local function ids(pool: any): { string }
	local out = {}
	for k in pairs(pool) do table.insert(out, k) end
	table.sort(out)
	return out
end

local function makePicker(parent: Frame, y: number, label: string, part: string, pool: any)
	UIUtil.label(parent, label, { Position = UDim2.new(0, 12, 0, y), Size = UDim2.new(0, 70, 0, 24) })
	local btn = UIUtil.button(parent, tostring(selection[part]), function()
		local keys = ids(pool)
		local cur = selection[part]
		local idx = 1
		for i, k in ipairs(keys) do if k == cur then idx = i break end end
		selection[part] = keys[(idx % #keys) + 1]
	end, { Position = UDim2.new(0, 88, 0, y), Size = UDim2.new(0, 220, 0, 24) })
	-- Keep button text synced to selection.
	game:GetService("RunService").RenderStepped:Connect(function()
		btn.Text = tostring(selection[part] or "(none)")
	end)
end

function CraftingUI.init(_profile: any)
	local gui = UIUtil.screenGui("MR_Crafting")
	local panel = UIUtil.frame(gui, {
		Size = UDim2.new(0, 360, 0, 300),
		Position = UDim2.new(0.5, -180, 0.5, -150),
		Visible = false,
		BackgroundColor3 = Color3.fromRGB(18, 14, 20),
	})
	UIUtil.label(panel, "Blacksmith  [B]", { Position = UDim2.new(0, 12, 0, 8), TextSize = 16 })
	makePicker(panel,  40, "Blade",  "blade",  WeaponComponents.BLADES)
	makePicker(panel,  70, "Hilt",   "hilt",   WeaponComponents.HILTS)
	makePicker(panel, 100, "Guard",  "guard",  WeaponComponents.GUARDS)
	makePicker(panel, 130, "Pommel", "pommel", WeaponComponents.POMMELS)
	makePicker(panel, 160, "Rune",   "rune",   WeaponComponents.RUNES)

	UIUtil.button(panel, "Forge!", function()
		Remotes.event("Crafting_Forge"):FireServer(selection)
	end, { Position = UDim2.new(0.5, -60, 1, -40), Size = UDim2.new(0, 120, 0, 32) })

	UIUtil.toggleOnKey(gui, panel, Enum.KeyCode.B)
end

return CraftingUI
