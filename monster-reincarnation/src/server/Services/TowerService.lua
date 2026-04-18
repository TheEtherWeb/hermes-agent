--!strict
-- Endgame tower: 30 floors, periodic bosses, twist rules per floor.
-- Floor data comes from DungeonData.TOWER. Parties reserve private servers
-- via TeleportService; here we track per-guild progress.

local TeleportService = game:GetService("TeleportService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DungeonData: any = require(Shared:WaitForChild("DungeonData"))
local Remotes:     any = require(Shared:WaitForChild("Remotes"))

local Services = require(script.Parent)

local TowerService = {}

local playerProgress: { [number]: number } = {}   -- highest cleared floor
local guildProgress:  { [string]: number } = {}

function TowerService.currentFloor(player: Player): number
	return playerProgress[player.UserId] or 0
end

function TowerService.enter(player: Player, rawFloor: any)
	local requested = math.clamp(tonumber(rawFloor) or 1, 1, DungeonData.TOWER.floors)
	local highest = TowerService.currentFloor(player)
	if requested > highest + 1 then
		Remotes.event("UI_SendNotification"):FireClient(player, { kind = "error", text = "Clear the previous floor first." })
		return
	end

	local twist = DungeonData.TOWER.twistForFloor(requested)
	local boss  = DungeonData.TOWER.bossAtFloor(requested)

	-- Normally: reserve a teleport server and send players.
	-- Here: just notify + set a pseudo in-tower flag.
	Remotes.event("UI_SendNotification"):FireClient(player, {
		kind = "info",
		text = ("Entering floor %d (%s%s)"):format(requested, twist, boss and (", boss: " .. boss) or ""),
	})
end

function TowerService.clearFloor(player: Player, floor: number)
	local prev = playerProgress[player.UserId] or 0
	if floor > prev then playerProgress[player.UserId] = floor end

	local DataService = Services.get("DataService")
	local profile = DataService.getProfile(player.UserId)
	if profile and profile.guildId then
		guildProgress[profile.guildId] = math.max(guildProgress[profile.guildId] or 0, floor)
		local Guild = Services.get("Guild")
		Guild.addScore(profile.guildId, 10 + floor * 2)
	end

	-- Major floors drop unique mats.
	local boss = DungeonData.TOWER.bossAtFloor(floor)
	if boss then
		DataService.mutate(player.UserId, function(p)
			table.insert(p.inventory, {
				id = game:GetService("HttpService"):GenerateGUID(false),
				kind = "material", templateId = "DreamheartShard", qty = 1,
			})
		end)
		Remotes.event("UI_SendNotification"):FireClient(player, {
			kind = "success", text = ("Floor %d boss defeated: %s"):format(floor, boss),
		})
	end
end

function TowerService.start()
	Remotes.event("Dungeon_EnterTower").OnServerEvent:Connect(function(plr, floor)
		TowerService.enter(plr, floor)
	end)
end

return TowerService
