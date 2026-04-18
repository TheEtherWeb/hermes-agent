--!strict
-- Weapon chronicle: per-weapon event log (kills, transfers, fusions, inherits).
-- Stored inline on the weapon's InventoryItem.data.weapon.chronicle.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Util: any = require(Shared:WaitForChild("Util"))

local Services = require(script.Parent)

local WeaponChronicle = {}

local MAX_ENTRIES = 200
local MAX_TEXT = 160

-- Find a weapon across *all loaded profiles* (needed for owner transfers). For
-- persistence across sessions, entries are stored on the weapon itself so they
-- travel with it.
local function locateWeapon(weaponId: string): (any, any)
	local DataService = Services.get("DataService")
	for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
		local profile = DataService.getProfile(plr.UserId)
		if profile then
			for _, item in ipairs(profile.inventory) do
				if item.id == weaponId and item.data and item.data.weapon then
					return profile, item
				end
			end
		end
	end
	return nil, nil
end

function WeaponChronicle.append(weaponId: string, entry: any)
	if typeof(entry) ~= "table" then return end
	entry.text = string.sub(tostring(entry.text or ""), 1, MAX_TEXT)
	entry.ts = entry.ts or os.time()

	local _profile, item = locateWeapon(weaponId)
	if not item then return end
	local w = item.data.weapon
	w.chronicle = w.chronicle or {}
	table.insert(w.chronicle, entry)
	if #w.chronicle > MAX_ENTRIES then
		table.remove(w.chronicle, 1)
	end
end

function WeaponChronicle.onTransfer(weaponId: string, fromUserId: number?, toUserId: number?)
	WeaponChronicle.append(weaponId, {
		ts = os.time(),
		kind = "transfer",
		text = ("transferred %s -> %s"):format(tostring(fromUserId or "?"), tostring(toUserId or "?")),
		playerUserId = toUserId,
	})
end

function WeaponChronicle.onInherit(weaponId: string, heirUserId: number, bloodlineId: string, generation: number)
	WeaponChronicle.append(weaponId, {
		ts = os.time(),
		kind = "inherit",
		text = ("inherited by generation %d of bloodline %s"):format(generation, string.sub(bloodlineId, 1, 6)),
		playerUserId = heirUserId,
		generation = generation,
	})
end

function WeaponChronicle.onFusion(weaponId: string, fusedWithName: string)
	WeaponChronicle.append(weaponId, {
		ts = os.time(),
		kind = "fusion",
		text = "fused with " .. fusedWithName,
	})
end

function WeaponChronicle.onRename(weaponId: string, oldName: string, newName: string)
	WeaponChronicle.append(weaponId, {
		ts = os.time(),
		kind = "rename",
		text = ("renamed %s -> %s"):format(oldName, newName),
	})
end

function WeaponChronicle.getChronicle(weaponId: string): { any }
	local _profile, item = locateWeapon(weaponId)
	if not item then return {} end
	return Util.deepCopy(item.data.weapon.chronicle or {})
end

return WeaponChronicle
