-- Dream Delinquent: Class Minigame UI
-- Renders and handles the three minigame types: sequence, rhythm, keyword.
-- Activated by server when a class period begins and player is in class zone.

local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Modules     = ReplicatedStorage:WaitForChild("Modules")
local Remotes     = ReplicatedStorage:WaitForChild("Remotes")

local Constants   = require(Modules.Constants)
local ClassMinigame = require(Modules.ClassMinigame)

local RF_SubmitMinigame = Remotes:WaitForChild("SubmitMinigame", 10)
local RE_StartMinigame  = Remotes:WaitForChild("StartMinigame", 10)

-- ─────────────────────────────────────────────────────────────────────────────
-- Root ScreenGui
-- ─────────────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name           = "MinigameUI"
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled        = false
gui.Parent         = PlayerGui

-- Dark backdrop
local backdrop = Instance.new("Frame")
backdrop.Size             = UDim2.new(1,0,1,0)
backdrop.BackgroundColor3 = Color3.fromRGB(0,0,0)
backdrop.BackgroundTransparency = 0.5
backdrop.BorderSizePixel  = 0
backdrop.Parent           = gui

-- Main card
local card = Instance.new("Frame")
card.Size             = UDim2.new(0,500,0,340)
card.Position         = UDim2.new(0.5,-250,0.5,-170)
card.BackgroundColor3 = Constants.THEME.BG_PRIMARY
card.BorderSizePixel  = 0
card.Parent           = gui
local cCorner = Instance.new("UICorner"); cCorner.CornerRadius = UDim.new(0,14); cCorner.Parent = card
local cStroke = Instance.new("UIStroke"); cStroke.Color = Constants.THEME.PANEL_BORDER; cStroke.Thickness = 1.5; cStroke.Parent = card

-- Header
local subjectLabel = Instance.new("TextLabel")
subjectLabel.Size             = UDim2.new(1,-16,0,30)
subjectLabel.Position         = UDim2.new(0,8,0,8)
subjectLabel.Text             = "MATHEMATICS"
subjectLabel.TextColor3       = Constants.THEME.ACCENT_STRONGER
subjectLabel.Font             = Constants.FONT_TITLE
subjectLabel.TextSize         = 20
subjectLabel.BackgroundTransparency = 1
subjectLabel.TextXAlignment   = Enum.TextXAlignment.Left
subjectLabel.Parent           = card

-- Timer bar
local timerBg = Instance.new("Frame")
timerBg.Size          = UDim2.new(1,-16,0,6)
timerBg.Position      = UDim2.new(0,8,0,44)
timerBg.BackgroundColor3 = Constants.THEME.STAT_BAR_BG
timerBg.BorderSizePixel = 0
timerBg.Parent        = card
local timerCorner = Instance.new("UICorner"); timerCorner.CornerRadius = UDim.new(0,3); timerCorner.Parent = timerBg

local timerFill = Instance.new("Frame")
timerFill.Size          = UDim2.new(1,0,1,0)
timerFill.BackgroundColor3 = Constants.THEME.ACCENT_STRONGER
timerFill.BorderSizePixel = 0
timerFill.Parent        = timerBg
local tfCorner = Instance.new("UICorner"); tfCorner.CornerRadius = UDim.new(0,3); tfCorner.Parent = timerFill

-- Prompt area
local promptFrame = Instance.new("Frame")
promptFrame.Size          = UDim2.new(1,-16,0,200)
promptFrame.Position      = UDim2.new(0,8,0,58)
promptFrame.BackgroundTransparency = 1
promptFrame.Parent        = card

local promptLabel = Instance.new("TextLabel")
promptLabel.Size          = UDim2.new(1,0,0,40)
promptLabel.TextColor3    = Constants.THEME.TEXT_PRIMARY
promptLabel.Font          = Constants.FONT_BODY
promptLabel.TextSize      = 14
promptLabel.BackgroundTransparency = 1
promptLabel.TextWrapped   = true
promptLabel.TextXAlignment = Enum.TextXAlignment.Center
promptLabel.Parent        = promptFrame

-- Round counter
local roundLabel = Instance.new("TextLabel")
roundLabel.Size           = UDim2.new(0,80,0,20)
roundLabel.Position       = UDim2.new(1,-88,0,8)
roundLabel.Text           = "1/5"
roundLabel.TextColor3     = Constants.THEME.TEXT_SECONDARY
roundLabel.Font           = Constants.FONT_MONO
roundLabel.TextSize       = 12
roundLabel.BackgroundTransparency = 1
roundLabel.TextXAlignment = Enum.TextXAlignment.Right
roundLabel.Parent         = card

-- Score display
local scoreLabel = Instance.new("TextLabel")
scoreLabel.Size           = UDim2.new(0,80,0,20)
scoreLabel.Position       = UDim2.new(1,-88,0,30)
scoreLabel.Text           = "Score: 0"
scoreLabel.TextColor3     = Constants.THEME.ACCENT_STRONGER
scoreLabel.Font           = Constants.FONT_MONO
scoreLabel.TextSize       = 12
scoreLabel.BackgroundTransparency = 1
scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
scoreLabel.Parent         = card

-- ─────────────────────────────────────────────────────────────────────────────
-- SEQUENCE MINIGAME (Math)
-- Buttons for numeric answers
-- ─────────────────────────────────────────────────────────────────────────────
local sequenceContainer = Instance.new("Frame")
sequenceContainer.Size  = UDim2.new(1,0,1,0)
sequenceContainer.BackgroundTransparency = 1
sequenceContainer.Parent = promptFrame
sequenceContainer.Visible = false

local seqDisplay = Instance.new("TextLabel")
seqDisplay.Size           = UDim2.new(1,0,0,50)
seqDisplay.Position       = UDim2.new(0,0,0,0)
seqDisplay.Text           = "2, 4, 6, 8, ?"
seqDisplay.TextColor3     = Constants.THEME.TEXT_HIGHLIGHT
seqDisplay.Font           = Constants.FONT_TITLE
seqDisplay.TextSize       = 32
seqDisplay.BackgroundTransparency = 1
seqDisplay.TextXAlignment = Enum.TextXAlignment.Center
seqDisplay.Parent         = sequenceContainer

-- Number buttons 0-9
local numPad = Instance.new("Frame")
numPad.Size  = UDim2.new(0,240,0,100)
numPad.Position = UDim2.new(0.5,-120,0,60)
numPad.BackgroundTransparency = 1
numPad.Parent = sequenceContainer

local numLayout = Instance.new("UIGridLayout")
numLayout.CellSize    = UDim2.new(0,44,0,40)
numLayout.CellPadding = UDim2.new(0,6,0,6)
numLayout.Parent      = numPad

local numButtons = {}
for n = 0, 9 do
	local nb = Instance.new("TextButton")
	nb.Text           = tostring(n)
	nb.BackgroundColor3 = Constants.THEME.BG_SECONDARY
	nb.TextColor3     = Constants.THEME.TEXT_PRIMARY
	nb.Font           = Constants.FONT_TITLE
	nb.TextSize       = 18
	nb.BorderSizePixel= 0
	nb.AutoButtonColor= false
	nb.Parent         = numPad
	local nc = Instance.new("UICorner"); nc.CornerRadius = UDim.new(0,6); nc.Parent = nb
	numButtons[n] = nb
end

-- Current typed answer
local typedAnswer = ""
local answerLabel = Instance.new("TextLabel")
answerLabel.Size          = UDim2.new(0,200,0,30)
answerLabel.Position      = UDim2.new(0.5,-100,0,170)
answerLabel.Text          = "_ _ _"
answerLabel.TextColor3    = Constants.THEME.TEXT_HIGHLIGHT
answerLabel.Font          = Constants.FONT_TITLE
answerLabel.TextSize      = 22
answerLabel.BackgroundTransparency = 1
answerLabel.TextXAlignment = Enum.TextXAlignment.Center
answerLabel.Parent        = sequenceContainer

-- ─────────────────────────────────────────────────────────────────────────────
-- RHYTHM MINIGAME (Gym / Music)
-- Horizontal lane with beat markers
-- ─────────────────────────────────────────────────────────────────────────────
local rhythmContainer = Instance.new("Frame")
rhythmContainer.Size  = UDim2.new(1,0,1,0)
rhythmContainer.BackgroundTransparency = 1
rhythmContainer.Parent = promptFrame
rhythmContainer.Visible = false

local rhythmLane = Instance.new("Frame")
rhythmLane.Size          = UDim2.new(1,-20,0,60)
rhythmLane.Position      = UDim2.new(0,10,0,40)
rhythmLane.BackgroundColor3 = Color3.fromRGB(20,18,32)
rhythmLane.BorderSizePixel = 0
rhythmLane.Parent        = rhythmContainer
local rlCorner = Instance.new("UICorner"); rlCorner.CornerRadius = UDim.new(0,8); rlCorner.Parent = rhythmLane

-- Hit zone marker
local hitZone = Instance.new("Frame")
hitZone.Size          = UDim2.new(0,8,1,0)
hitZone.Position      = UDim2.new(0.15,0,0,0)
hitZone.BackgroundColor3 = Color3.fromRGB(255,220,60)
hitZone.BorderSizePixel = 0
hitZone.Parent        = rhythmLane
local hzCorner = Instance.new("UICorner"); hzCorner.CornerRadius = UDim.new(0,4); hzCorner.Parent = hitZone

local rhythmInstruction = Instance.new("TextLabel")
rhythmInstruction.Size          = UDim2.new(1,0,0,30)
rhythmInstruction.Position      = UDim2.new(0,0,0,110)
rhythmInstruction.Text          = "Press SPACE when the beat hits the zone"
rhythmInstruction.TextColor3    = Constants.THEME.TEXT_SECONDARY
rhythmInstruction.Font          = Constants.FONT_BODY
rhythmInstruction.TextSize      = 13
rhythmInstruction.BackgroundTransparency = 1
rhythmInstruction.TextXAlignment = Enum.TextXAlignment.Center
rhythmInstruction.Parent        = rhythmContainer

-- Beat markers (created per prompt)
local beatMarkers = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Game state
-- ─────────────────────────────────────────────────────────────────────────────
local activeGame = nil   -- { type, rounds, currentRound, score, ... }
local timerConnection = nil

local function endGame()
	if timerConnection then timerConnection:Disconnect(); timerConnection = nil end
	if not activeGame then return end

	local finalScore = math.clamp(activeGame.score, 0, 100)
	gui.Enabled = false

	-- Submit to server
	RF_SubmitMinigame:InvokeServer(activeGame.subjectId, finalScore)
	activeGame = nil
end

local function nextRound()
	if not activeGame then return end
	activeGame.currentRound = activeGame.currentRound + 1
	roundLabel.Text = activeGame.currentRound .. "/" .. activeGame.totalRounds

	if activeGame.currentRound > activeGame.totalRounds then
		endGame()
		return
	end

	-- Reset timer
	TweenService:Create(timerFill,
		TweenInfo.new(activeGame.roundTime, Enum.EasingStyle.Linear),
		{ Size = UDim2.new(0,0,1,0) }
	):Play()

	if timerConnection then timerConnection:Disconnect() end
	timerConnection = task.delay(activeGame.roundTime, function()
		-- Time ran out on this round: no score for it
		nextRound()
	end)
end

local function startSequenceGame(prompt, gameData)
	sequenceContainer.Visible = true
	rhythmContainer.Visible   = false
	promptLabel.Text          = "What comes next in the sequence?"

	seqDisplay.Text = table.concat(prompt.display, ", ") .. ", ?"
	typedAnswer = ""
	answerLabel.Text = "_ _ _"

	-- Wire number buttons
	for n, btn in pairs(numButtons) do
		btn.MouseButton1Click:Connect(function()
			if #typedAnswer < 4 then
				typedAnswer = typedAnswer .. tostring(n)
				answerLabel.Text = typedAnswer

				-- Check answer
				local correct = tonumber(typedAnswer) == prompt.answer
				if correct then
					activeGame.score = activeGame.score + (100 / activeGame.totalRounds)
					answerLabel.TextColor3 = Color3.fromRGB(80,220,80)
					task.delay(0.4, function()
						answerLabel.TextColor3 = Constants.THEME.TEXT_HIGHLIGHT
						nextRound()
					end)
				elseif #typedAnswer >= 4 then
					answerLabel.TextColor3 = Color3.fromRGB(220,80,80)
					task.delay(0.4, function()
						typedAnswer = ""
						answerLabel.Text = "_ _ _"
						answerLabel.TextColor3 = Constants.THEME.TEXT_HIGHLIGHT
					end)
				end
			end
		end)
	end
end

local function startRhythmGame(prompt, gameData)
	rhythmContainer.Visible = true
	sequenceContainer.Visible = false
	promptLabel.Text = "Keep the rhythm. Press SPACE."

	-- Clear old markers
	for _, m in ipairs(beatMarkers) do m:Destroy() end
	beatMarkers = {}

	-- Create beat markers
	local laneWidth = rhythmLane.AbsoluteSize.X
	for i, beat in ipairs(prompt.pattern) do
		if beat == 1 then
			local marker = Instance.new("Frame")
			marker.Size          = UDim2.new(0,20,0.8,0)
			marker.Position      = UDim2.new(1 + (i-1) * 0.12, 0, 0.1, 0)
			marker.BackgroundColor3 = Constants.THEME.ACCENT_STRANGER
			marker.BorderSizePixel = 0
			marker.Parent        = rhythmLane
			local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0,4); mc.Parent = marker
			table.insert(beatMarkers, marker)

			-- Animate across lane
			task.spawn(function()
				task.wait((i-1) * 0.5)
				TweenService:Create(marker,
					TweenInfo.new(0.5 * #prompt.pattern, Enum.EasingStyle.Linear),
					{ Position = UDim2.new(-0.1, 0, 0.1, 0) }
				):Play()
			end)
		end
	end

	-- Space bar handler
	local spaceConn
	local hitCount = 0
	spaceConn = UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode ~= Enum.KeyCode.Space then return end

		-- Check proximity to hit zone
		local closest = math.huge
		for _, m in ipairs(beatMarkers) do
			local mX = m.AbsolutePosition.X
			local zX = hitZone.AbsolutePosition.X
			closest = math.min(closest, math.abs(mX - zX))
		end

		if closest < 25 then
			hitCount = hitCount + 1
			activeGame.score = (hitCount / #beatMarkers) * 100
			scoreLabel.Text = ("Score: %d"):format(math.floor(activeGame.score))
			-- Flash hit zone
			TweenService:Create(hitZone,
				TweenInfo.new(0.1),
				{ BackgroundColor3 = Color3.fromRGB(80,220,80) }
			):Play()
			task.delay(0.15, function()
				TweenService:Create(hitZone,
					TweenInfo.new(0.1),
					{ BackgroundColor3 = Color3.fromRGB(255,220,60) }
				):Play()
			end)
		end
	end)

	task.delay(gameData.roundTime, function()
		if spaceConn then spaceConn:Disconnect() end
		nextRound()
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Remote: StartMinigame fires from server when class begins
-- ─────────────────────────────────────────────────────────────────────────────
RE_StartMinigame.OnClientEvent:Connect(function(data)
	-- data = { subjectId, prompt, gameType, roundTime, totalRounds }
	local gameDef = ClassMinigame.GAMES[data.subjectId]
	if not gameDef then return end

	gui.Enabled = true

	subjectLabel.Text = gameDef.name:upper()
	promptLabel.Text  = gameDef.description

	activeGame = {
		subjectId    = data.subjectId,
		gameType     = gameDef.gameType,
		score        = 0,
		currentRound = 1,
		totalRounds  = gameDef.rounds,
		roundTime    = gameDef.timePerRound,
	}

	roundLabel.Text = "1/" .. gameDef.rounds
	scoreLabel.Text = "Score: 0"

	-- Start timer
	TweenService:Create(timerFill,
		TweenInfo.new(gameDef.timePerRound, Enum.EasingStyle.Linear),
		{ Size = UDim2.new(0,0,1,0) }
	):Play()

	if gameDef.gameType == "sequence" then
		local prompt = ClassMinigame.GeneratePrompt(data.subjectId, 1)
		startSequenceGame(prompt, gameDef)
	elseif gameDef.gameType == "rhythm" then
		local prompt = ClassMinigame.GeneratePrompt(data.subjectId, 1)
		startRhythmGame(prompt, gameDef)
	else
		-- Generic: just a timer, award pass on completion
		promptLabel.Text = gameDef.description
		timerConnection  = task.delay(gameDef.timePerRound * gameDef.rounds, function()
			activeGame.score = 70  -- default pass
			endGame()
		end)
	end
end)
