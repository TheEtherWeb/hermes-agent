-- AugmentationData.lua
-- Complete augmentation catalog for Last Sector.
-- Every aug has a slot, origin, tier, IL cost, stat effects, and special flags.

local AugmentationData = {}

-- ─── Tier Definitions ────────────────────────────────────────────────────────
AugmentationData.Tiers = {
    { id = 1, label = "Mark I",   creditCost = 500,   scrapCost = 0    },
    { id = 2, label = "Mark II",  creditCost = 1500,  scrapCost = 100  },
    { id = 3, label = "Mark III", creditCost = 4000,  scrapCost = 300  },
    { id = 4, label = "Mark IV",  creditCost = 10000, scrapCost = 800  },
    { id = 5, label = "Apex",     creditCost = 25000, scrapCost = 2000 },
}

-- ─── Helper ──────────────────────────────────────────────────────────────────
local function aug(id, slot, origin, tier, ilBase, displayName, desc, stats, flags)
    return {
        Id          = id,
        Slot        = slot,
        Origin      = origin,
        Tier        = tier,
        ILBase      = ilBase,      -- base Identity Load added when equipped
        DisplayName = displayName,
        Description = desc,
        Stats       = stats or {},
        Flags       = flags or {},
    }
end

-- ─── ARM AUGMENTATIONS ───────────────────────────────────────────────────────
AugmentationData.Arms = {

    -- Corporate Arms
    aug("arm_corp_servo_1", "Arms", "Corporate", 1, 8,
        "Prismatic Servo Arm I",
        "Standard corporate-grade servo limb. Clean sockets, regulated output. Your arm is now licensed property.",
        { RecoilReduce = 0.10, MeleeBonus = 0.05, ReloadSpeed = 0.08, HeavyWeaponHandling = 0.05 },
        { corpBranded = true }
    ),
    aug("arm_corp_servo_3", "Arms", "Corporate", 3, 22,
        "Prismatic Servo Arm III",
        "Full haptic-feedback limb with recoil compensation foam in the shoulder housing.",
        { RecoilReduce = 0.28, MeleeBonus = 0.12, ReloadSpeed = 0.20, HeavyWeaponHandling = 0.15, ToolMountSlots = 1 },
        { corpBranded = true }
    ),
    aug("arm_corp_blade_5", "Arms", "Corporate", 5, 45,
        "Obsidian Blade Array",
        "Retractable mono-ceramic blades housed in a precision corporate chassis. Devastating in close quarters. Very expensive to explain.",
        { RecoilReduce = 0.30, BladeIntegration = true, BladeDamage = 55, MeleeRange = 1.5, ToolMountSlots = 2 },
        { corpBranded = true, bladeUnlock = "CerBladeCombo" }
    ),

    -- Military Arms
    aug("arm_mil_reaper_2", "Arms", "Military", 2, 14,
        "Reaper-Pattern Combat Arm",
        "Stripped of all non-essential systems. The power delivery is loud and the heat vents are ugly but it will not stop working.",
        { RecoilReduce = 0.15, MeleeBonus = 0.20, HeavyWeaponHandling = 0.25, GripStrength = 0.30 },
        { powerHungry = true }
    ),
    aug("arm_mil_railmount_4", "Arms", "Military", 4, 38,
        "Rail-Mount Assault Arm",
        "Houses a micro-rail accelerator in the forearm. Fires hardened slugs from a wrist port. The rest of the arm still works fine.",
        { RecoilReduce = 0.22, RailgunIntegration = true, RailgunDamage = 65, HeavyWeaponHandling = 0.30 },
        { powerHungry = true, weaponMount = "WristRail" }
    ),
    aug("arm_mil_missile_5", "Arms", "Military", 5, 55,
        "Manticore Missile Arm",
        "Full replacement. Shoulder-launched micro-missiles. Six-tube capacity. Reload from back-mounted magazine. Tactically absurd.",
        { HeavyWeaponHandling = 0.40, MissileLaunch = true, MissileDamage = 120, MissileCount = 6, ReloadSpeed = -0.10 },
        { powerHungry = true, weaponMount = "MissileLauncher", largeSilhouette = true }
    ),

    -- Salvage Arms
    aug("arm_sal_patchwork_1", "Arms", "Salvage", 1, 5,
        "Patchwork Grip",
        "Salvaged from three different arms. Uncomfortable. Effective. Nobody can tell where it came from.",
        { RecoilReduce = 0.08, MeleeBonus = 0.10, GripStrength = 0.15 },
        { unstable = true, hackable = true }
    ),
    aug("arm_sal_scrap_blade_3", "Arms", "Salvage", 3, 16,
        "Harvester Blade Assembly",
        "Industrial cutter repurposed. The edge is irregular. The damage is not.",
        { BladeIntegration = true, BladeDamage = 38, MeleeRange = 1.2, RecoilReduce = 0.10 },
        { unstable = true, hackable = true, bladeUnlock = "HarvesterSpin" }
    ),
    aug("arm_sal_tether_4", "Arms", "Salvage", 4, 24,
        "Tether Harpoon Mount",
        "Spring-loaded anchor spike. Fires 30 meters. Pulls targets. Also useful for movement. Extremely illegal in corporate districts.",
        { TetherHarpoon = true, TetherRange = 30, TetherDamage = 25, GripStrength = 0.20 },
        { unstable = true, hackable = true, weaponMount = "TetherHarpoon" }
    ),

    -- Religious Arms
    aug("arm_rel_choir_5", "Arms", "Religious", 5, 60,
        "Choir-of-Hands",
        "Six-jointed fractal arm. Cult-grown. The extra articulation is not human. Neither is the targeting.",
        { BladeIntegration = true, BladeDamage = 70, MeleeRange = 2.5, RecoilReduce = 0.35, ToolMountSlots = 3 },
        { cultLocked = true, bladeUnlock = "ChoirStrike", networkSync = true }
    ),

    -- Android Arms
    aug("arm_and_precision_3", "Arms", "Android", 3, 30,
        "Null-Margin Precision Limb",
        "Designed for android chassis. The tolerances are beyond human-use specifications. If you are human, it still works. It just feels wrong.",
        { RecoilReduce = 0.35, AccuracyBonus = 0.20, ReloadSpeed = 0.25, ToolMountSlots = 2 },
        { androidArchitecture = true, requiresAndroidSpine = false }
    ),
    aug("arm_and_ghost_5", "Arms", "Android", 5, 50,
        "Ghost-Echo Emitter Arm",
        "Arm houses a phase emitter that deploys haptic decoy-copies of the arm's movement. Confuses targeting. Beautiful and wrong.",
        { RecoilReduce = 0.30, GhostEchoStep = true, GhostDecoys = 2, AccuracyBonus = 0.15 },
        { androidArchitecture = true, networkSync = true }
    ),
}

-- ─── LEG AUGMENTATIONS ───────────────────────────────────────────────────────
AugmentationData.Legs = {

    aug("leg_corp_sprint_1", "Legs", "Corporate", 1, 8,
        "Titan-Step Leg Brace I",
        "Corporate standard. Servo-assisted knee joints. Makes you faster. Still logs your step count.",
        { SprintBonus = 0.10, SlideDistance = 0.10, JumpBonus = 0.05 },
        { corpBranded = true }
    ),
    aug("leg_corp_mag_3", "Legs", "Corporate", 3, 24,
        "Mag-Lock Stabilizer Legs",
        "Magnetic gripping soles. Walk on metal surfaces at any angle. Ideal for the endless vertical architecture of the Strata.",
        { MagneticPerch = true, SprintBonus = 0.15, WallKick = true, SlideDistance = 0.20 },
        { corpBranded = true }
    ),
    aug("leg_mil_overclock_4", "Legs", "Military", 4, 36,
        "Shockwave Legs",
        "Military surplus. The pistons hit so hard that landing from height sends a shockwave that staggers nearby targets.",
        { SprintBonus = 0.25, JumpBonus = 0.30, LandingShockwave = true, ShockwaveDamage = 40, ShockwaveRadius = 8 },
        { powerHungry = true }
    ),
    aug("leg_mil_burst_3", "Legs", "Military", 3, 22,
        "Burst-Step Actuators",
        "Three-burst dash system. Short range, extremely fast. Used for gap closing and breaking firing lines.",
        { BurstStep = true, BurstCount = 3, BurstSpeed = 60, SlideDistance = 0.30 },
        { powerHungry = true }
    ),
    aug("leg_sal_crawler_2", "Legs", "Salvage", 2, 12,
        "Crawler Legs",
        "Multi-joint legs salvaged from a maintenance bot. Eerie movement profile. Excellent for traversing ruined architecture.",
        { CrawlerLegs = true, WallKick = true, SlideDistance = 0.25, CrouchProfile = -0.30 },
        { unstable = true, largeSilhouette = false }
    ),
    aug("leg_sal_jetleg_4", "Legs", "Salvage", 4, 28,
        "Scrap-Jet Legs",
        "Salvaged turbine housing grafted into thigh casing. Provides erratic vertical boost. Definitely not rated for indoor use.",
        { JumpJet = true, JumpJetHeight = 25, SprintBonus = 0.20, JumpBonus = 0.40 },
        { unstable = true, hackable = true }
    ),
    aug("leg_rel_phantom_5", "Legs", "Religious", 5, 58,
        "Phantom Gate Legs",
        "Cult-constructed. The leg motion exists partially outside normal space during transition. This is not a metaphor.",
        { AirDash = true, AirDashCount = 2, BurstStep = true, BurstCount = 2, WallKick = true, GhostEchoStep = true },
        { cultLocked = true, networkSync = true }
    ),
    aug("leg_and_precision_3", "Legs", "Android", 3, 28,
        "Resonance-Step Legs",
        "Android-architecture legs with vibration-damped contacts. Silent movement. Dramatically improved slide mechanics.",
        { SilentMovement = true, SlideDistance = 0.40, SprintBonus = 0.20, WallKick = true },
        { androidArchitecture = true }
    ),
}

-- ─── SPINE AUGMENTATIONS ─────────────────────────────────────────────────────
AugmentationData.Spine = {

    aug("spine_corp_battery_1", "Spine", "Corporate", 1, 10,
        "Standard Spine Battery",
        "Mounted along the thoracic vertebrae. Powers all installed augmentations. Corporate-regulated capacity.",
        { EnergyMax = 30, EnergyRegen = 2, ModuleSlots = 1 },
        { corpBranded = true }
    ),
    aug("spine_corp_battery_3", "Spine", "Corporate", 3, 28,
        "Cascade Power Column",
        "Upgraded battery architecture. Multiple cells. Emergency burst reserve for overdrive extension.",
        { EnergyMax = 70, EnergyRegen = 5, ModuleSlots = 2, OverdriveDurationBonus = 0.20 },
        { corpBranded = true }
    ),
    aug("spine_mil_armor_2", "Spine", "Military", 2, 18,
        "Bone-Thread Armor Weave",
        "Graphene threads driven through existing bone structure. Increases structural integrity to a concerning degree.",
        { ArmorBonus = 30, MaxHealth = 25, ExplosiveResist = 0.15 },
        { powerHungry = false }
    ),
    aug("spine_mil_heat_4", "Spine", "Military", 4, 40,
        "Overload Spine",
        "No capacity governor. No thermal limiter. The military didn't care about longevity, they cared about output peaks.",
        { EnergyMax = 100, EnergyRegen = 8, ModuleSlots = 3, OverdriveDurationBonus = 0.35, HeatCapacity = -0.20 },
        { powerHungry = true }
    ),
    aug("spine_sal_splice_2", "Spine", "Salvage", 2, 12,
        "Splice Spine",
        "Four different batteries poorly welded to a repurposed spine brace. It works. Ask the salvager who built it.",
        { EnergyMax = 45, EnergyRegen = 3, ModuleSlots = 2 },
        { unstable = true, hackable = true }
    ),
    aug("spine_rel_column_5", "Spine", "Religious", 5, 65,
        "Ascension Column",
        "Cult-grown spinal column replacement. The material is not metal. It interfaces with machine networks directly.",
        { EnergyMax = 120, EnergyRegen = 12, ModuleSlots = 4, NetworkSync = true, CultSignal = true, OverdriveDurationBonus = 0.50 },
        { cultLocked = true, networkSync = true }
    ),
    aug("spine_and_lattice_4", "Spine", "Android", 4, 48,
        "Memory Lattice Spine",
        "Android-grade memory architecture installed along the spine. Enables Ghost Sync expansion and ghost-routine stability.",
        { EnergyMax = 90, EnergyRegen = 10, ModuleSlots = 3, GhostRoutineSlots = 2, IdentityLoadMax = 50 },
        { androidArchitecture = true }
    ),
}

-- ─── HEAD / OPTIC AUGMENTATIONS ──────────────────────────────────────────────
AugmentationData.Head = {

    aug("head_corp_optic_1", "Head", "Corporate", 1, 8,
        "Argus Optic I",
        "Standard corporate ocular replacement. Enemy highlight on alt-scan. Data overlay. Your blink rate is now logged.",
        { EnemyHighlight = true, WeakpointVisibility = 0.10, HackRange = 10, SocialMask = 0.05 },
        { corpBranded = true }
    ),
    aug("head_corp_optic_3", "Head", "Corporate", 3, 22,
        "Argus Optic III",
        "Thermal vision. Structural scan. Enemy hardware profiling. You can see exactly how augmented someone is.",
        { EnemyHighlight = true, ThermalVision = true, WeakpointVisibility = 0.30, HackRange = 20, SocialMask = 0.10, AugScan = true },
        { corpBranded = true }
    ),
    aug("head_mil_targeting_4", "Head", "Military", 4, 36,
        "Ballistic Fire Control",
        "Military-grade targeting lattice hardwired into the visual cortex. Bullet-drop prediction. Moving target lock assist.",
        { WeakpointVisibility = 0.45, AccuracyBonus = 0.20, BulletDropPredict = true, MovingTargetLock = true, HackRange = 8 },
        { powerHungry = true }
    ),
    aug("head_sal_scrambler_3", "Head", "Salvage", 3, 18,
        "Neural Scrambler Crown",
        "Salvaged ECM unit repurposed as headwear. Scrambles nearby targeting systems. Also gives you headaches.",
        { NeuralScrambler = true, ScramblerRadius = 15, HackRange = 15, EnemyHighlight = true },
        { unstable = true, hackable = true }
    ),
    aug("head_rel_cathedral_5", "Head", "Religious", 5, 60,
        "Cathedral Eye",
        "A machine-grown optical array that sees radio frequencies, ghost signals, and the remnants of old network minds. Not all of what it shows is real.",
        { EnemyHighlight = true, ThermalVision = true, GhostSignalVision = true, WeakpointVisibility = 0.60, HackRange = 40, MachineCall = true },
        { cultLocked = true, networkSync = true }
    ),
    aug("head_and_identity_3", "Head", "Android", 3, 32,
        "Identity Mask Module",
        "Android-built facial emulation unit. Passes social recognition checks. Suppresses identity flags in corporate security networks.",
        { SocialMask = 0.40, IdentityFlagSuppress = true, HackRange = 25, EnemyHighlight = true },
        { androidArchitecture = true }
    ),
}

-- ─── INTERNAL / ORGAN AUGMENTATIONS ─────────────────────────────────────────
AugmentationData.Internals = {

    aug("int_corp_stim_1", "Internals", "Corporate", 1, 6,
        "Stim Regulation Pack",
        "Sub-dermal stimulant dispenser. Regulated doses on damage threshold. Keeps you in the fight a few seconds longer.",
        { RegenRate = 2, OutOfCombatRegenBonus = 0.15, MaxHealth = 15 },
        { corpBranded = true }
    ),
    aug("int_mil_regen_3", "Internals", "Military", 3, 24,
        "Field Repair Nanites",
        "Military-grade nanite swarm housed in a synthetic stomach lining. Slow but consistent self-repair, even during combat.",
        { RegenRate = 5, CombatRegen = true, CombatRegenRate = 2, ToxinResist = 0.30 },
        { powerHungry = true }
    ),
    aug("int_sal_toxin_2", "Internals", "Salvage", 2, 10,
        "Toxin Filter",
        "Basic salvage job. Filters environmental toxins, gas, and most drug compounds. Relevant in lower-Strata chemical districts.",
        { ToxinResist = 0.60, EMPResist = 0.10, MaxHealth = 10 },
        { unstable = false }
    ),
    aug("int_sal_reroute_4", "Internals", "Salvage", 4, 30,
        "Damage Reroute System",
        "Redirects lethal damage spikes across multiple sub-systems instead of one critical hit. Survivability at the cost of system strain.",
        { MaxHealth = 30, LethalDamageRedirect = true, DamageRedirectThreshold = 60, EMPResist = -0.10 },
        { unstable = true, hackable = true }
    ),
    aug("int_rel_ghost_5", "Internals", "Religious", 5, 62,
        "Ghost-Memory Organ",
        "The cult calls this transcendence. A synthetic organ that stores experience as executable ghost routines. Die once and leave something behind.",
        { GhostMemory = true, ReviveOnce = true, ReviveCooldown = 300, IdentityLoadOnRevive = 40, MaxHealth = 20 },
        { cultLocked = true, networkSync = true }
    ),
    aug("int_and_chassis_3", "Internals", "Android", 3, 35,
        "Synthetic Organ Array",
        "Full internal replacement with android-architecture equivalents. No organic components remain in the torso cavity. Very efficient. Very quiet.",
        { MaxHealth = 20, MaxArmor = 25, RegenRate = 6, ToxinResist = 0.80, EMPResist = 0.20, IdentityLoadRate = 0.15 },
        { androidArchitecture = true }
    ),
}

-- ─── Flat lookup by ID ───────────────────────────────────────────────────────
AugmentationData.All = {}
for slot, list in pairs({ Arms = AugmentationData.Arms, Legs = AugmentationData.Legs,
                           Spine = AugmentationData.Spine, Head = AugmentationData.Head,
                           Internals = AugmentationData.Internals }) do
    for _, a in ipairs(list) do
        AugmentationData.All[a.Id] = a
    end
end

function AugmentationData.GetById(id)
    return AugmentationData.All[id]
end

function AugmentationData.GetBySlot(slot)
    local map = {
        Arms = AugmentationData.Arms, Legs = AugmentationData.Legs,
        Spine = AugmentationData.Spine, Head = AugmentationData.Head,
        Internals = AugmentationData.Internals,
    }
    return map[slot] or {}
end

return AugmentationData
