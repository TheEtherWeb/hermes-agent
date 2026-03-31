-- Dream Delinquent: GameManager (Server)
-- Master server script. Initialises all sub-systems and manages player lifecycle.

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local DataStoreService= game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local PlayerData   = require(Modules.PlayerData)
local ScheduleSystem  = require(Modules.ScheduleSystem)
local StrongerStrangerSystem = require(Modules.StrongerStrangerSystem)
local RumorSystem     = require(Modules.RumorSystem)
local CombatSystem    = require(Modules.CombatSystem)
local ClubSystem      = require(Modules.ClubSystem)
local GradeSystem     = require(Modules.GradeSystem)
local ClassMinigame   = require(Modules.ClassMinigame)
local PressureArts    = require(Modules.PressureArts)

local SharedRegistry  = require(script.Parent.SharedRegistry)

-- Remote events
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getRemote(name)
	local r = Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = Remotes
	end
	return r
end

local function getFunction(name)
	local r = Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteFunction")
		r.Name = name
		r.Parent = Remotes
	end
	return r
end

-- Events
local RE_StateUpdate       = getRemote("StateUpdate")
local RE_StrongerStranger  = getRemote("StrongerStranger")
local RE_RumorHeard        = getRemote("RumorHeard")
local RE_RumorResult       = getRemote("RumorResult")
local RE_PhaseChange       = getRemote("PhaseChange")
local RE_CombatResult      = getRemote("CombatResult")
local RE_ClubResult        = getRemote("ClubResult")
local RE_ClassResult       = getRemote("ClassResult")
local RE_DialogueLine      = getRemote("DialogueLine")
local RE_PortraitState     = getRemote("PortraitState")
local RE_MilestoneText     = getRemote("MilestoneText")
local RE_ParkourResult     = getRemote("ParkourResult")
local RE_StartMinigame     = getRemote("StartMinigame")
local RE_ShowDiploma       = getRemote("ShowDiploma")
local RE_PressureArtUnlocked = getRemote("PressureArtUnlocked")

-- Functions
local RF_GetPlayerState    = getFunction("GetPlayerState")
local RF_JoinClub          = getFunction("JoinClub")
local RF_SubmitMinigame    = getFunction("SubmitMinigame")
local RF_PursueRumor       = getFunction("PursueRumor")
local RF_ExamResult        = getFunction("ExamResult")
local RF_SetBackground     = getFunction("SetBackground")
local RF_StartCombat       = getFunction("StartCombat")
local RF_CombatAction      = getFunction("CombatAction")
local RF_FleeCombat        = getFunction("FleeCombat")

-- DataStore
local DataStore = DataStoreService:GetDataStore("DreamDelinquent_v1")

-- ─────────────────────────────────────────────────────────────────────────────
-- Shared schedule
-- ─────────────────────────────────────────────────────────────────────────────
local schedule = ScheduleSystem.new()

-- ─────────────────────────────────────────────────────────────────────────────
-- Helper: broadcast milestone text and portrait update
-- ─────────────────────────────────────────────────────────────────────────────
local function broadcastMilestone(player, data, strongerResult, strangerResult)
	if strongerResult and strongerResult.milestone then
		RE_MilestoneText:FireClient(player, {
			text = strongerResult.milestone,
			axis = "stronger",
			gain = strongerResult.gain,
		})
	end
	if strangerResult and strangerResult.milestone then
		RE_MilestoneText:FireClient(player, {
			text            = strangerResult.milestone,
			axis            = "stranger",
			gain            = strangerResult.gain,
			newCondition    = strangerResult.newCondition,
		})
	end
	-- Update portrait
	local portraitState = StrongerStrangerSystem.GetPortraitState(data)
	RE_PortraitState:FireClient(player, portraitState)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Helper: scan for newly unlockable Pressure Arts and notify client
-- ─────────────────────────────────────────────────────────────────────────────
local function scanAndNotifyArts(player, session)
	local eligible = PressureArts.ScanForUnlocks(session.data)
	if #eligible == 0 then return end

	local unlocked = {}
	for _, artId in ipairs(eligible) do
		local ok = PressureArts.TryUnlock(artId, session.data)
		if ok then
			local artDef = PressureArts.ARTS[artId]
			table.insert(unlocked, {
				id   = artId,
				name = artDef and artDef.name or artId,
			})
		end
	end

	if #unlocked > 0 then
		RE_PressureArtUnlocked:FireClient(player, unlocked)
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Schedule phase change handler
-- ─────────────────────────────────────────────────────────────────────────────
schedule:OnPhaseChange(function(newPhase, prevPhase, day)
	-- Broadcast to all clients
	for _, player in ipairs(Players:GetPlayers()) do
		RE_PhaseChange:FireClient(player, {
			phase   = newPhase,
			day     = day,
			isNight = schedule:IsNight(),
			lighting= schedule:GetLightingProfile(),
		})
	end

	-- School period attendance
	if ScheduleSystem.SCHOOL_PHASES[newPhase] then
		for _, player in ipairs(Players:GetPlayers()) do
			local session = SharedRegistry.get(player.UserId)
			if not session then continue end
			session.data.attendance = session.data.attendance + 1
			session.data:AddCredits(1)

			-- Trigger class minigame if in school zone
			local subject = schedule:GetCurrentSubject()
			if subject then
				local prompt = ClassMinigame.GeneratePrompt(subject, 1)
				RE_StartMinigame:FireClient(player, {
					subjectId  = subject,
					prompt     = prompt,
					gameType   = ClassMinigame.GAMES[subject] and ClassMinigame.GAMES[subject].gameType or "generic",
					roundTime  = ClassMinigame.GAMES[subject] and ClassMinigame.GAMES[subject].timePerRound or 15,
					totalRounds= ClassMinigame.GAMES[subject] and ClassMinigame.GAMES[subject].rounds or 1,
				})
			end
		end
	end

	-- AfterSchool: auto-run club sessions
	if newPhase == "AfterSchool" then
		for _, player in ipairs(Players:GetPlayers()) do
			local session = SharedRegistry.get(player.UserId)
			if not session or not session.data.activeClubId then continue end

			local result = ClubSystem.RunSession(session.data.activeClubId, session.data)
			if result then
				RE_ClubResult:FireClient(player, result)
				broadcastMilestone(player, session.data, result.strongerResult, result.strangerResult)
				scanAndNotifyArts(player, session)
				RE_StateUpdate:FireClient(player, session.data:Serialize())
			end
		end
	end

	-- Rumor delivery on phase change
	for _, player in ipairs(Players:GetPlayers()) do
		local session = SharedRegistry.get(player.UserId)
		if not session then continue end
		local rumors = RumorSystem.GetHearableRumors(newPhase, session.data)
		for _, rumor in ipairs(rumors) do
			RumorSystem.HearRumor(rumor.id, session.data)
			RE_RumorHeard:FireClient(player, {
				id    = rumor.id,
				title = rumor.title,
				body  = rumor.body,
			})
		end
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Player join
-- ─────────────────────────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	local userId = player.UserId

	local saved = nil
	pcall(function()
		saved = DataStore:GetAsync("player_" .. userId)
	end)

	local data
	if saved then
		data = PlayerData.Deserialize(saved)
	else
		data = PlayerData.new("Transfer")
	end

	local session = {
		data      = data,
		combatant = CombatSystem.Combatant.new(data),
		inCombat  = false,
	}
	SharedRegistry.set(userId, session)

	RE_StateUpdate:FireClient(player, data:Serialize())
	RE_PortraitState:FireClient(player, StrongerStrangerSystem.GetPortraitState(data))
	RE_PhaseChange:FireClient(player, {
		phase   = schedule.currentPhase,
		day     = schedule.currentDay,
		isNight = schedule:IsNight(),
		lighting= schedule:GetLightingProfile(),
	})
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Player leave: save
-- ─────────────────────────────────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
	local session = SharedRegistry.get(player.UserId)
	if not session then return end

	pcall(function()
		DataStore:SetAsync("player_" .. player.UserId, session.data:Serialize())
	end)

	SharedRegistry.remove(player.UserId)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Remote: GetPlayerState
-- ─────────────────────────────────────────────────────────────────────────────
RF_GetPlayerState.OnServerInvoke = function(player)
	local session = SharedRegistry.get(player.UserId)
	if not session then return nil end
	return session.data:Serialize()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Remote: SetBackground (first-time character creation)
-- ─────────────────────────────────────────────────────────────────────────────
RF_SetBackground.OnServerInvoke = function(player, backgroundId)
	local session = SharedRegistry.get(player.UserId)
	if not session then return false end

	-- Validate
	local valid = false
	for _, bg in ipairs(require(Modules.Constants).BACKGROUNDS) do
		if bg.id == backgroundId then valid = true; break end
	end
	if not valid then return false end

	-- Apply fresh with chosen background
	session.data = PlayerData.new(backgroundId)
	RE_StateUpdate:FireClient(player, session.data:Serialize())
	return true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Remote: JoinClub
-- ─────────────────────────────────────────────────────────────────────────────
RF_JoinClub.OnServerInvoke = function(player, clubId)
	local session = SharedRegistry.get(player.UserId)
	if not session then return false, "Session not found." end

	local ok, msg = ClubSystem.TryJoin(clubId, session.data)
	if ok then
		RE_StateUpdate:FireClient(player, session.data:Serialize())
	end
	return ok, msg
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Remote: SubmitMinigame
-- ─────────────────────────────────────────────────────────────────────────────
RF_SubmitMinigame.OnServerInvoke = function(player, subjectId, score)
	local session = SharedRegistry.get(player.UserId)
	if not session then return nil end
	if type(score) ~= "number" or score < 0 or score > 100 then return nil end

	local result = ClassMinigame.ProcessResult(subjectId, score, session.data)
	if result then
		RE_ClassResult:FireClient(player, result)
		broadcastMilestone(player, session.data, result.strongerResult, nil)
		scanAndNotifyArts(player, session)
		RE_StateUpdate:FireClient(player, session.data:Serialize())
	end
	return result
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Remote: PursueRumor
-- ─────────────────────────────────────────────────────────────────────────────
RF_PursueRumor.OnServerInvoke = function(player, rumorId)
	local session = SharedRegistry.get(player.UserId)
	if not session then return nil end

	local outcome = RumorSystem.PursueRumor(rumorId, session.data)
	if not outcome then return nil end

	local strangerResult = nil
	if outcome.strangerAction then
		strangerResult = StrongerStrangerSystem.AwardStranger(session.data, outcome.strangerAction)
	end
	if outcome.strongerAction then
		StrongerStrangerSystem.AwardStronger(session.data, outcome.strongerAction)
	end

	RumorSystem.ResolveRumor(rumorId, outcome.survived, session.data)

	if outcome.agencyAlert then
		session.data.agencyFlag = true
	end

	RE_RumorResult:FireClient(player, {
		rumorId    = rumorId,
		survived   = outcome.survived,
		isTrue     = outcome.isTrue,
		consequence= outcome.consequence,
		nextRumorId= outcome.nextRumorId,
	})
	broadcastMilestone(player, session.data, nil, strangerResult)
	scanAndNotifyArts(player, session)
	RE_StateUpdate:FireClient(player, session.data:Serialize())

	return outcome
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Remote: ExamResult
-- ─────────────────────────────────────────────────────────────────────────────
RF_ExamResult.OnServerInvoke = function(player, examScore)
	local session = SharedRegistry.get(player.UserId)
	if not session then return nil end
	if type(examScore) ~= "number" or examScore < 0 or examScore > 100 then return nil end

	local ok, exam = GradeSystem.IsEligible(session.data)
	if not ok then return { error = exam } end

	local result = GradeSystem.ProcessExamResult(examScore, session.data)

	-- Show diploma if graduated
	if result and result.diplomaAwarded then
		local diplomaData = GradeSystem.GenerateDiploma(session.data)
		RE_ShowDiploma:FireClient(player, diplomaData)
	end

	RE_StateUpdate:FireClient(player, session.data:Serialize())
	return result
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Remote: ParkourResult (client reports move, server validates + awards)
-- ─────────────────────────────────────────────────────────────────────────────
RE_ParkourResult.OnServerEvent:Connect(function(player, moveData)
	local session = SharedRegistry.get(player.UserId)
	if not session then return end
	if type(moveData) ~= "table" then return end

	local ParkourSystem = require(Modules.ParkourSystem)
	local result = ParkourSystem.ExecuteMove(
		moveData.moveType,
		session.data,
		100, 100   -- stamina values from client; full system uses character state
	)

	if result and result.success then
		if result.statGain then
			session.data:GainStat(result.statGain.stat, result.statGain.amount)
		end
		if result.strongerResult then
			broadcastMilestone(player, session.data, result.strongerResult, nil)
		end
		scanAndNotifyArts(player, session)
		RE_StateUpdate:FireClient(player, session.data:Serialize())
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Remote: StartCombat
-- ─────────────────────────────────────────────────────────────────────────────
RF_StartCombat.OnServerInvoke = function(player, targetUserId, npcId)
	local session = SharedRegistry.get(player.UserId)
	if not session then return nil, "No session" end

	-- NPC placeholder data
	local npcData = PlayerData.new("StreetKid")
	npcData.stats.Guts      = 15 + (npcId == "AlleyKing" and 20 or 0)
	npcData.stats.Power     = 12 + (npcId == "AlleyKing" and 15 or 0)
	npcData.stats.Athletics = 10
	npcData.fightingStyle   = (npcId == "AlleyKing") and "Brawler" or "Brawler"

	session.inCombat   = true
	session.combatant  = CombatSystem.Combatant.new(session.data)
	session.enemyCombatant = CombatSystem.Combatant.new(npcData)
	session.combatId   = tostring(tick())

	return session.combatId, nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Remote: CombatAction
-- ─────────────────────────────────────────────────────────────────────────────
RF_CombatAction.OnServerInvoke = function(player, action)
	local session = SharedRegistry.get(player.UserId)
	if not session or not session.inCombat then return nil end
	if type(action) ~= "table" then return nil end

	local attacker = session.combatant
	local defender = session.enemyCombatant
	if not attacker or not defender then return nil end

	local ClubSystem2 = require(Modules.ClubSystem)
	if not session.data.fightingStyle then
		session.data.fightingStyle = ClubSystem2.GetFightingStyleFromHistory(session.data)
	end

	-- Block toggle
	if action.moveType == "block" then
		attacker.isBlocking = action.value == true
		return { result = "block_toggle" }
	end

	-- Parry
	if action.moveType == "parry" then
		local window = CombatSystem.GetParryWindow(session.data.fightingStyle or "Brawler")
		attacker.isParrying = true
		attacker.parryTimer = window
		return { result = "parry_attempt" }
	end

	-- Stamina check
	if attacker.stamina < 5 then return { result = "no_stamina" } end
	if attacker.stunDuration > 0 then return { result = "stunned" } end

	local styleBonus = CombatSystem.GetStyleMod(
		session.data.fightingStyle or "Brawler", action.moveType
	)
	CombatSystem.RecordComboHit(attacker)
	local comboMult  = CombatSystem.GetComboMultiplier(attacker.comboCount)
	local hitResult  = CombatSystem.ApplyHit(attacker, defender, action.moveType, styleBonus * comboMult)

	hitResult.attackerHp = attacker.health
	hitResult.defenderHp = defender.health

	-- Simple enemy AI counter-attack
	if not hitResult.knockout then
		local enemyAction = { moveType = "light" }
		local enemyResult = CombatSystem.ApplyHit(defender, attacker, "light", 1.0)
		hitResult.enemyDamage = enemyResult.damage
		hitResult.attackerHp  = attacker.health

		-- Check player knockout
		if not attacker:IsAlive() then
			hitResult.playerKnockedOut = true
			session.inCombat = false
			local resolveResult = CombatSystem.ResolveFight(defender, attacker, StrongerStrangerSystem)
			broadcastMilestone(player, session.data,
				resolveResult.loser.strongerResult, nil)
			scanAndNotifyArts(player, session)
			RE_StateUpdate:FireClient(player, session.data:Serialize())
			RE_CombatResult:FireClient(player, { won = false })
		end
	else
		-- Player won
		session.inCombat = false
		local resolveResult = CombatSystem.ResolveFight(attacker, defender, StrongerStrangerSystem)
		broadcastMilestone(player, session.data,
			resolveResult.winner.strongerResult, nil)
		scanAndNotifyArts(player, session)
		RE_StateUpdate:FireClient(player, session.data:Serialize())
		RE_CombatResult:FireClient(player, {
			won  = true,
			wins = session.data.combatWins,
		})
	end

	return hitResult
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Remote: FleeCombat
-- ─────────────────────────────────────────────────────────────────────────────
RF_FleeCombat.OnServerInvoke = function(player)
	local session = SharedRegistry.get(player.UserId)
	if not session or not session.inCombat then return false, "Not in combat." end

	local fleeScore = session.data:GetStat("Athletics") + math.random(-5,5)
	local catchScore = (session.enemyCombatant
		and session.enemyCombatant.data:GetStat("Insight")
		or 10) + math.random(-5,5)

	if fleeScore > catchScore then
		session.inCombat = false
		StrongerStrangerSystem.AwardStronger(session.data, "escape_chase")
		RE_StateUpdate:FireClient(player, session.data:Serialize())
		return true, "Escaped."
	else
		return false, "Couldn't get away."
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Heartbeat: schedule tick + stamina/stun regen
-- ─────────────────────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function(dt)
	schedule:Tick(dt)

	for _, session in pairs(SharedRegistry.getAll()) do
		if session.combatant then
			CombatSystem.RegenStamina(session.combatant, dt)
			CombatSystem.TickCombo(session.combatant, dt)
			if session.combatant.parryTimer > 0 then
				session.combatant.parryTimer = session.combatant.parryTimer - dt
				if session.combatant.parryTimer <= 0 then
					session.combatant.isParrying = false
				end
			end
			if session.combatant.stunDuration > 0 then
				session.combatant.stunDuration = session.combatant.stunDuration - dt
			end
		end
	end
end)

-- Prevent stale CombatManager from conflicting (we handle combat here in prototype)
if script.Parent:FindFirstChild("CombatManager") then
	script.Parent.CombatManager:Destroy()
end

print("[GameManager] Dream Delinquent server initialised.")
