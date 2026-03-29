-- Dream Delinquent: Diploma Screen
-- Shown at graduation. Displays the player's full record.

local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Modules     = ReplicatedStorage:WaitForChild("Modules")
local Remotes     = ReplicatedStorage:WaitForChild("Remotes")

local Constants     = require(Modules.Constants)
local GradeSystem   = require(Modules.GradeSystem)

local RE_ShowDiploma = Remotes:WaitForChild("ShowDiploma", 10)

-- ─────────────────────────────────────────────────────────────────────────────
-- Build GUI
-- ─────────────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name           = "DiplomaScreen"
gui.IgnoreGuiInset = true
gui.Enabled        = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = PlayerGui

-- Parchment background
local parchment = Instance.new("Frame")
parchment.Size             = UDim2.new(0,560,0,480)
parchment.Position         = UDim2.new(0.5,-280,0.5,-240)
parchment.BackgroundColor3 = Color3.fromRGB(245,236,205)
parchment.BorderSizePixel  = 0
parchment.Parent           = gui

local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0,12); pc.Parent = parchment
local ps = Instance.new("UIStroke"); ps.Color = Color3.fromRGB(140,120,80); ps.Thickness = 3; ps.Parent = parchment

-- Top band
local topBand = Instance.new("Frame")
topBand.Size             = UDim2.new(1,0,0,60)
topBand.BackgroundColor3 = Color3.fromRGB(40,30,70)
topBand.BorderSizePixel  = 0
topBand.Parent           = parchment
local tbc = Instance.new("UICorner"); tbc.CornerRadius = UDim.new(0,12); tbc.Parent = topBand

local schoolName = Instance.new("TextLabel")
schoolName.Text            = "DREAM DELINQUENT HIGH SCHOOL"
schoolName.Size            = UDim2.new(1,-16,1,0)
schoolName.Position        = UDim2.new(0,8,0,0)
schoolName.TextColor3      = Color3.fromRGB(255,230,100)
schoolName.Font            = Enum.Font.GothamBold
schoolName.TextSize        = 18
schoolName.BackgroundTransparency = 1
schoolName.TextXAlignment  = Enum.TextXAlignment.Center
schoolName.Parent          = topBand

-- Certificate header
local certHeader = Instance.new("TextLabel")
certHeader.Text            = "Certificate of Completion"
certHeader.Size            = UDim2.new(1,0,0,30)
certHeader.Position        = UDim2.new(0,0,0,70)
certHeader.TextColor3      = Color3.fromRGB(80,60,40)
certHeader.Font            = Enum.Font.GothamBold
certHeader.TextSize        = 22
certHeader.BackgroundTransparency = 1
certHeader.TextXAlignment  = Enum.TextXAlignment.Center
certHeader.Parent          = parchment

-- Divider line
local divider = Instance.new("Frame")
divider.Size             = UDim2.new(0.8,0,0,2)
divider.Position         = UDim2.new(0.1,0,0,108)
divider.BackgroundColor3 = Color3.fromRGB(140,120,80)
divider.BorderSizePixel  = 0
divider.Parent           = parchment

-- Stats block
local statsBlock = Instance.new("Frame")
statsBlock.Size            = UDim2.new(1,-40,0,200)
statsBlock.Position        = UDim2.new(0,20,0,120)
statsBlock.BackgroundTransparency = 1
statsBlock.Parent          = parchment

local function makeStatRow(parent, label, value, yPos, valueColor)
	local lbl = Instance.new("TextLabel")
	lbl.Size          = UDim2.new(0.5,0,0,22)
	lbl.Position      = UDim2.new(0,0,0,yPos)
	lbl.Text          = label
	lbl.TextColor3    = Color3.fromRGB(100,80,60)
	lbl.Font          = Enum.Font.Gotham
	lbl.TextSize      = 14
	lbl.BackgroundTransparency = 1
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent        = parent

	local val = Instance.new("TextLabel")
	val.Size          = UDim2.new(0.5,0,0,22)
	val.Position      = UDim2.new(0.5,0,0,yPos)
	val.Text          = tostring(value)
	val.TextColor3    = valueColor or Color3.fromRGB(40,25,70)
	val.Font          = Enum.Font.GothamBold
	val.TextSize      = 14
	val.BackgroundTransparency = 1
	val.TextXAlignment = Enum.TextXAlignment.Right
	val.Parent        = parent
end

-- Filled dynamically on show
local gpaDisplay  = makeStatRow(statsBlock, "Grade Point Average", "—", 0, Color3.fromRGB(60,100,40))
local routeDisplay, conductDisplay, repDisplay, strangDisplay

-- Condition note
local conditionNote = Instance.new("TextLabel")
conditionNote.Size          = UDim2.new(1,0,0,22)
conditionNote.Position      = UDim2.new(0,0,0,196)
conditionNote.Text          = ""
conditionNote.TextColor3    = Color3.fromRGB(120,40,140)
conditionNote.Font          = Enum.Font.GothamBold
conditionNote.TextSize      = 12
conditionNote.BackgroundTransparency = 1
conditionNote.TextXAlignment = Enum.TextXAlignment.Center
conditionNote.Parent        = statsBlock

-- Bottom band
local bottomBand = Instance.new("Frame")
bottomBand.Size             = UDim2.new(1,0,0,50)
bottomBand.Position         = UDim2.new(0,0,1,-50)
bottomBand.BackgroundColor3 = Color3.fromRGB(40,30,70)
bottomBand.BorderSizePixel  = 0
bottomBand.Parent           = parchment
local bbc = Instance.new("UICorner"); bbc.CornerRadius = UDim.new(0,12); bbc.Parent = bottomBand

local bottomText = Instance.new("TextLabel")
bottomText.Text            = "\"What you feel now — keep it.\""
bottomText.Size            = UDim2.new(1,0,1,0)
bottomText.TextColor3      = Color3.fromRGB(200,180,120)
bottomText.Font            = Enum.Font.Gotham
bottomText.TextSize        = 13
bottomText.BackgroundTransparency = 1
bottomText.TextXAlignment  = Enum.TextXAlignment.Center
bottomText.Parent          = bottomBand

-- Continue button
local continueBtn = Instance.new("TextButton")
continueBtn.Text            = "CONTINUE"
continueBtn.Size            = UDim2.new(0,180,0,44)
continueBtn.Position        = UDim2.new(0.5,-90,0,440)
continueBtn.BackgroundColor3 = Color3.fromRGB(55,40,110)
continueBtn.TextColor3      = Color3.fromRGB(255,240,160)
continueBtn.Font            = Enum.Font.GothamBold
continueBtn.TextSize        = 16
continueBtn.BorderSizePixel = 0
continueBtn.AutoButtonColor = false
continueBtn.Parent          = gui

local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(0,10); cbc.Parent = continueBtn
local cbs = Instance.new("UIStroke"); cbs.Color = Color3.fromRGB(140,100,255); cbs.Thickness = 2; cbs.Parent = continueBtn

continueBtn.MouseButton1Click:Connect(function()
	TweenService:Create(parchment,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine),
		{ Position = UDim2.new(0.5,-280,1.5,0) }
	):Play()
	task.delay(0.6, function()
		gui.Enabled = false
	end)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Show diploma when server fires event
-- ─────────────────────────────────────────────────────────────────────────────
RE_ShowDiploma.OnClientEvent:Connect(function(diplomaData)
	-- diplomaData = { gpa, route, conduct, streetRep, schoolRep, rumorsSurv, conditions, conditionNote }

	-- Clear old rows
	for _, child in ipairs(statsBlock:GetChildren()) do
		if child:IsA("TextLabel") then child:Destroy() end
	end

	local y = 0
	local function row(lbl, val, color)
		makeStatRow(statsBlock, lbl, val, y, color)
		y = y + 26
	end

	row("GPA",               diplomaData.gpa,      Color3.fromRGB(60,120,60))
	row("Route",             diplomaData.route,     Color3.fromRGB(80,60,130))
	row("Conduct",           diplomaData.conduct,   Color3.fromRGB(80,80,80))
	row("School Rep",        diplomaData.schoolRep, Color3.fromRGB(60,80,140))
	row("Street Rep",        diplomaData.streetRep, Color3.fromRGB(140,60,60))
	row("Rumors Survived",   diplomaData.rumorsSurv,Color3.fromRGB(120,40,140))
	row("Days Elapsed",      diplomaData.dayCompleted, nil)
	if diplomaData.conditions and diplomaData.conditions ~= "" then
		row("Strange Conditions", diplomaData.conditions, Color3.fromRGB(140,40,180))
	end

	conditionNote.Text = diplomaData.conditionNote or ""

	-- Animate in
	parchment.Position = UDim2.new(0.5,-280,-0.6,0)
	gui.Enabled = true

	TweenService:Create(parchment,
		TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5,-280,0.5,-240) }
	):Play()
end)
