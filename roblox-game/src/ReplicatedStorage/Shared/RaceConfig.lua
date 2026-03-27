-- RaceConfig.lua
-- Encodes mechanical differences between Gem (Projection) and Ore (Extraction).
-- Keeps race-specific logic out of general combat code.

local Constants = require(script.Parent.Parent.Data.Constants)

return {
	Gem = {
		resourceName   = "Resonance",
		weaponMechanic = "Projection",

		-- Can this player summon right now?
		CanSummon = function(state)
			return (state.Resonance or 0) > 10 and not state.WeaponBroken and not state.IsCollapsed
		end,

		-- Upfront cost paid at summon time (Gems pay nothing upfront)
		SummonCost = function(_weaponDef)
			return 0
		end,

		-- Heat added when summoning
		SummonHeatCost = function(_weaponDef)
			return 0
		end,

		-- Resonance drained per second while weapon is active
		TickDrain = function(weaponDef, dt)
			return Constants.RESONANCE_BASE_DRAIN * (weaponDef.weight or 1.0) * dt
		end,

		-- Resource field name written to state
		ResourceField = "Resonance",

		-- Max resource
		MaxResource = Constants.MAX_RESONANCE,

		-- Regen per second when weapon is dismissed
		ResourceRegen = function(_state, dt)
			return Constants.RESONANCE_REGEN_RATE * dt
		end,
	},

	Ore = {
		resourceName   = "SoulForge",
		weaponMechanic = "Extraction",

		CanSummon = function(state)
			return state.Health > Constants.EXTRACTION_HEALTH_COST and not state.WeaponBroken and not state.IsCollapsed
		end,

		-- Ore pays health immediately on summon
		SummonCost = function(_weaponDef)
			return Constants.EXTRACTION_HEALTH_COST
		end,

		SummonHeatCost = function(_weaponDef)
			return Constants.HEAT_GAIN_EXTRACTION
		end,

		-- No resonance tick drain; Ore weapons don't drain a separate meter
		TickDrain = function(_weaponDef, _dt)
			return 0
		end,

		-- Ore slowly regens health while weapon is active (reward for staying aggressive)
		ResourceRegen = function(state, dt)
			-- Regen does not exceed (MaxHealth - original extraction cost)
			local cap = state.MaxHealth - Constants.EXTRACTION_HEALTH_COST
			if state.Health >= cap then return 0 end
			return Constants.ORE_HEALTH_REGEN_RATE * dt
		end,

		ResourceField = "Health",
		MaxResource   = nil,  -- N/A for Ore; uses MaxHealth
	},
}
