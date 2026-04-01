-- PlayerData.lua
-- Default player data schema and utility functions.
-- The server stores this in DataStore; the client receives a sanitized copy.

local GameData   = require(script.Parent.GameData)
local WeaponData = require(script.Parent.WeaponData)

local PlayerData = {}

-- ─── Default State ────────────────────────────────────────────────────────────
-- Returns a fresh default player data table.
function PlayerData.Default(class)
    class = class or "Human"
    local baseStats = GameData.ClassBaseStats[class] or GameData.ClassBaseStats.Human
    local loadout   = WeaponData.StartingLoadouts[class] or WeaponData.StartingLoadouts.Human

    return {
        -- ── Identity ──
        Class           = class,
        DisplayName     = "",          -- set on first login
        Level           = 1,
        XP              = 0,
        TotalPlayTime   = 0,           -- seconds

        -- ── Resources ──
        Credits         = 1000,
        Scrap           = 0,

        -- ── Vitals ──
        MaxHealth       = baseStats.MaxHealth,
        MaxArmor        = baseStats.MaxArmor,
        MaxEnergy       = baseStats.MaxEnergy,

        -- ── Movement stats (derived, refreshed on load) ──
        MoveSpeed       = baseStats.MoveSpeed,
        SprintMultiplier= baseStats.SprintMultiplier,
        JumpPower       = baseStats.JumpPower,

        -- ── Identity Load ──
        IdentityLoad    = 0,
        IdentityLoadMax = baseStats.IdentityLoadMax,

        -- ── Augmentation Slots ──
        -- Each slot holds an aug ID or nil.
        Augmentations = {
            Arms      = nil,
            Legs      = nil,
            Spine     = nil,
            Head      = nil,
            Internals = nil,
        },

        -- ── Unlocked Augmentations (IDs the player can purchase/equip) ──
        UnlockedAugs = {},

        -- ── Weapon Loadout ──
        Weapons = {
            Primary   = loadout.primary,
            Secondary = loadout.secondary,
        },

        -- ── Unlocked Weapons ──
        UnlockedWeapons = { loadout.primary, loadout.secondary },

        -- ── Faction Reputation ──
        -- Keys are faction IDs; values are numeric rep scores.
        FactionRep = {
            Axiom       = 0,
            SIA         = 0,
            Liberation  = 0,
            Salvagers   = 0,
            MachineCult = 0,
            Purists     = 0,
            Overseers   = (class == "Android") and 50 or -100,
        },

        -- ── Mission History ──
        CompletedMissions  = {},   -- list of mission IDs
        ActiveMission      = nil,  -- current mission ID or nil
        IncursionCount     = 0,    -- total incursion events participated in

        -- ── Statistics ──
        Stats = {
            TotalKills       = 0,
            BossKills        = 0,
            MissionsComplete = 0,
            OverdriveUses    = 0,
            AugChanges       = 0,
            SalvageCollected = 0,
            NeuralDamageDealt= 0,
            HeadshotKills    = 0,
        },

        -- ── Settings / Flags ──
        HasChosenClass     = (class ~= nil),
        TutorialComplete   = false,
        ActiveFlags        = {},   -- narrative flags set by choices

        -- ── Memory Fragments ──
        -- Lore collectibles found in the world.
        MemoryFragments    = {},
    }
end

-- ─── Level-Up ────────────────────────────────────────────────────────────────
function PlayerData.CanLevelUp(data)
    if data.Level >= GameData.MaxLevel then return false end
    local required = GameData.LevelXPTable[data.Level]
    return data.XP >= required
end

function PlayerData.LevelUp(data)
    if not PlayerData.CanLevelUp(data) then return false end
    local gains = GameData.LevelStatGains
    data.Level      = data.Level + 1
    data.MaxHealth  = data.MaxHealth  + gains.MaxHealth
    data.MaxArmor   = data.MaxArmor   + gains.MaxArmor
    data.MaxEnergy  = data.MaxEnergy  + gains.MaxEnergy
    -- Remove the XP spent on this level
    data.XP = data.XP - GameData.LevelXPTable[data.Level - 1]
    return true
end

-- ─── XP Award ────────────────────────────────────────────────────────────────
-- Applies XP and handles any resulting level-ups. Returns levels gained.
function PlayerData.AwardXP(data, amount)
    if data.Level >= GameData.MaxLevel then return 0 end
    data.XP = data.XP + amount
    local levelsGained = 0
    while PlayerData.CanLevelUp(data) do
        PlayerData.LevelUp(data)
        levelsGained = levelsGained + 1
    end
    return levelsGained
end

-- ─── Credit / Scrap Management ───────────────────────────────────────────────
function PlayerData.AwardCurrency(data, credits, scrap)
    data.Credits = data.Credits + (credits or 0)
    data.Scrap   = data.Scrap   + (scrap   or 0)
end

function PlayerData.CanAfford(data, credits, scrap)
    return data.Credits >= (credits or 0) and data.Scrap >= (scrap or 0)
end

function PlayerData.Spend(data, credits, scrap)
    if not PlayerData.CanAfford(data, credits, scrap) then return false end
    data.Credits = data.Credits - (credits or 0)
    data.Scrap   = data.Scrap   - (scrap   or 0)
    return true
end

-- ─── Faction Rep ─────────────────────────────────────────────────────────────
function PlayerData.AdjustRep(data, changes)
    -- changes = { FactionId = delta, ... }
    if not changes then return end
    for factionId, delta in pairs(changes) do
        if data.FactionRep[factionId] ~= nil then
            data.FactionRep[factionId] = data.FactionRep[factionId] + delta
        end
    end
end

-- ─── Flag Management ─────────────────────────────────────────────────────────
function PlayerData.SetFlag(data, flag)
    data.ActiveFlags[flag] = true
end

function PlayerData.HasFlag(data, flag)
    return data.ActiveFlags[flag] == true
end

-- ─── Aug Slot Validation ──────────────────────────────────────────────────────
function PlayerData.CanEquipAug(data, augId, AugmentationData)
    -- Must own the aug
    local owned = false
    for _, id in ipairs(data.UnlockedAugs) do
        if id == augId then owned = true; break end
    end
    if not owned then return false, "Aug not unlocked" end

    local aug = AugmentationData.GetById(augId)
    if not aug then return false, "Aug not found" end

    -- Android-architecture augs require android class
    if aug.Flags.androidArchitecture and data.Class ~= "Android" then
        return false, "Requires Android chassis"
    end

    -- Cult-locked augs require MachineCult rep >= 300
    if aug.Flags.cultLocked then
        local cultRep = data.FactionRep["MachineCult"] or 0
        if cultRep < 300 then return false, "Requires Choir Standing (MachineCult 300+)" end
    end

    return true
end

-- ─── Sanitized client snapshot ───────────────────────────────────────────────
-- Returns a copy safe to send to the client (strips no sensitive fields here,
-- but gives a clear pattern for future security separation).
function PlayerData.ClientSnapshot(data)
    return {
        Class            = data.Class,
        DisplayName      = data.DisplayName,
        Level            = data.Level,
        XP               = data.XP,
        Credits          = data.Credits,
        Scrap            = data.Scrap,
        MaxHealth        = data.MaxHealth,
        MaxArmor         = data.MaxArmor,
        MaxEnergy        = data.MaxEnergy,
        MoveSpeed        = data.MoveSpeed,
        JumpPower        = data.JumpPower,
        IdentityLoad     = data.IdentityLoad,
        IdentityLoadMax  = data.IdentityLoadMax,
        Augmentations    = data.Augmentations,
        UnlockedAugs     = data.UnlockedAugs,
        Weapons          = data.Weapons,
        UnlockedWeapons  = data.UnlockedWeapons,
        FactionRep       = data.FactionRep,
        ActiveMission    = data.ActiveMission,
        ActiveFlags      = data.ActiveFlags,
        Stats            = data.Stats,
        MemoryFragments  = data.MemoryFragments,
        HasChosenClass   = data.HasChosenClass,
        TutorialComplete = data.TutorialComplete,
    }
end

return PlayerData
