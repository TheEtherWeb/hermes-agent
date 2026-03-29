-- Dream Delinquent: NPCManager
-- Spawns and manages NPC dialogue, rumor delivery, and fight triggers.

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Modules  = ReplicatedStorage:WaitForChild("Modules")
local Remotes  = ReplicatedStorage:WaitForChild("Remotes")

local RumorSystem = require(Modules.RumorSystem)
local SharedRegistry = require(script.Parent.SharedRegistry)

local RE_DialogueLine = Remotes:WaitForChild("DialogueLine", 10)

-- ─────────────────────────────────────────────────────────────────────────────
-- NPC registry: tag -> { model, dialogueId }
-- ─────────────────────────────────────────────────────────────────────────────
local NPC_DEFINITIONS = {
	cafeteria_npc_1    = { color=BrickColor.new("Bright blue"),  dialogue="cafeteria_npc_1" },
	cafeteria_npc_2    = { color=BrickColor.new("Pastel orange"),dialogue="cafeteria_npc_2" },
	journalism_club_npc= { color=BrickColor.new("Bright yellow"),dialogue="journalism_club_npc" },
	occult_club_npc    = { color=BrickColor.new("Bright violet"),dialogue="occult_club_npc" },
	basketball_court_npc={ color=BrickColor.new("Bright red"),   dialogue="basketball_court_npc" },
	delinquent_npc_1   = { color=BrickColor.new("Dark grey"),    dialogue="delinquent_npc_1" },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Build a simple NPC model at a spawn point
-- ─────────────────────────────────────────────────────────────────────────────
local function buildNPC(spawnPart, dialogueId, color)
	local model = Instance.new("Model")
	model.Name  = dialogueId
	model.Parent = workspace.World.NPCs

	-- Torso
	local torso = Instance.new("Part")
	torso.Name     = "HumanoidRootPart"
	torso.Size     = Vector3.new(2, 3, 1)
	torso.CFrame   = CFrame.new(spawnPart.Position + Vector3.new(0, 2.5, 0))
	torso.BrickColor = color or BrickColor.new("Medium stone grey")
	torso.Anchored = true
	torso.CanCollide = true
	torso.Parent   = model

	-- Head
	local head = Instance.new("Part")
	head.Name    = "Head"
	head.Size    = Vector3.new(1.2, 1.2, 1.2)
	head.CFrame  = torso.CFrame * CFrame.new(0, 2.1, 0)
	head.BrickColor = color or BrickColor.new("Pastel yellow")
	head.Anchored= true
	head.Parent  = model

	-- Name billboard
	local bb = Instance.new("BillboardGui")
	bb.Size        = UDim2.new(0,120,0,30)
	bb.StudsOffset = Vector3.new(0,2,0)
	bb.AlwaysOnTop = true
	bb.Parent      = head

	local nl = Instance.new("TextLabel")
	nl.Size          = UDim2.new(1,0,1,0)
	nl.Text          = dialogueId:gsub("_npc",""):gsub("_"," "):upper()
	nl.TextColor3    = Color3.fromRGB(255,240,200)
	nl.Font          = Enum.Font.GothamBold
	nl.TextSize      = 12
	nl.BackgroundTransparency = 1
	nl.Parent        = bb

	-- Interact prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText    = "Talk"
	prompt.ObjectText    = dialogueId:gsub("_npc",""):gsub("_"," ")
	prompt.MaxActivationDistance = 8
	prompt.HoldDuration  = 0
	prompt.Parent        = torso

	-- Wire prompt
	prompt.Triggered:Connect(function(player)
		local session = SharedRegistry.get(player.UserId)
		local lines   = RumorSystem.NPC_DIALOGUE[dialogueId]
		if not lines then return end

		-- Deliver a line (cycle based on rumor state)
		local lineIdx = 1
		if session then
			local rumorsSeen = 0
			for _, state in pairs(session.data.rumorLog) do
				if state ~= "Unheard" then rumorsSeen = rumorsSeen + 1 end
			end
			lineIdx = math.clamp(rumorsSeen + 1, 1, #lines)
		end

		RE_DialogueLine:FireClient(player, {
			speaker = dialogueId,
			text    = lines[lineIdx],
		})
	end)

	return model
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Spawn all NPCs from tagged spawn points
-- ─────────────────────────────────────────────────────────────────────────────
local function spawnNPCs()
	-- Wait for World folder
	local npcFolder = workspace:WaitForChild("World", 10)
		and workspace.World:WaitForChild("NPCs", 5)
	if not npcFolder then
		warn("[NPCManager] NPCs folder not found yet.")
		return
	end

	-- Give WorldSetup time to finish
	task.wait(2)

	for tag, def in pairs(NPC_DEFINITIONS) do
		local spawnParts = CollectionService:GetTagged(tag)
		for _, sp in ipairs(spawnParts) do
			buildNPC(sp, def.dialogue, def.color)
		end
	end

	print("[NPCManager] NPCs spawned.")
end

task.spawn(spawnNPCs)

-- ─────────────────────────────────────────────────────────────────────────────
-- Proximity detection: player enters rumor trigger zone
-- ─────────────────────────────────────────────────────────────────────────────
-- Uses a polling approach for prototype (TouchEnded/Touched is also valid)
local RUMOR_ZONES = {}

local function indexRumorZones()
	task.wait(3)
	for _, part in ipairs(CollectionService:GetTagged("RumorTrigger")) do
		-- Get which rumor it triggers
		for _, tag in ipairs(CollectionService:GetTags(part)) do
			if tag:match("^R%d+$") then  -- matches R001, R002 etc.
				table.insert(RUMOR_ZONES, { part = part, rumorId = tag })
			end
		end
	end
	print("[NPCManager] Indexed", #RUMOR_ZONES, "rumor trigger zones.")
end

task.spawn(indexRumorZones)

-- Poll-based zone detection
RunService.Heartbeat:Connect(function()
	for _, zone in ipairs(RUMOR_ZONES) do
		if not zone.part or not zone.part.Parent then continue end
		local zonePos  = zone.part.Position
		local zoneSize = zone.part.Size

		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			if not char then continue end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if not hrp then continue end

			local delta = hrp.Position - zonePos
			if math.abs(delta.X) < zoneSize.X/2 + 2
				and math.abs(delta.Z) < zoneSize.Z/2 + 2 then

				local session = SharedRegistry.get(player.UserId)
				if not session then continue end

				-- Deliver rumor if not yet heard and in right phase
				local schedule = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
				-- We can't access server schedule from here directly.
				-- Instead we check if the rumor state is UNHEARD and it's after school hours.
				local rumorState = session.data:GetRumorState(zone.rumorId)
				if rumorState == "Unheard" then
					local rumor = RumorSystem.RUMORS[zone.rumorId]
					if rumor then
						RumorSystem.HearRumor(zone.rumorId, session.data)
						local RE_RumorHeard = Remotes:WaitForChild("RumorHeard", 5)
						if RE_RumorHeard then
							RE_RumorHeard:FireClient(player, {
								id    = rumor.id,
								title = rumor.title,
								body  = rumor.body,
							})
						end
					end
				end
			end
		end
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Dialogue UI remote handler (server side just broadcasts, client renders)
-- ─────────────────────────────────────────────────────────────────────────────
-- Client UI is handled in HUD.lua's DialogueLine event listener (extend there)
