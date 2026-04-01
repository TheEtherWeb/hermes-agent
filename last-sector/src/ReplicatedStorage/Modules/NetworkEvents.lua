-- NetworkEvents.lua
-- Central registry of all RemoteEvent and RemoteFunction names used
-- between client and server. Both sides require this module to stay in sync.
-- Actual RemoteEvent instances are created by Main.server.lua on startup.

local NetworkEvents = {}

-- ─── RemoteEvent Names ───────────────────────────────────────────────────────
-- Server → Client (FireClient / FireAllClients)
NetworkEvents.S2C = {
    -- Player state
    PlayerDataLoaded        = "PlayerDataLoaded",         -- initial data sync on join
    PlayerDataUpdated       = "PlayerDataUpdated",        -- partial update (credits, XP, etc.)
    LevelUp                 = "LevelUp",                  -- level gained notification
    IdentityLoadChanged     = "IdentityLoadChanged",      -- IL update

    -- Combat
    TakeDamage              = "TakeDamage",               -- { amount, damageType, source }
    StatusEffectApplied     = "StatusEffectApplied",      -- { effectId, duration }
    StatusEffectRemoved     = "StatusEffectRemoved",
    OverdriveActivated      = "OverdriveActivated",       -- { overdriveId, duration }
    OverdriveEnded          = "OverdriveEnded",
    EnemyKilled             = "EnemyKilled",              -- for kill feed / stats

    -- Mission
    MissionStarted          = "MissionStarted",           -- { missionId, missionData }
    MissionObjectiveUpdated = "MissionObjectiveUpdated",  -- { objectiveId, progress }
    MissionCompleted        = "MissionCompleted",         -- { missionId, rewards }
    MissionFailed           = "MissionFailed",
    IncursionTriggered      = "IncursionTriggered",       -- surprise incursion start
    IncursionEnded          = "IncursionEnded",

    -- Factions
    FactionRepChanged       = "FactionRepChanged",        -- { factionId, newRep, delta }
    FactionUnlocked         = "FactionUnlocked",          -- crossed a rep tier

    -- Augmentations
    AugEquipped             = "AugEquipped",              -- { slot, augId }
    AugUnequipped           = "AugUnequipped",
    AugUnlocked             = "AugUnlocked",              -- new aug in inventory
    StatsRecalculated       = "StatsRecalculated",        -- full stat table pushed

    -- World / Narrative
    MemoryFragmentFound     = "MemoryFragmentFound",      -- { fragmentId, content }
    NarrativeFlagSet        = "NarrativeFlagSet",
    FlashbackTriggered      = "FlashbackTriggered",       -- IL-based memory event
    DialogueGlitch          = "DialogueGlitch",           -- visual/audio corruption
    NPCReactionChanged      = "NPCReactionChanged",       -- NPC changes behavior toward player

    -- UI/UX
    HUDNotification         = "HUDNotification",          -- { text, duration, severity }
    ShowClassSelect         = "ShowClassSelect",           -- first login
    BossEncounterStarted    = "BossEncounterStarted",     -- { bossId, bossData }
    BossPhaseChanged        = "BossPhaseChanged",
    BossDefeated            = "BossDefeated",
}

-- Client → Server (FireServer)
NetworkEvents.C2S = {
    -- Player setup
    SelectClass             = "SelectClass",              -- { classId }
    SetDisplayName          = "SetDisplayName",

    -- Combat
    FireWeapon              = "FireWeapon",               -- { weaponId, origin, direction, hit }
    ActivateOverdrive       = "ActivateOverdrive",
    UseSecondary            = "UseSecondary",             -- { toolId, targetPosition }
    ReloadWeapon            = "ReloadWeapon",
    ActivateBodySystem      = "ActivateBodySystem",       -- aug-based active ability

    -- Augmentations
    RequestEquipAug         = "RequestEquipAug",          -- { slot, augId }
    RequestUnequipAug       = "RequestUnequipAug",        -- { slot }
    RequestPurchaseAug      = "RequestPurchaseAug",       -- { augId }

    -- Weapons
    RequestPurchaseWeapon   = "RequestPurchaseWeapon",
    RequestEquipWeapon      = "RequestEquipWeapon",       -- { lane, weaponId }

    -- Missions
    AcceptMission           = "AcceptMission",            -- { missionId }
    AbandonMission          = "AbandonMission",
    ObjectiveInteract       = "ObjectiveInteract",        -- { objectiveId, targetId }
    RequestIncursionJoin    = "RequestIncursionJoin",

    -- Faction
    RequestFactionContract  = "RequestFactionContract",

    -- World
    CollectMemoryFragment   = "CollectMemoryFragment",    -- { fragmentId }
    MakeNarrativeChoice     = "MakeNarrativeChoice",      -- { choiceId, option }
    InteractWithNPC         = "InteractWithNPC",          -- { npcId }
    HackTarget              = "HackTarget",               -- { targetId, hackPower }

    -- Debug (disabled in production)
    DebugGiveCredits        = "DebugGiveCredits",
    DebugSetIL              = "DebugSetIL",
    DebugSetClass           = "DebugSetClass",
}

-- ─── RemoteFunction Names ────────────────────────────────────────────────────
-- Client calls server, server returns value
NetworkEvents.RF = {
    GetPlayerData           = "GetPlayerData",            -- returns ClientSnapshot
    GetMissionList          = "GetMissionList",           -- { factionId? } → list
    GetAugCatalog           = "GetAugCatalog",            -- { slot? } → list
    GetWeaponCatalog        = "GetWeaponCatalog",
    GetFactionStatus        = "GetFactionStatus",         -- all faction reps + tiers
    GetBossLore             = "GetBossLore",              -- { bossId } → lore text
    GetMemoryFragment       = "GetMemoryFragment",        -- { fragmentId } → content
    ValidateHack            = "ValidateHack",             -- { targetId } → bool + result
}

return NetworkEvents
