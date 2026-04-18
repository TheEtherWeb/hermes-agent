-- Monster Reincarnation – Evolution Tree Definitions
local C = require(script.Parent.Constants)
local H = C.HIDDEN_STAT_THRESHOLD

local EvolutionData = {}

--[[
Each node:
  parent      – parent node id (nil = root)
  displayName – shown in UI
  description – flavour text
  statBonus   – applied on evolve
  traitGained – list of trait ids added
  unlockCond  – function(hiddenStats, stats, playerData) → bool
  isSecret    – hidden in tree until unlocked
  isUltimate  – final cap node
  pool        – which tree this belongs to
--]]

EvolutionData.Nodes = {

    -- ═══════════════════════════════════════════════════════════════════════
    -- SPIDER TREE
    -- ═══════════════════════════════════════════════════════════════════════
    SpiderlingRunt = {
        pool = "SpiderTree", parent = nil,
        displayName = "Spiderling Runt", description = "Your base form – fragile but venomous.",
        statBonus = {}, traitGained = {},
        unlockCond = function() return true end,
    },

    VenomWeaver = {
        pool = "SpiderTree", parent = "SpiderlingRunt",
        displayName = "Venom Weaver",
        description = "Your venom glands hypertrophy. Bites carry paralysing neurotoxin.",
        statBonus = {Dexterity=4, Intellect=3},
        traitGained = {"ParalyticVenom", "VenomSpit"},
        unlockCond = function(h) return h.PoisonDmgDealt >= H.POISON_MASTERY end,
    },

    SilkStalker = {
        pool = "SpiderTree", parent = "SpiderlingRunt",
        displayName = "Silk Stalker",
        description = "Mastery of silk navigation gives you unmatched terrain control.",
        statBonus = {Dexterity=5, Instinct=3},
        traitGained = {"WebWalker", "SilkLasso"},
        unlockCond = function(h) return h.SilkTraversals >= H.SILK_TRAVERSALS end,
    },

    BoneWidow = {
        pool = "SpiderTree", parent = "VenomWeaver",
        displayName = "Bone Widow",
        description = "You have consumed your way up the skeleton of countless prey.",
        statBonus = {Strength=5, Vitality=4},
        traitGained = {"BoneCrunch", "OsseousArmour"},
        unlockCond = function(h) return h.BoneKills >= H.BONE_KILLS end,
    },

    MirrorArachnid = {
        pool = "SpiderTree", parent = "SilkStalker",
        displayName = "Mirror Arachnid",
        description = "SECRET: Your body mirrors enemy forms, confusing attackers.",
        statBonus = {Dexterity=6, Instinct=5},
        traitGained = {"Mirage", "IllusionWeb"},
        isSecret = true,
        unlockCond = function(h, stats, p)
            -- defeat three identical enemies simultaneously (flagged by server)
            return p and p.SpecialFlags and p.SpecialFlags.TripleKill == true
        end,
    },

    Broodmother = {
        pool = "SpiderTree", parent = "BoneWidow",
        displayName = "Broodmother",
        description = "ULTIMATE: The hive is yours. Spawn minions endlessly.",
        statBonus = {Presence=10, Vitality=8, Strength=6},
        traitGained = {"EggSac", "HiveMind", "SpiderSwarm"},
        isUltimate = true,
        unlockCond = function(h, stats, p)
            return p and p.FollowerCount and p.FollowerCount >= 20
        end,
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- SLIME TREE
    -- ═══════════════════════════════════════════════════════════════════════
    SlimeBud = {
        pool = "SlimeTree", parent = nil,
        displayName = "Slime Bud", description = "Nascent slime – weak but absorbent.",
        statBonus = {}, traitGained = {},
        unlockCond = function() return true end,
    },

    AcidSlime = {
        pool = "SlimeTree", parent = "SlimeBud",
        displayName = "Acid Slime",
        description = "Your body generates corrosive acid that melts through armour.",
        statBonus = {Intellect=5, Strength=3},
        traitGained = {"AcidBody", "CorrosiveSpit"},
        unlockCond = function(h) return h.AcidStat >= H.ACID_STAT_CAP end,
    },

    CorpseSlime = {
        pool = "SlimeTree", parent = "SlimeBud",
        displayName = "Corpse Slime",
        description = "You absorb the dead, wearing their memories and strength.",
        statBonus = {Vitality=6, Strength=4},
        traitGained = {"CorpseAbsorb", "RotAura"},
        unlockCond = function(h) return h.CorpsesConsumed >= H.CORPSE_CONSUMED end,
    },

    MimicSlime = {
        pool = "SlimeTree", parent = "CorpseSlime",
        displayName = "Mimic Slime",
        description = "You replicate enemy forms perfectly for a short duration.",
        statBonus = {Dexterity=5, Presence=4},
        traitGained = {"FormCopy", "SneakMimic"},
        unlockCond = function(h) return h.HumanInvasions >= H.HUMAN_INVASIONS end,
    },

    ArcaneSlime = {
        pool = "SlimeTree", parent = "AcidSlime",
        displayName = "Arcane Slime",
        description = "Magic saturates your form; you become a living mana battery.",
        statBonus = {Intellect=8, Mana=50},
        traitGained = {"ManaAbsorption", "SpellConduit"},
        unlockCond = function(h) return h.SpellCasts >= H.SPELL_CASTS
            and h.ManaAbsorbed >= H.MANA_ABSORBED end,
    },

    SlimeSovereign = {
        pool = "SlimeTree", parent = "ArcaneSlime",
        displayName = "Slime Sovereign",
        description = "ULTIMATE: The dungeon expands with your mass. You rule the formless.",
        statBonus = {Presence=12, Vitality=10, Intellect=8},
        traitGained = {"DungeonBody", "FormlessKing", "AbsorbAll"},
        isUltimate = true,
        unlockCond = function(h, stats, p)
            local evols = p and p.PreviousEvolutions or {}
            local count = 0
            for _ in pairs(evols) do count = count + 1 end
            return count >= 2 and p.DungeonRooms and p.DungeonRooms >= 15
        end,
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- GOBLIN TREE
    -- ═══════════════════════════════════════════════════════════════════════
    GoblinRunt = {
        pool = "GoblinTree", parent = nil,
        displayName = "Goblin Runt", description = "Weak and small – but smarter than you look.",
        statBonus = {}, traitGained = {},
        unlockCond = function() return true end,
    },

    GoblinScout = {
        pool = "GoblinTree", parent = "GoblinRunt",
        displayName = "Goblin Scout",
        description = "Your ambush tactics are unrivalled. Strike first, vanish fast.",
        statBonus = {Dexterity=5, Instinct=4},
        traitGained = {"AmbushStrike", "SmokePouch"},
        unlockCond = function(h) return h.AmbushesDone >= H.AMBUSHES_DONE end,
    },

    TinkerGoblin = {
        pool = "GoblinTree", parent = "GoblinRunt",
        displayName = "Tinker Goblin",
        description = "Contraptions and traps bend to your whims.",
        statBonus = {Intellect=5, Dexterity=3},
        traitGained = {"TrapExpert", "BombToss"},
        unlockCond = function(h) return h.TrapsCrafted >= H.TRAPS_CRAFTED end,
    },

    WolfRider = {
        pool = "GoblinTree", parent = "GoblinScout",
        displayName = "Wolf Rider",
        description = "You have mastered the bond between goblin and beast.",
        statBonus = {Strength=4, Instinct=4},
        traitGained = {"BeastBond", "MountedCharge"},
        unlockCond = function(h) return h.BeastsBonded >= H.BEASTS_BONDED end,
    },

    HobgoblinCaptain = {
        pool = "GoblinTree", parent = "TinkerGoblin",
        displayName = "Hobgoblin Captain",
        description = "You lead goblin warbands with tactical precision.",
        statBonus = {Strength=5, Presence=5, Vitality=4},
        traitGained = {"WarCry", "TacticalCommand"},
        unlockCond = function(h) return h.SoldiersLed >= H.SOLDIERS_LED end,
    },

    GoblinShaman = {
        pool = "GoblinTree", parent = "WolfRider",
        displayName = "Goblin Shaman",
        description = "SECRET: Ancient spirits answer your war-paint.",
        statBonus = {Intellect=6, Mana=40, Presence=4},
        traitGained = {"SpiritTotem", "HexCurse"},
        isSecret = true,
        unlockCond = function(h, stats, p)
            return p and p.SpecialFlags and p.SpecialFlags.BeastSpirit == true
        end,
    },

    GoblinKing = {
        pool = "GoblinTree", parent = "HobgoblinCaptain",
        displayName = "Goblin King",
        description = "ULTIMATE: A sovereign of the wilds, your name makes kingdoms tremble.",
        statBonus = {Presence=12, Strength=8, Vitality=7},
        traitGained = {"KinglyAura", "TribalConquest", "RoyalEdict"},
        isUltimate = true,
        unlockCond = function(h, stats, p)
            return h.TerritoryConquered >= H.TERRITORY_CONQUERED
                and h.ChiefsAsLt >= H.CHIEFS_AS_LIEUTENANTS
        end,
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- DEMON TREE
    -- ═══════════════════════════════════════════════════════════════════════
    DemonSpark = {
        pool = "DemonTree", parent = nil,
        displayName = "Demon Spark", description = "The merest ember of infernal power.",
        statBonus = {}, traitGained = {},
        unlockCond = function() return true end,
    },

    ImmortalFlame = {
        pool = "DemonTree", parent = "DemonSpark",
        displayName = "Immortal Flame",
        description = "Your body ignites; fire no longer harms you.",
        statBonus = {Intellect=5, Mana=30},
        traitGained = {"FireImmunity", "FlameTouch"},
        unlockCond = function(h, stats) return stats.Mana >= 80 end,
    },

    ShadowDemon = {
        pool = "DemonTree", parent = "DemonSpark",
        displayName = "Shadow Demon",
        description = "You slip between shadow and reality.",
        statBonus = {Dexterity=5, Instinct=5},
        traitGained = {"Phasethrough", "ShadowStep"},
        unlockCond = function(h) return h.DarknessMinutes >= 60 end,
    },

    DemonLord = {
        pool = "DemonTree", parent = "ImmortalFlame",
        displayName = "Demon Lord",
        description = "ULTIMATE: Your presence reshapes reality. Contracts bind entire regions.",
        statBonus = {Presence=14, Intellect=10, Mana=80},
        traitGained = {"DomainAura", "MassPact", "InfernalEdge"},
        isUltimate = true,
        unlockCond = function(h, stats, p)
            local contracts = p and p.CompletedContracts or 0
            return contracts >= 10 and stats.Mana >= 150
        end,
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- BEASTKIN TREE
    -- ═══════════════════════════════════════════════════════════════════════
    BeastkinCub = {
        pool = "BeastkinTree", parent = nil,
        displayName = "Beastkin Cub", description = "Feral and raw, your strength is just awakening.",
        statBonus = {}, traitGained = {},
        unlockCond = function() return true end,
    },

    ApexPredator = {
        pool = "BeastkinTree", parent = "BeastkinCub",
        displayName = "Apex Predator",
        description = "You have climbed the food chain. Others flee from you.",
        statBonus = {Strength=7, Dexterity=5},
        traitGained = {"TerrifyingRoar", "BloodFrenzy"},
        unlockCond = function(h, stats, p)
            local kills = p and p.TotalKills or 0
            return kills >= 200
        end,
    },

    PackAlpha = {
        pool = "BeastkinTree", parent = "BeastkinCub",
        displayName = "Pack Alpha",
        description = "Your bond with beasts is absolute. A word summons a hunting party.",
        statBonus = {Presence=6, Instinct=5},
        traitGained = {"AlphaCall", "PackBond"},
        unlockCond = function(h) return h.BeastsBonded >= 10 end,
    },

    BeastKing = {
        pool = "BeastkinTree", parent = "PackAlpha",
        displayName = "Beast King",
        description = "ULTIMATE: All beasts answer to you. You are the living wild.",
        statBonus = {Strength=10, Presence=10, Vitality=8},
        traitGained = {"WildDominion", "BeastlordAura", "PrimordialRoar"},
        isUltimate = true,
        unlockCond = function(h, stats, p)
            return h.BeastsBonded >= 25 and h.SoldiersLed >= 30
        end,
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- UNDEAD TREE
    -- ═══════════════════════════════════════════════════════════════════════
    UndeadShard = {
        pool = "UndeadTree", parent = nil,
        displayName = "Undead Shard", description = "A broken soul clinging to undeath.",
        statBonus = {}, traitGained = {},
        unlockCond = function() return true end,
    },

    Revenant = {
        pool = "UndeadTree", parent = "UndeadShard",
        displayName = "Revenant",
        description = "Hatred sustains you. The more you suffer, the stronger you become.",
        statBonus = {Vitality=7, Strength=5},
        traitGained = {"HatredFuel", "DeathRattle"},
        unlockCond = function(h) return h.AmbushesSurvived >= H.AMBUSH_SURVIVAL end,
    },

    LichKing = {
        pool = "UndeadTree", parent = "Revenant",
        displayName = "Lich King",
        description = "ULTIMATE: Your soul is unbound. You raise armies from the dead.",
        statBonus = {Presence=14, Intellect=10, Vitality=10},
        traitGained = {"PhylacteryBond", "UndeadLegion", "SoulDrain"],
        isUltimate = true,
        unlockCond = function(h, stats, p)
            local undead = p and p.UndeadFollowers or 0
            return undead >= 20 and stats.Presence >= 20
        end,
    },
}

-- ── Helper: get all direct children of a node ────────────────────────────────
function EvolutionData.GetChildren(nodeId)
    local children = {}
    for id, data in pairs(EvolutionData.Nodes) do
        if data.parent == nodeId then
            table.insert(children, id)
        end
    end
    return children
end

-- ── Helper: check if a player meets unlock conditions ────────────────────────
function EvolutionData.CanEvolve(nodeId, hiddenStats, stats, playerData)
    local node = EvolutionData.Nodes[nodeId]
    if not node then return false end
    return node.unlockCond(hiddenStats, stats, playerData)
end

return EvolutionData
