-- WeaponTypes.lua
-- Eight weapon definitions: 4 base types × 2 variants (Projection / Extraction).
-- weight: multiplier on Resonance drain rate for Projection weapons.
-- breakThreshold: number of guard-breaking heavy hits before weapon breaks.

return {
	-- ── DAGGER ───────────────────────────────────────────────────────────────
	Dagger_Projection = {
		id             = "Dagger_Projection",
		displayName    = "Shardedge",
		race           = "Gem",
		baseType       = "Dagger",
		variant        = "Projection",
		lightDamage    = 12,
		heavyDamage    = 22,
		guardDamage    = 14,
		weight         = 0.6,  -- drains Resonance slowly
		breakThreshold = 5,    -- hard to break; fast weapons absorb pressure
		meleeRange     = 8,
		animSet        = "DaggerAnims",
		lore           = "A sliver of crystallised light. Fast and precise.",
	},
	Dagger_Extraction = {
		id             = "Dagger_Extraction",
		displayName    = "Coresnap",
		race           = "Ore",
		baseType       = "Dagger",
		variant        = "Extraction",
		lightDamage    = 14,
		heavyDamage    = 26,
		guardDamage    = 16,
		weight         = 1.0,
		breakThreshold = 4,
		meleeRange     = 8,
		animSet        = "DaggerAnims",
		lore           = "Wrenched from the body in a split second. Ruthlessly efficient.",
	},

	-- ── SWORD ────────────────────────────────────────────────────────────────
	Sword_Projection = {
		id             = "Sword_Projection",
		displayName    = "Manifested Blade",
		race           = "Gem",
		baseType       = "Sword",
		variant        = "Projection",
		lightDamage    = 18,
		heavyDamage    = 35,
		guardDamage    = 25,
		weight         = 1.0,
		breakThreshold = 3,
		meleeRange     = 10,
		animSet        = "SwordAnims",
		lore           = "A balanced projection. The standard of the Faceted Court.",
	},
	Sword_Extraction = {
		id             = "Sword_Extraction",
		displayName    = "Slagblade",
		race           = "Ore",
		baseType       = "Sword",
		variant        = "Extraction",
		lightDamage    = 20,
		heavyDamage    = 40,
		guardDamage    = 28,
		weight         = 1.0,
		breakThreshold = 3,
		meleeRange     = 10,
		animSet        = "SwordAnims",
		lore           = "Pulled from the chest with a sound like tearing metal.",
	},

	-- ── GREATSWORD ───────────────────────────────────────────────────────────
	Greatsword_Projection = {
		id             = "Greatsword_Projection",
		displayName    = "Resonant Colossal",
		race           = "Gem",
		baseType       = "Greatsword",
		variant        = "Projection",
		lightDamage    = 28,
		heavyDamage    = 58,
		guardDamage    = 45,
		weight         = 2.5,  -- drains Resonance fast; commitment weapon
		breakThreshold = 2,
		meleeRange     = 12,
		animSet        = "GreatswordAnims",
		lore           = "Enormous and brilliant. Maintaining it demands everything.",
	},
	Greatsword_Extraction = {
		id             = "Greatsword_Extraction",
		displayName    = "Masscore",
		race           = "Ore",
		baseType       = "Greatsword",
		variant        = "Extraction",
		lightDamage    = 30,
		heavyDamage    = 65,
		guardDamage    = 50,
		weight         = 1.0,
		breakThreshold = 2,
		meleeRange     = 12,
		animSet        = "GreatswordAnims",
		lore           = "The cost in blood is immense. So is the reward.",
	},

	-- ── SPEAR ────────────────────────────────────────────────────────────────
	Spear_Projection = {
		id             = "Spear_Projection",
		displayName    = "Prism Lance",
		race           = "Gem",
		baseType       = "Spear",
		variant        = "Projection",
		lightDamage    = 16,
		heavyDamage    = 38,
		guardDamage    = 22,
		weight         = 1.4,
		breakThreshold = 3,
		meleeRange     = 16,  -- long reach
		animSet        = "SpearAnims",
		lore           = "Light refracted to a point. Distance is its domain.",
	},
	Spear_Extraction = {
		id             = "Spear_Extraction",
		displayName    = "Veinpiercer",
		race           = "Ore",
		baseType       = "Spear",
		variant        = "Extraction",
		lightDamage    = 18,
		heavyDamage    = 42,
		guardDamage    = 26,
		weight         = 1.0,
		breakThreshold = 3,
		meleeRange     = 16,
		animSet        = "SpearAnims",
		lore           = "Drawn from the spine. Reaches where no short blade can.",
	},
}
