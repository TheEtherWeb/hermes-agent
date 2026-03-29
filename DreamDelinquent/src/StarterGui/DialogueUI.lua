-- Dream Delinquent: Dialogue UI
-- Renders NPC speech bubbles and dialogue boxes.

local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Remotes     = ReplicatedStorage:WaitForChild("Remotes")
local Modules     = ReplicatedStorage:WaitForChild("Modules")
local Constants   = require(Modules.Constants)

local RE_DialogueLine = Remotes:WaitForChild("DialogueLine", 10)

-- ─────────────────────────────────────────────────────────────────────────────
-- ScreenGui
-- ─────────────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name           = "DialogueUI"
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled        = false
gui.Parent         = PlayerGui

-- Main dialogue box (bottom-center)
local box = Instance.new("Frame")
box.Size             = UDim2.new(0,580,0,120)
box.Position         = UDim2.new(0.5,-290,1,10)   -- starts below screen
box.BackgroundColor3 = Constants.THEME.BG_PRIMARY
box.BorderSizePixel  = 0
box.Parent           = gui
local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0,12); bc.Parent = box
local bs = Instance.new("UIStroke"); bs.Color = Constants.THEME.PANEL_BORDER; bs.Thickness = 1.5; bs.Parent = box

-- Speaker portrait slot (left)
local speakerBox = Instance.new("Frame")
speakerBox.Size          = UDim2.new(0,80,0,80)
speakerBox.Position      = UDim2.new(0,10,0.5,-40)
speakerBox.BackgroundColor3 = Constants.THEME.BG_SECONDARY
speakerBox.BorderSizePixel = 0
speakerBox.Parent        = box
local sbc = Instance.new("UICorner"); sbc.CornerRadius = UDim.new(0,8); sbc.Parent = speakerBox

local speakerImg = Instance.new("ImageLabel")
speakerImg.Size  = UDim2.new(1,0,1,0)
speakerImg.Image = ""  -- set dynamically
speakerImg.BackgroundColor3 = Color3.fromRGB(50,45,70)
speakerImg.BackgroundTransparency = 0
speakerImg.Parent = speakerBox

local speakerName = Instance.new("TextLabel")
speakerName.Size          = UDim2.new(0,80,0,16)
speakerName.Position      = UDim2.new(0,10,1,-20)
speakerName.Text          = "NPC"
speakerName.TextColor3    = Constants.THEME.TEXT_SECONDARY
speakerName.Font          = Constants.FONT_MONO
speakerName.TextSize      = 10
speakerName.BackgroundTransparency = 1
speakerName.TextXAlignment = Enum.TextXAlignment.Center
speakerName.Parent        = box

-- Dialogue text area
local textArea = Instance.new("TextLabel")
textArea.Size             = UDim2.new(1,-110,1,-20)
textArea.Position         = UDim2.new(0,100,0,10)
textArea.Text             = ""
textArea.TextColor3       = Constants.THEME.TEXT_PRIMARY
textArea.Font             = Constants.FONT_BODY
textArea.TextSize         = 15
textArea.TextWrapped      = true
textArea.BackgroundTransparency = 1
textArea.TextXAlignment   = Enum.TextXAlignment.Left
textArea.TextYAlignment   = Enum.TextYAlignment.Top
textArea.Parent           = box

-- Press-to-continue indicator
local continueHint = Instance.new("TextLabel")
continueHint.Size          = UDim2.new(0,120,0,16)
continueHint.Position      = UDim2.new(1,-130,1,-20)
continueHint.Text          = "[ F ] Continue"
continueHint.TextColor3    = Constants.THEME.TEXT_SECONDARY
continueHint.Font          = Constants.FONT_MONO
continueHint.TextSize      = 10
continueHint.BackgroundTransparency = 1
continueHint.TextXAlignment = Enum.TextXAlignment.Right
continueHint.Visible       = false
continueHint.Parent        = box

-- ─────────────────────────────────────────────────────────────────────────────
-- State
-- ─────────────────────────────────────────────────────────────────────────────
local isOpen    = false
local queue     = {}
local typeConn  = nil
local waitingForClose = false

-- ─────────────────────────────────────────────────────────────────────────────
-- Typewriter effect
-- ─────────────────────────────────────────────────────────────────────────────
local function typeText(text, callback)
	if typeConn then typeConn:Disconnect(); typeConn = nil end

	textArea.Text = ""
	local i = 0
	local chars = string.len(text)

	typeConn = game:GetService("RunService").Heartbeat:Connect(function(dt)
		i = i + dt * 40   -- 40 chars/sec
		textArea.Text = text:sub(1, math.floor(i))
		if math.floor(i) >= chars then
			typeConn:Disconnect()
			typeConn = nil
			textArea.Text = text
			if callback then callback() end
		end
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Show/hide
-- ─────────────────────────────────────────────────────────────────────────────
local function slideIn()
	gui.Enabled = true
	TweenService:Create(box,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5,-290,1,-130) }
	):Play()
end

local function slideOut()
	local tween = TweenService:Create(box,
		TweenInfo.new(0.2, Enum.EasingStyle.Sine),
		{ Position = UDim2.new(0.5,-290,1,10) }
	)
	tween:Play()
	tween.Completed:Connect(function()
		gui.Enabled = false
		isOpen = false
	end)
end

local function showLine(data)
	isOpen = true
	waitingForClose = false

	speakerName.Text = data.speaker:gsub("_npc",""):gsub("_"," "):upper()

	if not gui.Enabled then
		slideIn()
	end

	typeText(data.text, function()
		continueHint.Visible = true
		waitingForClose = true
	end)
end

local function nextLine()
	if not isOpen then return end
	if typeConn then
		-- Skip to end of current line
		typeConn:Disconnect()
		typeConn = nil
		textArea.Text = queue[1] and queue[1].text or textArea.Text
		continueHint.Visible = true
		waitingForClose = true
		return
	end

	if not waitingForClose then return end

	continueHint.Visible = false
	table.remove(queue, 1)

	if #queue > 0 then
		showLine(queue[1])
	else
		slideOut()
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Input handler
-- ─────────────────────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.F then
		nextLine()
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Remote handler
-- ─────────────────────────────────────────────────────────────────────────────
RE_DialogueLine.OnClientEvent:Connect(function(data)
	table.insert(queue, data)
	if not isOpen then
		showLine(queue[1])
	end
end)
