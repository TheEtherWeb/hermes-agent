--!strict
-- Weapons accumulate XP from kills, stance usage, etc. Thresholds trigger
-- "awakening" into a persona branch. Persona grants new abilities and stat
-- bonuses.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants: any = require(Shared:WaitForChild("Constants"))
local Util:      any = require(Shared:WaitForChild("Util"))

local Services = require(script.Parent)

local WeaponPersona = {}

-- XP thresholds for persona levels.
local XP_PER_LEVEL = { 50, 150, 400, 1000, 2500, 5000, 10000 }

local BRANCHES = {
	-- Trigger heuristic: the stance most used when the awakening XP landed.
	-- Branches grant effects resolved by CombatService / CraftingService.
	Guardian = {
		unlockStance = "OneHand",
		titles = { "Shieldbreaker", "Warden" },
		effects = { blockRatingBonus = 4 },
	},
	Berserker = {
		unlockStance = "DualWield",
		titles = { "Rampage", "Bloodbrand" },
		effects = { bleedDamage = 6 },
	},
	Ironsworn = {
		unlockStance = "TwoHand",
		titles = { "Cleaver", "Mountainsplit" },
		effects = { postureBreakBonus = 0.10 },
	},
	Arcanist = {
		unlockStance = "SpellGrip",
		titles = { "Sparkweaver", "Gloomcall" },
		effects = { manaRegenBonus = 3 },
	},
	Spiderkiss = {
		-- Special: unlocked by killing 100 of a single enemy kind.
		titles = { "Spiderkiss Blade", "Venomdream" },
		effects = { poisonDamage = 6 },
	},
}

local function findEquipped(profile: any)
	if not profile.equippedWeaponId then return nil end
	for _, item in ipairs(profile.inventory) do
		if item.id == profile.equippedWeaponId then return item end
	end
	return nil
end

local function addXP(weaponItem: any, xp: number): (number, string?)
	local w = weaponItem.data.weapon
	w.persona.xp += xp
	local newLevel = w.persona.level
	local awakened = nil
	while true do
		local need = XP_PER_LEVEL[newLevel + 1]
		if not need or w.persona.xp < need then break end
		newLevel += 1
		-- At level 3 we mark awakenedBranch if not yet set.
		if not w.persona.awakenedBranch and newLevel >= 3 then
			awakened = "Guardian"
		end
	end
	w.persona.level = newLevel
	return newLevel, awakened
end

-- Tracks per-weapon per-enemy-kind kill counts for secret awakenings.
local weaponKillTracker: { [string]: { [string]: number } } = {}

function WeaponPersona.onKill(player: Player, targetId: string)
	local DataService = Services.get("DataService")
	local profile = DataService.getProfile(player.UserId)
	if not profile then return end
	local item = findEquipped(profile)
	if not item or not item.data or not item.data.weapon then return end

	DataService.mutate(player.UserId, function()
		local _level, awakened = addXP(item, 10)
		if awakened then
			item.data.weapon.persona.awakenedBranch = awakened
			table.insert(item.data.weapon.persona.titles, BRANCHES[awakened].titles[1])
		end
	end)

	-- Track per-enemy-kind count; 100 spiders -> Spiderkiss Blade.
	local kind = (targetId:match("^(%a+)") or "Unknown")
	weaponKillTracker[item.id] = weaponKillTracker[item.id] or {}
	local t = weaponKillTracker[item.id]
	t[kind] = (t[kind] or 0) + 1
	if kind == "Spider" and t[kind] >= 100 and item.data.weapon.persona.awakenedBranch ~= "Spiderkiss" then
		DataService.mutate(player.UserId, function()
			item.data.weapon.persona.awakenedBranch = "Spiderkiss"
			table.insert(item.data.weapon.persona.titles, "Spiderkiss Blade")
		end)
	end
end

function WeaponPersona.onStanceUse(player: Player, stance: string)
	local DataService = Services.get("DataService")
	local profile = DataService.getProfile(player.UserId)
	if not profile then return end
	local item = findEquipped(profile)
	if not item or not item.data or not item.data.weapon then return end
	DataService.mutate(player.UserId, function()
		addXP(item, 1)
	end)
end

function WeaponPersona.getBranchEffects(branchId: string?): { [string]: any }
	if not branchId then return {} end
	local b = BRANCHES[branchId]
	return b and b.effects or {}
end

return WeaponPersona
