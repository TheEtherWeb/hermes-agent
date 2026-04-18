--!strict
-- Evolution trees per starter species. Each node has unlock `conditions` that
-- EvolutionService evaluates against a profile + hidden stats. Secret nodes
-- are hidden from the UI until conditions are partially met.

local EvolutionTrees = {}

type Node = {
	id: string,
	display: string,
	branch: string,
	secret: boolean?,
	ultimate: boolean?,
	conditions: { [string]: any },  -- arbitrary; see EvolutionService.check
	grants: { [string]: any },
}

EvolutionTrees.TREES = {
	Spiderling = {
		{ id = "venom_weaver", display = "Venom Weaver",  branch = "poison",
		  conditions = { poisonDamageDealt = 500 },
		  grants = { stats = { Intellect = 4, Dexterity = 2 }, ability = "VenomCloud" } },
		{ id = "silk_stalker", display = "Silk Stalker",  branch = "mobility",
		  conditions = { webTraversed = 10 },
		  grants = { stats = { Dexterity = 6 }, ability = "SilkDash" } },
		{ id = "bone_widow",   display = "Bone Widow",    branch = "diet",
		  conditions = { hidden = { CorpsesEaten = 50 } },
		  grants = { stats = { Vitality = 5, Strength = 3 }, ability = "CarapaceGuard" } },
		{ id = "mirror_arachnid", display = "Mirror Arachnid", branch = "secret", secret = true,
		  conditions = { mirrorKill = 1 },   -- triple-same-enemy-at-once
		  grants = { ability = "MirrorClone" } },
		{ id = "broodmother", display = "Broodmother", branch = "ultimate", ultimate = true,
		  conditions = { followersOfKind = { Spider = 20 } },
		  grants = { stats = { Presence = 8, Intellect = 4 }, ability = "SpawnBrood" } },
	},

	SlimeBud = {
		{ id = "acid_slime",     display = "Acid Slime",     branch = "damage",
		  conditions = { statMaxed = "AcidAttack" },
		  grants = { ability = "AcidSpit" } },
		{ id = "mimic_slime",    display = "Mimic Slime",    branch = "defense",
		  conditions = { hidden = { AmbushesSurvived = 5 } },
		  grants = { ability = "MimicForm" } },
		{ id = "arcane_slime",   display = "Arcane Slime",   branch = "magic",
		  conditions = { hidden = { SpellsCast = 100 } },
		  grants = { stats = { Intellect = 6 }, ability = "ArcaneSurge" } },
		{ id = "corpse_slime",   display = "Corpse Slime",   branch = "diet",
		  conditions = { hidden = { CorpsesEaten = 100 } },
		  grants = { ability = "Engulf" } },
		{ id = "slime_sovereign", display = "Slime Sovereign", branch = "ultimate", ultimate = true,
		  conditions = { priorEvolutions = 2, dungeonSize = 15 },
		  grants = { stats = { Vitality = 10 }, ability = "RoyalSlime" } },
	},

	GoblinRunt = {
		{ id = "goblin_scout",    display = "Goblin Scout",   branch = "mobility",
		  conditions = { hidden = { AmbushLanded = 30 } },
		  grants = { stats = { Dexterity = 4, Instinct = 2 }, ability = "Scout" } },
		{ id = "tinker_goblin",   display = "Tinker Goblin",  branch = "craft",
		  conditions = { hidden = { TrapsBuilt = 10 } },
		  grants = { stats = { Intellect = 4 }, ability = "SetTrap" } },
		{ id = "wolf_rider",      display = "Wolf Rider",     branch = "beast",
		  conditions = { hidden = { BeastsBonded = 5 } },
		  grants = { ability = "BeastMount" } },
		{ id = "hobgoblin_captain", display = "Hobgoblin Captain", branch = "leader",
		  conditions = { followersOfKind = { Goblin = 50 } },
		  grants = { stats = { Strength = 4, Presence = 4 }, ability = "RallyCry" } },
		{ id = "goblin_shaman", display = "Goblin Shaman", branch = "secret", secret = true,
		  conditions = { ritualsPerformed = 3 },
		  grants = { ability = "BloodRitual" } },
		{ id = "goblin_king", display = "Goblin King", branch = "ultimate", ultimate = true,
		  conditions = { territoriesConquered = 1, chieftainsRecruited = 5 },
		  grants = { stats = { Presence = 10, Strength = 6 }, ability = "KingdomAura" } },
	},

	BeastkinPup = {
		{ id = "shadow_stalker", display = "Shadow Stalker", branch = "stealth",
		  conditions = { hidden = { DarknessAdapted = 100 } },
		  grants = { ability = "ShadowLunge" } },
		{ id = "moon_howler",    display = "Moon Howler",    branch = "pack",
		  conditions = { followersOfKind = { Beast = 8 } },
		  grants = { ability = "LunarRoar" } },
		{ id = "chain_breaker",  display = "Chain Breaker",  branch = "rage",
		  conditions = { hidden = { AmbushesSurvived = 25 } },
		  grants = { stats = { Strength = 6 }, ability = "RagingBite" } },
		{ id = "apex_chimera",   display = "Apex Chimera",   branch = "ultimate", ultimate = true,
		  conditions = { priorEvolutions = 2, legendaryKills = 3 },
		  grants = { stats = { Strength = 8, Dexterity = 6 }, ability = "ChimericForm" } },
	},

	DemonSpark = {
		{ id = "contract_warden", display = "Contract Warden", branch = "pact",
		  conditions = { contractsFulfilled = 5 },
		  grants = { stats = { Presence = 6 }, ability = "BindingSeal" } },
		{ id = "soul_reaper",     display = "Soul Reaper",     branch = "diet",
		  conditions = { hidden = { CorpsesEaten = 200 } },
		  grants = { ability = "SoulHarvest" } },
		{ id = "infernal_tactician", display = "Infernal Tactician", branch = "mind",
		  conditions = { hidden = { SpellsCast = 300 } },
		  grants = { stats = { Intellect = 8 }, ability = "HellfirePlan" } },
		{ id = "demon_lord", display = "Demon Lord", branch = "ultimate", ultimate = true,
		  conditions = { priorEvolutions = 2, contractsFulfilled = 25 },
		  grants = { stats = { Presence = 12, Intellect = 6 }, ability = "InfernalThrone" } },
	},
}

function EvolutionTrees.getTree(id: string)
	return EvolutionTrees.TREES[id]
end

function EvolutionTrees.findNode(treeId: string, nodeId: string)
	local t = EvolutionTrees.TREES[treeId]
	if not t then return nil end
	for _, n in ipairs(t) do
		if n.id == nodeId then return n end
	end
	return nil
end

return EvolutionTrees
