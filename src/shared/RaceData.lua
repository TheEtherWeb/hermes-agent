-- Monster Reincarnation – Race, Origin & Family Data
local RaceData = {}

-- ── Races ────────────────────────────────────────────────────────────────────
RaceData.Races = {
    SpiderlingRunt = {
        DisplayName  = "Spiderling Runt",
        Description  = "A tiny, venomous arachnid with silk-weaving potential.",
        AllowedGrips = {"OneHand", "DualWield"},
        BaseStats = {
            Health=60, Stamina=80, Mana=40,
            Strength=6, Dexterity=14, Vitality=6,
            Intellect=8, Instinct=12, Presence=4,
        },
        FactionBonus = {BeastTribes = 50},
        StartingArea  = "CaveNetwork",
        EvolutionPool = "SpiderTree",
        Traits = {"PoisonResist", "WebClimb", "Ambusher"},
    },

    SlimeBud = {
        DisplayName  = "Slime Bud",
        Description  = "An amorphous creature capable of absorbing attributes.",
        AllowedGrips = {"OneHand", "SpellGrip"},
        BaseStats = {
            Health=90, Stamina=60, Mana=70,
            Strength=5, Dexterity=7, Vitality=14,
            Intellect=10, Instinct=6, Presence=8,
        },
        FactionBonus = {},
        StartingArea  = "MudFens",
        EvolutionPool = "SlimeTree",
        Traits = {"AcidBody", "AbsorbNutrient", "ShapeShift"},
    },

    GoblinRunt = {
        DisplayName  = "Goblin Runt",
        Description  = "Scrappy, cunning, and surprisingly inventive.",
        AllowedGrips = {"OneHand", "DualWield", "TwoHand"},
        BaseStats = {
            Health=75, Stamina=90, Mana=30,
            Strength=9, Dexterity=12, Vitality=8,
            Intellect=9, Instinct=10, Presence=7,
        },
        FactionBonus = {GoblinClans = 100},
        StartingArea  = "GoblinWarrens",
        EvolutionPool = "GoblinTree",
        Traits = {"Scavenger", "TrapSense", "TribeSpeaker"},
    },

    DemonSpark = {
        DisplayName  = "Demon Spark",
        Description  = "A fledgling demon born in the Infernal Realm.",
        AllowedGrips = {"OneHand", "PhantomGrip", "SpellGrip"},
        BaseStats = {
            Health=70, Stamina=70, Mana=100,
            Strength=10, Dexterity=9, Vitality=8,
            Intellect=14, Instinct=9, Presence=10,
        },
        FactionBonus = {DemonCourt = 150},
        StartingArea  = "InfernalRealm",
        EvolutionPool = "DemonTree",
        IsDemon       = true,
        Traits = {"PactSeal", "FireResist", "SoulHarvest"},
    },

    BeastkinCub = {
        DisplayName  = "Beastkin Cub",
        Description  = "A feral hybrid of beast and humanoid, raw and powerful.",
        AllowedGrips = {"TwoHand", "DualWield", "OneHand"},
        BaseStats = {
            Health=100, Stamina=100, Mana=20,
            Strength=14, Dexterity=11, Vitality=12,
            Intellect=6, Instinct=13, Presence=7,
        },
        FactionBonus = {BeastTribes = 120},
        StartingArea  = "WildForest",
        EvolutionPool = "BeastkinTree",
        Traits = {"PackHunter", "FuryStrike", "BeastTongue"},
    },

    UndeadShard = {
        DisplayName  = "Undead Shard",
        Description  = "A fragment of a soul bound to decayed flesh.",
        AllowedGrips = {"OneHand", "TwoHand", "PhantomGrip"},
        BaseStats = {
            Health=110, Stamina=50, Mana=60,
            Strength=11, Dexterity=7, Vitality=16,
            Intellect=7, Instinct=6, Presence=12,
        },
        FactionBonus = {UndeadLegion = 100},
        StartingArea  = "CryptDepths",
        EvolutionPool = "UndeadTree",
        Traits = {"UndeathRegen", "FearAura", "SoulLink"},
    },
}

-- ── Origins ───────────────────────────────────────────────────────────────────
RaceData.Origins = {
    RuinedVillageSurvivor = {
        DisplayName = "Ruined Village Survivor",
        Description = "You crawled from the ashes of your home. Scavenging is second nature.",
        CompatibleRaces = {"SpiderlingRunt", "GoblinRunt", "BeastkinCub"},
        StatBonus    = {Instinct=3, Dexterity=2},
        StartingGold = 15,
        ExtraItem    = "ScrapBlade",
        FactionMod   = {Kingdoms = -50},
        HiddenFlag   = "ScavengerOrigin",
    },

    LabEscape = {
        DisplayName = "Lab Escape",
        Description = "Experimented on by mage-scholars, you broke free. Unnatural power hums in your cells.",
        CompatibleRaces = {"SlimeBud", "DemonSpark"},
        StatBonus    = {Intellect=5, Mana=20},
        StartingGold = 5,
        ExtraItem    = "ManaVial",
        FactionMod   = {MageGuild = -100},
        HiddenFlag   = "LabSubject",
    },

    ForgottenTomb = {
        DisplayName = "Forgotten Tomb",
        Description = "You awakened in a sealed crypt. Ancient knowledge lingers.",
        CompatibleRaces = {"UndeadShard", "GoblinRunt"},
        StatBonus    = {Vitality=4, Presence=3},
        StartingGold = 10,
        ExtraItem    = "TombRune",
        FactionMod   = {UndeadLegion = 50},
        HiddenFlag   = "TombOrigin",
    },

    InfernalPact = {
        DisplayName = "Infernal Pact",
        Description = "Born of an ancient bargain, your blood carries demonic ink.",
        CompatibleRaces = {"DemonSpark", "GoblinRunt"},
        StatBonus    = {Intellect=3, Presence=4},
        StartingGold = 0,
        ExtraItem    = "BlankContract",
        FactionMod   = {DemonCourt = 100, Kingdoms = -75},
        HiddenFlag   = "PactOrigin",
    },

    BloodyBattlefield = {
        DisplayName = "Bloody Battlefield",
        Description = "Hatched amid war, you are forged from conflict.",
        CompatibleRaces = {"BeastkinCub", "GoblinRunt", "SpiderlingRunt"},
        StatBonus    = {Strength=4, Stamina=15},
        StartingGold = 20,
        ExtraItem    = "BoneClub",
        FactionMod   = {},
        HiddenFlag   = "WarOrigin",
    },

    MysticGrove = {
        DisplayName = "Mystic Grove",
        Description = "Nurtured by ancient tree-spirits; magic flows in your veins.",
        CompatibleRaces = {"SlimeBud", "BeastkinCub"},
        StatBonus    = {Mana=30, Intellect=4},
        StartingGold = 8,
        ExtraItem    = "GroveSeed",
        FactionMod   = {BeastTribes = 60},
        HiddenFlag   = "GroveOrigin",
    },
}

-- ── Family Definitions ────────────────────────────────────────────────────────
-- Families are seeded randomly on roll; these define the pool.
RaceData.Families = {
    Skullsmash = {
        Crest       = "skull_smash",
        PassiveBonus= {Strength=2},
        UniquePassive= "BerserkThreshold",  -- enter berserk at <20% HP
        Renown      = 0,
    },
    Voidthread = {
        Crest       = "void_thread",
        PassiveBonus= {Dexterity=2},
        UniquePassive= "ShadowStep",
        Renown      = 0,
    },
    Ironmarrow = {
        Crest       = "iron_marrow",
        PassiveBonus= {Vitality=2},
        UniquePassive= "BoneShield",
        Renown      = 0,
    },
    CrimsonHex = {
        Crest       = "crimson_hex",
        PassiveBonus= {Intellect=2},
        UniquePassive= "FireCharm",
        Renown      = 0,
    },
    SilverMaw  = {
        Crest       = "silver_maw",
        PassiveBonus= {Instinct=2},
        UniquePassive= "PreyScent",
        Renown      = 0,
    },
    StoneBlood  = {
        Crest       = "stone_blood",
        PassiveBonus= {Vitality=3, Strength=1},
        UniquePassive= "Immovable",
        Renown      = 0,
    },
    NightVeil   = {
        Crest       = "night_veil",
        PassiveBonus= {Instinct=3},
        UniquePassive= "DarkAdaptation",
        Renown      = 0,
    },
    AncientBlood = {
        Crest        = "ancient_blood",
        PassiveBonus = {Presence=3},
        UniquePassive= "AncientAuthority",
        Renown       = 500,   -- starts with renown
        IsRare       = true,
    },
}

RaceData.FamilyPool = {}
for name, _ in pairs(RaceData.Families) do
    if not RaceData.Families[name].IsRare then
        table.insert(RaceData.FamilyPool, name)
    end
end
RaceData.RareFamilyPool = {"AncientBlood"}
RaceData.RARE_FAMILY_CHANCE = 0.05  -- 5% chance

return RaceData
