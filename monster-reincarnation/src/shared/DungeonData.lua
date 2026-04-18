--!strict
-- World zones + lair room templates + tower floor definitions.

local DungeonData = {}

DungeonData.ZONES = {
	CrawlingTunnels = { tier = 1, biome = "cave",    startingZone = true,
		foes = { "CaveRat", "WebSpider" }, boss = "GluttonousSpider",
		materials = { "IronOre", "ChitinShard", "SpiderSilk" } },
	SlimeMires = { tier = 1, biome = "marsh", startingZone = true,
		foes = { "BogSlime", "LeechSwarm" }, boss = "ElderSlime",
		materials = { "BogReed", "AcidSac", "BoneFragment" } },
	WhisperForest = { tier = 1, biome = "forest", startingZone = true,
		foes = { "WildWolf", "Stalkcat" }, boss = "AlphaWolf",
		materials = { "AshWood", "Pelt", "BeastFang" } },
	RuinedVillage = { tier = 2, biome = "ruins",
		foes = { "ScaredPeasant", "Vigilante" }, boss = "VigilanteCaptain",
		materials = { "IronIngot", "Parchment", "CopperCoin" } },
	AbandonedCrypt = { tier = 3, biome = "crypt",
		foes = { "Ghoul", "CryptGuard" }, boss = "CryptLord",
		materials = { "BoneCore", "SoulShard", "BlackIron" } },
	InfernalRift = { tier = 4, biome = "infernal",
		foes = { "Imp", "HellHound" }, boss = "BrassKing",
		materials = { "BrassIngot", "SoulShard", "DemonHorn" } },
	DragonsRest = { tier = 5, biome = "volcano",
		foes = { "AshWyvern", "DrakeKnight" }, boss = "AshDragon",
		materials = { "DragonScale", "FireCrystal", "MoltenGem" } },
}

-- Lair rooms: placeable inside a claimed dungeon core.
DungeonData.ROOMS = {
	BroodChamber = {
		display = "Brood Chamber",
		cost = { SpiderSilk = 10, ChitinShard = 5 },
		upkeep = { Food = 1 },
		gen = { spawnPer = { minutes = 30, unit = "Spider" } },
		requires = { race = "Spiderling" },
	},
	NutrientPool = {
		display = "Nutrient Pool",
		cost = { BogReed = 10, AcidSac = 5 },
		upkeep = { Water = 1 },
		gen = { spawnPer = { minutes = 45, unit = "SlimeSpawn" } },
		requires = { race = "SlimeBud" },
	},
	Workshop = {
		display = "Workshop",
		cost = { IronIngot = 5, AshWood = 10 },
		effect = { craftingSpeed = 0.25 },
	},
	Barracks = {
		display = "Barracks",
		cost = { IronIngot = 10, AshWood = 20 },
		effect = { followerTrainingSpeed = 0.25 },
	},
	RitualPit = {
		display = "Ritual Pit",
		cost = { BoneFragment = 15, SoulShard = 2 },
		effect = { ritualsEnabled = true, corruption = 1 },
	},
	TrapHall = {
		display = "Trap Hall",
		cost = { IronIngot = 3, AshWood = 3 },
		effect = { invaderDamagePerTile = 30 },
	},
	Library = {
		display = "Library",
		cost = { Parchment = 20, AshWood = 5 },
		effect = { xpBonus = 0.10 },
	},
	ThroneRoom = {
		display = "Throne Room",
		cost = { CrownsilverIngot = 1, AshWood = 30 },
		effect = { diplomacyBonus = 0.15 },
		unique = true,
	},
	Mausoleum = {
		display = "Mausoleum",
		cost = { BoneCore = 3, BoneFragment = 20 },
		effect = { undeadFollowerSlot = 3 },
	},
	PactChamber = {
		display = "Pact Chamber",
		cost = { DemonHorn = 2, SoulShard = 10 },
		effect = { contractSlotExtra = 1 },
		requires = { race = "DemonSpark" },
	},
}

-- Tower floor definitions. Every 10 floors is a major boss + lore unlock.
DungeonData.TOWER = {
	floors = 30,
	twistForFloor = function(floor: number): string
		local twists = { "trapRooms", "elementShift", "aiWaves", "doubleSpeed", "lowLight" }
		return twists[((floor - 1) % #twists) + 1]
	end,
	bossAtFloor = function(floor: number): string?
		if floor == 10 then return "DreambladeWarden" end
		if floor == 20 then return "EchoOfGods" end
		if floor == 30 then return "TheFirstSovereign" end
		return nil
	end,
}

function DungeonData.zone(id: string) return DungeonData.ZONES[id] end
function DungeonData.room(id: string) return DungeonData.ROOMS[id] end

return DungeonData
