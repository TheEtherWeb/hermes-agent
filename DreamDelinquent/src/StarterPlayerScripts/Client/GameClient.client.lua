-- Dream Delinquent: GameClient
-- Main client controller. Connects UI, input, and remote events.

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local Modules   = ReplicatedStorage:WaitForChild("Modules")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

local Constants = require(Modules.Constants)
local ParkourSystem = require(Modules.ParkourSystem)

-- ─────────────────────────────────────────────────────────────────────────────
-- Remote references
-- ─────────────────────────────────────────────────────────────────────────────
local function waitR(name)  return Remotes:WaitForChild(name, 15) end
local function waitF(name)  return Remotes:WaitForChild(name, 15) end

local RE_StateUpdate      = waitR("StateUpdate")
local RE_StrongerStranger = waitR("StrongerStranger")
local RE_RumorHeard       = waitR("RumorHeard")
local RE_RumorResult      = waitR("RumorResult")
local RE_PhaseChange      = waitR("PhaseChange")
local RE_CombatResult     = waitR("CombatResult")
local RE_ClubResult       = waitR("ClubResult")
local RE_ClassResult      = waitR("ClassResult")
local RE_DialogueLine     = waitR("DialogueLine")
local RE_PortraitState    = waitR("PortraitState")
local RE_MilestoneText    = waitR("MilestoneText")
local RE_ParkourResult    = waitR("ParkourResult")

local RF_GetPlayerState   = waitF("GetPlayerState")
local RF_JoinClub         = waitF("JoinClub")
local RF_SubmitMinigame   = waitF("SubmitMinigame")
local RF_PursueRumor      = waitF("PursueRumor")
local RF_CombatAction     = waitF("CombatAction")
local RF_StartCombat      = waitF("StartCombat")
local RF_FleeCombat       = waitF("FleeCombat")

-- ─────────────────────────────────────────────────────────────────────────────
-- Local state cache
-- ─────────────────────────────────────────────────────────────────────────────
local playerState    = nil
local currentPhase   = nil
local inCombat       = false
local combatId       = nil
local pendingRumors  = {}   -- { rumorData }

-- ─────────────────────────────────────────────────────────────────────────────
-- UI references (set after HUD loads)
-- ─────────────────────────────────────────────────────────────────────────────
local HUD            = nil
local MainHUD        = nil

-- Wait for GUI to load
local function waitForHUD()
	HUD     = PlayerGui:WaitForChild("HUD", 10)
	if HUD then
		MainHUD = require(HUD:WaitForChild("HUDController"))
	end
end

task.spawn(waitForHUD)

-- ─────────────────────────────────────────────────────────────────────────────
-- State update handler
-- ─────────────────────────────────────────────────────────────────────────────
RE_StateUpdate.OnClientEvent:Connect(function(data)
	playerState = data
	if MainHUD then
		MainHUD.UpdateStats(data)
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Phase change handler (lighting + UI phase indicator)
-- ─────────────────────────────────────────────────────────────────────────────
RE_PhaseChange.OnClientEvent:Connect(function(phaseData)
	currentPhase = phaseData.phase

	-- Update lighting
	local lighting = game:GetService("Lighting")
	if phaseData.lighting then
		local tInfo = TweenInfo.new(3, Enum.EasingStyle.Sine)
		local tween = TweenService:Create(lighting, tInfo, {
			Ambient = phaseData.lighting.ambient,
			Brightness = phaseData.lighting.brightness,
		})
		tween:Play()
	end

	if MainHUD then
		MainHUD.UpdatePhase(phaseData)
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Milestone text display
-- ─────────────────────────────────────────────────────────────────────────────
RE_MilestoneText.OnClientEvent:Connect(function(milestoneData)
	if MainHUD then
		MainHUD.ShowMilestone(milestoneData)
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Portrait state
-- ─────────────────────────────────────────────────────────────────────────────
RE_PortraitState.OnClientEvent:Connect(function(portraitState)
	if MainHUD then
		MainHUD.UpdatePortrait(portraitState)
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Rumor heard: show notification
-- ─────────────────────────────────────────────────────────────────────────────
RE_RumorHeard.OnClientEvent:Connect(function(rumorData)
	table.insert(pendingRumors, rumorData)
	if MainHUD then
		MainHUD.ShowRumorNotice(rumorData)
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Rumor result: outcome screen
-- ─────────────────────────────────────────────────────────────────────────────
RE_RumorResult.OnClientEvent:Connect(function(result)
	if MainHUD then
		MainHUD.ShowRumorResult(result)
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Club session result
-- ─────────────────────────────────────────────────────────────────────────────
RE_ClubResult.OnClientEvent:Connect(function(result)
	if MainHUD then
		MainHUD.ShowClubResult(result)
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Class minigame result
-- ─────────────────────────────────────────────────────────────────────────────
RE_ClassResult.OnClientEvent:Connect(function(result)
	if MainHUD then
		MainHUD.ShowClassResult(result)
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Combat result
-- ─────────────────────────────────────────────────────────────────────────────
RE_CombatResult.OnClientEvent:Connect(function(result)
	inCombat = false
	if MainHUD then
		MainHUD.ShowCombatResult(result)
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Parkour input handling
-- ─────────────────────────────────────────────────────────────────────────────
local character    = nil
local humanoid     = nil
local rootPart     = nil

local function onCharacterAdded(char)
	character = char
	humanoid  = char:WaitForChild("Humanoid")
	rootPart  = char:WaitForChild("HumanoidRootPart")

	-- Monitor for vault / wall-run / slide triggers from workspace geometry
	-- (geometry uses CollectionService tags: "VaultObject", "WallRunSurface", etc.)
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
if LocalPlayer.Character then onCharacterAdded(LocalPlayer.Character) end

-- Key bindings for parkour
local PARKOUR_KEYS = {
	[Enum.KeyCode.Space] = "Jump",
	[Enum.KeyCode.Q]     = "Vault",
	[Enum.KeyCode.LeftShift] = "Sprint",
	[Enum.KeyCode.C]     = "Slide",
	[Enum.KeyCode.F]     = "Interact",   -- pickup rumor / enter area
	[Enum.KeyCode.R]     = "Roll",
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not character or not humanoid then return end

	local action = PARKOUR_KEYS[input.KeyCode]
	if not action then return end

	if action == "Vault" and humanoid.MoveDirection.Magnitude > 0.1 then
		-- Client-side: visually attempt vault; server validates
		-- (In full build: Raycast forward for obstacle, send attempt to server)
		RE_ParkourResult:FireServer({ moveType = "Vault" })
	elseif action == "Slide" and humanoid.MoveDirection.Magnitude > 0.5 then
		RE_ParkourResult:FireServer({ moveType = "Slide" })
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Combat input
-- ─────────────────────────────────────────────────────────────────────────────
local COMBAT_KEYS = {
	[Enum.KeyCode.Z] = { moveType = "light" },
	[Enum.KeyCode.X] = { moveType = "heavy" },
	[Enum.KeyCode.C] = { moveType = "grab"  },
	[Enum.KeyCode.V] = { moveType = "parry" },
	[Enum.KeyCode.LeftShift] = { moveType = "block", value = true },
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not inCombat then return end

	local action = COMBAT_KEYS[input.KeyCode]
	if action then
		RF_CombatAction:InvokeServer(action)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if not inCombat then return end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		RF_CombatAction:InvokeServer({ moveType = "block", value = false })
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API for HUD to call actions
-- ─────────────────────────────────────────────────────────────────────────────
local GameClient = {}

function GameClient.JoinClub(clubId)
	local ok, msg = RF_JoinClub:InvokeServer(clubId)
	return ok, msg
end

function GameClient.SubmitMinigame(subjectId, score)
	return RF_SubmitMinigame:InvokeServer(subjectId, score)
end

function GameClient.PursueRumor(rumorId)
	return RF_PursueRumor:InvokeServer(rumorId)
end

function GameClient.GetPendingRumors()
	return pendingRumors
end

function GameClient.GetPlayerState()
	return playerState
end

function GameClient.GetCurrentPhase()
	return currentPhase
end

-- Expose globally for HUD scripts
_G.GameClient = GameClient

print("[GameClient] Initialised.")
