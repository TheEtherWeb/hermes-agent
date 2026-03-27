-- HeatUtils.lua
-- Pure heat system functions with no side effects.
-- Safe to require on both server and client.

local Constants = require(script.Parent.Parent.Data.Constants)
local Families  = require(script.Parent.Parent.Data.Families)
local Traits    = require(script.Parent.Parent.Data.Traits)

local HeatUtils = {}

-- Calculate heat gain for a given action type, applying family/trait modifiers.
-- @param state       PlayerState of the character generating heat
-- @param actionType  "lightAttack" | "heavyAttack" | "blocked" | "tookHit" | "extraction"
function HeatUtils.GetHeatGain(state, actionType)
	local base = 0
	if actionType == "lightAttack" then
		base = Constants.HEAT_GAIN_LIGHT
	elseif actionType == "heavyAttack" then
		base = Constants.HEAT_GAIN_HEAVY
	elseif actionType == "blocked" then
		base = Constants.HEAT_GAIN_BLOCKED
	elseif actionType == "tookHit" then
		base = Constants.HEAT_GAIN_TAKE_HIT
	elseif actionType == "extraction" then
		base = Constants.HEAT_GAIN_EXTRACTION
	end

	-- Family special rule: Quicksilver builds heat very fast
	local family = Families:Get(state.Race, state.Family)
	if family and family.specialRule == "quicksilverInstability" then
		base = base * Constants.QUICKSILVER_HEAT_GAIN_MULT
	end

	-- Family stat modifier: general heatGainMult
	local mods = family and family.statModifiers or {}
	if mods.heatGainMult then
		base = base * mods.heatGainMult
	end

	-- Trait modifier
	local traitDef = Traits:Get(state.Race, state.Trait)
	if traitDef and traitDef.passiveEffect == "heatGainMult" then
		base = base * traitDef.passiveValue
	end

	return math.max(0, base)
end

-- Should heat start decaying right now?
-- @param lastCombatTime  tick() timestamp of last combat event
function HeatUtils.ShouldDecayHeat(lastCombatTime)
	return (tick() - lastCombatTime) >= Constants.HEAT_COMBAT_PAUSE
end

-- Has the player hit the collapse threshold?
function HeatUtils.IsCollapse(heatValue)
	return heatValue >= Constants.MAX_HEAT
end

-- Is the player in the danger zone (warning state)?
-- @param heatValue     current heat
-- @param rankIndex     current rank (higher rank = higher safe threshold)
function HeatUtils.IsDangerZone(heatValue, rankIndex)
	local RankTiers = require(script.Parent.Parent.Data.RankTiers)
	local tier = RankTiers[rankIndex] or RankTiers[1]
	return heatValue >= tier.heatSafeThreshold
end

-- Compute heat decay delta for a single frame.
function HeatUtils.DecayDelta(dt)
	return Constants.HEAT_DECAY_RATE * dt
end

return HeatUtils
