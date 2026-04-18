--!strict
-- Guilds, ranks, base claim, score, chimes. Persisted in a guild DataStore.

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants: any = require(Shared:WaitForChild("Constants"))
local RankData:  any = require(Shared:WaitForChild("RankData"))
local Remotes:   any = require(Shared:WaitForChild("Remotes"))
local Util:      any = require(Shared:WaitForChild("Util"))

local Services = require(script.Parent)

local GuildService = {}

local guildStore = DataStoreService:GetDataStore(Constants.DataStore.GUILD_STORE)
local cache: { [string]: any } = {}

local function keyFor(id: string): string return "g_" .. id end

local function loadGuild(id: string): any?
	if cache[id] then return cache[id] end
	local ok, data = pcall(function() return guildStore:GetAsync(keyFor(id)) end)
	if not ok or not data then return nil end
	cache[id] = data
	return data
end

local function saveGuild(id: string)
	local g = cache[id]
	if not g then return end
	pcall(function()
		guildStore:UpdateAsync(keyFor(id), function() return g end)
	end)
end

function GuildService.create(player: Player, rawName: any, rawTag: any)
	local name = tostring(rawName or ""):sub(1, 24)
	local tag  = tostring(rawTag or ""):sub(1, 4)
	if #name < 3 or #tag < 2 then return end

	local DataService = Services.get("DataService")
	local profile = DataService.getProfile(player.UserId)
	if not profile then return end
	if profile.guildId then
		Remotes.event("UI_SendNotification"):FireClient(player, { kind = "error", text = "Already in a guild." })
		return
	end

	local id = Util.uuid()
	local guild = {
		id = id, name = name, tag = tag,
		leaderUserId = player.UserId,
		officers = {},
		members = { [player.UserId] = { rank = 4, joinedAt = os.time() } },
		score = 0,
		baseLocationId = nil,
		createdAt = os.time(),
		scoreResetAt = os.time() + Constants.Guild.GUILD_SCORE_RESET_INTERVAL_SEC,
	}
	cache[id] = guild
	saveGuild(id)

	DataService.mutate(player.UserId, function(p)
		p.guildId = id
		p.guildRank = 4
	end)

	Remotes.event("UI_SendNotification"):FireClient(player, { kind = "success", text = "Guild founded: " .. name })
end

function GuildService.invite(leader: Player, rawTargetUserId: any)
	local targetUserId = tonumber(rawTargetUserId)
	if not targetUserId then return end
	local DataService = Services.get("DataService")
	local leaderProfile = DataService.getProfile(leader.UserId)
	if not leaderProfile or not leaderProfile.guildId then return end
	if not RankData.canPerform(leaderProfile.guildRank, "invite") then return end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target then return end

	Remotes.event("Guild_Invite"):FireClient(target, {
		guildId = leaderProfile.guildId,
		fromName = leader.Name,
	})
end

function GuildService.acceptInvite(player: Player, rawGuildId: any)
	local guildId = tostring(rawGuildId)
	local guild = loadGuild(guildId)
	if not guild then return end
	if Util.tableLen(guild.members) >= Constants.Guild.MAX_MEMBERS then return end

	local DataService = Services.get("DataService")
	local profile = DataService.getProfile(player.UserId)
	if not profile or profile.guildId then return end

	guild.members[player.UserId] = { rank = 0, joinedAt = os.time() }
	saveGuild(guildId)

	DataService.mutate(player.UserId, function(p)
		p.guildId = guildId
		p.guildRank = 0
	end)
end

function GuildService.kick(kicker: Player, rawTargetUserId: any)
	local targetUserId = tonumber(rawTargetUserId)
	if not targetUserId then return end
	local DataService = Services.get("DataService")
	local kickerProfile = DataService.getProfile(kicker.UserId)
	if not kickerProfile or not kickerProfile.guildId then return end
	local guild = loadGuild(kickerProfile.guildId)
	if not guild then return end
	if not RankData.canPerform(kickerProfile.guildRank, "invite") then return end
	local entry = guild.members[targetUserId]
	if not entry then return end
	if entry.rank >= kickerProfile.guildRank then return end   -- can't kick equal/higher rank

	guild.members[targetUserId] = nil
	saveGuild(guild.id)

	-- If target online, clear their guildId.
	local target = Players:GetPlayerByUserId(targetUserId)
	if target then
		DataService.mutate(targetUserId, function(p) p.guildId = nil; p.guildRank = 0 end)
	end
end

function GuildService.promote(promoter: Player, rawTargetUserId: any, rawNewRank: any)
	local targetUserId = tonumber(rawTargetUserId)
	local newRank = tonumber(rawNewRank)
	if not targetUserId or not newRank then return end
	local DataService = Services.get("DataService")
	local pp = DataService.getProfile(promoter.UserId)
	if not pp or not pp.guildId then return end
	if not RankData.canPromoteTo(pp.guildRank, newRank) then return end
	local guild = loadGuild(pp.guildId)
	if not guild then return end
	local entry = guild.members[targetUserId]
	if not entry then return end
	entry.rank = newRank
	saveGuild(guild.id)

	local target = Players:GetPlayerByUserId(targetUserId)
	if target then
		DataService.mutate(targetUserId, function(p) p.guildRank = newRank end)
	end
end

function GuildService.addScore(guildId: string, delta: number)
	local guild = loadGuild(guildId)
	if not guild then return end
	guild.score = math.max(0, (guild.score or 0) + delta)
	saveGuild(guildId)

	-- Auto-promote based on score tier -> leader only.
end

function GuildService.getInfo(_plr: Player, rawId: any): any?
	local id = tostring(rawId)
	return loadGuild(id)
end

function GuildService.summonBase(player: Player)
	local DataService = Services.get("DataService")
	local profile = DataService.getProfile(player.UserId)
	if not profile or not profile.guildId then return end
	local guild = loadGuild(profile.guildId)
	if not guild or not guild.baseLocationId then
		Remotes.event("UI_SendNotification"):FireClient(player, { kind = "error", text = "No guild base set." })
		return
	end
	-- Delegate to DungeonService / LairService for teleport.
	local LairService = Services.optional("LairService")
	if LairService then
		LairService.teleportTo(player, guild.baseLocationId)
	end
end

function GuildService.start()
	Remotes.event("Guild_Create").OnServerEvent:Connect(function(plr, data)
		GuildService.create(plr, data and data.name, data and data.tag)
	end)
	Remotes.event("Guild_Invite").OnServerEvent:Connect(function(plr, data)
		if data and data.targetUserId then GuildService.invite(plr, data.targetUserId) end
	end)
	Remotes.event("Guild_AcceptInvite").OnServerEvent:Connect(function(plr, data)
		if data and data.guildId then GuildService.acceptInvite(plr, data.guildId) end
	end)
	Remotes.event("Guild_Kick").OnServerEvent:Connect(function(plr, data)
		if data and data.targetUserId then GuildService.kick(plr, data.targetUserId) end
	end)
	Remotes.event("Guild_Promote").OnServerEvent:Connect(function(plr, data)
		if data then GuildService.promote(plr, data.targetUserId, data.newRank) end
	end)
	Remotes.event("Guild_SummonBase").OnServerEvent:Connect(function(plr)
		GuildService.summonBase(plr)
	end)
	Remotes.func("Guild_GetInfo").OnServerInvoke = function(plr, id)
		return GuildService.getInfo(plr, id)
	end
end

return GuildService
