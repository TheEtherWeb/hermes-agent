-- CombatManager.lua
-- Server-side combat: hitbox validation, damage application, overdrive handling,
-- status effects, and weapon fire rate anti-cheat.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules      = ReplicatedStorage:WaitForChild("Modules")
local GameData     = require(Modules:WaitForChild("GameData"))
local WeaponData   = require(Modules:WaitForChild("WeaponData"))
local NetworkEvents= require(Modules:WaitForChild("NetworkEvents"))

local CombatManager = {}
CombatManager.__index = CombatManager

-- ── Internal State ────────────────────────────────────────────────────────────
local _remotes        = nil
local _playerManager  = nil
local _fireRecords    = {}   -- [userId] = { weaponId, lastFireTick, shotCount }
local _overdriveState = {}   -- [userId] = { active, expiresAt, overdriveId }
local _statusEffects  = {}   -- [userId] = { [effectId] = { expiresAt, tickNext, ... } }
local _armorValues    = {}   -- [userId] = currentArmor
local _energyValues   = {}   -- [userId] = currentEnergy

-- ── Init ─────────────────────────────────────────────────────────────────────
function CombatManager:Init(remoteFolder, playerManager)
    _remotes       = remoteFolder
    _playerManager = playerManager

    -- Wire C2S events
    _remotes:WaitForChild(NetworkEvents.C2S.FireWeapon).OnServerEvent:Connect(function(player, payload)
        self:HandleFireWeapon(player, payload)
    end)
    _remotes:WaitForChild(NetworkEvents.C2S.ActivateOverdrive).OnServerEvent:Connect(function(player)
        self:HandleActivateOverdrive(player)
    end)
    _remotes:WaitForChild(NetworkEvents.C2S.UseSecondary).OnServerEvent:Connect(function(player, toolId, targetPos)
        self:HandleUseSecondary(player, toolId, targetPos)
    end)
    _remotes:WaitForChild(NetworkEvents.C2S.ActivateBodySystem).OnServerEvent:Connect(function(player, augId)
        self:HandleBodySystemActivation(player, augId)
    end)

    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function()
            task.wait(0.2)
            self:InitPlayerCombatState(player)
        end)
    end)
    Players.PlayerRemoving:Connect(function(player)
        local uid = player.UserId
        _fireRecords[uid]    = nil
        _overdriveState[uid] = nil
        _statusEffects[uid]  = nil
        _armorValues[uid]    = nil
        _energyValues[uid]   = nil
    end)
end

-- ── Init Player Combat State ──────────────────────────────────────────────────
function CombatManager:InitPlayerCombatState(player)
    local uid  = player.UserId
    local data = _playerManager:GetData(player)
    if not data then return end

    _armorValues[uid]    = data.MaxArmor
    _energyValues[uid]   = data.MaxEnergy
    _fireRecords[uid]    = {}
    _overdriveState[uid] = { active = false }
    _statusEffects[uid]  = {}
end

-- ── Fire Weapon ───────────────────────────────────────────────────────────────
-- payload = { weaponId, origin (Vector3), direction (Vector3), hitData }
-- hitData = { type="character"|"part"|"none", targetId, hitPartName, distance }
function CombatManager:HandleFireWeapon(player, payload)
    if type(payload) ~= "table" then return end

    local weaponId  = payload.weaponId
    local hitData   = payload.hitData
    local uid       = player.UserId

    local data = _playerManager:GetData(player)
    if not data then return end

    -- Validate weapon is equipped
    if data.Weapons.Primary ~= weaponId and data.Weapons.Secondary ~= weaponId then
        return  -- client sent a weapon they don't have
    end

    local wDef = WeaponData.GetById(weaponId)
    if not wDef then return end

    -- Anti-cheat: fire rate check
    local record = _fireRecords[uid] or {}
    local now    = tick()
    if record.weaponId == weaponId and record.lastFireTick then
        local minInterval = 60 / (wDef.Stats.FireRate or 600) - 0.05  -- 50ms tolerance
        if (now - record.lastFireTick) < minInterval then
            warn("[CombatManager] Fire rate violation:", player.Name, weaponId)
            return
        end
    end
    _fireRecords[uid] = { weaponId = weaponId, lastFireTick = now }

    -- Distance sanity check
    local char = player.Character
    if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- No hit: nothing to apply
    if not hitData or hitData.type == "none" then return end

    -- Character hit
    if hitData.type == "character" then
        self:ApplyCharacterDamage(player, wDef, hitData, data)
    end
end

-- ── Apply Damage to a Character ───────────────────────────────────────────────
function CombatManager:ApplyCharacterDamage(shooter, wDef, hitData, shooterData)
    -- Find the target player or NPC humanoid
    local targetModel = workspace:FindFirstChild(hitData.targetId)
    if not targetModel then return end

    local targetHum = targetModel:FindFirstChildOfClass("Humanoid")
    if not targetHum or targetHum.Health <= 0 then return end

    -- Calculate base damage
    local baseDamage   = wDef.Stats.Damage or 10
    local damageType   = wDef.Stats.DamageType or "Ballistic"
    local armorPen     = wDef.Stats.ArmorPen   or 0

    -- Headshot / weakpoint multipliers
    local partName = (hitData.hitPartName or ""):lower()
    local mult = 1.0
    if partName == "head" then
        mult = GameData.Combat.HeadshotMultiplier
    elseif partName:find("weakpoint") then
        mult = GameData.Combat.WeakpointMultiplier
    end

    -- Overdrive damage bonus (shooter)
    if _overdriveState[shooter.UserId] and _overdriveState[shooter.UserId].active then
        local od = _overdriveState[shooter.UserId]
        if od.effects and od.effects.DamageBonus then
            mult = mult * (1 + od.effects.DamageBonus)
        end
    end

    local finalDamage = math.floor(baseDamage * mult)

    -- Apply armor absorption for NPC targets (players handled separately)
    local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
    if targetPlayer then
        -- PvP: apply armor damage reduction
        local targetUid   = targetPlayer.UserId
        local currentArmor= _armorValues[targetUid] or 0
        local armorBlock  = 0
        if currentArmor > 0 and armorPen < 1 then
            local effectiveArmor = currentArmor * (1 - armorPen)
            armorBlock = math.min(effectiveArmor, finalDamage * 0.5)
            _armorValues[targetUid] = math.max(0, currentArmor - armorBlock * 0.3)
        end
        finalDamage = math.max(1, finalDamage - math.floor(armorBlock))

        -- Inform target client
        _remotes:WaitForChild(NetworkEvents.S2C.TakeDamage):FireClient(targetPlayer,
            finalDamage, damageType, shooter.UserId
        )
        _playerManager:SetCombatTimestamp(targetPlayer)
    end

    -- Deal damage on server
    targetHum:TakeDamage(finalDamage)

    -- Check for kill
    if targetHum.Health <= 0 then
        self:OnKill(shooter, targetModel, hitData, mult >= GameData.Combat.HeadshotMultiplier)
    end

    -- Weapon special effects
    if wDef.Flags.chainLightning and wDef.Stats.ChainTargets then
        self:ApplyChainLightning(targetModel, finalDamage * 0.5, wDef.Stats.ChainTargets - 1)
    end
    if wDef.Flags.burnEffect then
        self:ApplyStatusEffect(targetPlayer or targetModel, "Burning")
    end
    if wDef.Flags.empEffect and math.random() < (wDef.Stats.EMPChance or 0) then
        self:ApplyStatusEffect(targetPlayer or targetModel, "EMPStun")
    end
end

-- ── On Kill ───────────────────────────────────────────────────────────────────
function CombatManager:OnKill(killer, targetModel, hitData, isHeadshot)
    local data = _playerManager:GetData(killer)
    if not data then return end

    -- Stat tracking
    data.Stats.TotalKills = (data.Stats.TotalKills or 0) + 1
    if isHeadshot then
        data.Stats.HeadshotKills = (data.Stats.HeadshotKills or 0) + 1
    end

    -- Award kill XP (base 50 + headshot bonus)
    local xp = 50 + (isHeadshot and 20 or 0)
    _playerManager:AwardXP(killer, xp)

    _remotes:WaitForChild(NetworkEvents.S2C.EnemyKilled):FireClient(killer,
        { targetId = hitData.targetId, headshot = isHeadshot, xpAwarded = xp }
    )
end

-- ── Chain Lightning ───────────────────────────────────────────────────────────
function CombatManager:ApplyChainLightning(origin, damage, chainCount)
    if chainCount <= 0 then return end
    local pos = origin:GetModelCFrame().Position
    local radius = 20

    for _, char in ipairs(workspace:GetDescendants()) do
        if chainCount <= 0 then break end
        if char:IsA("Model") and char ~= origin then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 then
                if (hrp.Position - pos).Magnitude <= radius then
                    hum:TakeDamage(math.floor(damage))
                    chainCount = chainCount - 1
                end
            end
        end
    end
end

-- ── Status Effects ────────────────────────────────────────────────────────────
function CombatManager:ApplyStatusEffect(target, effectId)
    local effectDef = GameData.StatusEffects[effectId]
    if not effectDef then return end

    if target:IsA("Player") then
        local uid = target.UserId
        if not _statusEffects[uid] then _statusEffects[uid] = {} end
        _statusEffects[uid][effectId] = {
            expiresAt = tick() + effectDef.duration,
            def       = effectDef,
        }
        _remotes:WaitForChild(NetworkEvents.S2C.StatusEffectApplied):FireClient(target,
            effectId, effectDef.duration
        )
    else
        -- NPC: apply via humanoid TakeDamage tick
        local hum = target:FindFirstChildOfClass("Humanoid")
        if hum and effectDef.tickDamage then
            task.spawn(function()
                local endTime = tick() + effectDef.duration
                while tick() < endTime and hum.Health > 0 do
                    hum:TakeDamage(effectDef.tickDamage)
                    task.wait(1)
                end
            end)
        end
    end
end

-- ── Overdrive ─────────────────────────────────────────────────────────────────
function CombatManager:HandleActivateOverdrive(player)
    local uid  = player.UserId
    local data = _playerManager:GetData(player)
    if not data then return end

    -- Check overdrive on cooldown
    local state = _overdriveState[uid]
    if state and state.active then return end
    if state and state.cooldownUntil and tick() < state.cooldownUntil then return end

    -- Get overdrive definition
    local overdriveId  = GameData.ClassBaseStats[data.Class].OverdriveId
    local overdriveDef = GameData.Overdrives[overdriveId]
    if not overdriveDef then return end

    -- Check energy cost
    local energy = _energyValues[uid] or 0
    if energy < overdriveDef.EnergyCost then
        _remotes:WaitForChild(NetworkEvents.S2C.HUDNotification):FireClient(player,
            "Insufficient energy for " .. overdriveDef.DisplayName, 3, "error"
        )
        return
    end
    _energyValues[uid] = energy - overdriveDef.EnergyCost

    -- Activate
    local expiresAt = tick() + overdriveDef.Duration
    _overdriveState[uid] = {
        active        = true,
        overdriveId   = overdriveId,
        expiresAt     = expiresAt,
        cooldownUntil = expiresAt + overdriveDef.Cooldown,
        effects       = overdriveDef.Effects,
    }

    -- Tell client
    _remotes:WaitForChild(NetworkEvents.S2C.OverdriveActivated):FireClient(player,
        overdriveId, overdriveDef.Duration, overdriveDef.Effects
    )

    -- Apply identity load delta
    local IdentityLoadMod = require(Modules:WaitForChild("IdentityLoad"))
    local ilDelta = IdentityLoadMod.OverdriveILDelta(overdriveId)
    if ilDelta ~= 0 then
        data.IdentityLoad = math.max(0, data.IdentityLoad + ilDelta)
        _remotes:WaitForChild(NetworkEvents.S2C.IdentityLoadChanged):FireClient(player,
            data.IdentityLoad, data.IdentityLoadMax
        )
    end

    -- Track overdrive use stat
    data.Stats.OverdriveUses = (data.Stats.OverdriveUses or 0) + 1

    -- Schedule end
    task.delay(overdriveDef.Duration, function()
        if _overdriveState[uid] and _overdriveState[uid].active then
            _overdriveState[uid].active = false
            _remotes:WaitForChild(NetworkEvents.S2C.OverdriveEnded):FireClient(player, overdriveId)
        end
    end)

    -- Android Ghost Sync: spawn ghost decoys
    if overdriveId == "GhostSync" and overdriveDef.Effects.GhostCount then
        self:SpawnGhostDecoys(player, overdriveDef.Effects.GhostCount, overdriveDef.Duration)
    end

    print("[CombatManager]", player.Name, "activated", overdriveId)
end

-- ── Ghost Decoys (Android Ghost Sync) ────────────────────────────────────────
function CombatManager:SpawnGhostDecoys(player, count, duration)
    local char = player.Character
    if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for i = 1, count do
        -- Simplified: create a named part at offset positions
        -- In full implementation this would be a proper ghost model
        local ghost = Instance.new("Part")
        ghost.Name     = "GhostDecoy_" .. i
        ghost.Anchored = false
        ghost.CanCollide = false
        ghost.Size     = Vector3.new(2, 5, 1)
        ghost.Transparency = 0.5
        ghost.BrickColor   = BrickColor.new("Electric blue")
        ghost.CFrame       = hrp.CFrame * CFrame.new(math.random(-8, 8), 0, math.random(-8, 8))
        ghost.Parent       = workspace

        game:GetService("Debris"):AddItem(ghost, duration)
    end
end

-- ── Secondary Tool ────────────────────────────────────────────────────────────
function CombatManager:HandleUseSecondary(player, toolId, targetPos)
    local data = _playerManager:GetData(player)
    if not data then return end
    if data.Weapons.Secondary ~= toolId then return end

    local tool = WeaponData.GetById(toolId)
    if not tool then return end

    -- Validate position is within range
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Basic range check: don't let tools be placed impossibly far
    if targetPos and (hrp.Position - targetPos).Magnitude > 100 then return end

    -- Each tool has unique behavior
    if tool.Flags.deployable then
        -- Spawn a world part at targetPos representing the deployed tool
        self:DeployTool(player, tool, targetPos)
    elseif tool.Flags.healing then
        -- Apply healing to player
        local heal = tool.Stats.HealAmount or 60
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.Health = math.min(hum.MaxHealth, hum.Health + heal)
        end
    elseif tool.Flags.cloak then
        -- Tell client to enter cloak visual state
        _remotes:WaitForChild(NetworkEvents.S2C.StatusEffectApplied):FireClient(player,
            "Cloak", tool.Stats.Duration
        )
    elseif tool.Flags.tether then
        -- Tether fires a harpoon: if targetPos is near a character, pull that character
        self:FireTether(player, tool, targetPos)
    end

    print("[CombatManager]", player.Name, "used secondary:", toolId)
end

-- ── Deploy Tool ───────────────────────────────────────────────────────────────
function CombatManager:DeployTool(player, tool, position)
    if not position then return end

    local part = Instance.new("Part")
    part.Name     = "Deployed_" .. tool.Id
    part.Anchored = true
    part.CanCollide = false
    part.Size     = Vector3.new(1, 1, 1)
    part.Position = position
    part.Parent   = workspace

    local duration = tool.Stats.Duration or 30
    game:GetService("Debris"):AddItem(part, duration)

    -- Specific effects per tool type
    if tool.Flags.barrier then
        part.Size        = Vector3.new(tool.Stats.Width or 3, tool.Stats.Height or 2.5, 0.2)
        part.Material    = Enum.Material.ForceField
        part.Transparency= 0.4
        part.BrickColor  = BrickColor.new("Bright blue")
    elseif tool.Flags.empEffect then
        -- EMP detonates after a short fuse
        task.delay(0.5, function()
            if part and part.Parent then
                local center = part.Position
                part:Destroy()
                -- Affect all humanoids in radius
                local radius = tool.Stats.EMPRadius or 10
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("Humanoid") then
                        local hrp = obj.Parent:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - center).Magnitude <= radius then
                            obj:TakeDamage(0)  -- EMP: disable systems not HP
                            local targetPlayer = Players:GetPlayerFromCharacter(obj.Parent)
                            if targetPlayer then
                                self:ApplyStatusEffect(targetPlayer, "EMPStun")
                            end
                        end
                    end
                end
            end
        end)
    end
end

-- ── Tether Harpoon ────────────────────────────────────────────────────────────
function CombatManager:FireTether(player, tool, targetPos)
    -- Check if anything is near targetPos
    local radius = 3
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Parent ~= player.Character then
            local hrp = obj.Parent:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - targetPos).Magnitude <= radius then
                -- Pull target toward player
                local char = player.Character
                if not char then return end
                local myHRP = char:FindFirstChild("HumanoidRootPart")
                if not myHRP then return end

                local pullDir  = (myHRP.Position - hrp.Position).Unit
                local pullForce= tool.Stats.PullForce or 80
                local bv = Instance.new("BodyVelocity")
                bv.Velocity        = pullDir * pullForce
                bv.MaxForce        = Vector3.new(1e4, 1e4, 1e4)
                bv.Parent          = hrp
                game:GetService("Debris"):AddItem(bv, 0.3)

                obj:TakeDamage(tool.Stats.Damage or 20)
                return
            end
        end
    end

    -- No target: pull player toward target position
    local char = player.Character
    if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local pullDir = (targetPos - hrp.Position).Unit
    local bv = Instance.new("BodyVelocity")
    bv.Velocity        = pullDir * 60
    bv.MaxForce        = Vector3.new(1e4, 1e4, 1e4)
    bv.Parent          = hrp
    game:GetService("Debris"):AddItem(bv, 0.4)
end

-- ── Body System Activation ────────────────────────────────────────────────────
function CombatManager:HandleBodySystemActivation(player, augId)
    local data = _playerManager:GetData(player)
    if not data then return end

    -- Verify player has this aug equipped
    local equipped = false
    for _, id in pairs(data.Augmentations) do
        if id == augId then equipped = true; break end
    end
    if not equipped then return end

    local aug = require(Modules:WaitForChild("AugmentationData")).GetById(augId)
    if not aug then return end

    -- Handle per-aug active abilities
    if aug.Flags.weaponMount == "WristRail" then
        -- Rail shot is handled via FireWeapon, nothing special here
    elseif aug.Flags.weaponMount == "MissileLauncher" then
        -- Missile launch already handled via FireWeapon
    elseif aug.Stats.NeuralScrambler then
        -- Activate scrambler aura
        _remotes:WaitForChild(NetworkEvents.S2C.StatusEffectApplied):FireClient(player,
            "NeuralScrambler_Active", 8
        )
    end
end

-- ── Public API ────────────────────────────────────────────────────────────────
function CombatManager:GetOverdriveState(player)
    return _overdriveState[player.UserId]
end

function CombatManager:IsInCombat(player)
    -- Combat state is managed by PlayerManager's combat timer
    return false  -- delegate to PlayerManager
end

function CombatManager:GetEnergy(player)
    return _energyValues[player.UserId] or 0
end

function CombatManager:DrainEnergy(player, amount)
    local uid = player.UserId
    _energyValues[uid] = math.max(0, (_energyValues[uid] or 0) - amount)
end

function CombatManager:DamagePlayer(player, amount, damageType, sourceId)
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:TakeDamage(amount)
    end
    _remotes:WaitForChild(NetworkEvents.S2C.TakeDamage):FireClient(player, amount, damageType, sourceId)
    _playerManager:SetCombatTimestamp(player)
end

return CombatManager
