-- PlayerManager.lua (ModuleScript, required by Main.server.lua)
-- Handles player join/leave, DataStore persistence, stat application,
-- passive regeneration, and broadcasting state updates to clients.

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules           = ReplicatedStorage:WaitForChild("Modules")
local GameData          = require(Modules:WaitForChild("GameData"))
local PlayerDataModule  = require(Modules:WaitForChild("PlayerData"))
local AugmentationData  = require(Modules:WaitForChild("AugmentationData"))
local IdentityLoad      = require(Modules:WaitForChild("IdentityLoad"))
local NetworkEvents     = require(Modules:WaitForChild("NetworkEvents"))

local PlayerManager = {}
PlayerManager.__index = PlayerManager

-- ── Internal state ────────────────────────────────────────────────────────────
local _store        = nil   -- DataStore instance
local _remotes      = nil   -- RemoteFolder reference
local _playerData   = {}    -- [userId] = data table (server-authoritative)
local _combatTimers = {}    -- [userId] = last damage timestamp

local DATASTORE_KEY_PREFIX = "LSPlayer_v1_"
local SAVE_INTERVAL        = 60   -- auto-save every 60 seconds
local _saveTimers          = {}   -- [userId] = time since last save

-- ── Init ─────────────────────────────────────────────────────────────────────
function PlayerManager:Init(remoteFolder)
    _remotes = remoteFolder
    _store   = DataStoreService:GetDataStore("LastSectorPlayerData_v1")

    Players.PlayerAdded:Connect(function(player)
        self:OnPlayerJoin(player)
    end)
    Players.PlayerRemoving:Connect(function(player)
        self:OnPlayerLeave(player)
    end)

    -- Handle players who joined before this script ran
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function() self:OnPlayerJoin(player) end)
    end

    -- Wire C2S events
    local function getRemote(name)
        return _remotes:WaitForChild(name)
    end

    getRemote(NetworkEvents.C2S.SelectClass).OnServerEvent:Connect(function(player, classId)
        self:HandleSelectClass(player, classId)
    end)
    getRemote(NetworkEvents.C2S.SetDisplayName).OnServerEvent:Connect(function(player, name)
        self:HandleSetDisplayName(player, name)
    end)

    -- RemoteFunction: GetPlayerData
    _remotes:WaitForChild(NetworkEvents.RF.GetPlayerData).OnServerInvoke = function(player)
        local data = _playerData[player.UserId]
        if data then return PlayerDataModule.ClientSnapshot(data) end
        return nil
    end
end

-- ── Player Join ───────────────────────────────────────────────────────────────
function PlayerManager:OnPlayerJoin(player)
    local userId = player.UserId
    local key    = DATASTORE_KEY_PREFIX .. userId

    local data
    local success, result = pcall(function()
        return _store:GetAsync(key)
    end)

    if success and result then
        data = result
        -- Migrate missing fields from Default
        local default = PlayerDataModule.Default(result.Class)
        for field, value in pairs(default) do
            if data[field] == nil then data[field] = value end
        end
    else
        -- New player
        data = PlayerDataModule.Default()
        print("[PlayerManager] New player:", player.Name)
    end

    _playerData[userId] = data
    _saveTimers[userId] = 0
    _combatTimers[userId] = 0

    -- Apply character if already spawned
    if player.Character then
        self:ApplyStatsToCharacter(player, data)
    end
    player.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        self:ApplyStatsToCharacter(player, data)
    end)

    -- Send initial data to client
    local snap = PlayerDataModule.ClientSnapshot(data)
    _remotes:WaitForChild(NetworkEvents.S2C.PlayerDataLoaded):FireClient(player, snap)

    -- Show class select if new
    if not data.HasChosenClass then
        _remotes:WaitForChild(NetworkEvents.S2C.ShowClassSelect):FireClient(player)
    end

    print("[PlayerManager] Loaded data for:", player.Name, "Class:", data.Class)
end

-- ── Player Leave ──────────────────────────────────────────────────────────────
function PlayerManager:OnPlayerLeave(player)
    local userId = player.UserId
    local data   = _playerData[userId]
    if data then
        self:SaveData(player, data)
    end
    _playerData[userId]   = nil
    _saveTimers[userId]   = nil
    _combatTimers[userId] = nil
end

-- ── Save ──────────────────────────────────────────────────────────────────────
function PlayerManager:SaveData(player, data)
    local key = DATASTORE_KEY_PREFIX .. player.UserId
    local success, err = pcall(function()
        _store:SetAsync(key, data)
    end)
    if not success then
        warn("[PlayerManager] Save failed for", player.Name, ":", err)
    end
end

-- ── Stat Application ─────────────────────────────────────────────────────────
-- Pushes data stats onto the Roblox character humanoid and attributes.
function PlayerManager:ApplyStatsToCharacter(player, data)
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    hum.MaxHealth  = data.MaxHealth
    hum.Health     = data.MaxHealth
    hum.WalkSpeed  = data.MoveSpeed
    hum.JumpPower  = data.JumpPower

    -- Store additional data as attributes for client access
    char:SetAttribute("MaxArmor",      data.MaxArmor)
    char:SetAttribute("MaxEnergy",     data.MaxEnergy)
    char:SetAttribute("IdentityLoad",  data.IdentityLoad)
    char:SetAttribute("Class",         data.Class)
    char:SetAttribute("Level",         data.Level)
end

-- ── Stat Recalculation ────────────────────────────────────────────────────────
-- Called after aug changes. Recomputes all derived stats and pushes to client.
function PlayerManager:RecalculateStats(player)
    local data = _playerData[player.UserId]
    if not data then return end

    local classStats = GameData.ClassBaseStats[data.Class]
    local lvl        = data.Level
    local gains      = GameData.LevelStatGains

    -- Base from class
    local maxHP     = classStats.MaxHealth  + (lvl - 1) * gains.MaxHealth
    local maxArmor  = classStats.MaxArmor   + (lvl - 1) * gains.MaxArmor
    local maxEnergy = classStats.MaxEnergy  + (lvl - 1) * gains.MaxEnergy
    local speed     = classStats.MoveSpeed
    local jump      = classStats.JumpPower
    local regenRate = classStats.RegenRate
    local energyRegen = classStats.EnergyRegen

    -- Apply aug bonuses
    for slot, augId in pairs(data.Augmentations) do
        if augId then
            local aug = AugmentationData.GetById(augId)
            if aug and aug.Stats then
                maxHP     = maxHP     + (aug.Stats.MaxHealth  or 0)
                maxArmor  = maxArmor  + (aug.Stats.MaxArmor   or 0)
                maxEnergy = maxEnergy + (aug.Stats.EnergyMax  or 0)
                speed     = speed     + (aug.Stats.SpeedBonus or 0)
                regenRate = regenRate + (aug.Stats.RegenRate  or 0)
                energyRegen = energyRegen + (aug.Stats.EnergyRegen or 0)
                jump      = jump + (aug.Stats.JumpBonus or 0)
                jump      = jump * (1 + (aug.Stats.JumpBonus or 0))
            end
        end
    end

    -- Apply IL strain penalties
    local penalties = IdentityLoad.GetStrainPenalties(data.IdentityLoad, data.Class)
    energyRegen = energyRegen + (penalties.EnergyRegen or 0)
    regenRate   = regenRate   + (penalties.RegenRate   or 0)

    -- Write back
    data.MaxHealth   = math.max(50,  maxHP)
    data.MaxArmor    = math.max(0,   maxArmor)
    data.MaxEnergy   = math.max(20,  maxEnergy)
    data.MoveSpeed   = math.clamp(speed, 8, 50)
    data.JumpPower   = math.clamp(jump, 30, 100)
    data._regenRate  = math.max(0, regenRate)
    data._energyRegen= math.max(0, energyRegen)

    -- Recalc IL
    data.IdentityLoad = IdentityLoad.Calculate(data.Augmentations, data.Class, AugmentationData)

    -- Update character
    self:ApplyStatsToCharacter(player, data)

    -- Broadcast to client
    local snap = PlayerDataModule.ClientSnapshot(data)
    _remotes:WaitForChild(NetworkEvents.S2C.PlayerDataUpdated):FireClient(player, snap)
    _remotes:WaitForChild(NetworkEvents.S2C.StatsRecalculated):FireClient(player, snap)
    _remotes:WaitForChild(NetworkEvents.S2C.IdentityLoadChanged):FireClient(player, data.IdentityLoad, data.IdentityLoadMax)
end

-- ── Passive Tick ─────────────────────────────────────────────────────────────
function PlayerManager:Tick(dt)
    for _, player in ipairs(Players:GetPlayers()) do
        local userId = player.UserId
        local data   = _playerData[userId]
        if not data then continue end

        -- Auto-save
        _saveTimers[userId] = (_saveTimers[userId] or 0) + dt
        if _saveTimers[userId] >= SAVE_INTERVAL then
            _saveTimers[userId] = 0
            task.spawn(function() self:SaveData(player, data) end)
        end

        -- Passive health/energy regen
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local outOfCombat = (tick() - (_combatTimers[userId] or 0)) > GameData.Combat.OutOfCombatTime
                local regenRate   = data._regenRate or GameData.ClassBaseStats[data.Class].RegenRate

                if outOfCombat and hum.Health < hum.MaxHealth then
                    hum.Health = math.min(hum.MaxHealth, hum.Health + regenRate * dt)
                end
            end
        end

        -- Passive IL checks: narrative flag triggers
        if data.IdentityLoad >= 300 and not data.ActiveFlags["il_fracture_warned"] then
            PlayerDataModule.SetFlag(data, "il_fracture_warned")
            _remotes:WaitForChild(NetworkEvents.S2C.HUDNotification):FireClient(player,
                "Identity fracture threshold reached. The city is reading you differently.",
                5, "warning"
            )
        end
    end
end

-- ── Handlers ─────────────────────────────────────────────────────────────────
function PlayerManager:HandleSelectClass(player, classId)
    local data = _playerData[player.UserId]
    if not data then return end
    if data.HasChosenClass then return end  -- can't re-select after first choice

    if not GameData.ClassBaseStats[classId] then
        warn("[PlayerManager] Invalid class:", classId)
        return
    end

    local default = PlayerDataModule.Default(classId)
    -- Preserve existing identity fields
    default.DisplayName = data.DisplayName
    _playerData[player.UserId] = default

    self:RecalculateStats(player)
    local snap = PlayerDataModule.ClientSnapshot(default)
    _remotes:WaitForChild(NetworkEvents.S2C.PlayerDataLoaded):FireClient(player, snap)
    print("[PlayerManager]", player.Name, "selected class:", classId)
end

function PlayerManager:HandleSetDisplayName(player, name)
    local data = _playerData[player.UserId]
    if not data then return end
    -- Sanitize: trim, clamp length
    name = tostring(name):sub(1, 24):match("^%s*(.-)%s*$")
    if #name < 2 then return end
    data.DisplayName = name
end

-- ── Public API used by other managers ────────────────────────────────────────
function PlayerManager:GetData(player)
    return _playerData[player.UserId]
end

function PlayerManager:AwardXP(player, amount)
    local data = _playerData[player.UserId]
    if not data then return end
    local gained = PlayerDataModule.AwardXP(data, amount)
    if gained > 0 then
        _remotes:WaitForChild(NetworkEvents.S2C.LevelUp):FireClient(player, data.Level)
        self:RecalculateStats(player)
    end
    _remotes:WaitForChild(NetworkEvents.S2C.PlayerDataUpdated):FireClient(player,
        { XP = data.XP, Level = data.Level }
    )
end

function PlayerManager:AwardCurrency(player, credits, scrap)
    local data = _playerData[player.UserId]
    if not data then return end
    PlayerDataModule.AwardCurrency(data, credits, scrap)
    _remotes:WaitForChild(NetworkEvents.S2C.PlayerDataUpdated):FireClient(player,
        { Credits = data.Credits, Scrap = data.Scrap }
    )
end

function PlayerManager:AdjustFactionRep(player, changes)
    local data = _playerData[player.UserId]
    if not data then return end
    PlayerDataModule.AdjustRep(data, changes)
    for factionId, delta in pairs(changes) do
        local newRep = data.FactionRep[factionId] or 0
        _remotes:WaitForChild(NetworkEvents.S2C.FactionRepChanged):FireClient(player,
            factionId, newRep, delta
        )
    end
end

function PlayerManager:SetCombatTimestamp(player)
    _combatTimers[player.UserId] = tick()
end

function PlayerManager:SetFlag(player, flag)
    local data = _playerData[player.UserId]
    if not data then return end
    PlayerDataModule.SetFlag(data, flag)
end

function PlayerManager:HasFlag(player, flag)
    local data = _playerData[player.UserId]
    if not data then return false end
    return PlayerDataModule.HasFlag(data, flag)
end

return PlayerManager
