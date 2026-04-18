--!strict
-- Lair claim + room placement. Each player (or guild) owns one dungeon core
-- with a grid of rooms. Rooms produce resources and supply passive effects.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DungeonData: any = require(Shared:WaitForChild("DungeonData"))
local Remotes:     any = require(Shared:WaitForChild("Remotes"))
local Util:        any = require(Shared:WaitForChild("Util"))

local Services = require(script.Parent)

local LairService = {}

-- In-memory lair registry. Persisted via DataService alongside the profile
-- (profile.dungeonId -> lairId, and we mirror the lair object in a dedicated
-- section of the profile under .lair).
-- For brevity we keep lairs keyed by userId of the claimant (or guildId).

local lairs: { [string]: any } = {}  -- keyed by ownerKey ("u_<userId>" or "g_<guildId>")

local function ownerKey(profile: any): string
	if profile.guildId then return "g_" .. profile.guildId end
	return "u_" .. profile.userId
end

local function ensureLair(profile: any): any
	local key = ownerKey(profile)
	if not lairs[key] then
		lairs[key] = {
			id = Util.uuid(),
			ownerKey = key,
			rooms = {},           -- array of { id, roomId, x, y, level, placedAt }
			resources = { Food = 0, Water = 0, Mana = 0, Souls = 0, Morale = 50 },
			claimedZone = nil,
			lastTick = os.time(),
		}
	end
	return lairs[key]
end

function LairService.claim(player: Player, zoneId: string)
	local DataService = Services.get("DataService")
	local profile = DataService.getProfile(player.UserId)
	if not profile then return end
	if not DungeonData.zone(zoneId) then return end

	local lair = ensureLair(profile)
	lair.claimedZone = zoneId
	DataService.mutate(player.UserId, function(p) p.dungeonId = lair.id end)
	Remotes.event("UI_SendNotification"):FireClient(player, { kind = "success", text = "Claimed " .. zoneId })
end

local function hasMaterials(profile: any, cost: any): boolean
	for mat, qty in pairs(cost or {}) do
		local have = 0
		for _, item in ipairs(profile.inventory) do
			if item.kind == "material" and item.templateId == mat then have += item.qty end
		end
		if have < qty then return false end
	end
	return true
end

local function consume(profile: any, cost: any)
	for mat, qty in pairs(cost or {}) do
		local remaining = qty
		for i = #profile.inventory, 1, -1 do
			local item = profile.inventory[i]
			if item.kind == "material" and item.templateId == mat then
				if item.qty > remaining then
					item.qty -= remaining; remaining = 0; break
				else
					remaining -= item.qty
					table.remove(profile.inventory, i)
					if remaining <= 0 then break end
				end
			end
		end
	end
end

function LairService.placeRoom(player: Player, rawRequest: any)
	local req = Util.sanitize(rawRequest) or {}
	local roomId = tostring(req.roomId)
	local room = DungeonData.room(roomId)
	if not room then return end

	local DataService = Services.get("DataService")
	local profile = DataService.getProfile(player.UserId)
	if not profile then return end

	-- Race gate
	if room.requires and room.requires.race and room.requires.race ~= profile.race then
		Remotes.event("UI_SendNotification"):FireClient(player, { kind = "error", text = "Race-restricted room." })
		return
	end

	local lair = ensureLair(profile)

	-- Unique rooms can only be placed once.
	if room.unique then
		for _, r in ipairs(lair.rooms) do
			if r.roomId == roomId then
				Remotes.event("UI_SendNotification"):FireClient(player, { kind = "error", text = "Only one allowed." })
				return
			end
		end
	end

	if not hasMaterials(profile, room.cost) then
		Remotes.event("UI_SendNotification"):FireClient(player, { kind = "error", text = "Insufficient materials." })
		return
	end

	DataService.mutate(player.UserId, function(p) consume(p, room.cost) end)

	table.insert(lair.rooms, {
		id = Util.uuid(), roomId = roomId,
		x = tonumber(req.x) or 0, y = tonumber(req.y) or 0,
		level = 1, placedAt = os.time(),
	})

	-- Update evolution-tracker for "dungeon size" used by Slime Sovereign.
	DataService.mutate(player.UserId, function(p)
		p.trackers = p.trackers or {}
		p.trackers.dungeonSize = #lair.rooms
	end)

	Remotes.event("UI_SendNotification"):FireClient(player, { kind = "success", text = "Built " .. room.display })
end

function LairService.removeRoom(player: Player, rawRoomId: any)
	local id = tostring(rawRoomId)
	local DataService = Services.get("DataService")
	local profile = DataService.getProfile(player.UserId)
	if not profile then return end
	local lair = ensureLair(profile)
	for i, r in ipairs(lair.rooms) do
		if r.id == id then
			table.remove(lair.rooms, i)
			DataService.mutate(player.UserId, function(p)
				p.trackers = p.trackers or {}
				p.trackers.dungeonSize = #lair.rooms
			end)
			return
		end
	end
end

function LairService.teleportTo(player: Player, lairId: string)
	-- Placeholder: locate a spawn pad tagged by lairId. In a multi-server build
	-- this would TeleportToPrivateServer with a reservation code.
	local char = player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		(char.HumanoidRootPart :: BasePart).CFrame = CFrame.new(0, 50, 0)
	end
end

-- Tick: every minute, rooms generate their outputs.
function LairService.start()
	task.spawn(function()
		while true do
			task.wait(60)
			for _, lair in pairs(lairs) do
				for _, r in ipairs(lair.rooms) do
					local room = DungeonData.room(r.roomId)
					if room and room.gen and room.gen.spawnPer then
						lair.resources.Morale = math.min(100, (lair.resources.Morale or 50) + 1)
					end
					if room and room.effect and room.effect.corruption then
						local ownerId = lair.ownerKey:match("^u_(%d+)$")
						if ownerId then
							local DataService = Services.get("DataService")
							DataService.mutate(tonumber(ownerId) :: number, function(p)
								p.corruption = (p.corruption or 0) + room.effect.corruption
							end)
						end
					end
				end
			end
		end
	end)

	Remotes.event("Lair_PlaceRoom").OnServerEvent:Connect(function(plr, req)
		LairService.placeRoom(plr, req)
	end)
	Remotes.event("Lair_RemoveRoom").OnServerEvent:Connect(function(plr, id)
		LairService.removeRoom(plr, id)
	end)
end

function LairService.getLair(profile: any): any?
	return lairs[ownerKey(profile)]
end

return LairService
