-- CombatUtils.lua
-- Pure combat math functions with no side effects.
-- Safe to require on both server and client.

local Constants  = require(script.Parent.Parent.Data.Constants)
local RankTiers  = require(script.Parent.Parent.Data.RankTiers)
local Traits     = require(script.Parent.Parent.Data.Traits)
local WeaponTypes = require(script.Parent.Parent.Data.WeaponTypes)

local CombatUtils = {}

-- Scale a base damage value by the attacker's current rank.
function CombatUtils.ApplyStatScale(baseDamage, rankIndex)
	local tier = RankTiers[rankIndex] or RankTiers[1]
	return math.floor(baseDamage * tier.statScale)
end

-- Calculate final damage dealt to the target's health.
-- @param attackerState  PlayerState of the attacker
-- @param weaponTypeId   string weapon id (from WeaponTypes)
-- @param attackType     "light" | "heavy"
function CombatUtils.CalculateDamage(attackerState, weaponTypeId, attackType)
	local weaponDef = WeaponTypes[weaponTypeId]
	if not weaponDef then return 0 end

	local base = (attackType == "heavy") and weaponDef.heavyDamage or weaponDef.lightDamage

	-- Apply rank scaling
	base = CombatUtils.ApplyStatScale(base, attackerState.RankIndex)

	-- Apply trait modifiers
	local traitTable = Traits:Get(attackerState.Race, attackerState.Trait)
	if traitTable then
		if attackType == "light" and traitTable.passiveEffect == "lightDamageMult" then
			base = math.floor(base * traitTable.passiveValue)
		elseif attackType == "heavy" and traitTable.passiveEffect == "heavyDamageMult" then
			base = math.floor(base * traitTable.passiveValue)
		end
	end

	-- Critical hit check (trait StarFacet / Prism etc.)
	local critChance = 0
	if traitTable and traitTable.passiveEffect == "criticalHitChance" then
		critChance = traitTable.passiveValue
	end
	if math.random() < critChance then
		base = math.floor(base * 1.5)
	end

	return math.max(1, base)
end

-- Calculate guard damage when the defender is blocking.
function CombatUtils.CalculateGuardDamage(attackerState, weaponTypeId, attackType)
	local weaponDef = WeaponTypes[weaponTypeId]
	if not weaponDef then return 0 end

	local base = weaponDef.guardDamage
	if attackType == "heavy" then
		base = math.floor(base * 1.4)
	end

	base = CombatUtils.ApplyStatScale(base, attackerState.RankIndex)

	-- Hammered trait bonus
	local traitTable = Traits:Get(attackerState.Race, attackerState.Trait)
	if traitTable and traitTable.passiveEffect == "guardDamageMult" then
		base = math.floor(base * traitTable.passiveValue)
	end

	return math.max(1, base)
end

-- Should this hit break the defender's guard?
-- @param guardValue  current guard points (after applying guard damage)
function CombatUtils.IsGuardBroken(guardValue)
	return guardValue <= 0
end

-- Can the attacker's weapon break the defender's weapon?
-- Heavy attacks on a guard-broken defender check the weapon's breakThreshold.
-- @param weaponTypeId  attacker's weapon id
-- @param hitCount      how many guard-break hits have landed on this weapon (tracked externally)
function CombatUtils.ShouldBreakWeapon(weaponTypeId, hitCount)
	local weaponDef = WeaponTypes[weaponTypeId]
	if not weaponDef then return false end
	return hitCount >= (weaponDef.breakThreshold or 3)
end

-- Get melee range for a weapon type.
function CombatUtils.GetWeaponRange(weaponTypeId)
	local weaponDef = WeaponTypes[weaponTypeId]
	if not weaponDef then
		return Constants.MELEE_RANGE_SWORD
	end
	local base = weaponDef.baseType
	if base == "Dagger" then
		return Constants.MELEE_RANGE_DAGGER
	elseif base == "Sword" then
		return Constants.MELEE_RANGE_SWORD
	elseif base == "Greatsword" then
		return Constants.MELEE_RANGE_GREATSWORD
	elseif base == "Spear" then
		return Constants.MELEE_RANGE_SPEAR
	end
	return Constants.MELEE_RANGE_SWORD
end

return CombatUtils
