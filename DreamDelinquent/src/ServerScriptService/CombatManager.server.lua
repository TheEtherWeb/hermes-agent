-- Dream Delinquent: CombatManager (Server)
-- Handles PvP and PvE combat request validation and resolution.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules   = ReplicatedStorage:WaitForChild("Modules")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

local CombatSystem   = require(Modules.CombatSystem)
local StrongerStrangerSystem = require(Modules.StrongerStrangerSystem)
local ClubSystem     = require(Modules.ClubSystem)
local PlayerData     = require(Modules.PlayerData)

-- ─────────────────────────────────────────────────────────────────────────────
-- Active combat sessions: { combatId = { attacker, defender, ... } }
-- ─────────────────────────────────────────────────────────────────────────────
local activeSessions = {}   -- [combatId] = { a = Combatant, b = Combatant, ... }
local playerInCombat = {}   -- [userId]   = combatId

-- ─────────────────────────────────────────────────────────────────────────────
-- Remote references (created by GameManager)
-- ─────────────────────────────────────────────────────────────────────────────
local function waitRemote(name, class)
	local r = Remotes:WaitForChild(name, 10)
	if not r then
		if class == "Function" then
			r = Instance.new("RemoteFunction")
		else
			r = Instance.new("RemoteEvent")
		end
		r.Name = name
		r.Parent = Remotes
	end
	return r
end

local RE_CombatUpdate  = waitRemote("CombatUpdate")
local RE_CombatResult  = waitRemote("CombatResult")
local RE_MilestoneText = waitRemote("MilestoneText")
local RE_StateUpdate   = waitRemote("StateUpdate")

local RF_CombatAction  = waitRemote("CombatAction", "Function")
local RF_StartCombat   = waitRemote("StartCombat",  "Function")
local RF_FleeCombat    = waitRemote("FleeCombat",   "Function")

-- ─────────────────────────────────────────────────────────────────────────────
-- Shared playerData registry (set by GameManager via BindableFunction or direct ref)
-- We expose a helper modules rely on
-- ─────────────────────────────────────────────────────────────────────────────
local _activePlayers = {}  -- populated by reference from GameManager
-- Note: In production use a BindableEvent or shared ModuleScript for registry.
-- For prototype, GameManager exposes its table via a shared module.

local SharedRegistry = require(script.Parent:WaitForChild("SharedRegistry"))

-- ─────────────────────────────────────────────────────────────────────────────
-- Unique combat id
-- ─────────────────────────────────────────────────────────────────────────────
local function newCombatId()
	return tostring(tick()):gsub("%.", "")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Start a combat session (player vs player or player vs NPC)
-- ─────────────────────────────────────────────────────────────────────────────
local function startCombat(attackerPlayer, defenderPlayer, defenderNPCData)
	local attackerSession = SharedRegistry.get(attackerPlayer.UserId)
	if not attackerSession then return nil, "Attacker session missing." end
	if playerInCombat[attackerPlayer.UserId] then return nil, "Already in combat." end

	-- Determine fighting styles
	local function applyStyle(session)
		if not session.data.fightingStyle then
			session.data.fightingStyle = ClubSystem.GetFightingStyleFromHistory(session.data)
		end
	end
	applyStyle(attackerSession)

	local combatId = newCombatId()
	local a = CombatSystem.Combatant.new(attackerSession.data)
	local b

	if defenderPlayer then
		local defSession = SharedRegistry.get(defenderPlayer.UserId)
		if not defSession then return nil, "Defender session missing." end
		if playerInCombat[defenderPlayer.UserId] then return nil, "Defender busy." end
		applyStyle(defSession)
		b = CombatSystem.Combatant.new(defSession.data)
		playerInCombat[defenderPlayer.UserId] = combatId
		defSession.inCombat = true
	else
		-- NPC combatant
		b = CombatSystem.Combatant.new(defenderNPCData)
	end

	activeSessions[combatId] = {
		id        = combatId,
		a         = a,
		b         = b,
		aPlayer   = attackerPlayer,
		bPlayer   = defenderPlayer,
		bIsNPC    = defenderPlayer == nil,
		startTime = tick(),
		round     = 0,
	}
	playerInCombat[attackerPlayer.UserId] = combatId
	attackerSession.inCombat = true

	return combatId, nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Process a combat action
-- ─────────────────────────────────────────────────────────────────────────────
local function processCombatAction(player, action)
	local combatId = playerInCombat[player.UserId]
	if not combatId then return nil end
	local session = activeSessions[combatId]
	if not session then return nil end

	local isA = (session.aPlayer == player)
	local attacker = isA and session.a or session.b
	local defender = isA and session.b or session.a

	-- Validate stamina
	if attacker.stamina < 5 then
		return { result = "no_stamina" }
	end

	-- Stun check
	if attacker.stunDuration > 0 then
		return { result = "stunned" }
	end

	-- Get style bonus
	local styleBonus = CombatSystem.GetStyleMod(
		attacker.data.fightingStyle or "Brawler",
		action.moveType
	)

	-- Register parry
	if action.moveType == "parry" then
		local window = CombatSystem.GetParryWindow(attacker.data.fightingStyle or "Brawler")
		attacker.isParrying = true
		attacker.parryTimer = window
		-- Parry clears after window (handled in tick)
		return { result = "parry_attempt" }
	end

	-- Block toggle
	if action.moveType == "block" then
		attacker.isBlocking = action.value == true
		return { result = "block_toggle", blocking = attacker.isBlocking }
	end

	-- Record combo
	CombatSystem.RecordComboHit(attacker)
	local comboMult = CombatSystem.GetComboMultiplier(attacker.comboCount)
	local finalBonus = styleBonus * comboMult

	-- Apply hit
	local hitResult = CombatSystem.ApplyHit(attacker, defender, action.moveType, finalBonus)
	hitResult.comboCount = attacker.comboCount
	hitResult.attackerHp = attacker.health
	hitResult.defenderHp = defender.health
	hitResult.attackerSt = attacker.stamina
	hitResult.defenderSt = defender.stamina

	-- Check knockout
	if not defender:IsAlive() then
		hitResult.knockout = true
		-- Resolve fight
		local resolveResult = CombatSystem.ResolveFight(attacker, defender, StrongerStrangerSystem)
		hitResult.fightResult = resolveResult

		-- Clean up session
		playerInCombat[session.aPlayer.UserId] = nil
		if session.bPlayer then
			playerInCombat[session.bPlayer.UserId] = nil
		end
		activeSessions[combatId] = nil

		-- Broadcast final state
		local aSession = SharedRegistry.get(session.aPlayer.UserId)
		if aSession then
			RE_StateUpdate:FireClient(session.aPlayer, aSession.data:Serialize())
			if resolveResult.winner and resolveResult.winner.strongerResult then
				RE_MilestoneText:FireClient(session.aPlayer, {
					text = resolveResult.winner.strongerResult.milestone or "You feel stronger.",
					axis = "stronger",
					gain = resolveResult.winner.strongerResult.gain,
				})
			end
		end
		if session.bPlayer then
			local bSession = SharedRegistry.get(session.bPlayer.UserId)
			if bSession then
				RE_StateUpdate:FireClient(session.bPlayer, bSession.data:Serialize())
			end
		end
	end

	return hitResult
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Remote handlers
-- ─────────────────────────────────────────────────────────────────────────────
RF_StartCombat.OnServerInvoke = function(player, targetUserId, npcId)
	local defPlayer = nil
	if targetUserId then
		defPlayer = Players:GetPlayerByUserId(targetUserId)
	end

	-- TODO: NPC lookup by npcId for PvE fights
	local npcData = nil
	if npcId and not defPlayer then
		npcData = PlayerData.new("StreetKid")  -- placeholder NPC
		npcData.stats.Guts    = 15
		npcData.stats.Power   = 12
		npcData.stats.Athletics = 10
		npcData.fightingStyle = "Brawler"
	end

	local combatId, err = startCombat(player, defPlayer, npcData)
	return combatId, err
end

RF_CombatAction.OnServerInvoke = function(player, action)
	if type(action) ~= "table" then return nil end
	return processCombatAction(player, action)
end

RF_FleeCombat.OnServerInvoke = function(player)
	local combatId = playerInCombat[player.UserId]
	if not combatId then return false, "Not in combat." end
	local session = activeSessions[combatId]
	if not session then return false end

	-- Flee chance based on Athletics vs opponent's Insight
	local pSession = SharedRegistry.get(player.UserId)
	local fleeScore = pSession.data:GetStat("Athletics") + math.random(-5,5)
	local opponentData = (session.aPlayer == player) and session.b.data or session.a.data
	local catchScore = opponentData:GetStat("Insight") + math.random(-5, 5)

	if fleeScore > catchScore then
		playerInCombat[player.UserId] = nil
		if session.bPlayer then
			playerInCombat[session.bPlayer.UserId] = nil
		end
		activeSessions[combatId] = nil
		-- Small stranger gain for escaping a dangerous fight
		local sr = StrongerStrangerSystem.AwardStronger(pSession.data, "escape_chase")
		RE_StateUpdate:FireClient(player, pSession.data:Serialize())
		return true, "Escaped."
	else
		return false, "Couldn't get away."
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Tick: parry timer countdown
-- ─────────────────────────────────────────────────────────────────────────────
game:GetService("RunService").Heartbeat:Connect(function(dt)
	for _, session in pairs(activeSessions) do
		for _, combatant in pairs({ session.a, session.b }) do
			if combatant.parryTimer > 0 then
				combatant.parryTimer = combatant.parryTimer - dt
				if combatant.parryTimer <= 0 then
					combatant.isParrying = false
				end
			end
			if combatant.stunDuration > 0 then
				combatant.stunDuration = combatant.stunDuration - dt
			end
		end
	end
end)

print("[CombatManager] Initialised.")
