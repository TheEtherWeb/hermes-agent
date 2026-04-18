--!strict
-- Follower role definitions. Behaviour implemented in server/FollowerService.

local FollowerRoles = {}

FollowerRoles.ROLES = {
	Worker = {
		display = "Worker",
		task    = "harvestMaterials",
		output  = { materialPerTick = 1 },
		loyaltyTick = 0,
	},
	Guard = {
		display = "Guard",
		task    = "patrol",
		output  = { deterrence = 2 },
		combatWeight = 1.0,
	},
	Breeder = {
		display = "Breeder",
		task    = "increasePopulation",
		output  = { populationGrowth = 0.05 },
	},
	Crafter = {
		display = "Crafter",
		task    = "assistSmith",
		output  = { craftSpeed = 0.10 },
	},
	Priest = {
		display = "Priest",
		task    = "moraleRitual",
		output  = { moralePerTick = 1 },
	},
	Hunter = {
		display = "Hunter",
		task    = "rangedPatrol",
		output  = { foodPerTick = 1 },
		combatWeight = 0.9,
	},
	Lieutenant = {
		display = "Lieutenant",
		task    = "command",
		output  = { commandRadius = 40, commandBonus = 0.10 },
		unique  = true,
		named   = true,
	},
}

-- Simple stat curve for followers leveling up through service.
function FollowerRoles.xpToNext(level: number): number
	return math.floor(50 * (1.25 ^ level))
end

function FollowerRoles.get(id: string) return FollowerRoles.ROLES[id] end

return FollowerRoles
