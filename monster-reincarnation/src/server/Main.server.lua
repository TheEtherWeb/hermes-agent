--!strict
-- Server entry point. Registers all services with the locator, starts them,
-- and handles player join/leave lifecycle.

local Players = game:GetService("Players")

local ServicesFolder = script.Parent:WaitForChild("Services")
local Services = require(ServicesFolder)

-- Register services in dependency order. `require` the module, then register.
local function register(name: string, modName: string?)
	local mod = require(ServicesFolder:WaitForChild(modName or (name .. "Service")))
	Services.register(name, mod)
	return mod
end

-- Core first.
register("AntiExploit", "AntiExploitService")
register("Analytics",   "AnalyticsService")
register("DataService", "DataService")

-- Gameplay services.
register("Combat",           "CombatService")
register("WeaponPersona",    "WeaponPersonaService")
register("WeaponChronicle",  "WeaponChronicleService")
register("Crafting",         "CraftingService")
register("Evolution",        "EvolutionService")
register("Dynasty",          "DynastyService")
register("Mentor",           "MentorService")
register("Guild",            "GuildService")
register("Dungeon",          "DungeonService")
register("Lair",             "LairService")
register("Follower",         "FollowerService")
register("Contract",         "DemonContractService")
register("Faction",          "FactionService")
register("Economy",          "EconomyService")
register("Tower",            "TowerService")
register("Monetization",     "MonetizationService")
register("Npc",              "NpcService")

-- Start order: Data before anything that touches profiles.
local startOrder = {
	"DataService", "Analytics", "Monetization",
	"Combat", "Crafting", "Evolution", "Dynasty", "Mentor",
	"Guild", "Lair", "Follower", "Contract", "Faction",
	"Economy", "Tower", "Dungeon", "Npc",
}

for _, name in ipairs(startOrder) do
	local s = Services.get(name)
	if typeof(s.start) == "function" then
		local ok, err = pcall(s.start)
		if not ok then warn("[Main] start failed for " .. name .. ": " .. tostring(err)) end
	end
end

-- Player lifecycle ---------------------------------------------------------

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Data = Services.get("DataService")

Remotes.func("Profile_Get").OnServerInvoke = function(plr)
	return Data.getProfile(plr.UserId)
end

Players.PlayerAdded:Connect(function(plr)
	-- Race/origin are chosen in character-creation UI; default for first spawn.
	local profile = Data.loadProfile(plr, "GoblinRunt", "FeralYouth")
	Remotes.event("Profile_Replicate"):FireClient(plr, profile)

	-- Seed a few materials to make the vertical slice approachable.
	Data.mutate(plr.UserId, function(p)
		p.gold = 50
		table.insert(p.inventory, { id = game:GetService("HttpService"):GenerateGUID(false),
			kind = "material", templateId = "IronOre", qty = 5 })
		table.insert(p.inventory, { id = game:GetService("HttpService"):GenerateGUID(false),
			kind = "material", templateId = "AshWood", qty = 5 })
	end)

	local Analytics = Services.get("Analytics")
	Analytics.track("session_start", { userId = plr.UserId })
end)

Players.PlayerRemoving:Connect(function(plr)
	local Analytics = Services.get("Analytics")
	Analytics.track("session_end", { userId = plr.UserId, playtime = tick() })
end)

print("[MonsterReincarnation] Server ready.")
