-- Factions.lua
-- Six faction stubs: 3 Gem, 3 Ore.
-- Fully fleshed-out faction mechanics are post-prototype.

return {
	-- ── GEM FACTIONS ─────────────────────────────────────────────────────────
	FacetedCourt = {
		id          = "FacetedCourt",
		race        = "Gem",
		displayName = "The Faceted Court",
		lore        = "The ruling body of Gem society. Pristine, ceremonial, and utterly ruthless. Membership is by invitation or conquest. They define what perfection means — and they write the definitions to exclude everyone else.",
		aesthetic   = "White marble and prismatic light. Formal. Cold.",
		bonusType   = "guardEfficiency",
		bonusValue  = 1.10,
		standingRules = "Members must maintain Rank 2 or higher. Imperfect Gems may apply but are rarely accepted.",
		placeholder = true,
	},
	FamigliaRossa = {
		id          = "FamigliaRossa",
		race        = "Gem",
		displayName = "La Famiglia Rossa",
		lore        = "A found family built on rejection. The three heads of this faction are triplets, connected by blood and by shared exile. They formed something real where society gave them nothing.",
		aesthetic   = "Deep red and black. Warm light. Intimate but dangerous.",
		bonusType   = "lightDamage",
		bonusValue  = 1.10,
		standingRules = "Loyalty is the only requirement. Betrayal is the only crime.",
		placeholder = true,
	},
	ObsidianSovereignty = {
		id          = "ObsidianSovereignty",
		race        = "Gem",
		displayName = "The Obsidian Sovereignty",
		lore        = "They believe the Gem caste has grown soft. The Sovereignty pushes purity ideology to its furthest conclusion — only the hardest should lead.",
		aesthetic   = "Black glass and hard angles. Minimalist severity.",
		bonusType   = "heavyDamage",
		bonusValue  = 1.10,
		standingRules = "Strength above all. Clouded and Irregular Gems are regarded with suspicion.",
		placeholder = true,
	},

	-- ── ORE FACTIONS ─────────────────────────────────────────────────────────
	IronDominion = {
		id          = "IronDominion",
		race        = "Ore",
		displayName = "The Iron Dominion",
		lore        = "The largest Ore military faction. Structured, disciplined, and unapologetically expansionist. They measure worth in rank and nothing else.",
		aesthetic   = "Gunmetal grey and industrial orange. Functional. Scarred.",
		bonusType   = "maxHealth",
		bonusValue  = 10,
		standingRules = "Soldiers earn rank. Officers earn rank faster. No exceptions.",
		placeholder = true,
	},
	MagneticCovenant = {
		id          = "MagneticCovenant",
		race        = "Ore",
		displayName = "The Magnetic Covenant",
		lore        = "A faction built around aligned polarity — the idea that certain Ores are bound by internal force to one another and to a common purpose. More spiritual than military.",
		aesthetic   = "Deep navy and silver. Flowing lines. Ceremonial.",
		bonusType   = "resonanceRegen",
		bonusValue  = 1.15,
		standingRules = "Only Magnetized or aligned-trait Ores are granted inner circle access.",
		placeholder = true,
	},
	DeepCoreAssembly = {
		id          = "DeepCoreAssembly",
		race        = "Ore",
		displayName = "The Deep Core Assembly",
		lore        = "The underclass organizing. Labor Ores, industrial workers, low-caste families. They are slow to move but enormous in number. The Court does not take them seriously. That is a mistake.",
		aesthetic   = "Brown earth and glowing veins. Heavy. Grounded.",
		bonusType   = "heatControl",
		bonusValue  = 0.90,  -- 10% less heat gain
		standingRules = "Open to all Ore families regardless of caste. Higher-caste Ores are watched carefully.",
		placeholder = true,
	},
}
