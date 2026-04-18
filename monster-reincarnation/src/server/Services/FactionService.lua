--!strict
-- Player/faction reputation and joinability. Events from combat / contracts /
-- quests feed into FactionService.adjust, which applies capped deltas.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local FactionData: any = require(Shared:WaitForChild("FactionData"))
local Remotes:     any = require(Shared:WaitForChild("Remotes"))

local Services = require(script.Parent)

local FactionService = {}

local REP_CAP = 200

function FactionService.adjust(userId: number, factionId: string, delta: number)
	local faction = FactionData.get(factionId)
	if not faction then return end
	local DataService = Services.get("DataService")
	DataService.mutate(userId, function(p)
		p.factions = p.factions or {}
		local current = p.factions[factionId] or faction.initial or 0
		p.factions[factionId] = math.clamp(current + delta, -REP_CAP, REP_CAP)
	end)
end

function FactionService.onEvent(userId: number, factionId: string, eventKey: string)
	local faction = FactionData.get(factionId)
	if not faction or not faction.actions then return end
	local delta = faction.actions[eventKey]
	if not delta then return end
	FactionService.adjust(userId, factionId, delta)
end

function FactionService.tryJoin(player: Player, rawFactionId: any)
	local factionId = tostring(rawFactionId)
	local faction = FactionData.get(factionId)
	if not faction or not faction.joinable then return end

	local DataService = Services.get("DataService")
	local profile = DataService.getProfile(player.UserId)
	if not profile then return end

	local req = faction.requires or {}
	if req.level and profile.level < req.level then return end
	if req.intellect and profile.stats.Intellect < req.intellect then return end
	if req.race and profile.race ~= req.race then return end

	DataService.mutate(player.UserId, function(p)
		p.memberships = p.memberships or {}
		p.memberships[factionId] = os.time()
	end)
	Remotes.event("UI_SendNotification"):FireClient(player, { kind = "success", text = "Joined " .. faction.display })
end

function FactionService.leave(player: Player, rawFactionId: any)
	local factionId = tostring(rawFactionId)
	local DataService = Services.get("DataService")
	DataService.mutate(player.UserId, function(p)
		if p.memberships then p.memberships[factionId] = nil end
	end)
end

function FactionService.start()
	Remotes.event("Faction_Join").OnServerEvent:Connect(function(plr, id) FactionService.tryJoin(plr, id) end)
	Remotes.event("Faction_Leave").OnServerEvent:Connect(function(plr, id) FactionService.leave(plr, id) end)
end

return FactionService
