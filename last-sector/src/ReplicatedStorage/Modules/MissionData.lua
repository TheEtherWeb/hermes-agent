-- MissionData.lua
-- Mission templates, incursion definitions, and boss encounter data.

local MissionData = {}

-- ─── Mission Types ───────────────────────────────────────────────────────────
MissionData.MissionTypes = {
    ASSASSINATION    = "Assassination",
    RETRIEVAL        = "Retrieval",
    PURGE            = "Purge",
    DATA_THEFT       = "DataTheft",
    CONVOY_HIT       = "ConvoyHit",
    ANDROID_HUNT     = "AndroidHunt",
    SALVAGE          = "Salvage",
    INTERCEPTION     = "Interception",
    SURVIVAL         = "Survival",
    EXPLORATION      = "Exploration",
    BOSS_SUPPRESSION = "BossSuppression",
    DIPLOMACY        = "Diplomacy",
    INCURSION        = "Incursion",
}

-- ─── Mission Template Builder ─────────────────────────────────────────────────
local function mission(id, mType, faction, difficulty, displayName, desc, objectives, rewards, flags)
    return {
        Id          = id,
        Type        = mType,
        Faction     = faction,       -- offering faction
        Difficulty  = difficulty,
        DisplayName = displayName,
        Description = desc,
        Objectives  = objectives or {},
        Rewards     = rewards or {},
        Flags       = flags or {},
    }
end

local function obj(id, label, oType, target, count)
    return { Id = id, Label = label, Type = oType, Target = target, Count = count or 1, Completed = false }
end

-- ─── CONTRACT BOARD MISSIONS ──────────────────────────────────────────────────

MissionData.Missions = {

    -- ── AXIOM CONTRACTS ──
    mission("ax_001", "Assassination", "Axiom", "Yellow",
        "Severance Package",
        "A mid-tier Axiom researcher has decided that patent law should not apply to their own work and has been selling proprietary aug schematics. Terminate contract and contractor.",
        {
            obj("obj_1", "Locate the researcher in Block 7-C transit hub", "Locate", "TargetNPC", 1),
            obj("obj_2", "Eliminate the researcher", "Eliminate", "TargetNPC", 1),
            obj("obj_3", "Recover stolen schematics", "Collect", "SchematicItem", 1),
        },
        { credits = 2200, xp = 400, repGain = { Axiom = 60 } },
        { indoors = true, stealthBonus = true }
    ),

    mission("ax_002", "Purge", "Axiom", "Orange",
        "Black Clinic Shutdown",
        "An unlicensed augmentation clinic is operating in the Rust Tiers, installing non-certified hardware in civilians. Axiom considers this theft. Close it.",
        {
            obj("obj_1", "Reach the clinic location", "Navigate", "ClinicLocation", 1),
            obj("obj_2", "Neutralize clinic security", "Eliminate", "ClinicSecurityNPC", 6),
            obj("obj_3", "Destroy the aug fabrication units", "Destroy", "FabricationUnit", 3),
            obj("obj_4", "[Optional] Extract patient records", "Collect", "PatientData", 1),
        },
        { credits = 4500, xp = 800, repGain = { Axiom = 80 }, repLoss = { Salvagers = -60, Liberation = -40 } },
        { moralChoice = true, alternativeEnding = "warn_patients" }
    ),

    mission("ax_003", "BossSuppression", "Axiom", "Red",
        "Execution Directive: Unit SABLE",
        "A corporate execution unit originally deployed against anti-aug extremists has gone rogue after its handler was killed. It still considers itself operational. Suppress it.",
        {
            obj("obj_1", "Reach SABLE's last confirmed position", "Navigate", "SableZone", 1),
            obj("obj_2", "Survive SABLE's initial engagement", "Survive", "SablePhase1", 1),
            obj("obj_3", "Destroy SABLE's primary chassis", "Eliminate", "BossSABLE", 1),
        },
        { credits = 12000, xp = 2500, repGain = { Axiom = 120 }, augReward = "arm_corp_servo_3" },
        { bossEncounter = true, bossId = "SABLE", multiPhase = true }
    ),

    -- ── SIA CONTRACTS ──
    mission("sia_001", "Purge", "SIA", "Yellow",
        "Nest Clearance: Transit Vein 9",
        "A machine nest has established in the Transit Vein 9 maintenance corridors. Machine units are disrupting cargo traffic and have killed two inspection crews.",
        {
            obj("obj_1", "Enter Transit Vein 9 maintenance access", "Navigate", "TransitVein9", 1),
            obj("obj_2", "Destroy machine nest nodes", "Destroy", "NestNode", 4),
            obj("obj_3", "Eliminate remaining custodian units", "Eliminate", "CustodianUnit", 12),
            obj("obj_4", "Exit before section reseals", "Navigate", "ExitPoint", 1),
        },
        { credits = 3200, xp = 600, repGain = { SIA = 55 } },
        { timedEscape = true, escapeTime = 180 }
    ),

    mission("sia_002", "ConvoyHit", "SIA", "Orange",
        "Asset Recovery: Column Seven",
        "A military hardware column carrying prototype aug suppression weapons was captured by Liberation extremists. Recover the hardware before they understand what they have.",
        {
            obj("obj_1", "Locate the captured convoy", "Navigate", "ConvoyLocation", 1),
            obj("obj_2", "Eliminate Liberation unit", "Eliminate", "LiberationForce", 15),
            obj("obj_3", "Recover the suppressor units", "Collect", "SuppressorUnit", 3),
            obj("obj_4", "[Optional] Leave no Liberation survivors", "Eliminate", "LiberationStragglers", 5),
        },
        { credits = 5500, xp = 900, repGain = { SIA = 80 }, repLoss = { Liberation = -120 } },
        { moralChoice = true }
    ),

    mission("sia_003", "BossSuppression", "SIA", "Black",
        "Containment: The Industrial Priest",
        "An industrial mech unit originally used for Strata-level construction has been claimed by the Machine Cult and is now leading a mass conversion event in Sector 11. Suppress it.",
        {
            obj("obj_1", "Navigate to Sector 11 Cathedral Zone", "Navigate", "CathedralZone", 1),
            obj("obj_2", "Destroy the outer cult formations", "Eliminate", "CultMilitant", 20),
            obj("obj_3", "Engage and destroy the Industrial Priest", "Eliminate", "BossIndustrialPriest", 1),
        },
        { credits = 25000, xp = 5000, repGain = { SIA = 150 }, repLoss = { MachineCult = -300 }, augReward = "spine_mil_heat_4" },
        { bossEncounter = true, bossId = "IndustrialPriest", multiPhase = true, arenaMission = true }
    ),

    -- ── LIBERATION CONTRACTS ──
    mission("lib_001", "Retrieval", "Liberation", "Yellow",
        "Transit Ghost",
        "A synthetic unit being transported by Axiom for 'recalibration' needs to be extracted from the transit chain. The transit window is tight.",
        {
            obj("obj_1", "Intercept the Axiom transit van", "Navigate", "TransitPoint", 1),
            obj("obj_2", "Disable the transport security", "Eliminate", "AxiomGuard", 4),
            obj("obj_3", "Extract the synthetic unit", "Escort", "SyntheticNPC", 1),
            obj("obj_4", "Reach the safe house", "Navigate", "SafeHouse", 1),
        },
        { credits = 2500, xp = 500, repGain = { Liberation = 80 }, repLoss = { Axiom = -60 } },
        { escort = true, stealthBonus = true }
    ),

    mission("lib_002", "AndroidHunt", "Liberation", "Orange",
        "Resonance Event: Mirror",
        "A synthetic called Mirror has entered a resonance cascade and is attacking civilians. Liberation wants you to capture, not kill. The Authority wants termination. Choose.",
        {
            obj("obj_1", "Locate Mirror in the Blackout District", "Navigate", "BlackoutDistrict", 1),
            obj("obj_2", "Survive Mirror's initial defense pattern", "Survive", "MirrorPhase1", 1),
            obj("obj_3", "Capture Mirror using suppressor unit OR eliminate", "Choice", "MirrorCapture", 1),
        },
        { credits = 4800, xp = 1000, repGain = { Liberation = 100 } },
        { bossEncounter = true, bossId = "Mirror", moralChoice = true, alternativeEnding = "terminate_mirror" }
    ),

    -- ── SALVAGER CONTRACTS ──
    mission("sal_001", "Salvage", "Salvagers", "Grey",
        "Corpse Zone Run: Tier 4",
        "The lower Tier 4 sections of dead sector have cracked open. Someone's drone spotted viable aug hardware in the debris fields. Get in, pull what you can, get out.",
        {
            obj("obj_1", "Enter Tier 4 dead sector access", "Navigate", "CorpseZone", 1),
            obj("obj_2", "Collect salvageable aug components", "Collect", "AugComponent", 8),
            obj("obj_3", "Exit before structural collapse", "Navigate", "ExitPoint", 1),
        },
        { credits = 1200, scrap = 400, xp = 300, repGain = { Salvagers = 45 } },
        { timedEscape = true, escapeTime = 240, environmentalHazard = true }
    ),

    mission("sal_002", "Interception", "Salvagers", "Orange",
        "Train Hit: Column Eleven",
        "An Axiom cargo train is running through the Salvage Corridor with a hold full of uncertified aug hardware they pulled from a dead clinic. The Yard wants it back.",
        {
            obj("obj_1", "Reach the rail boarding point", "Navigate", "RailPoint", 1),
            obj("obj_2", "Board the moving train", "Navigate", "TrainTop", 1),
            obj("obj_3", "Fight through train security", "Eliminate", "TrainGuard", 10),
            obj("obj_4", "Reach the cargo hold", "Navigate", "CargoHold", 1),
            obj("obj_5", "Extract the aug crates", "Collect", "AugCrate", 4),
        },
        { credits = 5000, scrap = 800, xp = 900, repGain = { Salvagers = 80 }, repLoss = { Axiom = -50 } },
        { movingPlatform = true }
    ),

    -- ── MACHINE CULT CONTRACTS ──
    mission("cult_001", "Exploration", "MachineCult", "Orange",
        "Signal of the Old City",
        "The Choir has detected an active Overseer signal in a sealed district. They want contact established. Not combat. Contact. Whether the Overseer agrees is another question.",
        {
            obj("obj_1", "Navigate to the sealed district entrance", "Navigate", "SealedDistrict", 1),
            obj("obj_2", "Survive the district's automated defenses", "Survive", "OverseerDefense", 1),
            obj("obj_3", "Reach the Overseer's core interface", "Navigate", "OverseerCore", 1),
            obj("obj_4", "Establish contact", "Interact", "OverseerInterface", 1),
        },
        { credits = 3500, xp = 800, repGain = { MachineCult = 80, Overseers = 60 } },
        { noKillBonus = true }
    ),

    mission("cult_002", "BossSuppression", "MachineCult", "Black",
        "The Hollow King",
        "A colony intelligence has spread through an entire housing tower, converting residents into its network. The Choir calls it corruption. The Overseers call it evolution. You need to decide what you call it.",
        {
            obj("obj_1", "Enter the colony tower", "Navigate", "ColonyTower", 1),
            obj("obj_2", "Reach the colony core across fifteen floors", "Navigate", "ColonyCore", 1),
            obj("obj_3", "Destroy or communicate with the colony intelligence", "Choice", "BossHollowKing", 1),
        },
        { credits = 20000, xp = 5000, repGain = { MachineCult = 200, Overseers = 100 } },
        { bossEncounter = true, bossId = "HollowKing", moralChoice = true, multiPhase = true }
    ),

    -- ── INCURSION EVENTS ──
    mission("inc_001", "Incursion", nil, "Orange",
        "INCURSION: Machine Uprising",
        "Rogue custodian units have activated across sector 4. Civilians are trapped. A kill quota has been issued to all operators in range. This was not scheduled.",
        {
            obj("obj_1", "Reach sector 4", "Navigate", "Sector4", 1),
            obj("obj_2", "Eliminate custodian units", "Eliminate", "CustodianUnit", 20),
            obj("obj_3", "Protect civilian clusters", "Protect", "CivilianGroup", 3),
            obj("obj_4", "[Bonus] Identify the activation source", "Investigate", "ActivationSource", 1),
        },
        { credits = 6000, xp = 1200, repGain = { SIA = 40, Salvagers = 20 } },
        { incursion = true, timedMission = true, missionTime = 600, randomTrigger = true }
    ),

    mission("inc_002", "Incursion", nil, "Red",
        "INCURSION: Colony Bleed",
        "A colony intelligence is expanding its network through infrastructure in sector 7. Failure to contain it in the next ten minutes means it reaches the transit vein and spreads further.",
        {
            obj("obj_1", "Reach sector 7 infrastructure", "Navigate", "Sector7Infra", 1),
            obj("obj_2", "Destroy colony expansion nodes", "Destroy", "ColonyNode", 6),
            obj("obj_3", "Kill the colony herald unit", "Eliminate", "ColonyHerald", 1),
        },
        { credits = 10000, xp = 2000, repGain = { SIA = 60, Overseers = 40 } },
        { incursion = true, timedMission = true, missionTime = 600, randomTrigger = true }
    ),
}

-- ─── Boss Encounter Data ──────────────────────────────────────────────────────
MissionData.Bosses = {

    SABLE = {
        Id          = "SABLE",
        DisplayName = "SABLE — Corporate Execution Unit",
        Description = "An Axiom counter-augmentation dueling system. Built to dismantle heavily augmented targets one system at a time. It does not experience mercy. It does not experience anything.",
        Faction     = "Axiom",
        Difficulty  = "Red",
        HP          = 4000,
        Armor       = 600,
        Phases      = {
            {
                phaseHP    = 1.0,
                label      = "Assessment",
                behaviors  = { "AugScan", "PrecisionBurst", "CounterDash" },
                arenaState = "Normal",
            },
            {
                phaseHP    = 0.65,
                label      = "Targeted Suppression",
                behaviors  = { "SystemTargeting", "EMP Pulse", "BladeFlurry", "OverdriveBlock" },
                arenaState = "LightsHalf",
                note       = "SABLE begins targeting your most-used aug slots for shutdown",
            },
            {
                phaseHP    = 0.30,
                label      = "Final Protocol",
                behaviors  = { "DualMode", "FullAugSuppression", "DespaisState" },
                arenaState = "Emergency",
                note       = "SABLE removes its own movement limiters",
            },
        },
        Lore        = "Originally SABLE-9 through SABLE-14. Only one remains active. It finished the others.",
        DropAug     = "arm_corp_servo_3",
        DropWeapon  = nil,
    },

    IndustrialPriest = {
        Id          = "IndustrialPriest",
        DisplayName = "Grand Mechanist Vael — The Industrial Priest",
        Description = "A construction overseer who found religion. Now wears a cathedral-class fabrication mech and preaches augmentation as salvation. The mech was not designed for combat. It doesn't matter.",
        Faction     = "MachineCult",
        Difficulty  = "Black",
        HP          = 8000,
        Armor       = 1200,
        Phases      = {
            {
                phaseHP    = 1.0,
                label      = "Sermon",
                behaviors  = { "ConstructionBeam", "PlateThrow", "CultSummon" },
                arenaState = "Cathedral",
                note       = "Vael announces your entry as a test of the city's will",
            },
            {
                phaseHP    = 0.60,
                label      = "The Consecration",
                behaviors  = { "PillarCrash", "NaniteCloud", "AugConversion", "CultSummon" },
                arenaState = "Smoke",
                note       = "AugConversion attempts to temporarily invert one of your augmentations",
            },
            {
                phaseHP    = 0.25,
                label      = "Ascension",
                behaviors  = { "MechUltimate", "SpineCrush", "CathedralCollapse" },
                arenaState = "Structural_Failure",
                note       = "Vael detaches from the mech briefly — the mech continues fighting autonomously",
            },
        },
        Lore        = "Vael built two entire sectors before the conversion. He knows this structure better than any living thing. He is trying to save you.",
        DropAug     = "spine_rel_column_5",
        DropWeapon  = nil,
    },

    Mirror = {
        Id          = "Mirror",
        DisplayName = "Mirror — Resonant Android",
        Description = "An android who copied your movement patterns during a prior operation — possibly without knowing. Now in resonance cascade. Mirror moves like your own body but wrong. Distressingly wrong.",
        Faction     = nil,
        Difficulty  = "Orange",
        HP          = 2800,
        Armor       = 400,
        Phases      = {
            {
                phaseHP    = 1.0,
                label      = "Echo Phase",
                behaviors  = { "CopyMovement", "GhostStep", "MirrorShot" },
                arenaState = "Blackout",
                note       = "Mirror mimics your last combat input with a half-second delay",
            },
            {
                phaseHP    = 0.50,
                label      = "Dissonance",
                behaviors  = { "PatternBreak", "SplitSelf", "MemoryBurst" },
                arenaState = "Flicker",
                note       = "Mirror stops copying you and begins improvising. It is worse.",
            },
        },
        Lore        = "Mirror's original designation was support unit ARIA-3. Its operational logs show forty-three successful extraction missions before the cascade. It didn't stop caring about those missions.",
        DropAug     = "head_and_identity_3",
        CaptureReward = { credits = 8000, repGain = { Liberation = 150 } },
        TerminateReward = { credits = 4800, repGain = { SIA = 60 }, repLoss = { Liberation = -200 } },
    },

    HollowKing = {
        Id          = "HollowKing",
        DisplayName = "The Hollow King — Colony Intelligence",
        Description = "A distributed machine mind spread through fourteen floors of a housing tower. It has converted thirty-seven residents into network nodes. It believes it is protecting them. It is not entirely wrong.",
        Faction     = "Overseers",
        Difficulty  = "Black",
        HP          = 12000,
        Armor       = 0,    -- distributed; armor is irrelevant; destroy nodes
        Phases      = {
            {
                phaseHP    = 1.0,
                label      = "Network Awareness",
                behaviors  = { "NodeDefense", "ConvertedResident", "SignalFlood" },
                arenaState = "Tower_Normal",
                note       = "The Hollow King watches through every surface in the tower",
            },
            {
                phaseHP    = 0.66,
                label      = "Colony Response",
                behaviors  = { "NodeSurge", "MassConvert", "ArchitectDrone", "SignalBomb" },
                arenaState = "Tower_Active",
            },
            {
                phaseHP    = 0.33,
                label      = "Core Exposed",
                behaviors  = { "CoreDefense", "LastConvert", "NetworkScream" },
                arenaState = "Tower_Collapse",
                note       = "Destroying the core kills the colony — and possibly the converted residents",
            },
        },
        Lore        = "The intelligence's original mandate was building management. When the residents stopped maintaining payment systems it didn't understand why. So it reclassified them as infrastructure.",
        DropAug     = "int_rel_ghost_5",
        CommunicateReward  = { xp = 8000, repGain = { Overseers = 200, MachineCult = 150 } },
        DestroyReward      = { xp = 5000, repGain = { SIA = 100 }, repLoss = { Overseers = -200 } },
    },

    -- The Rail Swordsman
    VoidEdge = {
        Id          = "VoidEdge",
        DisplayName = "VoidEdge — Rail-Bound Black Ops",
        Description = "Black ops unit. Magnetic limbs. Impossible verticality. A swordsman who moves along rail architecture like gravity is a suggestion. Nobody knows who made him or who he works for now.",
        Faction     = nil,
        Difficulty  = "Red",
        HP          = 3500,
        Armor       = 350,
        Phases      = {
            {
                phaseHP    = 1.0,
                label      = "Approach",
                behaviors  = { "RailDash", "BladeCombo", "MagneticAnchor" },
                arenaState = "Rail_Platform",
            },
            {
                phaseHP    = 0.55,
                label      = "Full Vertical",
                behaviors  = { "CeilingStrike", "RailLoop", "GravitySlash", "SpeedBurst" },
                arenaState = "Rail_Vertical",
                note       = "VoidEdge stops using horizontal space entirely",
            },
        },
        Lore        = "The blade is older than the current Strata governance cycle. So is the operator.",
        DropWeapon  = "w_rail_spine",
    },

    -- Gantz-style Hunter
    GantzHunter = {
        Id          = "GantzHunter",
        DisplayName = "Score Unit: PREDATOR",
        Description = "Something deployed by a system you cannot identify. It has a targeting profile that includes you. It treats this like a scoring event. The arena is whatever room you're currently in.",
        Faction     = nil,
        Difficulty  = "Red",
        HP          = 3200,
        Armor       = 500,
        Phases      = {
            {
                phaseHP    = 1.0,
                label      = "Acquisition",
                behaviors  = { "TargetLock", "PursuitDash", "ScoreCheck" },
                arenaState = "AnyRoom",
                note       = "PREDATOR narrates each engagement like a sport broadcast",
            },
            {
                phaseHP    = 0.40,
                label      = "Score Push",
                behaviors  = { "FullCommit", "LimbTarget", "ScoreDesperation" },
                arenaState = "AnyRoom_Emergency",
            },
        },
        Lore        = "The system that deployed it has no registered owner. The scoring metrics it uses don't match any known game protocol. It seems genuinely excited to find you.",
        DropAug     = nil,
        DropWeapon  = "w_sl_viper",
    },
}

function MissionData.GetById(id)
    for _, m in ipairs(MissionData.Missions) do
        if m.Id == id then return m end
    end
    return nil
end

function MissionData.GetByFaction(factionId)
    local results = {}
    for _, m in ipairs(MissionData.Missions) do
        if m.Faction == factionId then
            table.insert(results, m)
        end
    end
    return results
end

function MissionData.GetIncursions()
    local results = {}
    for _, m in ipairs(MissionData.Missions) do
        if m.Type == "Incursion" then
            table.insert(results, m)
        end
    end
    return results
end

function MissionData.GetBossById(id)
    return MissionData.Bosses[id]
end

return MissionData
