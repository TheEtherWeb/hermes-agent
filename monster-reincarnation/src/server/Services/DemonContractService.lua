--!strict
-- Demon contracts between players. Demons offer buffs; humans accept with
-- terms (duration, demand, penalty). Only one active contract per player.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants: any = require(Shared:WaitForChild("Constants"))
local Remotes:   any = require(Shared:WaitForChild("Remotes"))
local Util:      any = require(Shared:WaitForChild("Util"))

local Services = require(script.Parent)

local DemonContractService = {}

local contracts: { [string]: any } = {}
local active:    { [number]: string } = {}       -- userId -> contractId

local VALID_OFFERS = {
	statBuff = true,        -- { stat = "Strength", amount = 10 }
	spellGrant = true,      -- { spellId = "Shadowbind" }
	weaponInfusion = true,  -- { affinity = "fire" }
	heal = true,            -- { amount = number }
}

local VALID_DEMANDS = {
	sacrificeItem = true,   -- { templateId, qty }
	killFaction = true,     -- { faction, count }
	killNpc = true,         -- { npcKind, count }
	loyalty = true,         -- { durationSec }
	goldTribute = true,     -- { amount }
}

local VALID_PENALTIES = {
	none = true, soulAbsorb = true, corruptionSpike = true, statDrain = true,
}

local function validateOffer(o: any): boolean
	if typeof(o) ~= "table" or not VALID_OFFERS[o.kind] then return false end
	if o.kind == "statBuff" then
		return typeof(o.stat) == "string" and typeof(o.amount) == "number" and o.amount <= 100
	end
	return true
end

local function validateDemand(d: any): boolean
	if typeof(d) ~= "table" or not VALID_DEMANDS[d.kind] then return false end
	if d.kind == "sacrificeItem" then return typeof(d.templateId) == "string" and typeof(d.qty) == "number" end
	if d.kind == "goldTribute" then return typeof(d.amount) == "number" and d.amount >= 0 end
	return true
end

function DemonContractService.offer(demon: Player, rawTerms: any)
	local terms = Util.sanitize(rawTerms) or {}
	local DataService = Services.get("DataService")
	local demonProfile = DataService.getProfile(demon.UserId)
	if not demonProfile or demonProfile.race ~= "DemonSpark" then return end
	if active[demon.UserId] then return end

	local hostUserId = tonumber(terms.hostUserId)
	if not hostUserId then return end
	local host = Players:GetPlayerByUserId(hostUserId)
	if not host then return end
	if active[hostUserId] then return end

	if not validateOffer(terms.offer) then return end
	if not validateDemand(terms.demand) then return end
	if not VALID_PENALTIES[terms.penaltyKind or "none"] then return end

	local duration = math.clamp(tonumber(terms.durationSec) or 3600,
		Constants.Contract.MIN_DURATION_SEC, Constants.Contract.MAX_DURATION_SEC)

	local id = Util.uuid()
	local contract = {
		id = id,
		demonUserId = demon.UserId,
		hostUserId = hostUserId,
		offer = terms.offer,
		demand = terms.demand,
		penaltyKind = terms.penaltyKind or "none",
		expiresAt = os.time() + duration,
		state = "pending",
	}
	contracts[id] = contract

	Remotes.event("Contract_Offer"):FireClient(host, contract)
end

function DemonContractService.accept(host: Player, rawContractId: any)
	local id = tostring(rawContractId)
	local contract = contracts[id]
	if not contract or contract.state ~= "pending" then return end
	if contract.hostUserId ~= host.UserId then return end
	if active[host.UserId] or active[contract.demonUserId] then return end

	contract.state = "active"
	active[host.UserId] = id
	active[contract.demonUserId] = id

	local DataService = Services.get("DataService")

	-- Apply host-side offer immediately.
	if contract.offer.kind == "statBuff" then
		DataService.mutate(host.UserId, function(p)
			p.buffs = p.buffs or {}
			table.insert(p.buffs, {
				key = "contract_" .. contract.offer.stat,
				stat = contract.offer.stat,
				amount = contract.offer.amount,
				expiresAt = contract.expiresAt,
			})
		end)
	elseif contract.offer.kind == "heal" then
		local char = host.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then hum.Health = math.min(hum.MaxHealth, hum.Health + (contract.offer.amount or 0)) end
	end

	-- Raise demon's faction standing.
	DataService.mutate(contract.demonUserId, function(p)
		p.factions = p.factions or {}
		p.factions.DemonCourt = (p.factions.DemonCourt or 0) + 5
	end)

	Remotes.event("UI_SendNotification"):FireClient(host, { kind = "info", text = "Contract sealed." })
end

function DemonContractService.reject(host: Player, rawContractId: any)
	local id = tostring(rawContractId)
	local contract = contracts[id]
	if not contract then return end
	if contract.hostUserId ~= host.UserId then return end
	contract.state = "rejected"
	contracts[id] = nil
end

function DemonContractService.breach(userId: number)
	local id = active[userId]
	if not id then return end
	local contract = contracts[id]
	if not contract then return end
	contract.state = "breached"

	local DataService = Services.get("DataService")
	if contract.penaltyKind == "soulAbsorb" then
		DataService.mutate(contract.hostUserId, function(p)
			for k, v in pairs(p.stats) do
				if typeof(v) == "number" then p.stats[k] = math.max(1, math.floor(v * 0.9)) end
			end
		end)
	elseif contract.penaltyKind == "corruptionSpike" then
		DataService.mutate(contract.hostUserId, function(p) p.corruption = (p.corruption or 0) + 25 end)
	elseif contract.penaltyKind == "statDrain" then
		DataService.mutate(contract.hostUserId, function(p) p.stats.Strength = math.max(1, (p.stats.Strength or 1) - 2) end)
	end

	active[contract.hostUserId] = nil
	active[contract.demonUserId] = nil
	contracts[id] = nil
end

function DemonContractService.fulfill(userId: number)
	local id = active[userId]
	if not id then return end
	local contract = contracts[id]
	if not contract then return end
	contract.state = "fulfilled"

	local DataService = Services.get("DataService")
	DataService.mutate(contract.demonUserId, function(p)
		p.trackers = p.trackers or {}
		p.trackers.contractsFulfilled = (p.trackers.contractsFulfilled or 0) + 1
		p.factions = p.factions or {}
		p.factions.DemonCourt = (p.factions.DemonCourt or 0) + 10
	end)

	active[contract.hostUserId] = nil
	active[contract.demonUserId] = nil
	contracts[id] = nil
end

function DemonContractService.start()
	-- Sweep expired contracts once a minute.
	task.spawn(function()
		while true do
			task.wait(60)
			local now = os.time()
			for id, c in pairs(contracts) do
				if c.expiresAt and now > c.expiresAt and c.state == "active" then
					DemonContractService.breach(c.hostUserId)
				end
			end
		end
	end)

	Remotes.event("Contract_Offer").OnServerEvent:Connect(function(plr, terms)
		DemonContractService.offer(plr, terms)
	end)
	Remotes.event("Contract_Accept").OnServerEvent:Connect(function(plr, id)
		DemonContractService.accept(plr, id)
	end)
	Remotes.event("Contract_Reject").OnServerEvent:Connect(function(plr, id)
		DemonContractService.reject(plr, id)
	end)
	Remotes.event("Contract_Breach").OnServerEvent:Connect(function(plr, _)
		DemonContractService.breach(plr.UserId)
	end)
end

return DemonContractService
