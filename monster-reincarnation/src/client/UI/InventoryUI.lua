--!strict
-- Inventory panel toggled with [I]. Shows materials, weapons, consumables.
-- Weapons display their persona level and a tooltip with chronicle entries.

local UIUtil = require(script.Parent:WaitForChild("UIUtil"))
local Remotes: any = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))

local InventoryUI = {}

local root: ScreenGui
local panel: Frame
local listFrame: ScrollingFrame
local cachedProfile: any = nil

local function render(profile: any)
	if not listFrame then return end
	for _, c in ipairs(listFrame:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	local y = 0
	for _, item in ipairs(profile.inventory or {}) do
		local row = UIUtil.frame(listFrame, {
			Size = UDim2.new(1, -12, 0, 32),
			Position = UDim2.new(0, 4, 0, y),
			BackgroundColor3 = Color3.fromRGB(30, 25, 35),
		})
		local label = item.templateId .. " x" .. tostring(item.qty or 1)
		if item.kind == "weapon" and item.data and item.data.weapon then
			local w = item.data.weapon
			label = (w.name or "Weapon") .. "  [" .. (w.quality or "") .. "]  L" .. tostring(w.persona.level or 1)
			if w.persona.awakenedBranch then
				label = label .. " * " .. w.persona.awakenedBranch
			end
		end
		UIUtil.label(row, label, { Position = UDim2.new(0, 8, 0, 6), Size = UDim2.new(1, -120, 0, 20) })

		if item.kind == "weapon" then
			UIUtil.button(row, "Equip", function()
				Remotes.event("Weapon_Equip"):FireServer({ weaponId = item.id })
			end, { Position = UDim2.new(1, -72, 0, 3), Size = UDim2.new(0, 64, 0, 24) })
		end

		y += 36
	end
	listFrame.CanvasSize = UDim2.new(0, 0, 0, y)
end

function InventoryUI.init(profile: any)
	root = UIUtil.screenGui("MR_Inventory")
	panel = UIUtil.frame(root, {
		Size = UDim2.new(0, 420, 0, 380),
		Position = UDim2.new(0.5, -210, 0.5, -190),
		Visible = false,
		BackgroundColor3 = Color3.fromRGB(18, 14, 20),
	})
	UIUtil.label(panel, "Inventory  [I]", { Position = UDim2.new(0, 12, 0, 8), TextSize = 16 })
	listFrame = Instance.new("ScrollingFrame")
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel = 0
	listFrame.Size = UDim2.new(1, -16, 1, -48)
	listFrame.Position = UDim2.new(0, 8, 0, 36)
	listFrame.ScrollBarThickness = 6
	listFrame.Parent = panel
	UIUtil.toggleOnKey(root, panel, Enum.KeyCode.I)
	cachedProfile = profile
	render(profile)
end

function InventoryUI.onProfile(profile: any)
	cachedProfile = profile
	render(profile)
end

return InventoryUI
