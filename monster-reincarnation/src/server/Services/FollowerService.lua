--!strict
-- Follower recruitment, role assignment, simple AI stub.
-- Physical behaviour would live in NPC rigs; here we track the data model.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local FollowerRoles: any = require(Shared:WaitForChild("FollowerRoles"))
local Remotes:       any = require(Shared:WaitForChild("Remotes"))
local Util:          any = require(Shared:WaitForChild("Util"))

local Services = require(script.Parent)

local FollowerService = {}

-- Player -> list of followers
local followers: { [number]: { [string]: any } } = {}

local function ensureBook(userId: number): any
	followers[userId] = followers[userId] or {}
	return followers[userId]
end

function FollowerService.recruit(player: Player, rawKind: any, rawName: any)
	local kind = tostring(rawKind)
	if kind:match("[^%w]") then return end
	local name = tostring(rawName or ""):sub(1, 24)
	local id = Util.uuid() .. "_" .. kind

	local DataService = Services.get("DataService")
	local profile = DataService.getProfile(player.UserId)
	if not profile then return end

	local book = ensureBook(player.UserId)
	book[id] = {
		id = id, kind = kind, name = #name > 0 and name or ("Unnamed " .. kind),
		role = "Worker",
		level = 1, xp = 0,
		hp = 50, maxHp = 50, loyalty = 50,
		createdAt = os.time(),
	}
	DataService.mutate(player.UserId, function(p) table.insert(p.followers, id) end)

	Remotes.event("UI_SendNotification"):FireClient(player, { kind = "success", text = "Recruited " .. kind })
end

function FollowerService.assignRole(player: Player, rawRequest: any)
	local req = Util.sanitize(rawRequest) or {}
	local id = tostring(req.followerId)
	local role = tostring(req.role)
	if not FollowerRoles.get(role) then return end

	local book = ensureBook(player.UserId)
	local f = book[id]
	if not f then return end

	-- Unique roles (e.g. Lieutenant): enforce one per player.
	local def = FollowerRoles.get(role)
	if def.unique then
		for _, other in pairs(book) do
			if other ~= f and other.role == role then
				Remotes.event("UI_SendNotification"):FireClient(player, { kind = "error", text = "Only one " .. role })
				return
			end
		end
	end
	f.role = role
end

function FollowerService.onKillAssist(player: Player, followerId: string)
	local book = ensureBook(player.UserId)
	local f = book[followerId]
	if not f then return end
	f.xp = (f.xp or 0) + 10
	while f.xp >= FollowerRoles.xpToNext(f.level) do
		f.xp -= FollowerRoles.xpToNext(f.level)
		f.level += 1
		f.maxHp = math.floor(f.maxHp * 1.1)
	end
end

function FollowerService.tickMinute()
	-- Loyalty drift: roles with moraleTick raise; idle drops slowly.
	for _, book in pairs(followers) do
		for _, f in pairs(book) do
			local def = FollowerRoles.get(f.role)
			if def and def.output and def.output.moralePerTick then
				f.loyalty = math.min(100, f.loyalty + def.output.moralePerTick)
			else
				f.loyalty = math.max(0, f.loyalty - 1)
			end
		end
	end
end

function FollowerService.countByKind(userId: number, kindSubstring: string): number
	local book = followers[userId] or {}
	local n = 0
	for _, f in pairs(book) do
		if string.find(f.kind, kindSubstring) then n += 1 end
	end
	return n
end

function FollowerService.start()
	task.spawn(function()
		while true do
			task.wait(60)
			FollowerService.tickMinute()
		end
	end)

	Remotes.event("Follower_Recruit").OnServerEvent:Connect(function(plr, data)
		FollowerService.recruit(plr, data and data.kind, data and data.name)
	end)
	Remotes.event("Follower_AssignRole").OnServerEvent:Connect(function(plr, data)
		FollowerService.assignRole(plr, data)
	end)
end

return FollowerService
