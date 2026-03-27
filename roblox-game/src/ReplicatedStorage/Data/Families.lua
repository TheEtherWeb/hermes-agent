-- Families.lua
-- All 16 families (8 Gem, 8 Ore).
-- statModifiers: flat or multiplier bonuses applied on PlayerState construction.
-- weaponUnlocks: which weapons become available at each rank index.

local GemFamilies = {
	Diamond = {
		id            = "Diamond",
		race          = "Gem",
		displayName   = "Diamond",
		casteTier     = 1,  -- highest caste
		defaultTrait  = "Faceted",
		lore          = "The apex of the Gem hierarchy. Diamond endures all pressure and answers with perfection. Their bearing alone commands silence in any room.",
		statModifiers = {
			maxHealthBonus    = 10,
			guardMaxBonus     = 10,
			projectionCostMult = 0.90,
		},
		weaponUnlocks = { [1] = "Sword_Projection", [3] = "Greatsword_Projection", [5] = "Spear_Projection" },
		factionAffinity = "FacetedCourt",
		specialRule   = nil,
	},
	Ruby = {
		id            = "Ruby",
		race          = "Gem",
		displayName   = "Ruby",
		casteTier     = 2,
		defaultTrait  = "StarFacet",
		lore          = "Burning clarity. Rubies are aggressors among the Gem families — their resonance runs hot and their strikes land like focused flame.",
		statModifiers = {
			lightDamageMult  = 1.10,
			heatGainMult     = 1.10,  -- runs a little hotter
		},
		weaponUnlocks = { [1] = "Dagger_Projection", [2] = "Sword_Projection", [4] = "Greatsword_Projection" },
		factionAffinity = "FamigliaRossa",
		specialRule   = nil,
	},
	Sapphire = {
		id            = "Sapphire",
		race          = "Gem",
		displayName   = "Sapphire",
		casteTier     = 2,
		defaultTrait  = "CleanCut",
		lore          = "Cool and calculating. Sapphires project with rare efficiency, sustaining complex forms longer than any other Gem family.",
		statModifiers = {
			resonanceRegenMult   = 1.15,
			projectionDurationMult = 1.20,
		},
		weaponUnlocks = { [1] = "Spear_Projection", [3] = "Sword_Projection" },
		factionAffinity = "FacetedCourt",
		specialRule   = nil,
	},
	Jade = {
		id            = "Jade",
		race          = "Gem",
		displayName   = "Jade",
		casteTier     = 3,
		defaultTrait  = "Irregular",
		lore          = "Ancient stone. Jade families are resilient and patient, their heat control bordering on meditative.",
		statModifiers = {
			heatGainMult    = 0.85,
			maxHealthBonus  = 8,
		},
		weaponUnlocks = { [1] = "Sword_Projection", [4] = "Spear_Projection" },
		factionAffinity = "ObsidianSovereignty",
		specialRule   = nil,
	},
	Quartz = {
		id            = "Quartz",
		race          = "Gem",
		displayName   = "Quartz",
		casteTier     = 4,
		defaultTrait  = "Prism",
		lore          = "Common but versatile. Quartz resonates easily and adapts to any weapon form. Underestimated by higher castes.",
		statModifiers = {
			resonanceRegenMult = 1.20,
		},
		weaponUnlocks = { [1] = "Dagger_Projection", [2] = "Sword_Projection", [3] = "Spear_Projection" },
		factionAffinity = nil,
		specialRule   = nil,
	},
	Spinel = {
		id            = "Spinel",
		race          = "Gem",
		displayName   = "Spinel",
		casteTier     = 3,
		defaultTrait  = "Faceted",
		lore          = "Loyal and precise. Spinel families often serve as bodyguards to higher-tier Gems, their guard discipline nearly flawless.",
		statModifiers = {
			guardMaxBonus      = 15,
			guardRecoveryRate  = 1.20,
		},
		weaponUnlocks = { [1] = "Sword_Projection", [3] = "Dagger_Projection" },
		factionAffinity = "FacetedCourt",
		specialRule   = nil,
	},
	Opal = {
		id            = "Opal",
		race          = "Gem",
		displayName   = "Opal",
		casteTier     = 4,
		defaultTrait  = "Prism",
		lore          = "Fractured light made solid. Opals shift and confuse, their resonance signature difficult to read or counter.",
		statModifiers = {
			criticalHitChance = 0.08,
			projectionCostMult = 0.95,
		},
		weaponUnlocks = { [1] = "Dagger_Projection", [3] = "Sword_Projection" },
		factionAffinity = nil,
		specialRule   = nil,
	},
	Painite = {
		id            = "Painite",
		race          = "Gem",
		displayName   = "Painite",
		casteTier     = 2,
		defaultTrait  = "Rough",
		lore          = "Rarest of the named families. Painite rarely speaks of their power — they simply demonstrate it when necessary.",
		statModifiers = {
			heavyDamageMult  = 1.15,
			maxHealthBonus   = 5,
			guardMaxBonus    = 5,
		},
		weaponUnlocks = { [1] = "Sword_Projection", [2] = "Greatsword_Projection" },
		factionAffinity = "ObsidianSovereignty",
		specialRule   = nil,
	},
}

local OreFamilies = {
	Iron = {
		id            = "Iron",
		race          = "Ore",
		displayName   = "Iron",
		casteTier     = 8,  -- mid-tier Ore (can refine to Steel)
		defaultTrait  = "Forged",
		lore          = "The backbone of the Iron Dominion. Iron Ores are soldiers first, everything else second.",
		statModifiers = {
			maxHealthBonus   = 12,
			heavyDamageMult  = 1.10,
		},
		weaponUnlocks = { [1] = "Sword_Extraction", [3] = "Greatsword_Extraction" },
		factionAffinity = "IronDominion",
		specialRule   = nil,
		refinementPath = "Steel",
	},
	Copper = {
		id            = "Copper",
		race          = "Ore",
		displayName   = "Copper",
		casteTier     = 10,
		defaultTrait  = "Layered",
		lore          = "Conductors and messengers. Copper Ores move quickly and recover faster than most.",
		statModifiers = {
			healthRegenMult   = 1.25,
			extractionCostMult = 0.90,
		},
		weaponUnlocks = { [1] = "Dagger_Extraction", [2] = "Sword_Extraction" },
		factionAffinity = "MagneticCovenant",
		specialRule   = nil,
		refinementPath = "Bronze",
	},
	TitaniumOre = {
		id            = "TitaniumOre",
		race          = "Ore",
		displayName   = "Titanium Ore",
		casteTier     = 7,
		defaultTrait  = "Tempered",
		lore          = "One of the current Alloyguard is Titanium. Their family's reputation for endurance is earned, not inherited.",
		statModifiers = {
			maxHealthBonus     = 20,
			fracturResistance  = 1.40,
		},
		weaponUnlocks = { [1] = "Greatsword_Extraction", [3] = "Spear_Extraction" },
		factionAffinity = "IronDominion",
		specialRule   = nil,
		refinementPath = "Titanium",
	},
	GoldOre = {
		id            = "GoldOre",
		race          = "Ore",
		displayName   = "Gold Ore",
		casteTier     = 7,
		defaultTrait  = "Dense",
		lore          = "Soft in its raw form, but Gold Ore families refine toward something untouchable. Their presence commands attention.",
		statModifiers = {
			guardMaxBonus    = 12,
			guardRecoveryRate = 1.15,
		},
		weaponUnlocks = { [1] = "Sword_Extraction", [4] = "Spear_Extraction" },
		factionAffinity = "MagneticCovenant",
		specialRule   = nil,
		refinementPath = "Gold",
	},
	Coal = {
		id            = "Coal",
		race          = "Ore",
		displayName   = "Coal",
		casteTier     = 12,
		defaultTrait  = "Raw",
		lore          = "Low-caste but dangerous. Coal burns. When a Coal Ore reaches their limit, the surrounding area suffers.",
		statModifiers = {
			heatGainMult    = 1.20,  -- generates heat faster (risky)
			lightDamageMult = 1.15,
		},
		weaponUnlocks = { [1] = "Dagger_Extraction", [3] = "Sword_Extraction" },
		factionAffinity = "DeepCoreAssembly",
		specialRule   = "highHeatBuildup",
		refinementPath = nil,  -- Coal does not refine
	},
	Sand = {
		id            = "Sand",
		race          = "Ore",
		displayName   = "Sand",
		casteTier     = 13,
		defaultTrait  = "Brittle",
		lore          = "Near the Dust class but not quite. Sand families are looked down upon but they have a secret — refined, they become Glass.",
		statModifiers = {
			lightDamageMult   = 1.20,
			extractionCostMult = 0.80,
		},
		weaponUnlocks = { [1] = "Dagger_Extraction", [2] = "Spear_Extraction" },
		factionAffinity = "DeepCoreAssembly",
		specialRule   = nil,
		refinementPath = "Glass",
	},
	Quicksilver = {
		id            = "Quicksilver",
		race          = "Ore",
		displayName   = "Quicksilver",
		casteTier     = 9,
		defaultTrait  = "Magnetized",
		lore          = "One of the Alloyguard is Quicksilver. Unstable, brilliant, and terrifying to fight. Unranked Quicksilver cannot control what they are.",
		statModifiers = {
			extractionCostMult = 0.75,  -- cheap extractions
			heatGainMult       = 2.0,   -- builds heat extremely fast
		},
		weaponUnlocks = { [1] = "Dagger_Extraction", [2] = "Sword_Extraction", [4] = "Spear_Extraction" },
		factionAffinity = nil,
		specialRule   = "quicksilverInstability",
		refinementPath = "Quicksilver",  -- becomes fully refined at Apex
	},
	TungstenOre = {
		id            = "TungstenOre",
		race          = "Ore",
		displayName   = "Tungsten Ore",
		casteTier     = 8,
		defaultTrait  = "Dense",
		lore          = "One of the current Alloyguard is Tungsten. They do not rush. They do not need to.",
		statModifiers = {
			maxHealthBonus   = 15,
			heavyDamageMult  = 1.25,
			guardDamageMult  = 1.20,
		},
		weaponUnlocks = { [1] = "Greatsword_Extraction", [3] = "Sword_Extraction" },
		factionAffinity = "IronDominion",
		specialRule   = nil,
		refinementPath = "Tungsten",
	},
}

return {
	Gem = GemFamilies,
	Ore = OreFamilies,

	Get = function(self, race, familyId)
		local raceTable = self[race]
		if not raceTable then return nil end
		return raceTable[familyId]
	end,

	GetDefaultWeapon = function(self, race, familyId, variant)
		local family = self:Get(race, familyId)
		if not family then return nil end
		local unlock = family.weaponUnlocks[1]
		if not unlock then return nil end
		-- Override variant if specified
		if variant then
			local baseType = unlock:match("^(%a+)_")
			if baseType then
				return baseType .. "_" .. variant
			end
		end
		return unlock
	end,
}
