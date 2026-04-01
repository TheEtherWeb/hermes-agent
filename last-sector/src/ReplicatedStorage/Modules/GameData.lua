-- GameData.lua
-- Core constants, enumerations, and configuration for Last Sector.
-- This module is shared between server and client.

local GameData = {}

-- ─── Version ────────────────────────────────────────────────────────────────
GameData.VERSION = "0.1.0"
GameData.GAME_NAME = "Last Sector"

-- ─── Player Classes ──────────────────────────────────────────────────────────
GameData.Classes = {
    HUMAN   = "Human",
    CYBORG  = "Cyborg",
    ANDROID = "Android",
}

-- Base stats per class at level 1.
-- These are multiplied/modified by augmentations and level scaling.
GameData.ClassBaseStats = {
    Human = {
        MaxHealth          = 150,
        MaxArmor           = 40,
        MaxEnergy          = 80,       -- Energy for overdrives and tools
        MoveSpeed          = 22,
        SprintMultiplier   = 1.6,
        JumpPower          = 52,
        IdentityLoadMax    = 100,      -- Human has lowest IL cap; slow accumulation
        IdentityLoadRate   = 0.4,      -- IL gain per aug tier equipped
        SocialBlend        = 90,       -- % chance security ignores player passively
        HackResist         = 30,
        EMPResist          = 20,
        RegenRate          = 4,        -- HP/s out of combat
        EnergyRegen        = 6,
        OverdriveId        = "BreakState",
    },
    Cyborg = {
        MaxHealth          = 200,
        MaxArmor           = 80,
        MaxEnergy          = 120,
        MoveSpeed          = 20,
        SprintMultiplier   = 1.7,
        JumpPower          = 50,
        IdentityLoadMax    = 300,
        IdentityLoadRate   = 1.0,
        SocialBlend        = 55,
        HackResist         = 50,
        EMPResist          = 55,
        RegenRate          = 3,
        EnergyRegen        = 8,
        OverdriveId        = "Overclock",
    },
    Android = {
        MaxHealth          = 180,
        MaxArmor           = 100,
        MaxEnergy          = 160,
        MoveSpeed          = 21,
        SprintMultiplier   = 1.75,
        JumpPower          = 54,
        IdentityLoadMax    = 600,
        IdentityLoadRate   = 1.8,
        SocialBlend        = 30,
        HackResist         = 80,
        EMPResist          = 75,
        RegenRate          = 5,        -- Module-assisted repair
        EnergyRegen        = 12,
        OverdriveId        = "GhostSync",
    },
}

-- ─── Augmentation Slot Types ─────────────────────────────────────────────────
GameData.AugSlots = {
    ARMS          = "Arms",
    LEGS          = "Legs",
    SPINE         = "Spine",
    HEAD          = "Head",
    INTERNALS     = "Internals",
}

-- ─── Weapon Lane Types ───────────────────────────────────────────────────────
GameData.WeaponLanes = {
    PRIMARY   = "Primary",
    SECONDARY = "Secondary",
    BODY      = "Body",
    OVERDRIVE = "Overdrive",
}

-- ─── Augmentation Philosophy / Origin Tiers ──────────────────────────────────
-- Where an aug came from affects IL cost, stability, and faction reactions.
GameData.AugOrigins = {
    CORPORATE  = "Corporate",   -- Clean, monitored, high IL cost
    MILITARY   = "Military",    -- Brutal, efficient, power-hungry
    SALVAGE    = "Salvage",     -- Weird, unstable, highly customizable
    RELIGIOUS  = "Religious",   -- Elegant, terrifying, cult-locked
    ANDROID    = "Android",     -- Precise, alienating, identity-eroding
}

-- IL cost multipliers per origin
GameData.AugOriginILMult = {
    Corporate = 1.4,
    Military  = 1.2,
    Salvage   = 0.8,
    Religious = 1.6,
    Android   = 2.0,
}

-- ─── Identity Load Thresholds ────────────────────────────────────────────────
-- Affects NPC reactions, faction flags, dialogue glitches, and endings.
GameData.IdentityLoadThresholds = {
    { min = 0,   max = 99,  label = "Intact",       colorHex = "#A8E6CF" },
    { min = 100, max = 199, label = "Augmented",    colorHex = "#FFD93D" },
    { min = 200, max = 299, label = "Compromised",  colorHex = "#FF8C42" },
    { min = 300, max = 399, label = "Fractured",    colorHex = "#E84855" },
    { min = 400, max = 499, label = "Synthetic",    colorHex = "#8338EC" },
    { min = 500, max = 999, label = "Lost Signal",  colorHex = "#3A3A3A" },
}

-- ─── Overdrive Definitions ───────────────────────────────────────────────────
GameData.Overdrives = {
    BreakState = {
        Class       = "Human",
        DisplayName = "Break State",
        Description = "Near-death adrenaline cascade. Accuracy peaks, pain suppression activates, last-resort systems engage. The body becomes terrifyingly precise.",
        Duration    = 12,   -- seconds
        EnergyCost  = 60,
        Cooldown    = 90,
        Effects = {
            AccuracyBonus     = 0.40,
            DamageBonus       = 0.30,
            DamageResist      = 0.25,
            MoveSpeedBonus    = 0.20,
            TriggerOnLowHP    = true,   -- auto-triggers at <20% HP
            LowHPThreshold    = 0.20,
        },
    },
    Overclock = {
        Class       = "Cyborg",
        DisplayName = "Overclock",
        Description = "Governor limiters shatter. Recoil becomes momentum. Heat vents blow. Every system pushes past rated capacity for as long as the body can hold it.",
        Duration    = 10,
        EnergyCost  = 80,
        Cooldown    = 75,
        Effects = {
            RecoilConversion  = true,   -- recoil impulse feeds movement burst
            FireRateBonus     = 0.50,
            MoveSpeedBonus    = 0.35,
            HeatGenRate       = 2.0,    -- multiplier on heat buildup
            DamageBonus       = 0.25,
            ArmorIgnore       = 0.15,
        },
    },
    GhostSync = {
        Class       = "Android",
        DisplayName = "Ghost Sync",
        Description = "Memory lattice expands. Ghost routines deploy simultaneously. The android becomes multiple, occupying tactical space in ways that defy targeting logic.",
        Duration    = 15,
        EnergyCost  = 100,
        Cooldown    = 60,
        Effects = {
            GhostCount        = 3,      -- decoy ghosts deployed
            NetworkHackBonus  = 0.60,
            DroneCallCount    = 2,
            InvisibilityPulse = true,   -- brief cloak on activation
            SyncDamageBonus   = 0.20,
            IdentityLoadDrain = 30,     -- consumes IL on use
        },
    },
}

-- ─── Level Scaling ───────────────────────────────────────────────────────────
GameData.MaxLevel = 40

-- XP required to reach each level (index = level)
GameData.LevelXPTable = (function()
    local t = {}
    for i = 1, GameData.MaxLevel do
        -- Curve: ~100 base, scaling up to ~12000 at 40
        t[i] = math.floor(80 * (i ^ 1.65))
    end
    return t
end)()

-- Stat bonus per level (additive on top of class base)
GameData.LevelStatGains = {
    MaxHealth  = 8,
    MaxArmor   = 3,
    MaxEnergy  = 4,
}

-- ─── Damage Types ────────────────────────────────────────────────────────────
GameData.DamageTypes = {
    BALLISTIC = "Ballistic",
    ENERGY    = "Energy",
    BLADE     = "Blade",
    EMP       = "EMP",
    EXPLOSIVE = "Explosive",
    NEURAL    = "Neural",    -- ignores armor, targets identity systems
}

-- Damage type vs. resistance tags
GameData.DamageResistances = {
    Ballistic = "BallisticResist",
    Energy    = "EnergyResist",
    Blade     = "BladeResist",
    EMP       = "EMPResist",
    Explosive = "ExplosiveResist",
    Neural    = "NeuralResist",
}

-- ─── Status Effects ──────────────────────────────────────────────────────────
GameData.StatusEffects = {
    BURNING       = { id = "Burning",      duration = 5,  tickDamage = 6,   damageType = "Energy"   },
    EMP_STUN      = { id = "EMPStun",      duration = 3,  disablesAugs = true                        },
    NANITE_DRAIN  = { id = "NaniteDrain",  duration = 8,  tickDamage = 4,   healEnemy = true         },
    NEURAL_GLITCH = { id = "NeuralGlitch", duration = 4,  invertControls = false, addIL = 10         },
    BLEED         = { id = "Bleed",        duration = 6,  tickDamage = 5,   damageType = "Ballistic" },
    FOAM_ROOT     = { id = "FoamRoot",     duration = 3,  freezesMovement = true                     },
    OVERDRIVE_LOCK= { id = "OverdriveLock",duration = 10, preventsOverdrive = true                   },
}

-- ─── Combat Configuration ────────────────────────────────────────────────────
GameData.Combat = {
    HeadshotMultiplier    = 2.2,
    WeakpointMultiplier   = 1.6,
    MaxFallDamage         = 80,
    FallDamageStartHeight = 20,   -- studs
    OutOfCombatTime       = 5,    -- seconds after last hit before regen starts
    MaxDamageDistance     = 2000, -- studs, raycast max
}

-- ─── Mission Difficulty Tiers ─────────────────────────────────────────────────
GameData.MissionDifficulty = {
    GREY   = { label = "Grey",   xpMult = 1.0, creditMult = 1.0, minLevel = 1  },
    YELLOW = { label = "Yellow", xpMult = 1.5, creditMult = 1.4, minLevel = 8  },
    ORANGE = { label = "Orange", xpMult = 2.0, creditMult = 1.9, minLevel = 16 },
    RED    = { label = "Red",    xpMult = 3.0, creditMult = 2.8, minLevel = 24 },
    BLACK  = { label = "Black",  xpMult = 5.0, creditMult = 5.0, minLevel = 32 },
}

-- ─── Currency ────────────────────────────────────────────────────────────────
GameData.Currency = {
    CREDITS    = "Credits",    -- standard pay, shops
    SCRAP      = "Scrap",      -- salvage currency, black market
    REP_POINTS = "RepPoints",  -- faction-specific, not traded
}

-- ─── Game Events ─────────────────────────────────────────────────────────────
-- Incursion events: the city breaks, everyone nearby gets a quota
GameData.IncursionTypes = {
    { id = "MachineUprising",  label = "Machine Uprising",  description = "Rogue custodian units have gone active in this sector. Neutralize or evacuate." },
    { id = "ColonyBleed",      label = "Colony Bleed",      description = "A hive intelligence is expanding through building infrastructure. Contain it now." },
    { id = "PurgePing",        label = "Purge Ping",        description = "A corporate kill squad has been dispatched to this district. Survive or assist." },
    { id = "SalvageRush",      label = "Salvage Rush",      description = "A sealed vault has cracked open. Extract maximum value before others arrive." },
    { id = "SignalBreak",      label = "Signal Break",      description = "An overseer system has gone silent. Find out why before it comes back wrong." },
    { id = "AndroidIncident",  label = "Android Incident",  description = "A synthetic unit has gone resonant. Apprehend or terminate before cascade." },
    { id = "CultActivation",   label = "Cult Activation",   description = "The machine cult is performing a mass-conversion ritual. Disrupt or witness." },
}

-- ─── NPC Reaction Tags ────────────────────────────────────────────────────────
-- Used by FactionManager to determine NPC behavior based on player IL level
GameData.NPCReactionMatrix = {
    -- { ilMin, ilMax, civilianReact, securityReact, machineReact, cultReact }
    { 0,   99,  "neutral",  "neutral",  "hostile",  "neutral"  },
    { 100, 199, "curious",  "watchful", "hostile",  "curious"  },
    { 200, 299, "nervous",  "alert",    "cautious", "friendly" },
    { 300, 399, "fearful",  "hostile",  "neutral",  "friendly" },
    { 400, 499, "hostile",  "hostile",  "friendly", "reverent" },
    { 500, 999, "fleeing",  "hostile",  "friendly", "reverent" },
}

return GameData
