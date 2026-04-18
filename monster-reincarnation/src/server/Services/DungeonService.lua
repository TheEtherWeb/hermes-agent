--!strict
-- World zones and tower coordination. Zones run on their own server instances
-- via TeleportService. For a single-server build, we expose APIs to spawn
-- encounters and track boss clears.

local TeleportService = game:GetService("TeleportService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DungeonData: any = require(Shared:WaitForChild("DungeonData"))
local Remotes:     any = require(Shared:WaitForChild("Remotes"))

local Services = require(script.Parent)

local DungeonService = {}

-- Per-player current zone for quest gating and encounter scaling.
local playerZone: { [number]: string } = {}

function DungeonService.getZone(zoneId: string)
	return DungeonData.zone(zoneId)
end

function DungeonService.enterZone(player: Player, zoneId: string)
	if not DungeonData.zone(zoneId) then return end
	playerZone[player.UserId] = zoneId
	Remotes.event("UI_SendNotification"):FireClient(player, { kind = "info", text = "Entering " .. zoneId })
end

function DungeonService.currentZone(userId: number): string?
	return playerZone[userId]
end

-- Scale mobs / loot to player level within zone tier.
function DungeonService.scaleForZone(zoneId: string, playerLevel: number): { hp: number, dmg: number, xp: number }
	local zone = DungeonData.zone(zoneId)
	local tier = zone and zone.tier or 1
	local base = 20 * tier
	return {
		hp  = base + playerLevel * 4,
		dmg = math.floor(base * 0.3),
		xp  = 10 * tier,
	}
end

-- Boss clear hook: grants guild score, drops rare material into inventory.
function DungeonService.onBossClear(player: Player, zoneId: string)
	local DataService = Services.get("DataService")
	local profile = DataService.getProfile(player.UserId)
	if not profile then return end

	local zone = DungeonData.zone(zoneId)
	if not zone then return end

	DataService.mutate(player.UserId, function(p)
		p.trackers = p.trackers or {}
		p.trackers.legendaryKills = (p.trackers.legendaryKills or 0) + 1
		-- award a random material from the zone
		local mats = zone.materials or {}
		local drop = mats[math.random(1, math.max(1, #mats))]
		if drop then
			table.insert(p.inventory, { id = game:GetService("HttpService"):GenerateGUID(false),
				kind = "material", templateId = drop, qty = 1 })
		end
	end)

	if profile.guildId then
		local Guild = Services.get("Guild")
		Guild.addScore(profile.guildId, 25 * (zone.tier or 1))
	end

	Remotes.event("UI_SendNotification"):FireClient(player, { kind = "success", text = "Defeated boss of " .. zoneId })
end

function DungeonService.start()
	-- No direct remotes; other services call in.
end

return DungeonService
