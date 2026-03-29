-- Dream Delinquent: CharacterSelect Screen
-- First-time character background and stat bias selection.
-- This LocalScript creates a full-screen UI on first join.

local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Modules     = ReplicatedStorage:WaitForChild("Modules")
local Remotes     = ReplicatedStorage:WaitForChild("Remotes")

local Constants = require(Modules.Constants)

-- ─────────────────────────────────────────────────────────────────────────────
-- Only show on first launch (checked via data flag)
-- ─────────────────────────────────────────────────────────────────────────────
local RF_GetPlayerState = Remotes:WaitForChild("GetPlayerState", 10)
local RF_SetBackground  = Remotes:FindFirstChild("SetBackground")
if not RF_SetBackground then
	RF_SetBackground = Instance.new("RemoteFunction")
	RF_SetBackground.Name = "SetBackground"
	RF_SetBackground.Parent = Remotes
end

local state = RF_GetPlayerState:InvokeServer()
if state and state.backgroundId and state.backgroundId ~= "Transfer" then
	-- Already has a background, skip character select
	return
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Build full-screen overlay
-- ─────────────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name           = "CharacterSelect"
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = PlayerGui

-- Background fill
local bg = Instance.new("Frame")
bg.Size              = UDim2.new(1,0,1,0)
bg.BackgroundColor3  = Color3.fromRGB(8,8,14)
bg.BorderSizePixel   = 0
bg.Parent            = gui

-- Gradient overlay
local grad = Instance.new("UIGradient")
grad.Color    = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(20,10,40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(8,8,14)),
})
grad.Rotation = 45
grad.Parent   = bg

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Text              = "DREAM DELINQUENT"
titleLabel.Size              = UDim2.new(1,0,0,60)
titleLabel.Position          = UDim2.new(0,0,0,40)
titleLabel.TextColor3        = Color3.fromRGB(255,230,80)
titleLabel.Font              = Enum.Font.GothamBold
titleLabel.TextSize          = 42
titleLabel.BackgroundTransparency = 1
titleLabel.TextXAlignment    = Enum.TextXAlignment.Center
titleLabel.TextStrokeTransparency = 0.4
titleLabel.TextStrokeColor3  = Color3.fromRGB(0,0,0)
titleLabel.Parent            = bg

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Text           = "You start with nothing. Let's see what you become."
subtitleLabel.Size           = UDim2.new(1,0,0,24)
subtitleLabel.Position       = UDim2.new(0,0,0,100)
subtitleLabel.TextColor3     = Color3.fromRGB(160,140,200)
subtitleLabel.Font           = Enum.Font.Gotham
subtitleLabel.TextSize       = 16
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Center
subtitleLabel.Parent         = bg

-- ─────────────────────────────────────────────────────────────────────────────
-- Two columns: left = backgrounds, right = stat preview
-- ─────────────────────────────────────────────────────────────────────────────
local leftCol = Instance.new("Frame")
leftCol.Size             = UDim2.new(0,340,0,340)
leftCol.Position         = UDim2.new(0.5,-340,0,140)
leftCol.BackgroundTransparency = 1
leftCol.Parent           = bg

local rightCol = Instance.new("Frame")
rightCol.Size            = UDim2.new(0,300,0,340)
rightCol.Position        = UDim2.new(0.5,20,0,140)
rightCol.BackgroundTransparency = 1
rightCol.Parent          = bg

-- Section header: left
local leftHeader = Instance.new("TextLabel")
leftHeader.Text          = "YOUR BACKGROUND"
leftHeader.Size          = UDim2.new(1,0,0,24)
leftHeader.TextColor3    = Color3.fromRGB(200,190,170)
leftHeader.Font          = Enum.Font.GothamBold
leftHeader.TextSize      = 14
leftHeader.BackgroundTransparency = 1
leftHeader.TextXAlignment = Enum.TextXAlignment.Left
leftHeader.Parent        = leftCol

-- Background list
local bgList = Instance.new("Frame")
bgList.Size             = UDim2.new(1,0,1,-30)
bgList.Position         = UDim2.new(0,0,0,28)
bgList.BackgroundTransparency = 1
bgList.Parent           = leftCol

local listLayout = Instance.new("UIListLayout")
listLayout.Padding   = UDim.new(0,6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent    = bgList

-- Right: stat preview
local rightHeader = Instance.new("TextLabel")
rightHeader.Text         = "STARTING STATS"
rightHeader.Size         = UDim2.new(1,0,0,24)
rightHeader.TextColor3   = Color3.fromRGB(200,190,170)
rightHeader.Font         = Enum.Font.GothamBold
rightHeader.TextSize     = 14
rightHeader.BackgroundTransparency = 1
rightHeader.TextXAlignment = Enum.TextXAlignment.Left
rightHeader.Parent       = rightCol

local previewDesc = Instance.new("TextLabel")
previewDesc.Text         = "Select a background to preview."
previewDesc.Size         = UDim2.new(1,0,0,40)
previewDesc.Position     = UDim2.new(0,0,0,28)
previewDesc.TextColor3   = Color3.fromRGB(140,130,160)
previewDesc.Font         = Enum.Font.Gotham
previewDesc.TextSize     = 13
previewDesc.TextWrapped  = true
previewDesc.BackgroundTransparency = 1
previewDesc.TextXAlignment = Enum.TextXAlignment.Left
previewDesc.Parent       = rightCol

-- Stat bars preview
local previewBars = {}
local barY = 76
for _, statName in ipairs(Constants.STATS) do
	local lbl = Instance.new("TextLabel")
	lbl.Text          = statName:sub(1,3):upper()
	lbl.Size          = UDim2.new(0,30,0,16)
	lbl.Position      = UDim2.new(0,0,0,barY)
	lbl.TextColor3    = Color3.fromRGB(150,140,170)
	lbl.Font          = Enum.Font.Code
	lbl.TextSize      = 10
	lbl.BackgroundTransparency = 1
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent        = rightCol

	local barBg = Instance.new("Frame")
	barBg.Size          = UDim2.new(0,240,0,10)
	barBg.Position      = UDim2.new(0,36,0,barY+3)
	barBg.BackgroundColor3 = Color3.fromRGB(25,23,38)
	barBg.BorderSizePixel = 0
	barBg.Parent        = rightCol
	local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0,4); bc.Parent = barBg

	local barFill = Instance.new("Frame")
	barFill.Size    = UDim2.new(0.05,0,1,0)
	barFill.BackgroundColor3 = Color3.fromRGB(100,180,255)
	barFill.BorderSizePixel = 0
	barFill.Parent  = barBg
	local bfc = Instance.new("UICorner"); bfc.CornerRadius = UDim.new(0,4); bfc.Parent = barFill

	previewBars[statName] = barFill
	barY = barY + 22
end

local psychicHint = Instance.new("TextLabel")
psychicHint.Text         = ""
psychicHint.Size         = UDim2.new(1,0,0,22)
psychicHint.Position     = UDim2.new(0,0,0,barY+6)
psychicHint.TextColor3   = Color3.fromRGB(160,80,255)
psychicHint.Font         = Enum.Font.GothamBold
psychicHint.TextSize     = 13
psychicHint.BackgroundTransparency = 1
psychicHint.TextXAlignment = Enum.TextXAlignment.Left
psychicHint.Parent       = rightCol

-- ─────────────────────────────────────────────────────────────────────────────
-- Background buttons
-- ─────────────────────────────────────────────────────────────────────────────
local selectedBg    = nil
local bgButtons     = {}

local function updatePreview(bg)
	previewDesc.Text = bg.name
	psychicHint.Text = "Psychic bias: " .. bg.psychicBias

	for _, statName in ipairs(Constants.STATS) do
		local base  = Constants.STAT_DEFAULT
		local bonus = bg.statBonus[statName] or 0
		local total = base + bonus
		local pct   = total / Constants.STAT_MAX

		local color = bonus > 0
			and Color3.fromRGB(100, 220, 120)
			or  Color3.fromRGB(80, 120, 180)

		TweenService:Create(previewBars[statName],
			TweenInfo.new(0.3, Enum.EasingStyle.Sine),
			{ Size = UDim2.new(pct, 0, 1, 0), BackgroundColor3 = color }
		):Play()
	end
end

for i, bgDef in ipairs(Constants.BACKGROUNDS) do
	local btn = Instance.new("TextButton")
	btn.Name            = bgDef.id
	btn.Size            = UDim2.new(1,0,0,42)
	btn.Text            = ""
	btn.BackgroundColor3 = Color3.fromRGB(18,16,30)
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.LayoutOrder     = i
	btn.Parent          = bgList

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0,8)
	btnCorner.Parent = btn

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color     = Color3.fromRGB(50,45,70)
	btnStroke.Thickness = 1
	btnStroke.Parent    = btn

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Text          = bgDef.name
	nameLabel.Size          = UDim2.new(1,-16,0,20)
	nameLabel.Position      = UDim2.new(0,8,0,4)
	nameLabel.TextColor3    = Color3.fromRGB(230,220,200)
	nameLabel.Font          = Enum.Font.GothamBold
	nameLabel.TextSize      = 14
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent        = btn

	-- Stat bonus summary
	local bonuses = {}
	for s, v in pairs(bgDef.statBonus) do
		table.insert(bonuses, s:sub(1,3) .. "+" .. v)
	end
	local bonusLabel = Instance.new("TextLabel")
	bonusLabel.Text         = table.concat(bonuses, "  ")
	bonusLabel.Size         = UDim2.new(1,-16,0,14)
	bonusLabel.Position     = UDim2.new(0,8,0,24)
	bonusLabel.TextColor3   = Color3.fromRGB(120,180,120)
	bonusLabel.Font         = Enum.Font.Code
	bonusLabel.TextSize     = 10
	bonusLabel.BackgroundTransparency = 1
	bonusLabel.TextXAlignment = Enum.TextXAlignment.Left
	bonusLabel.Parent       = btn

	btn.MouseButton1Click:Connect(function()
		selectedBg = bgDef.id
		for _, b in ipairs(bgButtons) do
			b.BackgroundColor3 = Color3.fromRGB(18,16,30)
			if b:FindFirstChildOfClass("UIStroke") then
				b:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(50,45,70)
			end
		end
		btn.BackgroundColor3 = Color3.fromRGB(38,28,68)
		btnStroke.Color      = Color3.fromRGB(140,80,255)
		updatePreview(bgDef)
	end)

	table.insert(bgButtons, btn)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Confirm button
-- ─────────────────────────────────────────────────────────────────────────────
local confirmBtn = Instance.new("TextButton")
confirmBtn.Text              = "BEGIN YOUR STORY"
confirmBtn.Size              = UDim2.new(0,220,0,50)
confirmBtn.Position          = UDim2.new(0.5,-110,1,-100)
confirmBtn.BackgroundColor3  = Color3.fromRGB(60,40,130)
confirmBtn.TextColor3        = Color3.fromRGB(255,240,160)
confirmBtn.Font              = Enum.Font.GothamBold
confirmBtn.TextSize          = 18
confirmBtn.BorderSizePixel   = 0
confirmBtn.AutoButtonColor   = false
confirmBtn.Parent            = bg

local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0,12); cc.Parent = confirmBtn
local cs = Instance.new("UIStroke"); cs.Color = Color3.fromRGB(160,120,255); cs.Thickness = 2; cs.Parent = confirmBtn

confirmBtn.MouseButton1Click:Connect(function()
	if not selectedBg then
		-- Flash subtitle as warning
		subtitleLabel.Text = "Choose a background first."
		subtitleLabel.TextColor3 = Color3.fromRGB(255,100,80)
		task.delay(1.5, function()
			subtitleLabel.Text = "You start with nothing. Let's see what you become."
			subtitleLabel.TextColor3 = Color3.fromRGB(160,140,200)
		end)
		return
	end

	RF_SetBackground:InvokeServer(selectedBg)

	-- Fade out
	local fadeFrame = Instance.new("Frame")
	fadeFrame.Size  = UDim2.new(1,0,1,0)
	fadeFrame.BackgroundColor3 = Color3.fromRGB(0,0,0)
	fadeFrame.BackgroundTransparency = 1
	fadeFrame.ZIndex = 20
	fadeFrame.BorderSizePixel = 0
	fadeFrame.Parent = bg

	TweenService:Create(fadeFrame,
		TweenInfo.new(1.2, Enum.EasingStyle.Sine),
		{ BackgroundTransparency = 0 }
	):Play()

	task.delay(1.3, function()
		gui:Destroy()
	end)
end)

-- Intro animation: fade in
bg.BackgroundTransparency = 1
TweenService:Create(bg,
	TweenInfo.new(1.0, Enum.EasingStyle.Sine),
	{ BackgroundTransparency = 0 }
):Play()
