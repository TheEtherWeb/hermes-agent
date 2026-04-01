-- MissionManager.lua
-- Mission lifecycle: accept, track objectives, complete, fail, reward.
-- Also manages incursion event scheduling and boss encounter state.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules        = ReplicatedStorage:WaitForChild("Modules")
local MissionData    = require(Modules:WaitForChild("MissionData"))
local GameData       = require(Modules:WaitForChild("GameData"))
local NetworkEvents  = require(Modules:WaitForChild("NetworkEvents"))
local PlayerDataMod  = require(Modules:WaitForChild("PlayerData"))

local MissionManager = {}
MissionManager.__index = MissionManager

-- ── Internal State ────────────────────────────────────────────────────────────
local _remotes        = nil
local _playerManager  = nil
local _factionManager = nil

-- Per-player active mission state
-- [userId] = { missionId, startTime, objectiveProgress = { [objId] = count }, timerLeft }
local _activeMissions = {}

-- Incursion scheduling
local _incursionCooldown = 0        -- seconds until next incursion can fire
local _incursionActive   = false
local INCURSION_INTERVAL_MIN = 300  -- 5 min min between incursions
local INCURSION_INTERVAL_MAX = 900  -- 15 min max

-- ── Init ─────────────────────────────────────────────────────────────────────
function MissionManager:Init(remoteFolder, playerManager, factionManager)
    _remotes        = remoteFolder
    _playerManager  = playerManager
    _factionManager = factionManager

    -- Reset incursion timer
    _incursionCooldown = math.random(INCURSION_INTERVAL_MIN, INCURSION_INTERVAL_MAX)

    -- Wire C2S events
    _remotes:WaitForChild(NetworkEvents.C2S.AcceptMission).OnServerEvent:Connect(function(player, missionId)
        self:HandleAcceptMission(player, missionId)
    end)
    _remotes:WaitForChild(NetworkEvents.C2S.AbandonMission).OnServerEvent:Connect(function(player)
        self:HandleAbandonMission(player)
    end)
    _remotes:WaitForChild(NetworkEvents.C2S.ObjectiveInteract).OnServerEvent:Connect(function(player, objectiveId, targetId)
        self:HandleObjectiveInteract(player, objectiveId, targetId)
    end)
    _remotes:WaitForChild(NetworkEvents.C2S.RequestIncursionJoin).OnServerEvent:Connect(function(player)
        self:HandleIncursionJoin(player)
    end)
    _remotes:WaitForChild(NetworkEvents.C2S.MakeNarrativeChoice).OnServerEvent:Connect(function(player, choiceId, option)
        self:HandleNarrativeChoice(player, choiceId, option)
    end)

    -- RemoteFunction: GetMissionList
    _remotes:WaitForChild(NetworkEvents.RF.GetMissionList).OnServerInvoke = function(player, factionId)
        return self:GetMissionListForPlayer(player, factionId)
    end

    -- RemoteFunction: GetBossLore
    _remotes:WaitForChild(NetworkEvents.RF.GetBossLore).OnServerInvoke = function(player, bossId)
        local boss = MissionData.GetBossById(bossId)
        return boss and boss.Lore or "No data found."
    end

    print("[MissionManager] Initialised. Incursion in:", _incursionCooldown, "s")
end

-- ── Accept Mission ────────────────────────────────────────────────────────────
function MissionManager:HandleAcceptMission(player, missionId)
    local uid  = player.UserId
    local data = _playerManager:GetData(player)
    if not data then return end

    -- Already on a mission?
    if _activeMissions[uid] then
        _remotes:WaitForChild(NetworkEvents.S2C.HUDNotification):FireClient(player,
            "Complete or abandon your current operation first.", 4, "warning"
        )
        return
    end

    local mission = MissionData.GetById(missionId)
    if not mission then
        warn("[MissionManager] Unknown mission:", missionId)
        return
    end

    -- Level check
    local diffDef = GameData.MissionDifficulty[mission.Difficulty:upper()]
    if diffDef and data.Level < diffDef.minLevel then
        _remotes:WaitForChild(NetworkEvents.S2C.HUDNotification):FireClient(player,
            "Insufficient level for this operation. Required: " .. diffDef.minLevel, 4, "error"
        )
        return
    end

    -- Faction rep check (must be at least Unknown / 0 rep with offering faction)
    if mission.Faction then
        local rep = data.FactionRep[mission.Faction] or 0
        if rep < -199 then
            _remotes:WaitForChild(NetworkEvents.S2C.HUDNotification):FireClient(player,
                "Faction distrust too high. Improve standing first.", 4, "error"
            )
            return
        end
    end

    -- Build objective progress table
    local progress = {}
    for _, obj in ipairs(mission.Objectives) do
        progress[obj.Id] = { current = 0, target = obj.Count or 1, completed = false }
    end

    _activeMissions[uid] = {
        missionId  = missionId,
        startTime  = tick(),
        progress   = progress,
        timerLeft  = mission.Flags.missionTime,  -- nil if untimed
        phase      = 1,
    }

    data.ActiveMission = missionId
    _remotes:WaitForChild(NetworkEvents.S2C.MissionStarted):FireClient(player, missionId, mission)

    print("[MissionManager]", player.Name, "accepted:", mission.DisplayName)
end

-- ── Abandon Mission ───────────────────────────────────────────────────────────
function MissionManager:HandleAbandonMission(player)
    local uid = player.UserId
    if not _activeMissions[uid] then return end

    local missionId = _activeMissions[uid].missionId
    _activeMissions[uid] = nil

    local data = _playerManager:GetData(player)
    if data then data.ActiveMission = nil end

    _remotes:WaitForChild(NetworkEvents.S2C.MissionFailed):FireClient(player, missionId, "Abandoned")
    print("[MissionManager]", player.Name, "abandoned:", missionId)
end

-- ── Objective Interact ────────────────────────────────────────────────────────
-- Called when the client confirms an interact-type objective (collecting item, talking to NPC, etc.)
function MissionManager:HandleObjectiveInteract(player, objectiveId, targetId)
    local uid   = player.UserId
    local state = _activeMissions[uid]
    if not state then return end

    local mission = MissionData.GetById(state.missionId)
    if not mission then return end

    -- Find the objective
    for _, obj in ipairs(mission.Objectives) do
        if obj.Id == objectiveId and (obj.Type == "Interact" or obj.Type == "Collect" or obj.Type == "Navigate") then
            local prog = state.progress[objectiveId]
            if prog and not prog.completed then
                prog.current = prog.current + 1
                if prog.current >= prog.target then
                    prog.completed = true
                end
                _remotes:WaitForChild(NetworkEvents.S2C.MissionObjectiveUpdated):FireClient(player,
                    objectiveId, prog.current, prog.target, prog.completed
                )
                self:CheckMissionCompletion(player, state, mission)
            end
        end
    end
end

-- ── Objective Progress (called by other systems: EnemyAI, CombatManager) ─────
function MissionManager:ProgressObjective(player, objectiveType, targetTag, count)
    local uid   = player.UserId
    local state = _activeMissions[uid]
    if not state then return end

    local mission = MissionData.GetById(state.missionId)
    if not mission then return end

    for _, obj in ipairs(mission.Objectives) do
        if obj.Type == objectiveType and (obj.Target == targetTag or targetTag == nil) then
            local prog = state.progress[obj.Id]
            if prog and not prog.completed then
                prog.current = math.min(prog.target, prog.current + (count or 1))
                if prog.current >= prog.target then
                    prog.completed = true
                end
                _remotes:WaitForChild(NetworkEvents.S2C.MissionObjectiveUpdated):FireClient(player,
                    obj.Id, prog.current, prog.target, prog.completed
                )
            end
        end
    end

    self:CheckMissionCompletion(player, state, mission)
end

-- ── Check Mission Completion ──────────────────────────────────────────────────
function MissionManager:CheckMissionCompletion(player, state, mission)
    -- Count required objectives (not optional ones marked by prefix)
    local requiredComplete = 0
    local requiredTotal    = 0

    for _, obj in ipairs(mission.Objectives) do
        -- Optional objectives have "[Optional]" in label
        if not obj.Label:find("Optional") and obj.Type ~= "Choice" then
            requiredTotal = requiredTotal + 1
            local prog = state.progress[obj.Id]
            if prog and prog.completed then
                requiredComplete = requiredComplete + 1
            end
        end
    end

    if requiredComplete >= requiredTotal then
        self:CompleteMission(player, state, mission)
    end
end

-- ── Complete Mission ──────────────────────────────────────────────────────────
function MissionManager:CompleteMission(player, state, mission)
    local uid  = player.UserId
    local data = _playerManager:GetData(player)
    if not data then return end

    -- Calculate bonus for optional objectives
    local optionalComplete = 0
    for _, obj in ipairs(mission.Objectives) do
        if obj.Label:find("Optional") then
            local prog = state.progress[obj.Id]
            if prog and prog.completed then optionalComplete = optionalComplete + 1 end
        end
    end

    -- Difficulty multipliers
    local diffKey = mission.Difficulty:upper()
    local diffDef = GameData.MissionDifficulty[diffKey] or GameData.MissionDifficulty.GREY
    local rewards = mission.Rewards

    local xpReward      = math.floor((rewards.xp      or 0) * diffDef.xpMult)
    local creditReward  = math.floor((rewards.credits  or 0) * diffDef.creditMult)
    local scrapReward   = rewards.scrap or 0
    local optBonus      = optionalComplete * 200  -- bonus credits per optional

    -- Apply time bonus for timed missions
    if state.timerLeft and state.timerLeft > 0 then
        local timeBonus = math.floor(state.timerLeft * 5)
        creditReward = creditReward + timeBonus
    end

    -- Award rewards
    _playerManager:AwardXP(player, xpReward)
    _playerManager:AwardCurrency(player, creditReward + optBonus, scrapReward)

    -- Faction rep
    if rewards.repGain then
        _playerManager:AdjustFactionRep(player, rewards.repGain)
    end
    if rewards.repLoss then
        _playerManager:AdjustFactionRep(player, rewards.repLoss)
    end

    -- Aug reward
    if rewards.augReward then
        -- Add aug to inventory if not already owned
        local owned = false
        for _, id in ipairs(data.UnlockedAugs) do
            if id == rewards.augReward then owned = true; break end
        end
        if not owned then
            table.insert(data.UnlockedAugs, rewards.augReward)
            _remotes:WaitForChild(NetworkEvents.S2C.AugUnlocked):FireClient(player, rewards.augReward)
        end
    end

    -- Mark mission complete
    table.insert(data.CompletedMissions, mission.Id)
    data.ActiveMission = nil
    data.Stats.MissionsComplete = (data.Stats.MissionsComplete or 0) + 1

    _activeMissions[uid] = nil

    -- Tell client
    _remotes:WaitForChild(NetworkEvents.S2C.MissionCompleted):FireClient(player, mission.Id, {
        xp       = xpReward,
        credits  = creditReward + optBonus,
        scrap    = scrapReward,
        augReward= rewards.augReward,
    })

    print("[MissionManager]", player.Name, "completed:", mission.DisplayName,
          "XP:", xpReward, "Credits:", creditReward)
end

-- ── Mission Tick ──────────────────────────────────────────────────────────────
function MissionManager:Tick(dt)
    -- Tick active missions (timed missions)
    for uid, state in pairs(_activeMissions) do
        if state.timerLeft then
            state.timerLeft = state.timerLeft - dt
            if state.timerLeft <= 0 then
                -- Find player and fail the mission
                local player = Players:GetPlayerByUserId(uid)
                if player then
                    local mission = MissionData.GetById(state.missionId)
                    _activeMissions[uid] = nil
                    local data = _playerManager:GetData(player)
                    if data then data.ActiveMission = nil end
                    _remotes:WaitForChild(NetworkEvents.S2C.MissionFailed):FireClient(player,
                        state.missionId, "Time expired"
                    )
                    print("[MissionManager]", player.Name, "mission timed out:", state.missionId)
                end
            end
        end
    end

    -- Incursion scheduling
    if not _incursionActive then
        _incursionCooldown = _incursionCooldown - dt
        if _incursionCooldown <= 0 then
            self:TriggerIncursion()
        end
    end
end

-- ── Incursion Events ──────────────────────────────────────────────────────────
function MissionManager:TriggerIncursion()
    local incursions = MissionData.GetIncursions()
    if #incursions == 0 then return end

    local chosen = incursions[math.random(#incursions)]
    _incursionActive = true

    print("[MissionManager] INCURSION TRIGGERED:", chosen.DisplayName)

    -- Notify all players
    for _, player in ipairs(Players:GetPlayers()) do
        _remotes:WaitForChild(NetworkEvents.S2C.IncursionTriggered):FireClient(player, chosen.Id, chosen)
    end

    -- Duration of incursion (from mission timer)
    local duration = chosen.Flags.missionTime or 600

    task.delay(duration, function()
        _incursionActive   = false
        _incursionCooldown = math.random(INCURSION_INTERVAL_MIN, INCURSION_INTERVAL_MAX)

        for _, player in ipairs(Players:GetPlayers()) do
            _remotes:WaitForChild(NetworkEvents.S2C.IncursionEnded):FireClient(player, chosen.Id)
        end

        print("[MissionManager] Incursion ended:", chosen.DisplayName)
    end)
end

function MissionManager:HandleIncursionJoin(player)
    -- Joining an incursion mid-event; give them the mission data
    -- In the full game, proximity to the incursion zone would be required
    print("[MissionManager]", player.Name, "joined active incursion")
end

-- ── Narrative Choices ─────────────────────────────────────────────────────────
function MissionManager:HandleNarrativeChoice(player, choiceId, option)
    local uid   = player.UserId
    local state = _activeMissions[uid]
    if not state then return end

    local data = _playerManager:GetData(player)
    if not data then return end

    -- Flag the choice
    PlayerDataMod.SetFlag(data, choiceId .. "_" .. option)

    -- Choice-specific outcomes
    if choiceId == "MirrorCapture" then
        if option == "capture" then
            _playerManager:AdjustFactionRep(player, { Liberation = 100 })
            _playerManager:AwardXP(player, 1000)
            _playerManager:AwardCurrency(player, 8000, 0)
            self:ProgressObjective(player, "Choice", "MirrorCapture", 1)
        elseif option == "terminate" then
            _playerManager:AdjustFactionRep(player, { SIA = 60, Liberation = -200 })
            _playerManager:AwardCurrency(player, 4800, 0)
            self:ProgressObjective(player, "Choice", "MirrorCapture", 1)
        end
    elseif choiceId == "HollowKing" then
        if option == "communicate" then
            _playerManager:AdjustFactionRep(player, { Overseers = 200, MachineCult = 150 })
            _playerManager:AwardXP(player, 8000)
            self:ProgressObjective(player, "Choice", "BossHollowKing", 1)
        elseif option == "destroy" then
            _playerManager:AdjustFactionRep(player, { SIA = 100, Overseers = -200 })
            _playerManager:AwardXP(player, 5000)
            self:ProgressObjective(player, "Choice", "BossHollowKing", 1)
        end
    end
end

-- ── Mission List for Player ───────────────────────────────────────────────────
function MissionManager:GetMissionListForPlayer(player, factionId)
    local data = _playerManager:GetData(player)
    if not data then return {} end

    local result = {}
    for _, mission in ipairs(MissionData.Missions) do
        -- Filter by faction if specified
        if factionId and mission.Faction ~= factionId then
            goto continue
        end

        -- Incursion missions only show during active incursion
        if mission.Type == "Incursion" and not _incursionActive then
            goto continue
        end

        -- Build display entry
        local diffDef = GameData.MissionDifficulty[mission.Difficulty:upper()]
        local alreadyDone = false
        for _, doneId in ipairs(data.CompletedMissions) do
            if doneId == mission.Id then alreadyDone = true; break end
        end

        table.insert(result, {
            Id          = mission.Id,
            DisplayName = mission.DisplayName,
            Description = mission.Description,
            Type        = mission.Type,
            Faction     = mission.Faction,
            Difficulty  = mission.Difficulty,
            MinLevel    = diffDef and diffDef.minLevel or 1,
            Completed   = alreadyDone,
            IsActive    = data.ActiveMission == mission.Id,
            Rewards = {
                xp      = mission.Rewards.xp,
                credits = mission.Rewards.credits,
            },
        })

        ::continue::
    end
    return result
end

-- ── Boss Encounter Notification ───────────────────────────────────────────────
function MissionManager:StartBossEncounter(player, bossId)
    local boss = MissionData.GetBossById(bossId)
    if not boss then return end
    _remotes:WaitForChild(NetworkEvents.S2C.BossEncounterStarted):FireClient(player, bossId, {
        DisplayName = boss.DisplayName,
        Description = boss.Description,
        HP          = boss.HP,
    })
end

function MissionManager:NotifyBossPhaseChange(player, bossId, phase)
    _remotes:WaitForChild(NetworkEvents.S2C.BossPhaseChanged):FireClient(player, bossId, phase)
end

return MissionManager
