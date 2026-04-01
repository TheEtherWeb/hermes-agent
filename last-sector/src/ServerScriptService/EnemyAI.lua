-- EnemyAI.lua
-- Enemy spawning, behavior state machines, and combat logic for NPCs.
-- Covers custodian units, security, salvager enemies, cultists, and boss patterns.

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules       = ReplicatedStorage:WaitForChild("Modules")
local GameData      = require(Modules:WaitForChild("GameData"))
local MissionData   = require(Modules:WaitForChild("MissionData"))

local EnemyAI = {}
EnemyAI.__index = EnemyAI

-- ── AI State Machine ───────────────────────────────────────────────────────────
local AIState = {
    IDLE      = "Idle",
    PATROL    = "Patrol",
    ALERT     = "Alert",
    CHASE     = "Chase",
    ATTACK    = "Attack",
    RETREAT   = "Retreat",
    DEAD      = "Dead",
}

-- ── Enemy Type Definitions ────────────────────────────────────────────────────
local EnemyTypes = {
    -- Corporate Security
    AxiomGuard = {
        displayName   = "Axiom Security Unit",
        hp            = 120,
        armor         = 40,
        damage        = 22,
        moveSpeed     = 16,
        attackRange   = 50,
        detectionRange= 60,
        attackRate    = 0.8,    -- shots per second
        damageType    = "Ballistic",
        factionTag    = "AxiomSecurity",
        drops         = { credits = { 30, 80 } },
        aiFlags       = { callsBackup = true, useCover = true },
    },
    AxiomElite = {
        displayName   = "Axiom Enforcement Elite",
        hp            = 250,
        armor         = 100,
        damage        = 38,
        moveSpeed     = 18,
        attackRange   = 70,
        detectionRange= 80,
        attackRate    = 1.0,
        damageType    = "Ballistic",
        factionTag    = "AxiomSecurity",
        drops         = { credits = { 80, 200 }, augChance = 0.10 },
        aiFlags       = { callsBackup = true, useCover = true, flanks = true },
    },

    -- SIA Tactical
    SIATactical = {
        displayName   = "SIA Tactical Operative",
        hp            = 180,
        armor         = 60,
        damage        = 30,
        moveSpeed     = 17,
        attackRange   = 80,
        detectionRange= 90,
        attackRate    = 0.9,
        damageType    = "Ballistic",
        factionTag    = "SIATactical",
        drops         = { credits = { 50, 130 } },
        aiFlags       = { callsBackup = true, useCover = true, grenades = true },
    },
    SIAHeavy = {
        displayName   = "SIA Heavy Suppressor",
        hp            = 400,
        armor         = 150,
        damage        = 45,
        moveSpeed     = 12,
        attackRange   = 60,
        detectionRange= 70,
        attackRate    = 0.6,
        damageType    = "Ballistic",
        factionTag    = "SIATactical",
        drops         = { credits = { 100, 300 } },
        aiFlags       = { heavy = true, suppressFire = true, coverDestroyer = true },
    },

    -- Machine / Custodian Units
    CustodianUnit = {
        displayName   = "Custodian Unit",
        hp            = 200,
        armor         = 80,
        damage        = 28,
        moveSpeed     = 14,
        attackRange   = 40,
        detectionRange= 55,
        attackRate    = 0.7,
        damageType    = "Energy",
        factionTag    = "Machine",
        drops         = { scrap = { 20, 60 } },
        aiFlags       = { machineUnit = true, empImmune = false, networked = true },
    },
    ArchitectDrone = {
        displayName   = "Architect Drone",
        hp            = 80,
        armor         = 20,
        damage        = 18,
        moveSpeed     = 30,
        attackRange   = 35,
        detectionRange= 100,
        attackRate    = 1.5,
        damageType    = "Energy",
        factionTag    = "Machine",
        drops         = { scrap = { 10, 40 } },
        aiFlags       = { flying = true, machineUnit = true, swarms = true },
    },

    -- Liberation (android extremists)
    LiberationCell = {
        displayName   = "Liberation Cell Operative",
        hp            = 150,
        armor         = 30,
        damage        = 24,
        moveSpeed     = 18,
        attackRange   = 60,
        detectionRange= 65,
        attackRate    = 1.0,
        damageType    = "Ballistic",
        factionTag    = "Liberation",
        drops         = { credits = { 20, 70 } },
        aiFlags       = { useCover = true, flanks = true },
    },
    LiberationAndroid = {
        displayName   = "Liberation Android Agent",
        hp            = 220,
        armor         = 60,
        damage        = 35,
        moveSpeed     = 22,
        attackRange   = 55,
        detectionRange= 80,
        attackRate    = 1.1,
        damageType    = "Energy",
        factionTag    = "Liberation",
        drops         = { credits = { 60, 160 } },
        aiFlags       = { android = true, hackTools = true, useCover = true },
    },

    -- Cult Militants
    CultMilitant = {
        displayName   = "Choir Militant",
        hp            = 160,
        armor         = 50,
        damage        = 26,
        moveSpeed     = 16,
        attackRange   = 45,
        detectionRange= 60,
        attackRate    = 0.8,
        damageType    = "Energy",
        factionTag    = "MachineCult",
        drops         = { credits = { 15, 50 }, scrap = { 5, 20 } },
        aiFlags       = { cultUnit = true, selfAugmented = true },
    },
    CultPriest = {
        displayName   = "Machine Priest",
        hp            = 300,
        armor         = 90,
        damage        = 40,
        moveSpeed     = 14,
        attackRange   = 30,
        detectionRange= 70,
        attackRate    = 0.5,
        damageType    = "Neural",
        factionTag    = "MachineCult",
        drops         = { credits = { 100, 250 }, augChance = 0.20 },
        aiFlags       = { healer = true, cultUnit = true, buffsAllies = true },
    },

    -- Salvage Zone Scavengers (hostile)
    SalvageRaider = {
        displayName   = "Corpse-Zone Raider",
        hp            = 100,
        armor         = 20,
        damage        = 18,
        moveSpeed     = 19,
        attackRange   = 30,
        detectionRange= 40,
        attackRate    = 1.2,
        damageType    = "Ballistic",
        factionTag    = "Hostile",
        drops         = { scrap = { 30, 90 }, credits = { 5, 25 } },
        aiFlags       = { aggressive = true, groupTactics = true },
    },
}

-- ── Internal Enemy Instance State ─────────────────────────────────────────────
-- Tracks all spawned enemy NPCs
-- [model] = { type, state, hp, armor, target, patrolPoints, lastAttackTime, ... }
local _enemies = {}

local _playerManager = nil
local _combatManager = nil

-- ── Init ─────────────────────────────────────────────────────────────────────
function EnemyAI:Init(playerManager, combatManager)
    _playerManager = playerManager
    _combatManager = combatManager

    -- Listen for enemy humanoid deaths
    -- In full implementation, enemies would be spawned by zone scripts.
    -- Here we hook into CharacterRemoving-equivalent for NPC models.
end

-- ── Spawn Enemy ───────────────────────────────────────────────────────────────
function EnemyAI:SpawnEnemy(enemyTypeId, position, patrolPoints)
    local typeDef = EnemyTypes[enemyTypeId]
    if not typeDef then
        warn("[EnemyAI] Unknown enemy type:", enemyTypeId)
        return nil
    end

    -- Build NPC model from parts
    -- (In production this loads a pre-built R15 rig from a folder in ReplicatedStorage/Assets)
    local model = Instance.new("Model")
    model.Name  = typeDef.displayName

    local hrp = Instance.new("Part")
    hrp.Name         = "HumanoidRootPart"
    hrp.Size         = Vector3.new(2, 2, 1)
    hrp.Position     = position
    hrp.Anchored     = false
    hrp.CanCollide   = true
    hrp.Parent       = model

    local hum = Instance.new("Humanoid")
    hum.MaxHealth    = typeDef.hp
    hum.Health       = typeDef.hp
    hum.WalkSpeed    = typeDef.moveSpeed
    hum.Parent       = model

    model.PrimaryPart = hrp
    model.Parent      = workspace

    -- Store state
    local state = {
        typeId        = enemyTypeId,
        typeDef       = typeDef,
        aiState       = AIState.PATROL,
        hp            = typeDef.hp,
        armor         = typeDef.armor or 0,
        target        = nil,
        lastAttackTime= 0,
        patrolPoints  = patrolPoints or {},
        patrolIndex   = 1,
        alertTime     = 0,
        model         = model,
        humanoid      = hum,
        hrp           = hrp,
    }
    _enemies[model] = state

    -- Hook death
    hum.Died:Connect(function()
        self:OnEnemyDeath(model, state)
    end)

    return model
end

-- ── AI Tick ───────────────────────────────────────────────────────────────────
function EnemyAI:Tick(dt)
    for model, state in pairs(_enemies) do
        if not model.Parent then
            _enemies[model] = nil
            continue
        end
        if state.aiState == AIState.DEAD then continue end

        -- Find closest player target
        local target, dist = self:FindClosestPlayer(state)

        -- State transitions
        if state.aiState == AIState.IDLE or state.aiState == AIState.PATROL then
            if target and dist <= state.typeDef.detectionRange then
                state.target   = target
                state.aiState  = AIState.ALERT
                state.alertTime= tick() + 0.8  -- short alert delay before engaging
            else
                self:DoPatrol(state, dt)
            end

        elseif state.aiState == AIState.ALERT then
            if tick() >= state.alertTime then
                state.aiState = AIState.CHASE
            end

        elseif state.aiState == AIState.CHASE then
            if not target or dist > state.typeDef.detectionRange * 1.5 then
                state.target  = nil
                state.aiState = AIState.PATROL
            elseif dist <= state.typeDef.attackRange then
                state.aiState = AIState.ATTACK
            else
                self:MoveToward(state, target)
            end

        elseif state.aiState == AIState.ATTACK then
            if not target then
                state.aiState = AIState.PATROL
            elseif dist > state.typeDef.attackRange * 1.2 then
                state.aiState = AIState.CHASE
            else
                self:DoAttack(state, target, dt)

                -- Flanking behavior
                if state.typeDef.aiFlags.flanks then
                    self:DoFlank(state, target)
                end
            end

        elseif state.aiState == AIState.RETREAT then
            -- Move away from target
            if state.hp > state.typeDef.hp * 0.4 then
                state.aiState = AIState.ATTACK
            else
                self:MoveAwayFrom(state, target)
            end
        end
    end
end

-- ── Find Closest Player ───────────────────────────────────────────────────────
function EnemyAI:FindClosestPlayer(state)
    local closest, closestDist = nil, math.huge
    local myPos = state.hrp.Position

    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        -- NPC reaction: if machine affinity is high, machines don't auto-attack
        local pData = _playerManager:GetData(player)
        if pData and state.typeDef.aiFlags.machineUnit then
            local il = pData.IdentityLoad
            local overseersRep = pData.FactionRep["Overseers"] or -100
            if overseersRep >= 300 then continue end  -- machine friendly
        end

        local dist = (hrp.Position - myPos).Magnitude
        if dist < closestDist then
            closest     = player
            closestDist = dist
        end
    end

    return closest, closestDist
end

-- ── Movement ──────────────────────────────────────────────────────────────────
function EnemyAI:MoveToward(state, player)
    if not player.Character then return end
    local targetHRP = player.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end
    state.humanoid:MoveTo(targetHRP.Position)
end

function EnemyAI:MoveAwayFrom(state, player)
    if not player.Character then return end
    local targetHRP = player.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end
    local awayDir = (state.hrp.Position - targetHRP.Position).Unit
    state.humanoid:MoveTo(state.hrp.Position + awayDir * 20)
end

function EnemyAI:DoPatrol(state, dt)
    if #state.patrolPoints == 0 then return end
    local target = state.patrolPoints[state.patrolIndex]
    if not target then return end

    state.humanoid:MoveTo(target)

    if (state.hrp.Position - target).Magnitude < 4 then
        state.patrolIndex = (state.patrolIndex % #state.patrolPoints) + 1
    end
end

function EnemyAI:DoFlank(state, target)
    if not target.Character then return end
    local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    -- Move perpendicular to target
    local toTarget = (targetHRP.Position - state.hrp.Position)
    local right    = Vector3.new(toTarget.Z, 0, -toTarget.X).Unit
    local flankPos = state.hrp.Position + right * 15

    state.humanoid:MoveTo(flankPos)
end

-- ── Attack ────────────────────────────────────────────────────────────────────
function EnemyAI:DoAttack(state, player, dt)
    local now = tick()
    local attackInterval = 1 / (state.typeDef.attackRate or 1)

    if now - state.lastAttackTime < attackInterval then return end
    state.lastAttackTime = now

    -- Line-of-sight check (simplified: distance and direct path)
    local char = player.Character
    if not char then return end
    local targetHRP = char:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    local dist = (state.hrp.Position - targetHRP.Position).Magnitude
    if dist > state.typeDef.attackRange then return end

    -- Raycast for LoS
    local rayOrigin = state.hrp.Position + Vector3.new(0, 2, 0)
    local rayDir    = (targetHRP.Position - rayOrigin)
    local rayResult = workspace:Raycast(rayOrigin, rayDir, RaycastParams.new())

    if rayResult and rayResult.Instance then
        local hitChar = rayResult.Instance.Parent
        if hitChar ~= char and hitChar ~= char.Parent then
            return  -- something blocking LoS
        end
    end

    -- Apply damage via CombatManager
    local damage = state.typeDef.damage
    -- Add distance falloff for ranged units
    if dist > state.typeDef.attackRange * 0.6 then
        damage = math.floor(damage * 0.75)
    end

    _combatManager:DamagePlayer(player, damage, state.typeDef.damageType, state.model.Name)

    -- Heal-aura behavior for CultPriest
    if state.typeDef.aiFlags.healer then
        self:HealNearbyEnemies(state, 15)
    end

    -- Summon backup
    if state.typeDef.aiFlags.callsBackup and not state._calledBackup then
        if state.hp < state.typeDef.hp * 0.5 then
            state._calledBackup = true
            -- In full implementation: signal the zone spawner
        end
    end
end

function EnemyAI:HealNearbyEnemies(healerState, healAmount)
    for model, state in pairs(_enemies) do
        if state ~= healerState and state.aiState ~= AIState.DEAD then
            local dist = (state.hrp.Position - healerState.hrp.Position).Magnitude
            if dist <= 20 then
                state.humanoid.Health = math.min(
                    state.humanoid.MaxHealth,
                    state.humanoid.Health + healAmount
                )
            end
        end
    end
end

-- ── Enemy Death ───────────────────────────────────────────────────────────────
function EnemyAI:OnEnemyDeath(model, state)
    state.aiState = AIState.DEAD

    -- Award drops to the player who made the kill
    -- (Simplified: award to closest player who attacked recently)
    local closestPlayer = self:FindKiller(state)
    if closestPlayer then
        -- Currency drops
        if state.typeDef.drops.credits then
            local lo, hi = table.unpack(state.typeDef.drops.credits)
            _playerManager:AwardCurrency(closestPlayer, math.random(lo, hi), 0)
        end
        if state.typeDef.drops.scrap then
            local lo, hi = table.unpack(state.typeDef.drops.scrap)
            _playerManager:AwardCurrency(closestPlayer, 0, math.random(lo, hi))
        end

        -- Notify mission system of kill
        -- (In full implementation: MissionManager:ProgressObjective via event)
    end

    -- Remove model after short delay (let death animation play)
    task.delay(3, function()
        if model and model.Parent then
            model:Destroy()
        end
        _enemies[model] = nil
    end)
end

function EnemyAI:FindKiller(state)
    -- Simplified: return closest living player
    local closest, closestDist = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local dist = (hrp.Position - state.hrp.Position).Magnitude
        if dist < closestDist then
            closest     = player
            closestDist = dist
        end
    end
    return closest
end

-- ── Boss Spawning ─────────────────────────────────────────────────────────────
function EnemyAI:SpawnBoss(bossId, position, missionManager, targetPlayer)
    local bossDef = MissionData.GetBossById(bossId)
    if not bossDef then
        warn("[EnemyAI] Unknown boss:", bossId)
        return
    end

    -- Create boss model
    local model = Instance.new("Model")
    model.Name  = bossDef.DisplayName

    local hrp = Instance.new("Part")
    hrp.Name     = "HumanoidRootPart"
    hrp.Size     = Vector3.new(3, 4, 2)
    hrp.Position = position
    hrp.Anchored = false
    hrp.BrickColor = BrickColor.new("Really black")
    hrp.Parent   = model

    local hum = Instance.new("Humanoid")
    hum.MaxHealth = bossDef.HP
    hum.Health    = bossDef.HP
    hum.WalkSpeed = 20
    hum.Parent    = model

    model.PrimaryPart = hrp
    model.Parent      = workspace

    if targetPlayer then
        missionManager:StartBossEncounter(targetPlayer, bossId)
    end

    -- Boss state machine
    local bossState = {
        bossId       = bossId,
        bossDef      = bossDef,
        currentPhase = 1,
        model        = model,
        humanoid     = hum,
        hrp          = hrp,
        lastAttackTime = 0,
        behaviourTimers= {},
    }

    -- Phase transitions based on HP %
    hum.HealthChanged:Connect(function(health)
        local pct = health / hum.MaxHealth
        local phases = bossDef.Phases
        for i, phase in ipairs(phases) do
            if i > bossState.currentPhase and pct <= phase.phaseHP then
                bossState.currentPhase = i
                if targetPlayer then
                    missionManager:NotifyBossPhaseChange(targetPlayer, bossId, phase)
                end
                print("[EnemyAI] Boss", bossId, "entering phase:", phase.label)
            end
        end
    end)

    hum.Died:Connect(function()
        print("[EnemyAI] Boss defeated:", bossId)
        if targetPlayer then
            -- Award drops
            if bossDef.DropAug then
                local pData = _playerManager:GetData(targetPlayer)
                if pData then
                    local owned = false
                    for _, id in ipairs(pData.UnlockedAugs) do
                        if id == bossDef.DropAug then owned = true; break end
                    end
                    if not owned then
                        table.insert(pData.UnlockedAugs, bossDef.DropAug)
                    end
                end
            end
            _playerManager:AwardXP(targetPlayer, bossDef.HP)  -- XP = boss HP as rough scaling
            local data = _playerManager:GetData(targetPlayer)
            if data then
                data.Stats.BossKills = (data.Stats.BossKills or 0) + 1
            end

            local remotes = workspace.Parent:FindFirstChild("ReplicatedStorage"):FindFirstChild("Remotes")
            if remotes then
                remotes:FindFirstChild("BossDefeated"):FireClient(targetPlayer, bossId)
            end
        end

        task.delay(5, function()
            if model and model.Parent then model:Destroy() end
        end)
    end)

    return model
end

-- ── Public: List all active enemies ──────────────────────────────────────────
function EnemyAI:GetActiveEnemyCount()
    local count = 0
    for _ in pairs(_enemies) do count = count + 1 end
    return count
end

EnemyAI.EnemyTypes = EnemyTypes
EnemyAI.AIState    = AIState

return EnemyAI
