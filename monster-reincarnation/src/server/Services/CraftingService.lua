--!strict
-- Forge weapons by combining components. Validates material ownership,
-- consumes inputs, and produces a bonded weapon item.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes:          any = require(Shared:WaitForChild("Remotes"))
local WeaponComponents: any = require(Shared:WaitForChild("WeaponComponents"))
local Util:             any = require(Shared:WaitForChild("Util"))
local Constants:        any = require(Shared:WaitForChild("Constants"))

local Services = require(script.Parent)

local CraftingService = {}

local REQUIRED_PARTS = { "blade", "hilt", "guard", "pommel" }

local function findMaterial(profile: any, templateId: string, qty: number): boolean
	local need = qty
	for _, item in ipairs(profile.inventory) do
		if item.kind == "material" and item.templateId == templateId then
			need -= item.qty
			if need <= 0 then return true end
		end
	end
	return false
end

local function consumeMaterial(profile: any, templateId: string, qty: number)
	local need = qty
	for i = #profile.inventory, 1, -1 do
		local item = profile.inventory[i]
		if item.kind == "material" and item.templateId == templateId then
			if item.qty > need then
				item.qty -= need
				return
			else
				need -= item.qty
				table.remove(profile.inventory, i)
				if need <= 0 then return end
			end
		end
	end
end

local function summariseStats(partIds: { [string]: string }, qualityMult: number): { [string]: any }, { string }
	local stats: { [string]: number } = {}
	local tags: { string } = {}

	local function add(partKind: string, id: string)
		local def = WeaponComponents.get(partKind, id)
		if not def then return end
		for k, v in pairs(def.stats or {}) do
			stats[k] = (stats[k] or 0) + (typeof(v) == "number" and v * qualityMult or v)
		end
		for _, tag in ipairs(def.tags or {}) do
			table.insert(tags, tag)
		end
	end

	add("BLADES", partIds.blade)
	add("HILTS",  partIds.hilt)
	add("GUARDS", partIds.guard)
	add("POMMELS", partIds.pommel)
	if partIds.rune then add("RUNES", partIds.rune) end

	return stats, tags
end

-- rawRequest: { blade = "IronLongblade", hilt = "LeatherBoundHilt", guard = "...",
--               pommel = "...", rune = "..." (optional), name = "..." (optional) }
function CraftingService.handleForge(player: Player, rawRequest: any)
	local req = Util.sanitize(rawRequest) or {}
	local AntiExploit = Services.get("AntiExploit")
	if not AntiExploit.checkRate(player.UserId, "forge", 2, 1) then return end

	local DataService = Services.get("DataService")
	local profile = DataService.getProfile(player.UserId)
	if not profile then return end

	for _, part in ipairs(REQUIRED_PARTS) do
		if typeof(req[part]) ~= "string" then return end
	end

	-- Validate materials: each part must resolve, and material assumption is
	-- that the user owns one matching ingot/material of the same templateId.
	local partIds: { [string]: string } = {}
	for _, part in ipairs(REQUIRED_PARTS) do partIds[part] = req[part] end
	if typeof(req.rune) == "string" then partIds.rune = req.rune end

	-- Simplistic materials: each component needs one unit of its display name.
	-- Real game would map component->materials in a schema.
	local matNeeds: { [string]: number } = {}
	for _, part in ipairs(REQUIRED_PARTS) do
		matNeeds[partIds[part]] = (matNeeds[partIds[part]] or 0) + 1
	end
	if partIds.rune then matNeeds[partIds.rune] = (matNeeds[partIds.rune] or 0) + 1 end

	for mat, qty in pairs(matNeeds) do
		if not findMaterial(profile, mat, qty) then
			Remotes.event("UI_SendNotification"):FireClient(player, { kind = "error", text = "Missing material: " .. mat })
			return
		end
	end

	-- Consume materials.
	DataService.mutate(player.UserId, function(p)
		for mat, qty in pairs(matNeeds) do
			consumeMaterial(p, mat, qty)
		end
	end)

	-- Roll quality.
	local rng = Random.new(os.time() + player.UserId + math.random(1, 1e6))
	local quality = WeaponComponents.rollQuality(rng)
	local stats, tags = summariseStats(partIds, quality.mult)

	local weaponId = Util.uuid()
	local name = (typeof(req.name) == "string" and #req.name <= 40 and req.name) or "Bonded Weapon"

	local weapon = {
		id = weaponId,
		templateId = "player_forged",
		components = partIds,
		baseStats = stats,
		baseTags = tags,
		quality = quality.key,
		name = name,
		crafterUserId = player.UserId,
		persona = { level = 1, xp = 0, awakenedBranch = nil, titles = {} },
		chronicle = {
			{ ts = os.time(), kind = "forge", text = ("forged by %s"):format(player.Name), playerUserId = player.UserId, generation = profile.generation },
		},
		ownerUserId = player.UserId,
		bondedBloodline = profile.bloodlineId,
	}

	local item = {
		id = weaponId,
		kind = "weapon",
		templateId = "player_forged",
		qty = 1,
		data = { weapon = weapon },
	}

	DataService.mutate(player.UserId, function(p)
		if #p.inventory >= Constants.AntiExploit.MAX_INVENTORY_SIZE then return end
		table.insert(p.inventory, item)
	end)

	Remotes.event("UI_SendNotification"):FireClient(player, {
		kind = "success",
		text = ("Forged %s (%s quality)"):format(name, quality.key),
	})
end

function CraftingService.start()
	Remotes.event("Crafting_Forge").OnServerEvent:Connect(function(plr, req)
		CraftingService.handleForge(plr, req)
	end)
end

return CraftingService
