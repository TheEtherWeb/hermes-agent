-- RankTiers.lua
-- Five rank tiers defining progression thresholds and stat scaling.

return {
	[1] = {
		name              = "Rough",
		xpRequired        = 0,
		statScale         = 1.00,
		heatSafeThreshold = 80,   -- heat % at which danger state triggers (collapse at 100)
		refinementEligible = false,
		alloyEligible      = false,
	},
	[2] = {
		name              = "Polished",
		xpRequired        = 500,
		statScale         = 1.15,
		heatSafeThreshold = 85,
		refinementEligible = false,
		alloyEligible      = false,
	},
	[3] = {
		name              = "Refined",
		xpRequired        = 1500,
		statScale         = 1.35,
		heatSafeThreshold = 90,
		refinementEligible = true,  -- Ores can begin refinement path
		alloyEligible      = false,
	},
	[4] = {
		name              = "Brilliant",
		xpRequired        = 3500,
		statScale         = 1.60,
		heatSafeThreshold = 95,
		refinementEligible = true,
		alloyEligible      = false,
	},
	[5] = {
		name              = "Apex",
		xpRequired        = 7500,
		statScale         = 2.00,
		heatSafeThreshold = 100,  -- fully mastered heat at Apex
		refinementEligible = true,
		alloyEligible      = true,  -- both races may pursue Alloy evolution
	},
}
