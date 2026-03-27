-- PlayerStateSchema.lua
-- Canonical PlayerState shape and constructor.
-- Shared by server (PlayerManager) and client (PlayerInit mirror).
-- ALL field names must be used consistently across every script.

local Constants = require(script.Parent.Parent.Data.Constants)
local Families  = require(script.Parent.Parent.Data.Families)

local PlayerStateSchema = {}

-- Construct a fresh PlayerState for a new character.
-- @param userId      number   player.UserId
-- @param race        string   "Gem" | "Ore"
-- @param familyId    string   family id from Families.lua
-- @param traitId     string   trait id from Traits.lua
-- @param weaponStyle string   weapon type id from WeaponTypes.lua (e.g. "Sword_Projection")
function PlayerStateSchema.New(userId, race, familyId, traitId, weaponStyle)
	local family = Families:Get(race, familyId)
	local mods   = family and family.statModifiers or {}

	local maxHealth = Constants.MAX_HEALTH + (mods.maxHealthBonus or 0)
	local maxGuard  = Constants.MAX_GUARD  + (mods.guardMaxBonus  or 0)

	local state = {
		-- ── Identity ─────────────────────────────────────────────────────
		UserId      = userId,
		Race        = race,       -- "Gem" | "Ore"
		Family      = familyId,
		Trait       = traitId,
		WeaponStyle = weaponStyle, -- active weapon type id

		-- ── Vitals ───────────────────────────────────────────────────────
		Health      = maxHealth,
		MaxHealth   = maxHealth,
		Guard       = maxGuard,
		MaxGuard    = maxGuard,

		-- ── Race resource ─────────────────────────────────────────────────
		-- Gems use Resonance; Ores don't have a separate resource meter.
		Resonance   = (race == "Gem") and Constants.MAX_RESONANCE or nil,
		MaxResonance = (race == "Gem") and Constants.MAX_RESONANCE or nil,

		-- ── Heat (universal, flavoured differently) ───────────────────────
		Heat        = 0,

		-- ── Weapon state ─────────────────────────────────────────────────
		WeaponActive  = false,
		WeaponBroken  = false,
		DisarmedTimer = 0,       -- seconds remaining in disarmed state

		-- ── Rank & progression ────────────────────────────────────────────
		RankIndex   = 1,
		XP          = 0,

		-- ── Evolution / advancement flags (framework only) ────────────────
		RefinementState = nil,   -- nil | "Eligible" | "InProgress" | "Complete"
		AlloyState      = nil,   -- nil | "Eligible" | "Active"

		-- ── Status flags ─────────────────────────────────────────────────
		IsCollapsed      = false,
		IsBlocking       = false,
		IsStaggered      = false,

		-- ── Timing (server-side, ignored by UI) ──────────────────────────
		LastCombatTime   = 0,   -- tick() timestamp of last damage event
		LastGuardHitTime = 0,   -- for guard regen delay
		LastAttackTime   = 0,   -- for rate-limiting
	}

	return state
end

-- Produce a shallow patch table (only changed fields) from old → new state.
-- Used by StateChanged remote to minimise network payload.
function PlayerStateSchema.Diff(oldState, newState)
	local patch = {}
	for k, v in pairs(newState) do
		if oldState[k] ~= v then
			patch[k] = v
		end
	end
	return patch
end

-- Apply a patch to an existing state table in-place.
function PlayerStateSchema.Apply(state, patch)
	for k, v in pairs(patch) do
		state[k] = v
	end
end

return PlayerStateSchema
