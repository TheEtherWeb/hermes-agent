--!strict
-- Persistent bloodlines. On death, the player's "next life" inherits from
-- their ancestor: gold %, a fraction of stats, heirloom weapons, family name.

local DataStoreService = game:GetService("DataStoreService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants: any = require(Shared:WaitForChild("Constants"))
local Util:      any = require(Shared:WaitForChild("Util"))
local Remotes:   any = require(Shared:WaitForChild("Remotes"))

local Services = require(script.Parent)

local DynastyService = {}

local dynastyStore = DataStoreService:GetDataStore(Constants.DataStore.DYNASTY_STORE)

local function keyFor(bloodlineId: string): string
	return "bl_" .. bloodlineId
end

local function loadLineage(bloodlineId: string): any
	local ok, data = pcall(function()
		return dynastyStore:GetAsync(keyFor(bloodlineId))
	end)
	if not ok then warn("[Dynasty] load fail: " .. tostring(data)) end
	return (ok and data) or { bloodlineId = bloodlineId, generations = {}, members = {}, renown = 0 }
end

local function saveLineage(bloodlineId: string, lineage: any)
	local ok, err = pcall(function()
		dynastyStore:UpdateAsync(keyFor(bloodlineId), function() return lineage end)
	end)
	if not ok then warn("[Dynasty] save fail: " .. tostring(err)) end
end

-- Called when a player dies "permanently". Serialises what the next heir
-- inherits. `profile` is the outgoing character.
function DynastyService.onDeath(profile: any)
	local lineage = loadLineage(profile.bloodlineId)
	lineage.lastDeathAt = os.time()

	table.insert(lineage.generations, {
		generation = profile.generation,
		race = profile.race,
		origin = profile.origin,
		finalLevel = profile.level,
		titles = profile.titles or {},
		diedAt = os.time(),
	})
	if #lineage.generations > Constants.Dynasty.MAX_GENERATIONS_TRACKED then
		table.remove(lineage.generations, 1)
	end

	-- Inheritance payload saved to the lineage record. Next character pulls.
	lineage.pendingInheritance = {
		familyName = profile.familyName,
		familyTrait = profile.familyTrait,
		bloodlineId = profile.bloodlineId,
		nextGeneration = profile.generation + 1,
		goldCarry = math.floor(profile.gold * Constants.Dynasty.INHERITANCE_GOLD_PCT),
		statCarry = {
			Strength  = math.floor((profile.stats.Strength  or 0) * Constants.Dynasty.INHERITANCE_STAT_PCT),
			Dexterity = math.floor((profile.stats.Dexterity or 0) * Constants.Dynasty.INHERITANCE_STAT_PCT),
			Vitality  = math.floor((profile.stats.Vitality  or 0) * Constants.Dynasty.INHERITANCE_STAT_PCT),
			Intellect = math.floor((profile.stats.Intellect or 0) * Constants.Dynasty.INHERITANCE_STAT_PCT),
			Instinct  = math.floor((profile.stats.Instinct  or 0) * Constants.Dynasty.INHERITANCE_STAT_PCT),
			Presence  = math.floor((profile.stats.Presence  or 0) * Constants.Dynasty.INHERITANCE_STAT_PCT),
		},
		heirlooms = profile.heirlooms or {},
		dungeonId = profile.dungeonId,
		guildId = profile.guildId,
		guildRank = profile.guildRank,
		factions = profile.factions,
	}

	lineage.renown = (lineage.renown or 0) + profile.level * 5
	saveLineage(profile.bloodlineId, lineage)
end

-- Called when a player elects to rebirth. We consume the pendingInheritance,
-- create a new profile-like payload, and hand it to DataService.
function DynastyService.rebirth(player: Player, chosenRace: string?)
	local DataService = Services.get("DataService")
	local profile = DataService.getProfile(player.UserId)
	if not profile then return end

	-- If they have a lineage waiting, inherit.
	local lineage = loadLineage(profile.bloodlineId)
	local pending = lineage.pendingInheritance

	-- Construct the heir: same bloodlineId, generation+1.
	DataService.mutate(player.UserId, function(p)
		if pending then
			p.generation = pending.nextGeneration
			p.familyName = pending.familyName
			p.familyTrait = pending.familyTrait
			p.gold = pending.goldCarry or 0
			for k, v in pairs(pending.statCarry or {}) do
				p.stats[k] = (p.stats[k] or 0) + v
			end
			p.heirlooms = pending.heirlooms or {}
			p.dungeonId = pending.dungeonId
			p.guildId = pending.guildId
			p.guildRank = pending.guildRank or 0
			p.factions = pending.factions or {}

			-- Append chronicle entry on each inherited heirloom.
			local Chronicle = Services.optional("WeaponChronicle")
			if Chronicle then
				for _, weaponId in ipairs(pending.heirlooms or {}) do
					Chronicle.onInherit(weaponId, player.UserId, p.bloodlineId, p.generation)
				end
			end
		end
		-- Reset mortality-fresh state
		p.level = 1
		p.xp = 0
		p.stats.Health = 100
		p.hidden = { AmbushesSurvived = 0, PoisonsConsumed = 0, DarknessAdapted = 0, SpellsCast = 0,
		             CorpsesEaten = 0, BeastsBonded = 0, AmbushLanded = 0, TrapsBuilt = 0 }
		p.inventory = {}
		if chosenRace then p.race = chosenRace end
		p.corruption = 0
	end)

	-- Clear pending to avoid double-inherit.
	lineage.pendingInheritance = nil
	saveLineage(profile.bloodlineId, lineage)

	Remotes.event("UI_SendNotification"):FireClient(player, {
		kind = "info", text = ("Rebirthed as generation %d of House %s"):format(profile.generation, profile.familyName),
	})
end

function DynastyService.getLineage(bloodlineId: string)
	return loadLineage(bloodlineId)
end

function DynastyService.start()
	Remotes.event("Dynasty_Rebirth").OnServerEvent:Connect(function(plr, chosenRace)
		DynastyService.rebirth(plr, typeof(chosenRace) == "string" and chosenRace or nil)
	end)
end

return DynastyService
