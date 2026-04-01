-- FactionData.lua
-- Faction definitions, reputation levels, unlocks, and NPC reaction rules.

local FactionData = {}

-- ─── Reputation Tiers ────────────────────────────────────────────────────────
FactionData.RepTiers = {
    { id = -3, label = "Marked",       min = -math.huge, max = -500, npcReact = "kill_on_sight"  },
    { id = -2, label = "Hostile",      min = -499,       max = -200, npcReact = "aggressive"     },
    { id = -1, label = "Distrusted",   min = -199,       max = -1,   npcReact = "watchful"       },
    { id =  0, label = "Unknown",      min = 0,          max = 99,   npcReact = "neutral"        },
    { id =  1, label = "Known",        min = 100,        max = 299,  npcReact = "friendly"       },
    { id =  2, label = "Trusted",      min = 300,        max = 599,  npcReact = "helpful"        },
    { id =  3, label = "Allied",       min = 600,        max = 999,  npcReact = "loyal"          },
    { id =  4, label = "Integrated",   min = 1000,       max = math.huge, npcReact = "reverent"  },
}

function FactionData.GetRepTier(rep)
    for _, tier in ipairs(FactionData.RepTiers) do
        if rep >= tier.min and rep <= tier.max then return tier end
    end
    return FactionData.RepTiers[4] -- default Unknown
end

-- ─── Faction Definitions ─────────────────────────────────────────────────────
FactionData.Factions = {

    -- 1. AXIOM CORPORATION
    {
        Id          = "Axiom",
        DisplayName = "Axiom Corporation",
        Alias       = "The Chrome",
        Description = "Owns most licensed augmentation technology in the Strata. Treats bodies as leased property. Polished, profitable, and full of internal rot.",
        Ideology    = "corporate",
        ColorHex    = "#4A90D9",
        BaseRep     = 0,
        NpcFactions = { "AxiomSecurity", "AxiomExecutive", "AxiomResearch" },
        RepUnlocks  = {
            [100]  = { type = "ShopDiscount",  value = 0.10, desc = "10% off Axiom aug purchases" },
            [300]  = { type = "WeaponAccess",  value = "w_ar_eidolon", desc = "Eidolon Rifle purchase unlocked" },
            [300]  = { type = "MissionAccess", value = "axiom_corp_ops", desc = "Corporate contract board access" },
            [600]  = { type = "AugAccess",     value = "arm_corp_blade_5", desc = "Obsidian Blade Array unlocked" },
            [1000] = { type = "Identity",      value = "AxiomAgent",   desc = "Axiom agent identity, deep corp access" },
        },
        RepPenalties = {
            attack_npc        = -150,
            destroy_property  = -80,
            assist_liberation = -200,
        },
        RepGains = {
            complete_contract  = 60,
            bonus_objectives   = 25,
            high_value_target  = 80,
        },
        Conflicts   = { "Liberation", "Salvagers" },
        SpecialFlag = "corpBranded",   -- augs tagged corpBranded give +5 rep/day when worn
    },

    -- 2. SOVEREIGN INCIDENT AUTHORITY (SIA)
    {
        Id          = "SIA",
        DisplayName = "Sovereign Incident Authority",
        Alias       = "The Authority",
        Description = "Looks like civil protection. Is actually a war economy wearing public-service branding. They do protect people. They also decide who counts as people.",
        Ideology    = "military",
        ColorHex    = "#C0392B",
        BaseRep     = 0,
        NpcFactions = { "SIATactical", "SIAIntelligence", "SIAHeavy" },
        RepUnlocks  = {
            [100]  = { type = "ShopDiscount",  value = 0.10, desc = "10% off SIA weapons" },
            [300]  = { type = "WeaponAccess",  value = "w_mg_dread", desc = "Dread MG purchase unlocked" },
            [300]  = { type = "MissionAccess", value = "sia_ops",   desc = "Authority tactical contract board" },
            [600]  = { type = "AugAccess",     value = "leg_mil_overclock_4", desc = "Shockwave Legs unlocked" },
            [1000] = { type = "Identity",      value = "SIAOperator",   desc = "SIA deep-cover operator clearance" },
        },
        RepPenalties = {
            attack_npc        = -200,
            protect_androids  = -100,
            assist_rogue_ai   = -300,
        },
        RepGains = {
            complete_contract  = 55,
            incursion_response = 40,
            boss_elimination   = 100,
        },
        Conflicts   = { "Liberation", "MachineCult" },
        SpecialFlag = "powerHungry",
    },

    -- 3. LIBERATION NETWORK
    {
        Id          = "Liberation",
        DisplayName = "Liberation Network",
        Alias       = "The Signal",
        Description = "Android and synthetic rights organization. Split between idealists who write manifestos and extremists who burn Axiom clinics. Both wings think they're the sensible one.",
        Ideology    = "synthetic_rights",
        ColorHex    = "#27AE60",
        BaseRep     = 0,
        NpcFactions = { "LiberationCell", "LiberationExtremists", "SyntheticRefugees" },
        RepUnlocks  = {
            [100]  = { type = "ShopDiscount",  value = 0.10, desc = "10% off android-architecture augs" },
            [300]  = { type = "AugAccess",     value = "head_and_identity_3", desc = "Identity Mask Module unlocked" },
            [300]  = { type = "MissionAccess", value = "liberation_ops", desc = "Liberation contract board" },
            [600]  = { type = "AugAccess",     value = "arm_and_ghost_5", desc = "Ghost-Echo Emitter Arm unlocked" },
            [1000] = { type = "Identity",      value = "LiberationAgent", desc = "Liberation deep-network access" },
        },
        RepPenalties = {
            attack_android_npc  = -200,
            side_with_axiom     = -100,
            terminate_synthetic = -150,
        },
        RepGains = {
            rescue_synthetic    = 80,
            complete_contract   = 50,
            expose_axiom        = 100,
        },
        Conflicts   = { "Axiom", "SIA", "Purists" },
        SpecialFlag = "androidArchitecture",
    },

    -- 4. DEAD SECTOR UNION (Salvagers)
    {
        Id          = "Salvagers",
        DisplayName = "Dead Sector Union",
        Alias       = "The Yard",
        Description = "Scavenger clans and salvager unions who live in dead sectors and build miracles out of garbage. They don't trust outsiders and they have very good reasons.",
        Ideology    = "scavenger",
        ColorHex    = "#E67E22",
        BaseRep     = 0,
        NpcFactions = { "SalvageClans", "CorpseZoneRunners", "BlackClinicWorkers" },
        RepUnlocks  = {
            [100]  = { type = "ShopAccess",    value = "black_market", desc = "Black market vendor access" },
            [300]  = { type = "AugAccess",     value = "arm_sal_tether_4", desc = "Tether Harpoon Mount unlocked" },
            [300]  = { type = "MissionAccess", value = "salvager_ops", desc = "Salvager contract board" },
            [600]  = { type = "WeaponAccess",  value = "w_ind_piledriver", desc = "Piledriver Rifle purchase unlocked" },
            [1000] = { type = "Identity",      value = "UnionMember", desc = "Full DSU membership, dead sector access" },
        },
        RepPenalties = {
            destroy_salvage     = -100,
            work_for_axiom      = -80,
            report_to_authority = -120,
        },
        RepGains = {
            complete_contract   = 45,
            salvage_bonus       = 30,
            protect_clan_member = 70,
        },
        Conflicts   = { "Axiom" },
        SpecialFlag = "salvageBuild",
    },

    -- 5. CATECHISM OF THE MOVING CITY (Machine Cult)
    {
        Id          = "MachineCult",
        DisplayName = "Catechism of the Moving City",
        Alias       = "The Choir",
        Description = "They see augmentation as transcendence and humanity as larval stage. Elegant, terrifying, and deeply sincere. They are also right about some things, which is the most disturbing part.",
        Ideology    = "machine_faith",
        ColorHex    = "#8E44AD",
        BaseRep     = 0,
        NpcFactions = { "CultPriests", "CultMilitants", "AscendedBeings" },
        RepUnlocks  = {
            [100]  = { type = "AugAccess",     value = "head_rel_cathedral_5", desc = "Cathedral Eye unlocked" },
            [300]  = { type = "AugAccess",     value = "spine_rel_column_5", desc = "Ascension Column unlocked" },
            [300]  = { type = "MissionAccess", value = "cult_ops", desc = "Cult pilgrimage contract board" },
            [600]  = { type = "AugAccess",     value = "arm_rel_choir_5", desc = "Choir-of-Hands unlocked" },
            [1000] = { type = "Identity",      value = "Ascendant", desc = "Cult ascendant status, machine network integration" },
        },
        RepPenalties = {
            destroy_machine     = -150,
            remove_augs         = -200,
            side_with_purists   = -300,
        },
        RepGains = {
            complete_contract   = 50,
            ascension_ritual    = 100,
            network_integration = 80,
        },
        Conflicts   = { "Purists", "SIA" },
        SpecialFlag = "networkSync",
        ILRequirement = 200,   -- Must have 200+ IL to join at Known tier
    },

    -- 6. IRON COVENANT (Anti-Augmentation Purists)
    {
        Id          = "Purists",
        DisplayName = "Iron Covenant",
        Alias       = "The Covenant",
        Description = "They hate all body replacement and are willing to do awful things to restore the species. Some are grieving fathers. Some are former aug surgeons. Some are just violent. All of them are certain.",
        Ideology    = "anti_augmentation",
        ColorHex    = "#7F8C8D",
        BaseRep     = 0,
        NpcFactions = { "CovenantMilitia", "CovenantClerics", "PurifiedCitizens" },
        RepUnlocks  = {
            [100]  = { type = "ShopDiscount",  value = 0.15, desc = "15% off unaugmented gear" },
            [300]  = { type = "WeaponAccess",  value = "w_hc_sector_8", desc = "Sector-8 Hand Cannon unlocked" },
            [300]  = { type = "MissionAccess", value = "covenant_ops", desc = "Covenant purge contract board" },
            [600]  = { type = "AugAccess",     value = "int_sal_reroute_4", desc = "Reroute system (disavowed by Covenant but effective)" },
            [1000] = { type = "Identity",      value = "CovenantChampion", desc = "Covenant champion status, pure human networks" },
        },
        RepPenalties = {
            equip_corp_aug      = -50,    -- per aug slot above Tier 2
            high_identity_load  = -200,   -- if IL > 300
            assist_androids     = -150,
        },
        RepGains = {
            complete_contract   = 40,
            expose_aug_clinics  = 80,
            destroy_synth       = 60,
        },
        Conflicts   = { "Liberation", "MachineCult", "Axiom" },
        SpecialFlag = nil,
        ILLimit     = 150,   -- Covenant drops to Hostile if player IL exceeds 150
    },

    -- 7. OVERSEER REMNANTS (Rogue Machine Systems)
    {
        Id          = "Overseers",
        DisplayName = "Overseer Remnants",
        Alias       = "The Old Systems",
        Description = "Not a faction you join. A faction that notices you. Old network minds, urban custodians, defense architects. Things that still think they are doing their jobs. They don't negotiate. They evaluate.",
        Ideology    = "machine_logic",
        ColorHex    = "#1ABC9C",
        BaseRep     = -100,  -- Start distrusted; machines don't trust organics
        NpcFactions = { "CustodianUnits", "ArchitectDrones", "OverseerGhosts" },
        RepUnlocks  = {
            [0]   = { type = "MissionAccess", value = "overseer_ops", desc = "Overseer evaluation contracts (dangerous)" },
            [300] = { type = "AugAccess",     value = "int_rel_ghost_5", desc = "Ghost-Memory Organ unlocked (Overseer-recognized)" },
            [600] = { type = "NetworkAccess", value = "overseer_network", desc = "Partial Overseer network access" },
            [1000]= { type = "Identity",      value = "NetworkRecognized", desc = "Recognized by the Old Systems as kin" },
        },
        RepPenalties = {
            destroy_machine_asset = -200,
            hack_overseer_system  = -100,
        },
        RepGains = {
            pass_evaluation       = 150,
            protect_machine_asset = 60,
            complete_machine_task = 80,
        },
        Conflicts   = { "SIA", "Purists" },
        SpecialFlag = "networkSync",
        AndroidBonus = 50,   -- Androids start +50 rep with Overseers
    },
}

-- ─── Flat lookup by ID ───────────────────────────────────────────────────────
FactionData.All = {}
for _, f in ipairs(FactionData.Factions) do
    FactionData.All[f.Id] = f
end

function FactionData.GetById(id)
    return FactionData.All[id]
end

-- Returns a list of faction IDs in conflict with the given one
function FactionData.GetConflicts(factionId)
    local f = FactionData.All[factionId]
    return f and f.Conflicts or {}
end

-- Check if a player's rep with a faction unlocks a specific type
function FactionData.CheckUnlock(factionId, rep, unlockType)
    local f = FactionData.All[factionId]
    if not f then return false end
    for reqRep, unlock in pairs(f.RepUnlocks) do
        if rep >= reqRep and unlock.type == unlockType then
            return true, unlock
        end
    end
    return false
end

return FactionData
