--!strict
-- HUD: health, stamina, posture, stance indicator, gold, level.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UIUtil = require(script.Parent:WaitForChild("UIUtil"))

local HUD = {}

local root: ScreenGui
local healthBar, staminaBar, postureBar: Frame, Frame, Frame
local stanceLabel, goldLabel, levelLabel, nameLabel: TextLabel, TextLabel, TextLabel, TextLabel

local function makeBar(parent: Instance, color: Color3, y: number): Frame
	local bg = UIUtil.frame(parent, {
		Size = UDim2.new(0, 220, 0, 14),
		Position = UDim2.new(0, 12, 0, y),
		BackgroundColor3 = Color3.fromRGB(14, 12, 14),
	})
	local fg = UIUtil.frame(bg, {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = color,
	})
	return fg
end

function HUD.init(profile: any)
	root = UIUtil.screenGui("MR_HUD")
	local panel = UIUtil.frame(root, {
		Size = UDim2.new(0, 250, 0, 120),
		Position = UDim2.new(0, 12, 1, -132),
		BackgroundColor3 = Color3.fromRGB(18, 14, 20),
		BackgroundTransparency = 0.2,
	})
	nameLabel = UIUtil.label(panel, profile.familyName .. " — " .. (profile.race or "Unknown"), { Position = UDim2.new(0, 8, 0, 4) })
	levelLabel = UIUtil.label(panel, "Lv " .. (profile.level or 1) .. " Gen " .. (profile.generation or 1), { Position = UDim2.new(0, 8, 0, 22) })
	goldLabel = UIUtil.label(panel, "Gold: " .. (profile.gold or 0), { Position = UDim2.new(0, 160, 0, 22) })

	healthBar  = makeBar(panel, Color3.fromRGB(170, 40, 40), 44)
	staminaBar = makeBar(panel, Color3.fromRGB(40, 150, 70), 62)
	postureBar = makeBar(panel, Color3.fromRGB(180, 150, 40), 80)

	stanceLabel = UIUtil.label(panel, "Stance: OneHand", { Position = UDim2.new(0, 8, 0, 98) })

	-- Health driven by Humanoid.
	local function hookHumanoid(char: Model)
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		local conn = hum.HealthChanged:Connect(function(h)
			healthBar.Size = UDim2.new(math.clamp(h / math.max(1, hum.MaxHealth), 0, 1), 0, 1, 0)
		end)
		hum.Died:Connect(function() if conn then conn:Disconnect() end end)
		healthBar.Size = UDim2.new(hum.Health / math.max(1, hum.MaxHealth), 0, 1, 0)
	end
	local lp = Players.LocalPlayer
	if lp.Character then hookHumanoid(lp.Character) end
	lp.CharacterAdded:Connect(hookHumanoid)
end

function HUD.onProfile(profile: any)
	if not root then return end
	if levelLabel then levelLabel.Text = "Lv " .. (profile.level or 1) .. " Gen " .. (profile.generation or 1) end
	if goldLabel  then goldLabel.Text  = "Gold: " .. (profile.gold or 0) end
	if nameLabel  then nameLabel.Text  = profile.familyName .. " — " .. (profile.race or "Unknown") end
end

function HUD.setStance(stance: string)
	if stanceLabel then stanceLabel.Text = "Stance: " .. stance end
end

function HUD.setStamina(pct: number)
	if staminaBar then staminaBar.Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0) end
end

function HUD.setPosture(pct: number)
	if postureBar then postureBar.Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0) end
end

return HUD
