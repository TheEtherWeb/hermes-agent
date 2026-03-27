-- HUDController.client.lua
-- Drives the four animated stat bars: Health, Guard, Heat, Resource (Resonance/Ore).
-- Also handles the Rank display, XP bar, and floating damage numbers.

local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local HUDController = {}

-- ── Build HUD frames ──────────────────────────────────────────────────────────

local screenGui  -- set when UIManager mounts
local hudFrame, healthFill, guardFill, heatFill, resFill
local rankLabel, xpFill
local bossFrame, bossNameLabel, bossHpFill
local rankUpNotif, rankUpLabel
local healthLabel, guardLabel, heatLabel, resLabel

local BAR_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function MakeBar(parent, name, yPos, fillColor, labelText)
	local container = Instance.new("Frame")
	container.Name = name .. "_Container"
	container.Size = UDim2.new(0, 220, 0, 22)
	container.Position = UDim2.new(0, 10, 0, yPos)
	container.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	container.BorderSizePixel = 0
	container.Parent = parent

	local bg = Instance.new("UICorner")
	bg.CornerRadius = UDim.new(0, 4)
	bg.Parent = container

	local fill = Instance.new("Frame")
	fill.Name = name .. "_Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Parent = container

	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 4)
	fc.Parent = fill

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.Parent = container

	return fill, label
end

local function BuildHUD(gui)
	screenGui = gui

	-- Main HUD anchored bottom-left
	hudFrame = Instance.new("Frame")
	hudFrame.Name = "HUD_Frame"
	hudFrame.Size = UDim2.new(0, 240, 0, 130)
	hudFrame.Position = UDim2.new(0, 10, 1, -140)
	hudFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	hudFrame.BackgroundTransparency = 0.4
	hudFrame.BorderSizePixel = 0
	hudFrame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = hudFrame

	healthFill, healthLabel = MakeBar(hudFrame, "Health", 8,  Color3.fromRGB(200, 50, 50),  "HP 100")
	guardFill,  guardLabel  = MakeBar(hudFrame, "Guard",  36, Color3.fromRGB(60, 130, 220), "GRD 100")
	heatFill,   heatLabel   = MakeBar(hudFrame, "Heat",   64, Color3.fromRGB(210, 120, 20), "HEAT 0%")
	resFill,    resLabel     = MakeBar(hudFrame, "Res",    92, Color3.fromRGB(40, 200, 200), "RES 100")

	-- Rank display (top-left)
	local rankFrame = Instance.new("Frame")
	rankFrame.Name = "Rank_Frame"
	rankFrame.Size = UDim2.new(0, 180, 0, 50)
	rankFrame.Position = UDim2.new(0, 10, 0, 10)
	rankFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	rankFrame.BackgroundTransparency = 0.4
	rankFrame.BorderSizePixel = 0
	rankFrame.Parent = gui

	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 6)
	rc.Parent = rankFrame

	rankLabel = Instance.new("TextLabel")
	rankLabel.Size = UDim2.new(1, 0, 0.55, 0)
	rankLabel.BackgroundTransparency = 1
	rankLabel.Text = "ROUGH"
	rankLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	rankLabel.Font = Enum.Font.GothamBold
	rankLabel.TextSize = 14
	rankLabel.Parent = rankFrame

	xpFill, _ = MakeBar(rankFrame, "XP", 28, Color3.fromRGB(180, 160, 40), "")
	xpFill.Parent.Size = UDim2.new(0.9, 0, 0, 12)
	xpFill.Parent.Position = UDim2.new(0.05, 0, 0, 32)

	-- Boss HP bar (top-center, hidden by default)
	bossFrame = Instance.new("Frame")
	bossFrame.Name = "BossHP_Frame"
	bossFrame.Size = UDim2.new(0, 400, 0, 48)
	bossFrame.AnchorPoint = Vector2.new(0.5, 0)
	bossFrame.Position = UDim2.new(0.5, 0, 0, 10)
	bossFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	bossFrame.BackgroundTransparency = 0.4
	bossFrame.BorderSizePixel = 0
	bossFrame.Visible = false
	bossFrame.Parent = gui

	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 6)
	bc.Parent = bossFrame

	bossNameLabel = Instance.new("TextLabel")
	bossNameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	bossNameLabel.BackgroundTransparency = 1
	bossNameLabel.Text = "BOSS"
	bossNameLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	bossNameLabel.Font = Enum.Font.GothamBold
	bossNameLabel.TextSize = 16
	bossNameLabel.Parent = bossFrame

	bossHpFill, _ = MakeBar(bossFrame, "BossHP", 26, Color3.fromRGB(180, 30, 30), "")
	bossHpFill.Parent.Size = UDim2.new(0.9, 0, 0, 14)
	bossHpFill.Parent.Position = UDim2.new(0.05, 0, 0, 28)

	-- Rank-up notification (center screen)
	rankUpNotif = Instance.new("Frame")
	rankUpNotif.Name = "RankUp_Frame"
	rankUpNotif.Size = UDim2.new(0, 320, 0, 70)
	rankUpNotif.AnchorPoint = Vector2.new(0.5, 0.5)
	rankUpNotif.Position = UDim2.new(0.5, 0, 0.35, 0)
	rankUpNotif.BackgroundColor3 = Color3.fromRGB(40, 40, 10)
	rankUpNotif.BackgroundTransparency = 0.2
	rankUpNotif.BorderSizePixel = 0
	rankUpNotif.Visible = false
	rankUpNotif.Parent = gui

	local rnc = Instance.new("UICorner")
	rnc.CornerRadius = UDim.new(0, 10)
	rnc.Parent = rankUpNotif

	rankUpLabel = Instance.new("TextLabel")
	rankUpLabel.Size = UDim2.new(1, 0, 1, 0)
	rankUpLabel.BackgroundTransparency = 1
	rankUpLabel.Text = "RANK UP"
	rankUpLabel.TextColor3 = Color3.fromRGB(255, 220, 60)
	rankUpLabel.Font = Enum.Font.GothamBold
	rankUpLabel.TextSize = 22
	rankUpLabel.Parent = rankUpNotif
end

-- ── Bar update helpers ────────────────────────────────────────────────────────

local function SetBarFraction(fillFrame, fraction)
	local clamped = math.clamp(fraction, 0, 1)
	TweenService:Create(fillFrame, BAR_TWEEN, { Size = UDim2.new(clamped, 0, 1, 0) }):Play()
end

local function FlashHeatBar(heatFraction)
	if heatFraction > 0.8 then
		local pulse = TweenService:Create(heatFill, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true), {
			BackgroundColor3 = Color3.fromRGB(240, 30, 10),
		})
		pulse:Play()
	else
		heatFill.BackgroundColor3 = Color3.fromRGB(210, 120, 20)
	end
end

-- ── Public: called by UIManager when state changes ────────────────────────────

function HUDController.OnStateChanged(state, _patch)
	if not hudFrame then
		BuildHUD(_G.ScreenGui)
	end

	-- Health
	local hpFrac = state.Health / (state.MaxHealth or 100)
	SetBarFraction(healthFill, hpFrac)
	healthLabel.Text = "HP " .. math.ceil(state.Health)

	-- Guard
	local grdFrac = state.Guard / (state.MaxGuard or 100)
	SetBarFraction(guardFill, grdFrac)
	guardLabel.Text = "GRD " .. math.ceil(state.Guard)

	-- Heat
	local heatFrac = state.Heat / 100
	SetBarFraction(heatFill, heatFrac)
	heatLabel.Text = string.format("HEAT %d%%", math.floor(heatFrac * 100))
	FlashHeatBar(heatFrac)

	-- Resource bar
	if state.Race == "Gem" then
		resLabel.Text = "RES " .. math.ceil(state.Resonance or 0)
		SetBarFraction(resFill, (state.Resonance or 0) / (state.MaxResonance or 100))
		resFill.BackgroundColor3 = Color3.fromRGB(40, 200, 200)
	else
		-- Ore: show health-cost indicator (how much health the next summon will cost)
		local costFrac = 20 / (state.MaxHealth or 100)
		SetBarFraction(resFill, costFrac)
		resFill.BackgroundColor3 = Color3.fromRGB(200, 80, 30)
		resLabel.Text = "COST -20"
	end

	-- Rank
	local RankTiers = require(game:GetService("ReplicatedStorage").Data.RankTiers)
	local tier = RankTiers[state.RankIndex or 1]
	if rankLabel and tier then
		rankLabel.Text = tier.name:upper()
	end

	-- XP bar
	if xpFill and tier then
		local nextTier = RankTiers[(state.RankIndex or 1) + 1]
		if nextTier then
			local xpFrac = (state.XP - tier.xpRequired) / (nextTier.xpRequired - tier.xpRequired)
			SetBarFraction(xpFill, math.clamp(xpFrac, 0, 1))
		else
			SetBarFraction(xpFill, 1)
		end
	end
end

-- ── Rank-up notification ──────────────────────────────────────────────────────

task.defer(function()
	while not (_G.Remotes and _G.Remotes.RankUp) do task.wait(0.1) end
	_G.Remotes.RankUp.OnClientEvent:Connect(function(data)
		if not rankUpNotif then return end
		rankUpLabel.Text = "RANK UP: " .. (data.newRankName or "")
		rankUpNotif.Visible = true
		rankUpNotif.Position = UDim2.new(0.5, 0, 0.45, 0)
		TweenService:Create(rankUpNotif, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.35, 0),
		}):Play()
		task.delay(2.5, function()
			TweenService:Create(rankUpNotif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0.25, 0),
			}):Play()
			task.delay(0.3, function()
				rankUpNotif.Visible = false
			end)
		end)
	end)

	-- Boss spawn → show boss bar
	_G.Remotes.BossSpawned.OnClientEvent:Connect(function(data)
		if not bossFrame then return end
		bossNameLabel.Text = data.name or "BOSS"
		bossFrame.Visible = true
		SetBarFraction(bossHpFill, 1)
	end)

	_G.Remotes.BossHealthUpdate.OnClientEvent:Connect(function(data)
		if not bossHpFill then return end
		SetBarFraction(bossHpFill, data.health / (data.maxHealth or 500))
		if data.phase == 2 then
			bossNameLabel.TextColor3 = Color3.fromRGB(255, 40, 40)
		end
	end)

	_G.Remotes.BossDefeated.OnClientEvent:Connect(function()
		if bossFrame then
			TweenService:Create(bossFrame, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()
			task.delay(1.2, function() bossFrame.Visible = false end)
		end
	end)
end)

return HUDController
