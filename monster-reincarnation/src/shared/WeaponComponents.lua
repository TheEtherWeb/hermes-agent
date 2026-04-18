--!strict
-- Crafting components. Blades/hilts/guards/pommels/runes. Each piece contributes
-- stats and affinity tags; CraftingService sums them into a finished weapon.

local WeaponComponents = {}

WeaponComponents.BLADES = {
	IronLongblade    = { name = "Iron Longblade",    stats = { damage = 14, speed = 1.00 }, tags = {} },
	MeteoricClaymore = { name = "Meteoric Claymore", stats = { damage = 24, speed = 0.80 }, tags = { "heavy" } },
	SerratedDagger   = { name = "Serrated Dagger",   stats = { damage =  9, speed = 1.40 }, tags = { "light", "bleed" } },
	InfernalBlade    = { name = "Infernal Blade",    stats = { damage = 20, speed = 0.95, fireDamage = 6 }, tags = { "fire" } },
	DragonboneEdge   = { name = "Dragonbone Edge",   stats = { damage = 26, speed = 0.90 }, tags = { "rare" } },
	WidowFang        = { name = "Widow Fang",        stats = { damage = 12, speed = 1.20, poisonDamage = 4 }, tags = { "poison" } },
}

WeaponComponents.HILTS = {
	LeatherBoundHilt  = { name = "Leather-bound Hilt", stats = { Dexterity = 2 } },
	EaglewoodHilt     = { name = "Eaglewood Hilt",     stats = { Strength = 2 } },
	ChitinHilt        = { name = "Chitin Hilt",        stats = { Dexterity = 1, Instinct = 1 } },
	CrownsilverHilt   = { name = "Crownsilver Hilt",   stats = { Presence = 3 } },
}

WeaponComponents.GUARDS = {
	SteelCrossguard   = { name = "Steel Crossguard",   stats = { blockRating = 8 } },
	DragonboneGuard   = { name = "Dragonbone Guard",   stats = { blockRating = 5, lifesteal = 0.03 } },
	SpikedGuard       = { name = "Spiked Guard",       stats = { blockRating = 4, thornsDamage = 6 } },
	VowedGuard        = { name = "Vowed Guard",        stats = { blockRating = 6, postureBreak = 0.10 } },
}

WeaponComponents.POMMELS = {
	StonePommel       = { name = "Stone Pommel",      stats = { postureRegen = 2 } },
	CrystalPommel     = { name = "Crystal Pommel",    stats = { manaRegen = 2 } },
	BoneFragmentPommel= { name = "Bone Fragment",     stats = { postureRegen = 1, Strength = 1 } },
	VoidshardPommel   = { name = "Voidshard",         stats = { manaRegen = 3, corruption = 1 } },
}

WeaponComponents.RUNES = {
	RuneOfFlame       = { name = "Rune of Flame",     stats = { fireDamage = 8 },     affinity = "fire" },
	SigilOfCorruption = { name = "Sigil of Corruption", stats = { lifesteal = 0.05 }, affinity = "dark"  },
	RuneOfSilk        = { name = "Rune of Silk",      stats = { postureBreak = 0.05 }, affinity = "poison" },
	SigilOfCrown      = { name = "Sigil of the Crown", stats = { Presence = 3 },      affinity = "holy" },
	RuneOfFrost       = { name = "Rune of Frost",     stats = { frostDamage = 6 },    affinity = "frost" },
}

WeaponComponents.QUALITY_TIERS = {
	{ key = "poor",      weight = 20, mult = 0.80 },
	{ key = "fair",      weight = 40, mult = 0.95 },
	{ key = "good",      weight = 25, mult = 1.05 },
	{ key = "fine",      weight = 12, mult = 1.15 },
	{ key = "excellent", weight =  3, mult = 1.30 },
}

function WeaponComponents.get(partKind: string, id: string)
	local pool = WeaponComponents[string.upper(partKind)]
	if not pool then return nil end
	return pool[id]
end

function WeaponComponents.rollQuality(rng: Random): { key: string, mult: number }
	local total = 0
	for _, q in ipairs(WeaponComponents.QUALITY_TIERS) do total += q.weight end
	local roll = rng:NextNumber() * total
	local acc = 0
	for _, q in ipairs(WeaponComponents.QUALITY_TIERS) do
		acc += q.weight
		if roll <= acc then
			return { key = q.key, mult = q.mult }
		end
	end
	local last = WeaponComponents.QUALITY_TIERS[#WeaponComponents.QUALITY_TIERS]
	return { key = last.key, mult = last.mult }
end

return WeaponComponents
