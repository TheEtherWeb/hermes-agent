--!strict
-- Evaluates evolution node unlock conditions against a profile. Applies the
-- granted effects when a player chooses an unlocked node.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Evolution: any = require(Shared:WaitForChild("EvolutionTrees"))
local Remotes:   any = require(Shared:WaitForChild("Remotes"))
local Util:      any = require(Shared:WaitForChild("Util"))

local Services = require(script.Parent)

local EvolutionService = {}

-- Profile-scratch counters that conditions may examine. These live on the
-- profile (hidden + some first-class fields the other services bump).
local function checkCondition(profile: any, cond: any): boolean
	if cond.poisonDamageDealt and (profile.trackers and profile.trackers.poisonDamageDealt or 0) < cond.poisonDamageDealt then return false end
	if cond.webTraversed and (profile.trackers and profile.trackers.webTraversed or 0) < cond.webTraversed then return false end
	if cond.hidden then
		for hk, hv in pairs(cond.hidden) do
			if (profile.hidden[hk] or 0) < hv then return false end
		end
	end
	if cond.priorEvolutions and (profile.trackers and profile.trackers.priorEvolutions or 0) < cond.priorEvolutions then return false end
	if cond.dungeonSize and (profile.trackers and profile.trackers.dungeonSize or 0) < cond.dungeonSize then return false end
	if cond.followersOfKind then
		for kind, n in pairs(cond.followersOfKind) do
			local have = 0
			for _, fid in ipairs(profile.followers) do
				if string.find(fid, kind) then have += 1 end
			end
			if have < n then return false end
		end
	end
	if cond.contractsFulfilled and (profile.trackers and profile.trackers.contractsFulfilled or 0) < cond.contractsFulfilled then return false end
	if cond.statMaxed then
		if (profile.stats[cond.statMaxed] or 0) < 20 then return false end
	end
	if cond.territoriesConquered and (profile.trackers and profile.trackers.territoriesConquered or 0) < cond.territoriesConquered then return false end
	if cond.chieftainsRecruited and (profile.trackers and profile.trackers.chieftainsRecruited or 0) < cond.chieftainsRecruited then return false end
	if cond.ritualsPerformed and (profile.trackers and profile.trackers.ritualsPerformed or 0) < cond.ritualsPerformed then return false end
	if cond.legendaryKills and (profile.trackers and profile.trackers.legendaryKills or 0) < cond.legendaryKills then return false end
	if cond.mirrorKill and (profile.trackers and profile.trackers.mirrorKill or 0) < cond.mirrorKill then return false end
	return true
end

function EvolutionService.listAvailable(profile: any): { any }
	local tree = Evolution.getTree(profile.race) or {}
	local out = {}
	for _, node in ipairs(tree) do
		local unlocked = checkCondition(profile, node.conditions or {})
		-- Hide secret nodes until at least one sub-condition is partially met.
		local visible = true
		if node.secret then
			visible = unlocked    -- conservative: show only once fully unlocked
		end
		if visible then
			local copy = Util.deepCopy(node)
			copy.unlocked = unlocked
			table.insert(out, copy)
		end
	end
	return out
end

function EvolutionService.apply(player: Player, rawNodeId: any)
	local nodeId = tostring(rawNodeId)
	local DataService = Services.get("DataService")
	local profile = DataService.getProfile(player.UserId)
	if not profile then return end

	local node = Evolution.findNode(profile.race, nodeId)
	if not node then return end
	if not checkCondition(profile, node.conditions or {}) then return end

	DataService.mutate(player.UserId, function(p)
		p.trackers = p.trackers or {}
		p.trackers.priorEvolutions = (p.trackers.priorEvolutions or 0) + 1
		for statKey, statVal in pairs((node.grants and node.grants.stats) or {}) do
			p.stats[statKey] = (p.stats[statKey] or 0) + statVal
		end
		if node.grants and node.grants.ability then
			p.abilities = p.abilities or {}
			table.insert(p.abilities, node.grants.ability)
		end
		p.lastEvolution = node.id
		-- Ultimate evolutions grant titles and render a world announcement.
		if node.ultimate then
			p.titles = p.titles or {}
			table.insert(p.titles, node.display)
		end
	end)

	Remotes.event("UI_SendNotification"):FireClient(player, {
		kind = "success", text = "Evolved: " .. node.display,
	})
end

function EvolutionService.start()
	Remotes.event("Evolution_Choose").OnServerEvent:Connect(function(plr, nodeId)
		EvolutionService.apply(plr, nodeId)
	end)

	Remotes.func("EvolutionTree_Get").OnServerInvoke = function(plr)
		local DataService = Services.get("DataService")
		local profile = DataService.getProfile(plr.UserId)
		if not profile then return {} end
		return EvolutionService.listAvailable(profile)
	end
end

return EvolutionService
