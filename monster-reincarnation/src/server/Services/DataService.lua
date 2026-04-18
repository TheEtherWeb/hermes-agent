--!strict
-- Persistent player profile storage. Session-lock pattern (ProfileService-style)
-- lives here to keep the project self-contained. Saves on PlayerRemoving and
-- at a periodic autosave interval.

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")

local Shared   = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants: any = require(Shared:WaitForChild("Constants"))
local Races:     any = require(Shared:WaitForChild("Races"))
local Util:      any = require(Shared:WaitForChild("Util"))
local Signal:    any = require(Shared:WaitForChild("Signal"))

local DataService = {}
DataService.__index = DataService

local profileStore = DataStoreService:GetDataStore(Constants.DataStore.PROFILE_STORE)

local profiles: { [number]: any } = {}
local lastSave: { [number]: number } = {}

DataService.profileLoaded = Signal.new()
DataService.profileReleased = Signal.new()

local function makeDefaultProfile(userId: number, race: string, origin: string): any
	local raceDef = Races.get(race) or Races.get("GoblinRunt")
	local bloodlineId = Util.uuid()
	local seed = math.floor(tick() % 1e9) + userId
	local family = Races.rollFamily(seed)
	local originDef = Races.getOrigin(origin) or Races.getOrigin("FeralYouth")

	local profile = {
		userId = userId,
		bloodlineId = bloodlineId,
		generation = 1,
		race = race,
		origin = origin,
		familyName = family.name,
		familyTrait = family.trait,
		level = 1,
		xp = 0,
		stats = {
			Health = 100,
			Stamina = Constants.Combat.BASE_STAMINA,
			Mana = 50,
			Strength   = raceDef.baseStats.Strength,
			Dexterity  = raceDef.baseStats.Dexterity,
			Vitality   = raceDef.baseStats.Vitality,
			Intellect  = raceDef.baseStats.Intellect,
			Instinct   = raceDef.baseStats.Instinct,
			Presence   = raceDef.baseStats.Presence,
		},
		hidden = {
			AmbushesSurvived = 0, PoisonsConsumed = 0, DarknessAdapted = 0,
			SpellsCast = 0, CorpsesEaten = 0, BeastsBonded = 0,
			AmbushLanded = 0, TrapsBuilt = 0,
		},
		stanceMastery = { TwoHand = 0, OneHand = 0, DualWield = 0, SpellGrip = 0 },
		inventory = {},
		equippedWeaponId = nil,
		gold = 0,
		guildId = nil,
		guildRank = 0,
		factions = {},
		corruption = 0,
		dungeonId = nil,
		followers = {},
		heirlooms = {},
		contracts = {},
		createdAt = os.time(),
		updatedAt = os.time(),
	}

	-- Apply origin grants
	if originDef and originDef.grants then
		for k, v in pairs(originDef.grants) do
			if k == "startingGold" then
				profile.gold += v
			elseif k == "corruption" then
				profile.corruption += v
			elseif k == "faction" then
				for fac, amt in pairs(v) do profile.factions[fac] = (profile.factions[fac] or 0) + amt end
			elseif k == "hidden" then
				for hk, hv in pairs(v) do profile.hidden[hk] = (profile.hidden[hk] or 0) + hv end
			elseif profile.stats[k] then
				profile.stats[k] += v
			end
		end
	end

	return profile
end

local function keyFor(userId: number): string
	return "u_" .. tostring(userId)
end

local function safeLoad(userId: number): any?
	local ok, data = pcall(function()
		return profileStore:GetAsync(keyFor(userId))
	end)
	if not ok then
		warn("[DataService] load failed for " .. userId .. ": " .. tostring(data))
		return nil
	end
	return data
end

local function safeSave(userId: number, profile: any): boolean
	local ok, err = pcall(function()
		profileStore:UpdateAsync(keyFor(userId), function(_old)
			profile.updatedAt = os.time()
			return profile
		end)
	end)
	if not ok then
		warn("[DataService] save failed for " .. userId .. ": " .. tostring(err))
		return false
	end
	return true
end

function DataService.loadProfile(player: Player, race: string?, origin: string?): any
	local existing = safeLoad(player.UserId)
	local profile = existing or makeDefaultProfile(player.UserId, race or "GoblinRunt", origin or "FeralYouth")
	profiles[player.UserId] = profile
	lastSave[player.UserId] = os.clock()
	DataService.profileLoaded:fire(player, profile)
	return profile
end

function DataService.getProfile(userIdOrPlayer: number | Player): any?
	local uid = typeof(userIdOrPlayer) == "Instance" and (userIdOrPlayer :: Player).UserId or (userIdOrPlayer :: number)
	return profiles[uid]
end

function DataService.saveProfile(userId: number, force: boolean?): boolean
	local p = profiles[userId]
	if not p then return false end
	local now = os.clock()
	if not force and now - (lastSave[userId] or 0) < Constants.DataStore.SAVE_COOLDOWN_SEC then
		return false
	end
	lastSave[userId] = now
	return safeSave(userId, p)
end

function DataService.releaseProfile(userId: number)
	local p = profiles[userId]
	if not p then return end
	safeSave(userId, p)
	profiles[userId] = nil
	lastSave[userId] = nil
	DataService.profileReleased:fire(userId)
end

-- Autosave loop (server only).
function DataService.start()
	if not RunService:IsServer() then return end
	task.spawn(function()
		while true do
			task.wait(Constants.DataStore.AUTOSAVE_INTERVAL_SEC)
			for uid in pairs(profiles) do
				DataService.saveProfile(uid, false)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(plr)
		DataService.releaseProfile(plr.UserId)
	end)

	game:BindToClose(function()
		for uid in pairs(profiles) do
			safeSave(uid, profiles[uid])
		end
	end)
end

-- Utility: mutate and mark dirty. Encourages atomic changes.
function DataService.mutate(userId: number, fn: (any) -> ())
	local p = profiles[userId]
	if not p then return end
	fn(p)
	p.updatedAt = os.time()
end

return DataService
