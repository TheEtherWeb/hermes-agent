-- Dream Delinquent: Stronger / Stranger System
-- Manages milestone broadcasts, visual triggers, and condition unlocks.

local Constants   = require(script.Parent.Constants)
local RemoteEvent -- resolved at runtime

local StrongerStrangerSystem = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Action tables: what activities add to which axis
-- ─────────────────────────────────────────────────────────────────────────────
StrongerStrangerSystem.STRONGER_ACTIONS = {
	-- School
	["class_attend"]     = 5,
	["class_pass"]       = 10,
	["class_ace"]        = 20,
	["gym_drill"]        = 8,
	["study_session"]    = 7,
	-- Sports & clubs
	["club_session"]     = 10,
	["sport_practice"]   = 12,
	["sport_win"]        = 20,
	["sport_loss"]       = 5,   -- still grows through struggle
	-- Combat
	["fight_win"]        = 15,
	["fight_loss"]       = 8,
	["fight_survival"]   = 10,
	["combo_clean"]      = 5,
	["parry_clean"]      = 5,
	-- Parkour
	["vault_clean"]      = 4,
	["wall_run"]         = 4,
	["rooftop_reach"]    = 8,
	["escape_chase"]     = 10,
	-- Misc
	["part_time_job"]    = 6,
	["train_solo"]       = 8,
}

StrongerStrangerSystem.STRANGER_ACTIONS = {
	-- Rumors
	["rumor_heard"]      = 5,
	["rumor_pursued"]    = 15,
	["rumor_survived"]   = 25,
	["rumor_failed"]     = 10,  -- trauma still marks you
	-- Encounters
	["encounter_demon"]  = 30,
	["encounter_vampire"]= 30,
	["encounter_ghost"]  = 20,
	["encounter_alien"]  = 35,
	["encounter_rogue"]  = 25,
	-- Conditions
	["cursed"]           = 40,
	["bitten"]           = 50,
	["branded"]          = 45,
	["taken"]            = 55,
	["haunted"]          = 35,
	-- Clubs
	["occult_session"]   = 8,
	-- Places
	["old_district_visit"]= 10,
	["night_city_roam"]  = 8,
	["anomaly_site"]     = 20,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Server-side: award progression and check milestones
-- ─────────────────────────────────────────────────────────────────────────────
function StrongerStrangerSystem.AwardStronger(playerData, actionId, multiplier)
	multiplier = multiplier or 1
	local base  = StrongerStrangerSystem.STRONGER_ACTIONS[actionId] or 0
	local gain  = math.ceil(base * multiplier)
	if gain <= 0 then return nil end

	local prev  = playerData.stronger
	playerData:AddStronger(gain)
	local label = playerData:CheckStrongerMilestone(prev)
	return { gain = gain, milestone = label, axis = "stronger" }
end

function StrongerStrangerSystem.AwardStranger(playerData, actionId, multiplier)
	multiplier = multiplier or 1
	local base  = StrongerStrangerSystem.STRANGER_ACTIONS[actionId] or 0
	local gain  = math.ceil(base * multiplier)
	if gain <= 0 then return nil end

	local prev  = playerData.stranger
	playerData:AddStranger(gain)
	local label = playerData:CheckStrangerMilestone(prev)

	-- Check condition triggers
	local newCondition = StrongerStrangerSystem._CheckConditionTrigger(playerData, actionId)

	return { gain = gain, milestone = label, axis = "stranger", newCondition = newCondition }
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Condition unlock logic based on action + stranger level
-- ─────────────────────────────────────────────────────────────────────────────
function StrongerStrangerSystem._CheckConditionTrigger(playerData, actionId)
	if actionId == "bitten" and not playerData:HasCondition("Bitten") then
		playerData:AddCondition("Bitten")
		return "Bitten"
	end
	if actionId == "cursed" and not playerData:HasCondition("Cursed") then
		playerData:AddCondition("Cursed")
		return "Cursed"
	end
	if actionId == "branded" and not playerData:HasCondition("Branded") then
		playerData:AddCondition("Branded")
		return "Branded"
	end
	if actionId == "taken" and not playerData:HasCondition("Taken") then
		playerData:AddCondition("Taken")
		return "Taken"
	end
	if actionId == "haunted" and not playerData:HasCondition("Haunted") then
		playerData:AddCondition("Haunted")
		return "Haunted"
	end
	-- Resonant: organic psychic route without monster infection
	if playerData.stranger >= 200
		and playerData.stats.Psych >= 30
		and not playerData:HasCondition("Resonant")
		and #playerData.strangeConditions == 0 then
		playerData:AddCondition("Resonant")
		return "Resonant"
	end
	-- Hybrid: multiple conditions
	if #playerData.strangeConditions >= 2 and not playerData:HasCondition("Hybrid") then
		playerData:AddCondition("Hybrid")
		return "Hybrid"
	end
	return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Compute portrait emotional state from player data
-- ─────────────────────────────────────────────────────────────────────────────
function StrongerStrangerSystem.GetPortraitState(playerData, healthPercent, staminaPercent)
	healthPercent  = healthPercent  or 1
	staminaPercent = staminaPercent or 1

	-- Near manifestation
	if playerData:CanUnlockManifestation() then
		return Constants.PORTRAIT_STATES.GLOWING
	end

	-- High stranger distortion
	if playerData.stranger >= 700 then
		return Constants.PORTRAIT_STATES.DISTORTED
	end

	-- Combat states
	if healthPercent < 0.25 then
		return Constants.PORTRAIT_STATES.BRUISED
	end
	if healthPercent < 0.5 or staminaPercent < 0.3 then
		return Constants.PORTRAIT_STATES.SWEATING
	end

	-- Fear / psychic pressure
	if playerData:HasCondition("Haunted") or playerData:HasCondition("Cursed") then
		return Constants.PORTRAIT_STATES.TENSE
	end

	-- Performing well
	if playerData.stronger > 300 then
		return Constants.PORTRAIT_STATES.FOCUSED
	end

	return Constants.PORTRAIT_STATES.NEUTRAL
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Stat scaling utilities used by other systems
-- ─────────────────────────────────────────────────────────────────────────────
function StrongerStrangerSystem.GetStatMultiplier(statValue)
	-- Returns 1.0 at stat=5, scales up to ~2.5 at stat=100
	return 1 + (statValue / 60)
end

return StrongerStrangerSystem
