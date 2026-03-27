-- Traits.lua
-- Structural traits for Gems and Ores.
-- passiveEffect keys match field names in PlayerState or modifier tables.

local GemTraits = {
	Faceted = {
		id           = "Faceted",
		race         = "Gem",
		displayName  = "Faceted",
		passiveEffect = "guardRecoveryRate",
		passiveValue  = 1.15,  -- 15% faster guard regen
		description  = "Precisely cut planes deflect force efficiently, aiding guard recovery.",
		rarity       = "Common",
	},
	Rough = {
		id           = "Rough",
		race         = "Gem",
		displayName  = "Rough",
		passiveEffect = "projectionCostMult",
		passiveValue  = 0.90,  -- 10% cheaper projection cost
		description  = "Uncut and raw. Projection bleeds freely, cheapening manifestation.",
		rarity       = "Common",
	},
	CleanCut = {
		id           = "CleanCut",
		race         = "Gem",
		displayName  = "Clean Cut",
		passiveEffect = "projectionDurationMult",
		passiveValue  = 1.20,  -- 20% longer projection before drain
		description  = "Flawless geometry sustains resonance far beyond the norm.",
		rarity       = "Uncommon",
	},
	Geode = {
		id           = "Geode",
		race         = "Gem",
		displayName  = "Geode",
		passiveEffect = "maxHealthBonus",
		passiveValue  = 15,   -- +15 max health
		description  = "Hollow interior cushions internal shocks. More room to endure.",
		rarity       = "Uncommon",
	},
	StarFacet = {
		id           = "StarFacet",
		race         = "Gem",
		displayName  = "Star Facet",
		passiveEffect = "criticalHitChance",
		passiveValue  = 0.10,  -- 10% crit chance
		description  = "Light converges to a single point. A rare alignment of force.",
		rarity       = "Rare",
	},
	Prism = {
		id           = "Prism",
		race         = "Gem",
		displayName  = "Prism",
		passiveEffect = "resonanceRegenMult",
		passiveValue  = 1.25,  -- 25% faster resonance regen
		description  = "Splits and refracts internal energy, accelerating resonance return.",
		rarity       = "Rare",
	},
	Irregular = {
		id           = "Irregular",
		race         = "Gem",
		displayName  = "Irregular",
		passiveEffect = "heatGainMult",
		passiveValue  = 0.80,  -- 20% less heat generated
		description  = "Asymmetric form disperses heat unpredictably, bleeding it away.",
		rarity       = "Uncommon",
	},
	Clouded = {
		id           = "Clouded",
		race         = "Gem",
		displayName  = "Clouded",
		passiveEffect = "guardMaxBonus",
		passiveValue  = 20,  -- +20 max guard
		description  = "Internal inclusions absorb force across a wider surface.",
		rarity       = "Common",
	},
}

local OreTraits = {
	Raw = {
		id           = "Raw",
		race         = "Ore",
		displayName  = "Raw",
		passiveEffect = "extractionCostMult",
		passiveValue  = 0.85,  -- 15% cheaper extraction health cost
		description  = "Unprocessed form pulls weapons freely. Sloppy but effective.",
		rarity       = "Common",
	},
	Forged = {
		id           = "Forged",
		race         = "Ore",
		displayName  = "Forged",
		passiveEffect = "heavyDamageMult",
		passiveValue  = 1.20,  -- 20% more heavy attack damage
		description  = "Shaped under pressure. Strikes carry the weight of the forge.",
		rarity       = "Uncommon",
	},
	Tempered = {
		id           = "Tempered",
		race         = "Ore",
		displayName  = "Tempered",
		passiveEffect = "fracturResistance",
		passiveValue  = 1.30,  -- 30% harder to weapon-break
		description  = "Heated and cooled to near-perfect hardness. Does not break easily.",
		rarity       = "Uncommon",
	},
	Hammered = {
		id           = "Hammered",
		race         = "Ore",
		displayName  = "Hammered",
		passiveEffect = "guardDamageMult",
		passiveValue  = 1.25,  -- 25% more guard pressure per hit
		description  = "Surface beaten flat. Hits land with overwhelming pressure.",
		rarity       = "Rare",
	},
	Layered = {
		id           = "Layered",
		race         = "Ore",
		displayName  = "Layered",
		passiveEffect = "healthRegenMult",
		passiveValue  = 1.40,  -- 40% faster health regen during extraction
		description  = "Strata absorb and redistribute damage inward. Regenerates quickly.",
		rarity       = "Uncommon",
	},
	Magnetized = {
		id           = "Magnetized",
		race         = "Ore",
		displayName  = "Magnetized",
		passiveEffect = "meleeRangeBonus",
		passiveValue  = 2,   -- +2 studs to all weapon ranges
		description  = "Polarized field extends the weapon's reach like a gravitational pull.",
		rarity       = "Rare",
	},
	Brittle = {
		id           = "Brittle",
		race         = "Ore",
		displayName  = "Brittle",
		passiveEffect = "lightDamageMult",
		passiveValue  = 1.35,  -- 35% more light attack damage
		description  = "Cracks at the edges but hits like shattered glass. Volatile precision.",
		rarity       = "Uncommon",
	},
	Dense = {
		id           = "Dense",
		race         = "Ore",
		displayName  = "Dense",
		passiveEffect = "maxHealthBonus",
		passiveValue  = 20,  -- +20 max health
		description  = "Compacted to extreme density. Nearly impossible to move. Hard to kill.",
		rarity       = "Common",
	},
}

return {
	Gem = GemTraits,
	Ore = OreTraits,

	-- Helper: get trait by race and id
	Get = function(self, race, traitId)
		local raceTable = self[race]
		if not raceTable then return nil end
		return raceTable[traitId]
	end,
}
