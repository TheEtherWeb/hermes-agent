-- Dream Delinquent: Stronger / Stranger System
-- Canon update:
--   Strong activities award Stronger stats (Athletics, Power, etc.)
--   Supernatural encounters award Stranger stats (Pressure, Control, etc.)
--   Psych grows from both extremes and serves as the bridge.
--   Conditions modify Stranger stat behaviour but are not stats themselves.

local Constants = require(script.Parent.Constants)

local StrongerStrangerSystem = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- STRONGER actions → Stronger stat gains
-- Each entry maps an action to a table of { statName = baseAmount }
-- ─────────────────────────────────────────────────────────────────────────────
StrongerStrangerSystem.STRONGER_ACTIONS = {
	-- School
	class_attend    = { axis=5,  stats={ Insight=1 } },
	class_pass      = { axis=10, stats={ Insight=2, Tech=1 } },
	class_ace       = { axis=20, stats={ Insight=3, Tech=2 } },
	gym_drill       = { axis=8,  stats={ Athletics=2, Guts=1 } },
	study_session   = { axis=7,  stats={ Insight=2 } },
	-- Sports & clubs
	club_session    = { axis=10, stats={} },  -- per-club overrides in ClubSystem
	sport_practice  = { axis=12, stats={ Athletics=1, Technique=1 } },
	sport_win       = { axis=20, stats={ Athletics=2, Technique=2, Guts=1 } },
	sport_loss      = { axis=5,  stats={ Guts=2 } },
	-- Combat
	fight_win       = { axis=15, stats={ Power=2, Technique=1, Guts=1 } },
	fight_loss      = { axis=8,  stats={ Guts=2, Power=1 } },
	fight_survival  = { axis=10, stats={ Guts=2 } },
	combo_clean     = { axis=5,  stats={ Technique=1 } },
	parry_clean     = { axis=5,  stats={ Technique=1, Insight=1 } },
	-- Parkour
	vault_clean     = { axis=4,  stats={ Athletics=1 } },
	wall_run        = { axis=4,  stats={ Athletics=1, Guts=1 } },
	rooftop_reach   = { axis=8,  stats={ Athletics=2, Guts=1 } },
	escape_chase    = { axis=10, stats={ Athletics=2, Insight=1 } },
	-- Misc
	part_time_job   = { axis=6,  stats={ Charisma=1 } },
	train_solo      = { axis=8,  stats={ Power=1, Athletics=1 } },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- STRANGER actions → Stranger stat gains
-- Each entry maps to { axis total, Stranger stats to award, Psych gain }
-- ─────────────────────────────────────────────────────────────────────────────
StrongerStrangerSystem.STRANGER_ACTIONS = {
	-- Rumor exposure
	rumor_heard      = { axis=5,  strangerStats={ Resonance=1 },          psych=0 },
	rumor_pursued    = { axis=15, strangerStats={ Resonance=2, Instinct=1 }, psych=1 },
	rumor_survived   = { axis=25, strangerStats={ Resonance=2, Control=1, Threshold=1 }, psych=2 },
	rumor_failed     = { axis=10, strangerStats={ Distortion=2 },          psych=1 },
	-- Encounters
	encounter_demon  = { axis=30, strangerStats={ Hunger=3, Threshold=2, Distortion=1 }, psych=3 },
	encounter_vampire= { axis=30, strangerStats={ Instinct=3, Hunger=2,  Mask=1 },       psych=2 },
	encounter_ghost  = { axis=20, strangerStats={ Resonance=3, Instinct=2 },             psych=2 },
	encounter_alien  = { axis=35, strangerStats={ Resonance=4, Distortion=2 },           psych=3 },
	encounter_rogue  = { axis=25, strangerStats={ Pressure=3, Control=1, Threshold=2 },  psych=3 },
	-- Condition triggers
	cursed           = { axis=40, strangerStats={ Hunger=3, Distortion=2 },  psych=2 },
	bitten           = { axis=50, strangerStats={ Instinct=4, Hunger=3 },    psych=3 },
	branded          = { axis=45, strangerStats={ Pressure=3, Threshold=2 }, psych=3 },
	taken            = { axis=55, strangerStats={ Resonance=5, Distortion=3 }, psych=4 },
	haunted          = { axis=35, strangerStats={ Resonance=3, Instinct=2 }, psych=2 },
	-- Club
	occult_session   = { axis=8,  strangerStats={ Resonance=3, Control=1 },  psych=1 },
	-- Places
	old_district_visit  = { axis=10, strangerStats={ Resonance=2 },          psych=0 },
	night_city_roam     = { axis=8,  strangerStats={ Instinct=1, Resonance=1 }, psych=0 },
	anomaly_site        = { axis=20, strangerStats={ Distortion=2, Resonance=2 }, psych=2 },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Award Stronger progression
-- Returns { gain, milestone, statGains } or nil
-- ─────────────────────────────────────────────────────────────────────────────
function StrongerStrangerSystem.AwardStronger(playerData, actionId, multiplier)
	multiplier = multiplier or 1
	local def  = StrongerStrangerSystem.STRONGER_ACTIONS[actionId]
	if not def then return nil end

	local axisGain = math.ceil(def.axis * multiplier)
	local prevAxis = playerData.stronger
	playerData:AddStronger(axisGain)
	local milestone = playerData:CheckStrongerMilestone(prevAxis)

	-- Award individual Stronger stats
	local statGains = {}
	for stat, base in pairs(def.stats) do
		local actual = playerData:GainStat(stat, math.ceil(base * multiplier))
		if actual > 0 then statGains[stat] = actual end
	end

	return { gain=axisGain, milestone=milestone, axis="stronger", statGains=statGains }
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Award Stranger progression
-- Returns { gain, milestone, strangerStatGains, psychGain, newCondition } or nil
-- ─────────────────────────────────────────────────────────────────────────────
function StrongerStrangerSystem.AwardStranger(playerData, actionId, multiplier)
	multiplier = multiplier or 1
	local def  = StrongerStrangerSystem.STRANGER_ACTIONS[actionId]
	if not def then return nil end

	local axisGain = math.ceil(def.axis * multiplier)
	local prevAxis = playerData.stranger
	playerData:AddStranger(axisGain)
	local milestone = playerData:CheckStrangerMilestone(prevAxis)

	-- Award individual Stranger stats
	local strangerStatGains = {}
	if def.strangerStats then
		for stat, base in pairs(def.strangerStats) do
			local actual = playerData:GainStrangerStat(stat, math.ceil(base * multiplier))
			if actual > 0 then strangerStatGains[stat] = actual end
		end
	end

	-- Psych gains come from supernatural pressure
	local psychGain = 0
	if def.psych and def.psych > 0 then
		psychGain = math.ceil(def.psych * multiplier)
		playerData:GainPsych(psychGain)
	end

	-- Condition trigger
	local newCondition = StrongerStrangerSystem._CheckConditionTrigger(playerData, actionId)

	return {
		gain             = axisGain,
		milestone        = milestone,
		axis             = "stranger",
		strangerStatGains= strangerStatGains,
		psychGain        = psychGain,
		newCondition     = newCondition,
	}
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Condition trigger logic
-- ─────────────────────────────────────────────────────────────────────────────
function StrongerStrangerSystem._CheckConditionTrigger(playerData, actionId)
	local triggers = {
		bitten  = "Bitten",
		cursed  = "Cursed",
		branded = "Branded",
		taken   = "Taken",
		haunted = "Haunted",
	}

	local condition = triggers[actionId]
	if condition then
		if playerData:AddCondition(condition) then
			return condition
		end
	end

	-- Beastblooded: high Instinct + Hunger without Bitten yet
	if playerData:GetStrangerStat("Instinct") >= 30
		and playerData:GetStrangerStat("Hunger") >= 25
		and not playerData:HasCondition("Bitten")
		and not playerData:HasCondition("Beastblooded") then
		playerData:AddCondition("Beastblooded")
		return "Beastblooded"
	end

	-- Hollowed: very high Control + Mask; low Hunger
	if playerData:GetStrangerStat("Control") >= 40
		and playerData:GetStrangerStat("Mask") >= 35
		and playerData:GetStrangerStat("Hunger") < 10
		and not playerData:HasCondition("Hollowed") then
		playerData:AddCondition("Hollowed")
		return "Hollowed"
	end

	-- Resonant: clean psychic path; no monster infection, high Resonance
	if playerData.stranger >= 200
		and playerData.psych >= 30
		and playerData:GetStrangerStat("Resonance") >= 25
		and #playerData.strangeConditions == 0 then
		playerData:AddCondition("Resonant")
		return "Resonant"
	end

	-- Hybrid: two or more conditions
	if #playerData.strangeConditions >= 2 and not playerData:HasCondition("Hybrid") then
		playerData:AddCondition("Hybrid")
		return "Hybrid"
	end

	return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Portrait state computation (uses both stat sheets)
-- ─────────────────────────────────────────────────────────────────────────────
function StrongerStrangerSystem.GetPortraitState(playerData, healthPct, staminaPct)
	healthPct  = healthPct  or 1
	staminaPct = staminaPct or 1

	if playerData:CanUnlockManifestation() then
		return Constants.PORTRAIT_STATES.GLOWING
	end

	-- Threshold and Distortion drive distortion state
	local distLevel = playerData:GetStrangerStat("Distortion")
		+ playerData:GetStrangerStat("Threshold")
	if distLevel >= 80 or playerData.stranger >= 700 then
		return Constants.PORTRAIT_STATES.DISTORTED
	end

	if healthPct < 0.25 then return Constants.PORTRAIT_STATES.BRUISED  end
	if healthPct < 0.5 or staminaPct < 0.3 then return Constants.PORTRAIT_STATES.SWEATING end

	-- Fear/psychic pressure from conditions
	if playerData:HasCondition("Haunted") or playerData:HasCondition("Taken") then
		return Constants.PORTRAIT_STATES.AFRAID
	end
	if playerData:HasCondition("Cursed") then
		return Constants.PORTRAIT_STATES.TENSE
	end

	-- Performing well
	if playerData.stronger > 300 then
		return Constants.PORTRAIT_STATES.FOCUSED
	end

	return Constants.PORTRAIT_STATES.NEUTRAL
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Psych-driven stat scaling (used by Pressure Arts and combat psychic moves)
-- ─────────────────────────────────────────────────────────────────────────────
function StrongerStrangerSystem.GetPsychMultiplier(playerData)
	-- At psych=5 → 1.0; at psych=100 → ~2.5
	return 1 + (playerData.psych / 60)
end

-- Stranger stat scaling  (used by Pressure Arts)
function StrongerStrangerSystem.GetStrangerStatMultiplier(playerData, statName)
	local val = playerData:GetStrangerStat(statName)
	return 1 + (val / 80)
end

-- Stronger stat scaling (used by combat)
function StrongerStrangerSystem.GetStatMultiplier(statValue)
	return 1 + (statValue / 60)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Psychic affinity suggestion  (which psychic type fits this player)
-- Based on highest Stranger stats + psychicBias
-- ─────────────────────────────────────────────────────────────────────────────
function StrongerStrangerSystem.SuggestPsychicType(playerData)
	if playerData.psychicType then return playerData.psychicType end

	-- Score each psychic type by its affinities
	local scores = {}
	for _, ptype in ipairs(Constants.PSYCHIC_TYPES) do
		local affinities = Constants.PSYCHIC_STAT_AFFINITY[ptype] or {}
		local score = 0
		for _, statName in ipairs(affinities) do
			score = score + playerData:GetStrangerStat(statName)
		end
		-- Bias bonus
		if playerData.psychicBias == ptype then
			score = score + 20
		end
		scores[ptype] = score
	end

	local best, bestScore = nil, -1
	for ptype, score in pairs(scores) do
		if score > bestScore then
			best      = ptype
			bestScore = score
		end
	end

	return best
end

return StrongerStrangerSystem
