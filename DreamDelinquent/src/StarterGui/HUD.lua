-- Dream Delinquent: HUD ScreenGui
-- This script IS the HUD. It creates and manages all UI frames procedurally.
-- In Roblox, place this as a LocalScript inside a ScreenGui named "HUD" in StarterGui.

local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Modules     = ReplicatedStorage:WaitForChild("Modules")
local Constants   = require(Modules.Constants)

-- ─────────────────────────────────────────────────────────────────────────────
-- Root ScreenGui
-- ─────────────────────────────────────────────────────────────────────────────
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name            = "HUD"
ScreenGui.ResetOnSpawn    = false
ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent          = PlayerGui

-- ─────────────────────────────────────────────────────────────────────────────
-- Utility: make a frame
-- ─────────────────────────────────────────────────────────────────────────────
local function makeFrame(parent, name, size, pos, bg, borderColor, cornerRadius)
	local f = Instance.new("Frame")
	f.Name              = name
	f.Size              = size or UDim2.new(0,200,0,100)
	f.Position          = pos  or UDim2.new(0,0,0,0)
	f.BackgroundColor3  = bg   or Constants.THEME.BG_SECONDARY
	f.BorderSizePixel   = 0
	f.Parent            = parent
	if cornerRadius then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, cornerRadius)
		c.Parent = f
	end
	if borderColor then
		local s = Instance.new("UIStroke")
		s.Color     = borderColor
		s.Thickness = 1.5
		s.Parent    = f
	end
	return f
end

local function makeLabel(parent, name, text, size, pos, textColor, font, textSize)
	local l = Instance.new("TextLabel")
	l.Name            = name
	l.Size            = size or UDim2.new(1,0,1,0)
	l.Position        = pos  or UDim2.new(0,0,0,0)
	l.Text            = text or ""
	l.TextColor3      = textColor or Constants.THEME.TEXT_PRIMARY
	l.Font            = font or Constants.FONT_BODY
	l.TextSize        = textSize or 14
	l.BackgroundTransparency = 1
	l.TextXAlignment  = Enum.TextXAlignment.Left
	l.Parent          = parent
	return l
end

local function makeButton(parent, name, text, size, pos, bg)
	local b = Instance.new("TextButton")
	b.Name            = name
	b.Size            = size or UDim2.new(0,120,0,36)
	b.Position        = pos  or UDim2.new(0,0,0,0)
	b.Text            = text or ""
	b.TextColor3      = Constants.THEME.TEXT_PRIMARY
	b.Font            = Constants.FONT_BODY
	b.TextSize        = 14
	b.BackgroundColor3= bg or Constants.THEME.BG_SECONDARY
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Parent          = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0,6)
	c.Parent = b
	local s = Instance.new("UIStroke")
	s.Color     = Constants.THEME.PANEL_BORDER
	s.Thickness = 1
	s.Parent    = b
	return b
end

local function makeBar(parent, name, fillColor, size, pos)
	local bg = makeFrame(parent, name.."_BG",
		size, pos,
		Constants.THEME.STAT_BAR_BG, nil, 4)
	local fill = makeFrame(bg, name.."_Fill",
		UDim2.new(1,0,1,0),
		UDim2.new(0,0,0,0),
		fillColor, nil, 4)
	return bg, fill
end

-- ─────────────────────────────────────────────────────────────────────────────
-- PANEL 1: Portrait  (top-left)
-- ─────────────────────────────────────────────────────────────────────────────
local portraitPanel = makeFrame(ScreenGui, "PortraitPanel",
	UDim2.new(0,120,0,160),
	UDim2.new(0,12,0,12),
	Constants.THEME.BG_PRIMARY,
	Constants.THEME.PANEL_BORDER, 8)

-- Portrait image (placeholder: coloured rectangle)
local portraitFrame = makeFrame(portraitPanel, "PortraitImage",
	UDim2.new(1,-8,0,100),
	UDim2.new(0,4,0,4),
	Color3.fromRGB(40,38,55), nil, 6)

local portraitImg = Instance.new("ImageLabel")
portraitImg.Name   = "Image"
portraitImg.Size   = UDim2.new(1,0,1,0)
portraitImg.Image  = ""   -- set per player avatar / character art
portraitImg.BackgroundTransparency = 1
portraitImg.ImageColor3 = Color3.fromRGB(180,160,200)
portraitImg.Parent = portraitFrame

-- Emotional overlay tint (changes with portrait state)
local portraitTint = makeFrame(portraitFrame, "Tint",
	UDim2.new(1,0,1,0),
	UDim2.new(0,0,0,0),
	Color3.fromRGB(0,0,0), nil, 6)
portraitTint.BackgroundTransparency = 1

local portraitStateLabel = makeLabel(portraitPanel, "StateLabel",
	"NEUTRAL",
	UDim2.new(1,-8,0,18),
	UDim2.new(0,4,0,106),
	Constants.THEME.TEXT_SECONDARY, Constants.FONT_MONO, 11)
portraitStateLabel.TextXAlignment = Enum.TextXAlignment.Center

-- HP / Stamina bars under portrait
local hpBg, hpFill = makeBar(portraitPanel, "HP",
	Constants.THEME.HEALTH_COLOR,
	UDim2.new(1,-8,0,8),
	UDim2.new(0,4,0,128))

local stBg, stFill = makeBar(portraitPanel, "ST",
	Constants.THEME.STAMINA_COLOR,
	UDim2.new(1,-8,0,6),
	UDim2.new(0,4,0,140))

local hpLabel = makeLabel(hpBg, "HPLabel", "HP", UDim2.new(1,0,1,0),
	UDim2.new(0,4,0,0), Constants.THEME.TEXT_PRIMARY, Constants.FONT_MONO, 9)
hpLabel.TextXAlignment = Enum.TextXAlignment.Left

local stLabel = makeLabel(stBg, "STLabel", "ST", UDim2.new(1,0,1,0),
	UDim2.new(0,4,0,0), Constants.THEME.TEXT_PRIMARY, Constants.FONT_MONO, 8)

-- ─────────────────────────────────────────────────────────────────────────────
-- PANEL 2: Stat strip  (left side, below portrait)
-- ─────────────────────────────────────────────────────────────────────────────
local statPanel = makeFrame(ScreenGui, "StatPanel",
	UDim2.new(0,120,0,200),
	UDim2.new(0,12,0,180),
	Constants.THEME.BG_PRIMARY,
	Constants.THEME.PANEL_BORDER, 8)

local statBars = {}
local statY = 4
for _, statName in ipairs(Constants.STATS) do
	local rowLabel = makeLabel(statPanel, statName.."Label",
		statName:sub(1,3):upper(),
		UDim2.new(0,28,0,16),
		UDim2.new(0,4,0,statY),
		Constants.THEME.TEXT_SECONDARY, Constants.FONT_MONO, 10)

	local barBg = makeFrame(statPanel, statName.."BarBG",
		UDim2.new(0,72,0,8),
		UDim2.new(0,36,0,statY+4),
		Constants.THEME.STAT_BAR_BG, nil, 3)

	local barFill = makeFrame(barBg, statName.."Fill",
		UDim2.new(0.05,0,1,0),
		UDim2.new(0,0,0,0),
		Constants.THEME.ACCENT_STRONGER, nil, 3)

	statBars[statName] = { bg=barBg, fill=barFill }
	statY = statY + 21
end

-- ─────────────────────────────────────────────────────────────────────────────
-- PANEL 3: Stronger / Stranger meters (bottom-left)
-- ─────────────────────────────────────────────────────────────────────────────
local dualPanel = makeFrame(ScreenGui, "DualPanel",
	UDim2.new(0,140,0,70),
	UDim2.new(0,12,0,390),
	Constants.THEME.BG_PRIMARY,
	Constants.THEME.PANEL_BORDER, 8)

-- Stronger
makeLabel(dualPanel, "StrongerLabel", "STRONGER",
	UDim2.new(0,70,0,14), UDim2.new(0,6,0,6),
	Constants.THEME.ACCENT_STRONGER, Constants.FONT_MONO, 10)
local strongerBg, strongerFill = makeBar(dualPanel, "Stronger",
	Constants.THEME.ACCENT_STRONGER,
	UDim2.new(1,-12,0,8), UDim2.new(0,6,0,22))

-- Stranger
makeLabel(dualPanel, "StrangerLabel", "STRANGER",
	UDim2.new(0,70,0,14), UDim2.new(0,6,0,34),
	Constants.THEME.ACCENT_STRANGER, Constants.FONT_MONO, 10)
local strangerBg, strangerFill = makeBar(dualPanel, "Stranger",
	Constants.THEME.ACCENT_STRANGER,
	UDim2.new(1,-12,0,8), UDim2.new(0,6,0,50))

-- ─────────────────────────────────────────────────────────────────────────────
-- PANEL 4: Phase / schedule indicator (top-center)
-- ─────────────────────────────────────────────────────────────────────────────
local phasePanel = makeFrame(ScreenGui, "PhasePanel",
	UDim2.new(0,220,0,36),
	UDim2.new(0.5,-110,0,8),
	Constants.THEME.BG_PRIMARY,
	Constants.THEME.PANEL_BORDER, 18)

local phaseLabel = makeLabel(phasePanel, "PhaseLabel", "MORNING  •  DAY 1",
	UDim2.new(1,-16,1,0), UDim2.new(0,8,0,0),
	Constants.THEME.TEXT_HIGHLIGHT, Constants.FONT_TITLE, 14)
phaseLabel.TextXAlignment = Enum.TextXAlignment.Center

-- Phase progress bar
local phaseProg = makeFrame(phasePanel, "ProgressBar",
	UDim2.new(0,0,0,2),
	UDim2.new(0,0,1,-2),
	Constants.THEME.ACCENT_STRONGER, nil, 1)

-- ─────────────────────────────────────────────────────────────────────────────
-- PANEL 5: Milestone text (center screen, appears and fades)
-- ─────────────────────────────────────────────────────────────────────────────
local milestoneLabel = Instance.new("TextLabel")
milestoneLabel.Name              = "MilestoneLabel"
milestoneLabel.Size              = UDim2.new(0,400,0,60)
milestoneLabel.Position          = UDim2.new(0.5,-200,0.42,0)
milestoneLabel.Text              = ""
milestoneLabel.TextColor3        = Constants.THEME.ACCENT_STRONGER
milestoneLabel.Font              = Constants.FONT_TITLE
milestoneLabel.TextSize          = 24
milestoneLabel.BackgroundTransparency = 1
milestoneLabel.TextTransparency  = 1
milestoneLabel.TextXAlignment    = Enum.TextXAlignment.Center
milestoneLabel.TextStrokeTransparency = 0.5
milestoneLabel.TextStrokeColor3  = Color3.fromRGB(0,0,0)
milestoneLabel.ZIndex            = 10
milestoneLabel.Parent            = ScreenGui

local function showMilestone(text, axis)
	milestoneLabel.Text = text
	milestoneLabel.TextColor3 = (axis == "stranger")
		and Constants.THEME.ACCENT_STRANGER
		or  Constants.THEME.ACCENT_STRONGER

	local tweenIn  = TweenService:Create(milestoneLabel,
		TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ TextTransparency = 0 })
	local tweenOut = TweenService:Create(milestoneLabel,
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
		{ TextTransparency = 1 })

	tweenIn:Play()
	tweenIn.Completed:Connect(function()
		task.wait(1.8)
		tweenOut:Play()
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- PANEL 6: Rumor notification (slides in from right)
-- ─────────────────────────────────────────────────────────────────────────────
local rumorNotice = makeFrame(ScreenGui, "RumorNotice",
	UDim2.new(0,260,0,70),
	UDim2.new(1,20,0,60),   -- starts off-screen right
	Constants.THEME.BG_PRIMARY,
	Constants.THEME.ACCENT_STRANGER, 8)

makeLabel(rumorNotice, "Tag", "RUMOR", UDim2.new(1,-12,0,16),
	UDim2.new(0,8,0,6), Constants.THEME.ACCENT_STRANGER, Constants.FONT_MONO, 10)
local rumorTitle = makeLabel(rumorNotice, "Title", "",
	UDim2.new(1,-12,0,20), UDim2.new(0,8,0,22),
	Constants.THEME.TEXT_HIGHLIGHT, Constants.FONT_TITLE, 14)
local rumorBody = makeLabel(rumorNotice, "Body", "",
	UDim2.new(1,-12,0,24), UDim2.new(0,8,0,42),
	Constants.THEME.TEXT_SECONDARY, Constants.FONT_BODY, 11)
rumorBody.TextWrapped = true

local function showRumorNotice(rumorData)
	rumorTitle.Text = rumorData.title or "Unknown"
	rumorBody.Text  = rumorData.body or ""

	local tweenIn  = TweenService:Create(rumorNotice,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(1,-272,0,60) })
	local tweenOut = TweenService:Create(rumorNotice,
		TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
		{ Position = UDim2.new(1,20,0,60) })

	tweenIn:Play()
	tweenIn.Completed:Connect(function()
		task.wait(3.5)
		tweenOut:Play()
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- PANEL 7: Result popups (club session / class result)
-- ─────────────────────────────────────────────────────────────────────────────
local resultPanel = makeFrame(ScreenGui, "ResultPanel",
	UDim2.new(0,300,0,200),
	UDim2.new(0.5,-150,0.5,-100),
	Constants.THEME.BG_PRIMARY,
	Constants.THEME.PANEL_BORDER, 12)
resultPanel.Visible = false

makeLabel(resultPanel, "Header", "",
	UDim2.new(1,-16,0,26), UDim2.new(0,8,0,8),
	Constants.THEME.ACCENT_STRONGER, Constants.FONT_TITLE, 18)
local resultBody = Instance.new("ScrollingFrame")
resultBody.Name            = "Body"
resultBody.Size            = UDim2.new(1,-16,1,-80)
resultBody.Position        = UDim2.new(0,8,0,40)
resultBody.BackgroundTransparency = 1
resultBody.ScrollBarThickness = 4
resultBody.BorderSizePixel = 0
resultBody.Parent          = resultPanel

local resultText = makeLabel(resultBody, "Text", "",
	UDim2.new(1,0,0,0), UDim2.new(0,0,0,0),
	Constants.THEME.TEXT_PRIMARY, Constants.FONT_BODY, 13)
resultText.TextWrapped = true
resultText.AutomaticSize = Enum.AutomaticSize.Y

local closeBtn = makeButton(resultPanel, "CloseBtn", "CLOSE",
	UDim2.new(0,100,0,32),
	UDim2.new(0.5,-50,1,-40),
	Constants.THEME.BG_SECONDARY)
closeBtn.MouseButton1Click:Connect(function()
	resultPanel.Visible = false
end)

local function showResult(header, lines, accentColor)
	resultPanel.FindFirstChild("Header").Text = header
	resultPanel.FindFirstChild("Header").TextColor3 = accentColor or Constants.THEME.ACCENT_STRONGER
	resultText.Text = table.concat(lines, "\n")
	resultText.Size = UDim2.new(1,0,0,#lines * 18)
	resultBody.CanvasSize = UDim2.new(0,0,0,#lines * 18)
	resultPanel.Visible = true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- PANEL 8: Character creation / background select
-- ─────────────────────────────────────────────────────────────────────────────
local charSelectPanel = makeFrame(ScreenGui, "CharSelectPanel",
	UDim2.new(0,420,0,320),
	UDim2.new(0.5,-210,0.5,-160),
	Constants.THEME.BG_PRIMARY,
	Constants.THEME.PANEL_BORDER, 12)
charSelectPanel.Visible = false

makeLabel(charSelectPanel, "Title", "CHOOSE YOUR BACKGROUND",
	UDim2.new(1,-16,0,28), UDim2.new(0,8,0,8),
	Constants.THEME.TEXT_HIGHLIGHT, Constants.FONT_TITLE, 18)
makeLabel(charSelectPanel, "Subtitle", "You start clubless and trackless. What you become is up to you.",
	UDim2.new(1,-16,0,18), UDim2.new(0,8,0,38),
	Constants.THEME.TEXT_SECONDARY, Constants.FONT_BODY, 12)

local bgList = Instance.new("UIListLayout")
bgList.SortOrder = Enum.SortOrder.LayoutOrder
bgList.Padding    = UDim.new(0,6)
bgList.Parent     = charSelectPanel

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants2 = require(Modules.Constants)

local bgContainer = Instance.new("Frame")
bgContainer.Name             = "BgContainer"
bgContainer.Size             = UDim2.new(1,-16,0,220)
bgContainer.Position         = UDim2.new(0,8,0,62)
bgContainer.BackgroundTransparency = 1
bgContainer.Parent           = charSelectPanel

local bgListLayout = Instance.new("UIListLayout")
bgListLayout.Padding      = UDim.new(0,4)
bgListLayout.SortOrder    = Enum.SortOrder.LayoutOrder
bgListLayout.Parent       = bgContainer

local selectedBackground = nil

for i, bg in ipairs(Constants2.BACKGROUNDS) do
	local row = makeButton(bgContainer, bg.id,
		bg.name .. "   –   " .. bg.psychicBias .. " bias",
		UDim2.new(1,0,0,32), nil,
		Constants2.THEME.BG_SECONDARY)
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.LayoutOrder    = i

	local bonusText = {}
	for stat, val in pairs(bg.statBonus) do
		table.insert(bonusText, stat.."+"..val)
	end
	makeLabel(row, "Bonus", table.concat(bonusText, "  "),
		UDim2.new(0,160,1,0), UDim2.new(1,-170,0,0),
		Constants2.THEME.TEXT_SECONDARY, Constants2.FONT_MONO, 10)

	row.MouseButton1Click:Connect(function()
		selectedBackground = bg.id
		-- Highlight
		for _, child in ipairs(bgContainer:GetChildren()) do
			if child:IsA("TextButton") then
				child.BackgroundColor3 = Constants2.THEME.BG_SECONDARY
			end
		end
		row.BackgroundColor3 = Color3.fromRGB(40,35,65)
	end)
end

local startBtn = makeButton(charSelectPanel, "StartBtn", "BEGIN",
	UDim2.new(0,120,0,38),
	UDim2.new(0.5,-60,1,-50),
	Color3.fromRGB(60,45,110))
startBtn.Font     = Constants.FONT_TITLE
startBtn.TextSize = 16
startBtn.MouseButton1Click:Connect(function()
	if selectedBackground then
		charSelectPanel.Visible = false
		-- Notify server (handled via a remote set up in GameManager)
		local RF = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("SetBackground")
		if RF then RF:InvokeServer(selectedBackground) end
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- PANEL 9: Club selection menu (toggled by keybind)
-- ─────────────────────────────────────────────────────────────────────────────
local clubMenuPanel = makeFrame(ScreenGui, "ClubMenu",
	UDim2.new(0,280,0,380),
	UDim2.new(1,-300,0,60),
	Constants.THEME.BG_PRIMARY,
	Constants.THEME.PANEL_BORDER, 10)
clubMenuPanel.Visible = false

makeLabel(clubMenuPanel, "Title", "CLUBS & TEAMS",
	UDim2.new(1,-12,0,22), UDim2.new(0,6,0,6),
	Constants.THEME.TEXT_HIGHLIGHT, Constants.FONT_TITLE, 16)

local clubScroll = Instance.new("ScrollingFrame")
clubScroll.Name              = "ClubScroll"
clubScroll.Size              = UDim2.new(1,-8,1,-40)
clubScroll.Position          = UDim2.new(0,4,0,34)
clubScroll.BackgroundTransparency = 1
clubScroll.ScrollBarThickness = 4
clubScroll.BorderSizePixel   = 0
clubScroll.Parent            = clubMenuPanel

local clubListLayout = Instance.new("UIListLayout")
clubListLayout.Padding    = UDim.new(0,3)
clubListLayout.SortOrder  = Enum.SortOrder.LayoutOrder
clubListLayout.Parent     = clubScroll

for i, club in ipairs(Constants.CLUBS) do
	local row = makeButton(clubScroll, club.id,
		club.name,
		UDim2.new(1,-4,0,36), nil,
		Constants.THEME.BG_SECONDARY)
	row.LayoutOrder    = i
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextSize       = 13

	makeLabel(row, "Type", club.type:upper(),
		UDim2.new(0,40,0,10), UDim2.new(1,-46,0,4),
		Constants.THEME.TEXT_SECONDARY, Constants.FONT_MONO, 9)

	row.MouseButton1Click:Connect(function()
		local gc = _G.GameClient
		if gc then
			local ok, msg = gc.JoinClub(club.id)
			showMilestone(ok and ("Joined " .. club.name) or msg,
				ok and "stronger" or "stranger")
		end
	end)
end

clubScroll.CanvasSize = UDim2.new(0,0,0, #Constants.CLUBS * 39 + 8)

-- ─────────────────────────────────────────────────────────────────────────────
-- PANEL 10: Rumor board (shows heard rumors)
-- ─────────────────────────────────────────────────────────────────────────────
local rumorBoardPanel = makeFrame(ScreenGui, "RumorBoard",
	UDim2.new(0,300,0,320),
	UDim2.new(1,-320,0,60),
	Constants.THEME.BG_PRIMARY,
	Constants.THEME.ACCENT_STRANGER, 10)
rumorBoardPanel.Visible = false

makeLabel(rumorBoardPanel, "Title", "RUMOR BOARD",
	UDim2.new(1,-12,0,22), UDim2.new(0,6,0,6),
	Constants.THEME.ACCENT_STRANGER, Constants.FONT_TITLE, 16)

local rumorScroll = Instance.new("ScrollingFrame")
rumorScroll.Name              = "Scroll"
rumorScroll.Size              = UDim2.new(1,-8,1,-40)
rumorScroll.Position          = UDim2.new(0,4,0,34)
rumorScroll.BackgroundTransparency = 1
rumorScroll.ScrollBarThickness= 4
rumorScroll.BorderSizePixel   = 0
rumorScroll.Parent            = rumorBoardPanel

local rumorLayout = Instance.new("UIListLayout")
rumorLayout.Padding   = UDim.new(0,6)
rumorLayout.SortOrder = Enum.SortOrder.LayoutOrder
rumorLayout.Parent    = rumorScroll

local rumorEntries = {}

local function addRumorEntry(rumorData)
	local entry = makeFrame(rumorScroll, rumorData.id,
		UDim2.new(1,-4,0,56), nil,
		Color3.fromRGB(22,20,35),
		Constants.THEME.ACCENT_STRANGER, 6)
	entry.LayoutOrder = #rumorEntries + 1

	makeLabel(entry, "Title", rumorData.title,
		UDim2.new(1,-8,0,18), UDim2.new(0,4,0,4),
		Constants.THEME.TEXT_HIGHLIGHT, Constants.FONT_TITLE, 13)

	local bodyL = makeLabel(entry, "Body", rumorData.body,
		UDim2.new(1,-8,0,28), UDim2.new(0,4,0,22),
		Constants.THEME.TEXT_SECONDARY, Constants.FONT_BODY, 11)
	bodyL.TextWrapped = true

	local pursueBtn = makeButton(entry, "PursueBtn", "PURSUE",
		UDim2.new(0,70,0,20),
		UDim2.new(1,-78,0,4),
		Color3.fromRGB(40,25,65))
	pursueBtn.TextSize = 11

	pursueBtn.MouseButton1Click:Connect(function()
		local gc = _G.GameClient
		if gc then
			gc.PursueRumor(rumorData.id)
			pursueBtn.Text = "PURSUING..."
			pursueBtn.Active = false
		end
	end)

	table.insert(rumorEntries, entry)
	rumorScroll.CanvasSize = UDim2.new(0,0,0, #rumorEntries * 62 + 10)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Keybinds for toggling menus
-- ─────────────────────────────────────────────────────────────────────────────
local UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.G then
		clubMenuPanel.Visible  = not clubMenuPanel.Visible
		rumorBoardPanel.Visible = false
	elseif input.KeyCode == Enum.KeyCode.J then
		rumorBoardPanel.Visible = not rumorBoardPanel.Visible
		clubMenuPanel.Visible  = false
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- HUDController module: consumed by GameClient
-- ─────────────────────────────────────────────────────────────────────────────
local HUDController = {}

function HUDController.UpdateStats(data)
	if not data then return end

	-- Stat bars
	for _, statName in ipairs(Constants.STATS) do
		local bars = statBars[statName]
		if bars then
			local pct = (data.stats[statName] or 0) / Constants.STAT_MAX
			local tween = TweenService:Create(bars.fill,
				TweenInfo.new(0.5, Enum.EasingStyle.Sine),
				{ Size = UDim2.new(math.clamp(pct,0.02,1), 0, 1, 0) })
			tween:Play()
		end
	end

	-- Stronger / Stranger
	local sPct = (data.stronger or 0) / Constants.STRONGER_MAX
	TweenService:Create(strongerFill,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine),
		{ Size = UDim2.new(math.clamp(sPct,0.01,1),0,1,0) }):Play()

	local xPct = (data.stranger or 0) / Constants.STRANGER_MAX
	TweenService:Create(strangerFill,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine),
		{ Size = UDim2.new(math.clamp(xPct,0.01,1),0,1,0) }):Play()
end

function HUDController.UpdatePhase(phaseData)
	phaseLabel.Text = phaseData.phase:upper() .. "  •  DAY " .. phaseData.day
	if phaseData.isNight then
		phaseLabel.TextColor3 = Constants.THEME.ACCENT_STRANGER
	else
		phaseLabel.TextColor3 = Constants.THEME.TEXT_HIGHLIGHT
	end
end

function HUDController.ShowMilestone(data)
	showMilestone(data.text, data.axis)
end

-- Portrait state visual
local PORTRAIT_COLORS = {
	Neutral   = { Color3.fromRGB(0,0,0),         0.95 },   -- near-transparent
	Focused   = { Color3.fromRGB(50,100,200),      0.85 },
	Smirk     = { Color3.fromRGB(100,80,30),       0.9  },
	Tense     = { Color3.fromRGB(150,60,30),       0.7  },
	Bruised   = { Color3.fromRGB(80,20,20),        0.55 },
	Sweating  = { Color3.fromRGB(60,80,120),       0.75 },
	Afraid    = { Color3.fromRGB(40,20,80),        0.6  },
	Distorted = { Color3.fromRGB(120,30,200),      0.4  },
	Glowing   = { Color3.fromRGB(200,180,50),      0.3  },
}

function HUDController.UpdatePortrait(state)
	local cfg = PORTRAIT_COLORS[state]
	if cfg then
		TweenService:Create(portraitTint,
			TweenInfo.new(0.6, Enum.EasingStyle.Sine),
			{ BackgroundColor3 = cfg[1], BackgroundTransparency = cfg[2] }):Play()
	end
	portraitStateLabel.Text = state:upper()
end

function HUDController.ShowRumorNotice(rumorData)
	showRumorNotice(rumorData)
	addRumorEntry(rumorData)
end

function HUDController.ShowRumorResult(result)
	local lines = {}
	if result.survived then
		table.insert(lines, "You survived.")
	else
		table.insert(lines, "You didn't make it out clean.")
	end
	if result.isTrue then
		table.insert(lines, "The rumor was real.")
	else
		table.insert(lines, "It was just a rumor.")
	end
	if result.consequence then
		table.insert(lines, "")
		table.insert(lines, "Consequence: " .. result.consequence)
	end
	if result.nextRumorId then
		table.insert(lines, "")
		table.insert(lines, "Something else is stirring...")
	end
	showResult(
		result.survived and "You Came Back." or "What Happened There?",
		lines,
		result.survived and Constants.THEME.ACCENT_STRONGER or Constants.THEME.ACCENT_STRANGER
	)
end

function HUDController.ShowClubResult(result)
	local lines = { result.clubName }
	if result.flavourText then
		table.insert(lines, "")
		table.insert(lines, result.flavourText)
	end
	table.insert(lines, "")
	for stat, gain in pairs(result.statGains or {}) do
		table.insert(lines, stat .. "  +" .. gain)
	end
	if result.strongerResult and result.strongerResult.gain > 0 then
		table.insert(lines, "")
		table.insert(lines, "Stronger  +" .. result.strongerResult.gain)
	end
	showResult("After School", lines, Constants.THEME.ACCENT_STRONGER)
end

function HUDController.ShowClassResult(result)
	local lines = {
		"Score: " .. result.score,
		"Grade: " .. result.tier:upper(),
		"",
	}
	for stat, gain in pairs(result.statGains or {}) do
		table.insert(lines, stat .. "  +" .. gain)
	end
	if result.credits > 0 then
		table.insert(lines, "Credits  +" .. result.credits)
	end
	table.insert(lines, ("GPA  %.2f"):format(result.newGPA))
	showResult("Class Complete", lines, Constants.THEME.ACCENT_STRONGER)
end

function HUDController.ShowCombatResult(result)
	local lines = {}
	if result.won then
		table.insert(lines, "You won the fight.")
		table.insert(lines, "")
		table.insert(lines, "Wins: " .. (result.wins or ""))
	else
		table.insert(lines, "You lost.")
		table.insert(lines, "")
		table.insert(lines, "But something held.")
	end
	showResult("Fight Over", lines,
		result.won and Constants.THEME.ACCENT_STRONGER or Constants.THEME.ACCENT_STRANGER)
end

-- Register with script
local HUDScript = script
local mod = Instance.new("ModuleScript")
mod.Name   = "HUDController"
mod.Source = "return require(game:GetService('Players').LocalPlayer.PlayerGui.HUD)"
mod.Parent = HUDScript.Parent

-- Expose for GameClient
return HUDController
