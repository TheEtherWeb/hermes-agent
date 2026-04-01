-- WeaponData.lua
-- Complete weapon catalog for Last Sector.
-- Weapons belong to primary or secondary lanes.
-- Stats are base values before aug/perk modifications.

local WeaponData = {}

-- ─── Weapon Families ─────────────────────────────────────────────────────────
WeaponData.Families = {
    ASSAULT_RIFLE  = "AssaultRifle",
    SMG            = "SMG",
    HAND_CANNON    = "HandCannon",
    SHOTGUN        = "Shotgun",
    RAIL_WEAPON    = "RailWeapon",
    SMART_LAUNCHER = "SmartLauncher",
    ARC_THROWER    = "ArcThrower",
    SNIPER         = "Sniper",
    SUPPORT_MG     = "SupportMG",
    INDUSTRIAL     = "Industrial",   -- weapons pulled from the city itself
    SECONDARY_TOOL = "SecondaryTool",
}

-- ─── Helper ──────────────────────────────────────────────────────────────────
local function weapon(id, family, lane, displayName, desc, stats, flags)
    return {
        Id          = id,
        Family      = family,
        Lane        = lane,      -- "Primary" or "Secondary"
        DisplayName = displayName,
        Description = desc,
        Stats       = stats or {},
        Flags       = flags or {},
    }
end

-- ─── PRIMARY WEAPONS ─────────────────────────────────────────────────────────

WeaponData.Primary = {

    -- Assault Rifles
    weapon("w_ar_kontrak", "AssaultRifle", "Primary",
        "Kontrak-7 Assault Rifle",
        "Standard-issue field rifle. Used by three different armies across six sectors. You know what it does because everyone does.",
        { Damage = 28, FireRate = 620, MagSize = 30, ReloadTime = 2.2, Accuracy = 0.72, Range = 180, Recoil = 0.35, DamageType = "Ballistic" },
        { fullAuto = true }
    ),
    weapon("w_ar_vex", "AssaultRifle", "Primary",
        "VEX-11 Urban Carbine",
        "Shorter barrel, folded stock. Designed for corridor combat in collapsed transit tunnels. Feels like shouting in a small room.",
        { Damage = 24, FireRate = 780, MagSize = 35, ReloadTime = 1.8, Accuracy = 0.62, Range = 120, Recoil = 0.45, DamageType = "Ballistic" },
        { fullAuto = true, altFire = "BurstFire" }
    ),
    weapon("w_ar_eidolon", "AssaultRifle", "Primary",
        "Eidolon Pattern Rifle",
        "Corporate military issue. Extremely clean tolerances, built-in stabilizer, and a usage license embedded in the grip. The license expires.",
        { Damage = 30, FireRate = 560, MagSize = 28, ReloadTime = 2.0, Accuracy = 0.82, Range = 220, Recoil = 0.28, DamageType = "Ballistic" },
        { fullAuto = true, corpLicensed = true }
    ),

    -- SMGs
    weapon("w_smg_hornet", "SMG", "Primary",
        "Hornet Compact SMG",
        "Small enough to draw with one hand. Fast enough to empty before you realize you've started shooting.",
        { Damage = 18, FireRate = 950, MagSize = 40, ReloadTime = 1.5, Accuracy = 0.55, Range = 80, Recoil = 0.55, DamageType = "Ballistic" },
        { fullAuto = true, oneHanded = true }
    ),
    weapon("w_smg_blacknail", "SMG", "Primary",
        "Blacknail SMG",
        "Salvager-built. No safety. No serial number. The fire rate selector has three positions: fast, faster, and structural damage.",
        { Damage = 20, FireRate = 1050, MagSize = 45, ReloadTime = 1.6, Accuracy = 0.50, Range = 70, Recoil = 0.65, DamageType = "Ballistic" },
        { fullAuto = true, salvageBuild = true, hackable = true }
    ),

    -- Hand Cannons
    weapon("w_hc_sector_8", "HandCannon", "Primary",
        "Sector-8 Hand Cannon",
        "Four rounds. Each one hits like a controlled architectural event. Slow, heavy, and very honest.",
        { Damage = 75, FireRate = 130, MagSize = 4, ReloadTime = 2.8, Accuracy = 0.85, Range = 160, Recoil = 0.80, DamageType = "Ballistic" },
        { semiAuto = true }
    ),
    weapon("w_hc_void_mark", "HandCannon", "Primary",
        "Void Mark",
        "Energy-core hand cannon. Fires a compressed plasma bolt that burns through light armor. Expensive rounds. Worth it.",
        { Damage = 90, FireRate = 100, MagSize = 6, ReloadTime = 2.5, Accuracy = 0.80, Range = 200, Recoil = 0.60, DamageType = "Energy" },
        { semiAuto = true, energyAmmo = true }
    ),

    -- Shotguns
    weapon("w_sg_sever", "Shotgun", "Primary",
        "Sever Industrial Shotgun",
        "Originally used to breach sealed cargo doors. Repurposed. The spread pattern creates a short-range exclusion zone.",
        { Damage = 85, PelletCount = 8, FireRate = 70, MagSize = 6, ReloadTime = 3.5, Accuracy = 0.35, Range = 40, Recoil = 0.90, DamageType = "Ballistic" },
        { pumpAction = true, coverDestroyer = true }
    ),
    weapon("w_sg_chain_sever", "Shotgun", "Primary",
        "Chain-Sever Full-Auto Shotgun",
        "Military surplus. Full-auto, 12-round drum, brutal heat buildup. Hallway clearance weapon. Don't use it near anything you want standing.",
        { Damage = 70, PelletCount = 6, FireRate = 160, MagSize = 12, ReloadTime = 3.8, Accuracy = 0.30, Range = 35, Recoil = 1.1, DamageType = "Ballistic" },
        { fullAuto = true, drumMag = true, heatBuildup = true }
    ),

    -- Rail Weapons
    weapon("w_rail_spine", "RailWeapon", "Primary",
        "Spineshard Rail Rifle",
        "Electromagnetic accelerator. Fires a dense ferric spike at extreme velocity. Goes through walls. Goes through most things.",
        { Damage = 130, FireRate = 45, MagSize = 5, ReloadTime = 3.2, Accuracy = 0.92, Range = 600, Recoil = 0.20, DamageType = "Ballistic", ArmorPen = 0.60 },
        { semiAuto = true, wallPenetration = true, powerHungry = true }
    ),
    weapon("w_rail_arc_lance", "RailWeapon", "Primary",
        "Arc Lance",
        "Short-range rail weapon optimized for charged bursts. Fires energy lances that chain between augmented targets.",
        { Damage = 85, FireRate = 80, MagSize = 8, ReloadTime = 2.4, Accuracy = 0.75, Range = 80, Recoil = 0.30, DamageType = "Energy", ChainTargets = 2 },
        { semiAuto = true, energyAmmo = true, chainLightning = true }
    ),

    -- Smart Launchers
    weapon("w_sl_viper", "SmartLauncher", "Primary",
        "Viper Smart Launcher",
        "Fires a micro-missile that tracks heat signatures. Eight-round tube. Terrifying in enclosed spaces and open ones.",
        { Damage = 100, SplashRadius = 5, FireRate = 80, MagSize = 8, ReloadTime = 3.0, Accuracy = 0.90, Range = 400, DamageType = "Explosive", TrackingStrength = 0.75 },
        { guided = true, lockRequired = false, softLock = true }
    ),

    -- Arc Throwers
    weapon("w_arc_conduit", "ArcThrower", "Primary",
        "Conduit Arc Thrower",
        "Sustained electrical discharge. Devastating against augmented targets and machine units. Useless if your target is wet in certain ways.",
        { Damage = 18, TickRate = 10, MaxRange = 20, MagSize = 100, ReloadTime = 2.0, DamageType = "Energy", EMPChance = 0.25 },
        { beam = true, sustainedFire = true, empEffect = true }
    ),

    -- Snipers
    weapon("w_snip_meridian", "Sniper", "Primary",
        "Meridian Anti-Material Rifle",
        "Long range precision platform. Bolt action. The round travels far enough that you stop hearing the shot eventually.",
        { Damage = 200, FireRate = 25, MagSize = 5, ReloadTime = 3.5, Accuracy = 0.97, Range = 1200, Recoil = 0.50, DamageType = "Ballistic", ArmorPen = 0.40 },
        { boltAction = true, scopeRequired = true }
    ),
    weapon("w_snip_ghost_read", "Sniper", "Primary",
        "Ghost-Read Neural Sniper",
        "Fires a neural disruption spike. Doesn't kill the body. Kills the system. Outstanding on androids and heavy augmenteds.",
        { Damage = 80, NeuralDamage = 150, FireRate = 20, MagSize = 3, ReloadTime = 4.0, Accuracy = 0.95, Range = 800, DamageType = "Neural" },
        { boltAction = true, scopeRequired = true, neuralWeapon = true }
    ),

    -- Support MGs
    weapon("w_mg_dread", "SupportMG", "Primary",
        "Dread Support MG",
        "Bipod-deployed or hip-fired at significant personal risk. Tears cover apart. Suppresses entire corridors. Excessive in almost every context.",
        { Damage = 35, FireRate = 750, MagSize = 100, ReloadTime = 5.0, Accuracy = 0.60, Range = 300, Recoil = 0.70, DamageType = "Ballistic", CoverDestroyer = true },
        { fullAuto = true, heavyWeapon = true, bipodDeploy = true }
    ),

    -- Industrial
    weapon("w_ind_piledriver", "Industrial", "Primary",
        "Piledriver Pneumatic Rifle",
        "Repurposed construction tool. Fires compressed-gas bolts used for anchoring structural beams. The velocity is not safe for humans.",
        { Damage = 95, FireRate = 40, MagSize = 10, ReloadTime = 3.0, Accuracy = 0.78, Range = 150, Recoil = 0.60, DamageType = "Ballistic", ArmorPen = 0.50 },
        { pumpAction = true, coverDestroyer = true }
    ),
    weapon("w_ind_welders_arc", "Industrial", "Primary",
        "Welder's Arc",
        "An industrial plasma cutter scaled to combat range. Short, very hot, very final.",
        { Damage = 40, TickRate = 8, MaxRange = 12, MagSize = 60, ReloadTime = 2.0, DamageType = "Energy", BurnChance = 0.60 },
        { beam = true, sustainedFire = true, burnEffect = true }
    ),
}

-- ─── SECONDARY WEAPONS / TOOLS ───────────────────────────────────────────────

WeaponData.Secondary = {

    weapon("s_mine_tremor", "SecondaryTool", "Secondary",
        "Tremor Mine",
        "Proximity-detonated seismic charge. Stuns movement, opens armor plates on heavy units.",
        { Damage = 60, BlastRadius = 4, CarryCount = 3, FuseType = "Proximity", DamageType = "Explosive" },
        { deployable = true }
    ),
    weapon("s_drone_hornet", "SecondaryTool", "Secondary",
        "Hornet Combat Drone",
        "Autonomous attack unit. Follows and engages priority targets. Destroyed in one heavy hit.",
        { Damage = 15, AttackRange = 40, HP = 60, Duration = 45, CarryCount = 1 },
        { deployable = true, autonomous = true }
    ),
    weapon("s_cloak_shroud", "SecondaryTool", "Secondary",
        "Shroud Cloak Pack",
        "Personal optical dampener. Lasts eight seconds. Movement breaks it. Worth every credit when you need it.",
        { Duration = 8, Cooldown = 30, CarryCount = 1 },
        { cloak = true, movementBreak = true }
    ),
    weapon("s_hack_spike", "SecondaryTool", "Secondary",
        "Hacking Spike",
        "Thrown. Embeds in a surface or target and begins passive network intrusion. Effective range 30m from spike.",
        { HackPower = 40, Duration = 20, Range = 30, CarryCount = 3 },
        { thrown = true, hackTool = true }
    ),
    weapon("s_emp_charge", "SecondaryTool", "Secondary",
        "EMP Charge",
        "Detonates an electromagnetic pulse. Disables all augs and electronics in radius for 4 seconds. Including yours if you're careless.",
        { EMPRadius = 12, Duration = 4, CarryCount = 2, FriendlyFire = true },
        { thrown = true, empEffect = true }
    ),
    weapon("s_sensor_knife", "SecondaryTool", "Secondary",
        "Sensor Knife",
        "Thrown tracking blade. Marks all enemies within 15m of impact point through walls for 30 seconds.",
        { TrackRadius = 15, MarkDuration = 30, Damage = 25, CarryCount = 4, DamageType = "Blade" },
        { thrown = true, marking = true }
    ),
    weapon("s_riot_foam", "SecondaryTool", "Secondary",
        "Riot Foam Canister",
        "Deployes fast-hardening polymer foam. Roots targets and covers cover. Dissolves in ninety seconds.",
        { FoamRadius = 3, RootDuration = 4, Duration = 90, CarryCount = 2 },
        { deployable = true, foamRoot = true }
    ),
    weapon("s_shield_beacon", "SecondaryTool", "Secondary",
        "Shield Beacon",
        "Dropped deployable that projects a hard-light barrier up to 3m wide. Takes significant punishment before failing.",
        { HP = 250, Width = 3, Height = 2.5, Duration = 60, CarryCount = 1 },
        { deployable = true, barrier = true }
    ),
    weapon("s_tether_harpoon", "SecondaryTool", "Secondary",
        "Tether Harpoon",
        "Fires a wired spike. Attaches to surfaces or targets. Can be used to zip forward or drag enemies toward you.",
        { Range = 35, PullForce = 80, Damage = 20, CarryCount = 1, DamageType = "Ballistic" },
        { tether = true, movementTool = true }
    ),
    weapon("s_nanite_pack", "SecondaryTool", "Secondary",
        "Nanite Repair Pack",
        "One-use burst of repair nanites. Restores 80 HP instantly. Cannot be used mid-overdrive.",
        { HealAmount = 80, UseTime = 1.2, CarryCount = 3 },
        { consumable = true, healing = true }
    ),
    weapon("s_decoy_ghost", "SecondaryTool", "Secondary",
        "Ghost Decoy Projector",
        "Deployed holographic decoy that mimics your last known movement pattern. Fools basic targeting for six seconds.",
        { Duration = 6, Cooldown = 25, CarryCount = 2 },
        { decoy = true }
    ),
}

-- ─── Flat lookup by ID ───────────────────────────────────────────────────────
WeaponData.All = {}
for _, w in ipairs(WeaponData.Primary) do WeaponData.All[w.Id] = w end
for _, w in ipairs(WeaponData.Secondary) do WeaponData.All[w.Id] = w end

function WeaponData.GetById(id)
    return WeaponData.All[id]
end

-- Starting loadouts per class
WeaponData.StartingLoadouts = {
    Human   = { primary = "w_ar_kontrak",  secondary = "s_nanite_pack"   },
    Cyborg  = { primary = "w_ar_vex",      secondary = "s_drone_hornet"  },
    Android = { primary = "w_snip_ghost_read", secondary = "s_hack_spike" },
}

return WeaponData
