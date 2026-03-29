-- Dream Delinquent: Parkour System
-- Handles movement augmentation, vault detection, wall-run, slide, and roll.
-- Server validates success; client handles visual feedback.

local Constants = require(script.Parent.Constants)
local StrongerStrangerSystem = require(script.Parent.StrongerStrangerSystem)

local ParkourSystem = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Move types
-- ─────────────────────────────────────────────────────────────────────────────
ParkourSystem.MOVES = {
	VAULT        = "Vault",
	WALL_RUN     = "WallRun",
	WALL_JUMP    = "WallJump",
	SLIDE        = "Slide",
	ROLL         = "Roll",
	ROOFTOP_REACH= "RooftopReach",
	CHASE        = "Chase",
	ESCAPE       = "Escape",
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Stamina costs per move
-- ─────────────────────────────────────────────────────────────────────────────
ParkourSystem.STAMINA_COST = {
	Vault        = Constants.PARKOUR.STAMINA_VAULT_COST,
	WallRun      = Constants.PARKOUR.STAMINA_WALLRUN_COST,
	WallJump     = 10,
	Slide        = 5,
	Roll         = 3,
	RooftopReach = 18,
	Chase        = 6,  -- per second
	Escape       = 6,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Speed multipliers
-- ─────────────────────────────────────────────────────────────────────────────
ParkourSystem.SPEED_MOD = {
	Vault    = Constants.PARKOUR.VAULT_SPEED_BONUS,
	WallRun  = 1.2,
	Slide    = Constants.PARKOUR.SLIDE_SPEED_BONUS,
	Roll     = 0.8,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Unlock requirements (by Athletics stat level)
-- ─────────────────────────────────────────────────────────────────────────────
ParkourSystem.UNLOCK_REQUIREMENTS = {
	Vault        = { Athletics = 10 },
	WallRun      = { Athletics = 20, Guts = 10 },
	WallJump     = { Athletics = 25 },
	Slide        = { Athletics = 15 },
	Roll         = { Athletics = 10 },
	RooftopReach = { Athletics = 30, Guts = 15 },
}

function ParkourSystem.CanPerformMove(moveType, playerData)
	local req = ParkourSystem.UNLOCK_REQUIREMENTS[moveType]
	if not req then return true end
	for stat, minVal in pairs(req) do
		if playerData:GetStat(stat) < minVal then
			return false, stat, minVal
		end
	end
	return true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Execution: returns result table used by server to update client
-- ─────────────────────────────────────────────────────────────────────────────
function ParkourSystem.ExecuteMove(moveType, playerData, currentStamina, maxStamina)
	local canDo, failStat, failVal = ParkourSystem.CanPerformMove(moveType, playerData)
	if not canDo then
		return {
			success = false,
			reason  = ("Needs %s %d"):format(failStat, failVal),
		}
	end

	local cost = ParkourSystem.STAMINA_COST[moveType] or 0
	if currentStamina < cost then
		return { success = false, reason = "Not enough stamina" }
	end

	local newStamina = currentStamina - cost

	-- Small stat gains per unique move
	local statGain = nil
	if moveType == "Vault" or moveType == "Slide" then
		statGain = { stat = "Athletics", amount = 1 }
	elseif moveType == "WallRun" or moveType == "WallJump" then
		statGain = { stat = "Athletics", amount = 1 }
		if math.random() < 0.3 then
			statGain = { stat = "Guts", amount = 1 }
		end
	elseif moveType == "RooftopReach" then
		statGain = { stat = "Athletics", amount = 2 }
	end

	-- Stronger gains
	local strongerAction = {
		Vault        = "vault_clean",
		WallRun      = "wall_run",
		WallJump     = "vault_clean",
		Slide        = "vault_clean",
		Roll         = "vault_clean",
		RooftopReach = "rooftop_reach",
	}

	-- Only award occasionally (not every single move)
	local strongerResult = nil
	if math.random() < 0.2 then  -- 20% chance per move
		strongerResult = StrongerStrangerSystem.AwardStronger(
			playerData,
			strongerAction[moveType] or "vault_clean"
		)
	end

	return {
		success       = true,
		newStamina    = newStamina,
		speedMod      = ParkourSystem.SPEED_MOD[moveType] or 1.0,
		statGain      = statGain,
		strongerResult= strongerResult,
		moveType      = moveType,
	}
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Fall damage & roll mitigation
-- ─────────────────────────────────────────────────────────────────────────────
function ParkourSystem.CalculateFallDamage(fallHeight, playerData, didRoll)
	if fallHeight < Constants.PARKOUR.ROLL_FALL_THRESHOLD then
		return 0
	end

	local rawDamage = (fallHeight - Constants.PARKOUR.ROLL_FALL_THRESHOLD) * 2
	if didRoll then
		local athlMult = 1 - (playerData:GetStat("Athletics") / 200)
		rawDamage = rawDamage * math.max(0.1, athlMult)
	end

	return math.ceil(rawDamage)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Chase & escape resolution
-- ─────────────────────────────────────────────────────────────────────────────
function ParkourSystem.ResolveChase(chaser, target)
	-- Returns "caught", "escaped", or "ongoing"
	local chaserAthl  = chaser:GetStat("Athletics")
	local targetAthl  = target:GetStat("Athletics")
	local chaserGuts  = chaser:GetStat("Guts")
	local targetGuts  = target:GetStat("Guts")
	local chaserInsight = chaser:GetStat("Insight")
	local targetInsight = target:GetStat("Insight")

	local chaserScore  = chaserAthl * 0.5 + chaserGuts * 0.3 + chaserInsight * 0.2
	local targetScore  = targetAthl * 0.5 + targetGuts * 0.2 + targetInsight * 0.3

	-- Randomise outcome slightly
	chaserScore  = chaserScore  + math.random(-5, 5)
	targetScore  = targetScore  + math.random(-5, 5)

	if chaserScore >= targetScore + 10 then
		return "caught"
	elseif targetScore >= chaserScore + 10 then
		return "escaped"
	end
	return "ongoing"
end

return ParkourSystem
