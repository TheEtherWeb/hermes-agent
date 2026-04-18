--!strict
-- Races, origins, and family traits. Used by char-creation and evolution gates.

local Races = {}

Races.RACES = {
	Spiderling = {
		display   = "Spiderling",
		blurb     = "Eight-legged vermin. Fragile, patient, and hungrier than it looks.",
		baseStats = { Strength = 4, Dexterity = 10, Vitality = 5, Intellect = 3, Instinct = 9, Presence = 2 },
		startTree = "Spiderling",
		startArea = "CrawlingTunnels",
	},
	SlimeBud = {
		display   = "Slime Bud",
		blurb     = "Translucent child of a dungeon pool. Absorbs what it defeats.",
		baseStats = { Strength = 3, Dexterity = 5, Vitality = 9, Intellect = 8, Instinct = 4, Presence = 2 },
		startTree = "SlimeBud",
		startArea = "SlimeMires",
	},
	GoblinRunt = {
		display   = "Goblin Runt",
		blurb     = "Underfed runt of a broken tribe. Clever, vicious, ambitious.",
		baseStats = { Strength = 6, Dexterity = 8, Vitality = 6, Intellect = 5, Instinct = 6, Presence = 4 },
		startTree = "GoblinRunt",
		startArea = "RuinedVillage",
	},
	BeastkinPup = {
		display   = "Beastkin Pup",
		blurb     = "A half-wild cub with sharp senses and sharper teeth.",
		baseStats = { Strength = 7, Dexterity = 9, Vitality = 7, Intellect = 4, Instinct = 8, Presence = 3 },
		startTree = "BeastkinPup",
		startArea = "WhisperForest",
	},
	DemonSpark = {
		display   = "Demon Spark",
		blurb     = "A soul-ember exiled from the Infernal Realm. Powerful but unwelcome.",
		baseStats = { Strength = 5, Dexterity = 6, Vitality = 4, Intellect = 10, Instinct = 5, Presence = 8 },
		startTree = "DemonSpark",
		startArea = "InfernalRift",
		requiresContract = true,  -- demons must keep contracts to exist in overworld
	},
}

Races.ORIGINS = {
	RuinedVillageSurvivor = {
		display = "Ruined Village Survivor",
		blurb   = "You remember fire and the sound of the bell.",
		grants  = { Instinct = 2, startingGold = 10, faction = { Humanity = -5 } },
	},
	LabEscape = {
		display = "Lab Escape",
		blurb   = "You clawed your way out of a research cage.",
		grants  = { Intellect = 2, startingItem = "TornNotebook", faction = { MageGuild = -10 } },
	},
	CryptBorn = {
		display = "Crypt-Born",
		blurb   = "Born in a place the living avoid.",
		grants  = { Presence = 2, hidden = { DarknessAdapted = 20 } },
	},
	BrokenPact = {
		display = "Broken Pact",
		blurb   = "A contract hangs over you from before you were born.",
		grants  = { corruption = 10, faction = { DemonCourt = 10 } },
	},
	FeralYouth = {
		display = "Feral Youth",
		blurb   = "Raised by the forest itself.",
		grants  = { Dexterity = 2, faction = { BeastTribes = 15 } },
	},
}

-- Family traits rolled at character creation. Seeded by bloodlineId so siblings
-- share them. Some are rare (weight < 1), revealed via the family crest.
Races.FAMILY_POOL = {
	{ name = "Skullsmash", weight = 10, trait = { key = "scavenger_bonus",  value = 0.10, desc = "+10% loot from humanoid corpses." } },
	{ name = "Redveil",    weight =  2, trait = { key = "fire_charm",        value = 0.05, desc = "Flames damage you 5% less." } },
	{ name = "Whitebrine", weight =  6, trait = { key = "cold_tolerance",    value = 0.15, desc = "Cold zones don't slow you." } },
	{ name = "Hollowroot", weight =  8, trait = { key = "night_regen",       value = 0.20, desc = "+20% regen at night." } },
	{ name = "Emberkin",   weight =  3, trait = { key = "fire_affinity",     value = 0.10, desc = "+10% fire damage dealt." } },
	{ name = "Sableflow",  weight =  4, trait = { key = "stealth_bonus",     value = 0.10, desc = "Ambush range +10%." } },
	{ name = "Glassmaw",   weight =  1, trait = { key = "ancient_contract",  value = true, desc = "Can sign one demon pact for free." } },
	{ name = "Paletongue", weight =  5, trait = { key = "mentor_discount",   value = 0.25, desc = "Mentorships 25% faster." } },
}

function Races.rollFamily(seed: number): { name: string, trait: { [string]: any } }
	local rng = Random.new(seed)
	local total = 0
	for _, f in ipairs(Races.FAMILY_POOL) do total += f.weight end
	local roll = rng:NextNumber() * total
	local acc = 0
	for _, f in ipairs(Races.FAMILY_POOL) do
		acc += f.weight
		if roll <= acc then
			return { name = f.name, trait = f.trait }
		end
	end
	local last = Races.FAMILY_POOL[#Races.FAMILY_POOL]
	return { name = last.name, trait = last.trait }
end

function Races.get(raceId: string)
	return Races.RACES[raceId]
end

function Races.getOrigin(originId: string)
	return Races.ORIGINS[originId]
end

return Races
