-- Monster Reincarnation – Shared Constants
local Constants = {}

-- ── Versioning ──────────────────────────────────────────────────────────────
Constants.DATA_VERSION = 1
Constants.SAVE_INTERVAL = 60          -- seconds between auto-saves
Constants.DATASTORE_KEY_PREFIX = "MR_v1_"

-- ── Stat Scaling ────────────────────────────────────────────────────────────
Constants.BASE_HEALTH = 100
Constants.VITALITY_HP_SCALE = 10     -- +10 HP per Vitality point
Constants.BASE_STAMINA = 100
Constants.STAMINA_REGEN_RATE = 8     -- per second
Constants.BASE_MANA = 50
Constants.MANA_REGEN_RATE = 3        -- per second
Constants.POSTURE_MAX = 100
Constants.POSTURE_REGEN_RATE = 5

-- ── Combat ──────────────────────────────────────────────────────────────────
Constants.HIT_COOLDOWN = 0.15        -- minimum seconds between registered hits
Constants.PARRY_WINDOW = 0.25        -- seconds a parry is active
Constants.PARRY_STAMINA_COST = 20
Constants.BLOCK_DAMAGE_REDUCTION = 0.5
Constants.GRIP_SWITCH_COOLDOWN = 0.4

Constants.GRIP = {
    TWO_HAND  = "TwoHand",
    ONE_HAND  = "OneHand",
    DUAL_WIELD = "DualWield",
    SPELL_GRIP = "SpellGrip",
    PHANTOM    = "PhantomGrip",
}

Constants.GRIP_POSTURE_MULTIPLIER = {
    TwoHand   = 1.6,
    OneHand   = 1.0,
    DualWield = 0.8,
    SpellGrip = 0.5,
    PhantomGrip = 1.2,
}

Constants.GRIP_STAMINA_COST = {
    TwoHand   = 22,
    OneHand   = 14,
    DualWield = 18,  -- per swing (fast but drains)
    SpellGrip = 10,
    PhantomGrip = 20,
}

-- ── Mastery ──────────────────────────────────────────────────────────────────
Constants.MASTERY_XP_PER_HIT = 1
Constants.MASTERY_XP_PER_KILL = 10
Constants.MASTERY_LEVELS = {
    [1]  = 0,
    [2]  = 150,
    [3]  = 400,
    [4]  = 900,
    [5]  = 1800,
    [6]  = 3200,
    [7]  = 5500,
    [8]  = 9000,
    [9]  = 14000,
    [10] = 20000,
}

-- ── Weapon Persona ───────────────────────────────────────────────────────────
Constants.PERSONA_XP_PER_KILL = 15
Constants.PERSONA_XP_PER_USE  = 1
Constants.PERSONA_AWAKEN_THRESHOLD = {100, 300, 700, 1500, 3000}
Constants.WEAPON_CHRONICLE_MAX_ENTRIES = 100

-- ── Evolution ────────────────────────────────────────────────────────────────
Constants.HIDDEN_STAT_THRESHOLD = {
    POISON_MASTERY    = 500,   -- total poison dmg dealt
    DARKNESS_ADAPT    = 30,    -- minutes in dark areas
    AMBUSH_SURVIVAL   = 25,    -- ambushes survived
    CORPSE_CONSUMED   = 100,
    BONE_KILLS        = 50,
    SILK_TRAVERSALS   = 10,
    ACID_STAT_CAP     = 80,    -- acid attack stat value
    SPELL_CASTS       = 100,
    HUMAN_INVASIONS   = 5,
    MANA_ABSORBED     = 300,
    AMBUSHES_DONE     = 30,
    TRAPS_CRAFTED     = 10,
    BEASTS_BONDED     = 5,
    SOLDIERS_LED      = 50,
    TERRITORY_CONQUERED = 1,
    CHIEFS_AS_LIEUTENANTS = 5,
}

-- ── Guild ────────────────────────────────────────────────────────────────────
Constants.GUILD_MAX_MEMBERS = 50
Constants.GUILD_SCORE_RESET_DAYS = 30
Constants.GUILD_SCORE_BOSS_KILL = 50
Constants.GUILD_SCORE_MOB_KILL  = 2
Constants.GUILD_SCORE_PVP_KILL  = 10
Constants.GUILD_BASE_SUMMON_RANGE = 5  -- studs from flat wall

Constants.GUILD_RANK = {
    RECRUIT    = 0,
    FOOTMAN    = 1,
    OFFICER    = 2,
    LIEUTENANT = 3,
    LEADER     = 4,
}

Constants.GUILD_RANK_SCORE = {
    [0] = 0,
    [1] = 100,
    [2] = 500,
    [3] = 1000,
    [4] = 2500,
}

-- ── Faction ──────────────────────────────────────────────────────────────────
Constants.FACTION_REP_MAX =  1000
Constants.FACTION_REP_MIN = -1000
Constants.FACTION_HOSTILE_THRESHOLD = -200
Constants.FACTION_ALLY_THRESHOLD    =  400

Constants.FACTION = {
    BEAST_TRIBES    = "BeastTribes",
    DEMON_COURT     = "DemonCourt",
    MAGE_GUILD      = "MageGuild",
    KINGDOMS        = "Kingdoms",
    CENTRAL_AUTH    = "CentralAuthority",
    GOBLIN_CLANS    = "GoblinClans",
    UNDEAD_LEGION   = "UndeadLegion",
}

-- ── Dungeon / Lair ────────────────────────────────────────────────────────────
Constants.DUNGEON_ROOM_TYPES = {
    "BroodChamber",
    "TrapHall",
    "Workshop",
    "Mausoleum",
    "Library",
    "ThroneRoom",
    "Barracks",
    "NutrientPool",
    "RitualPit",
    "SilkNest",
    "PactChamber",
    "Vault",
}

Constants.DUNGEON_ROOM_COST = {
    BroodChamber  = {stone=20, bone=10},
    TrapHall      = {iron=15, stone=10},
    Workshop      = {iron=20, wood=15},
    Mausoleum     = {bone=30, darkEssence=5},
    Library       = {wood=25, mana=10},
    ThroneRoom    = {stone=50, gold=20},
    Barracks      = {iron=25, wood=10},
    NutrientPool  = {slimeMass=20, water=15},
    RitualPit     = {darkEssence=15, bone=20},
    SilkNest      = {silk=30, wood=10},
    PactChamber   = {soulCrystal=5, darkEssence=20},
    Vault         = {iron=40, stone=30},
}

Constants.DUNGEON_MAX_ROOMS  = 30
Constants.DUNGEON_CLAIM_ITEM = "DungeonHeart"

-- ── Economy ───────────────────────────────────────────────────────────────────
Constants.AUCTION_FEE_RATE = 0.10     -- 10% listing fee
Constants.AUCTION_DURATION = 172800   -- 48 hours in seconds
Constants.TRADE_TIMEOUT    = 60       -- seconds for a trade offer to expire

-- ── Dynasty ───────────────────────────────────────────────────────────────────
Constants.INHERITANCE_CURRENCY_FRACTION = 0.25   -- child gets 25% of parent gold
Constants.INHERITANCE_XP_FRACTION       = 0.10
Constants.DYNASTY_SCORE_PER_GEN         = 100

-- ── Demon Contracts ──────────────────────────────────────────────────────────
Constants.CONTRACT_MAX_ACTIVE    = 1    -- per player
Constants.CONTRACT_SOUL_CAP      = 10   -- max corruption stacks
Constants.DEMON_OVERWORLD_TICKS  = 7200 -- base seconds a demon can stay

-- ── Tower ─────────────────────────────────────────────────────────────────────
Constants.TOWER_MAX_FLOORS      = 30
Constants.TOWER_BOSS_FLOORS     = {10, 20, 30}
Constants.TOWER_RESET_DAYS      = 30
Constants.TOWER_FLOOR_GUILD_XP  = 25

-- ── Mentor ────────────────────────────────────────────────────────────────────
Constants.MENTOR_MIN_POWER_LEVEL = 20
Constants.MENTOR_XP_REWARD       = 50
Constants.MENTOR_MAX_PAIRS       = 1

-- ── Sanity Limits (anti-exploit) ─────────────────────────────────────────────
Constants.MAX_STAT_VALUE       = 9999
Constants.MAX_GOLD             = 9999999
Constants.MAX_DAMAGE_PER_HIT   = 5000
Constants.MAX_HEAL_PER_TICK    = 500
Constants.MAX_INVENTORY_SLOTS  = 40
Constants.MAX_FOLLOWERS        = 100

return Constants
