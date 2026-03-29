-- Dream Delinquent: Combat System
-- Handles damage calculation, combo tracking, stamina, and style bonuses.
-- All server-authoritative. Client sends inputs; server validates and computes.

local Constants = require(script.Parent.Constants)
local StrongerStrangerSystem = require(script.Parent.StrongerStrangerSystem)

local CombatSystem = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Combatant state (per fighter, created fresh each encounter)
-- ─────────────────────────────────────────────────────────────────────────────
local Combatant = {}
Combatant.__index = Combatant

function Combatant.new(playerData)
	local self = setmetatable({}, Combatant)
	self.data         = playerData
	self.maxHealth    = Constants.COMBAT.BASE_HEALTH
		+ playerData:GetStat("Guts") * Constants.COMBAT.HEALTH_PER_GUTS
	self.health       = self.maxHealth
	self.maxStamina   = Constants.COMBAT.BASE_STAMINA
		+ playerData:GetStat("Athletics") * Constants.COMBAT.STAMINA_PER_ATH
	self.stamina      = self.maxStamina
	self.isBlocking   = false
	self.isParrying   = false
	self.parryTimer   = 0
	self.comboCount   = 0
	self.comboTimer   = 0
	self.stunDuration = 0
	self.knockback    = Vector3.new(0,0,0)
	return self
end

function Combatant:IsAlive()    return self.health > 0 end
function Combatant:HealthPct()  return self.health / self.maxHealth end
function Combatant:StaminaPct() return self.stamina / self.maxStamina end

-- ─────────────────────────────────────────────────────────────────────────────
-- Damage calculation
-- ─────────────────────────────────────────────────────────────────────────────
function CombatSystem.CalcDamage(attackerData, moveType, styleBonus)
	local base = 0
	if moveType == "light" then
		base = Constants.COMBAT.LIGHT_HIT_DAMAGE
	elseif moveType == "heavy" then
		base = Constants.COMBAT.HEAVY_HIT_DAMAGE
	elseif moveType == "grab" then
		base = Constants.COMBAT.GRAB_DAMAGE
	end

	-- Stat scaling
	local power = attackerData:GetStat("Power")
	local tech  = attackerData:GetStat("Technique")
	local powerMult = StrongerStrangerSystem.GetStatMultiplier(power)
	local techMult  = StrongerStrangerSystem.GetStatMultiplier(tech)

	if moveType == "grab" then
		base = base * powerMult
	elseif moveType == "heavy" then
		base = base * ((powerMult + techMult) / 2)
	else
		base = base * techMult
	end

	-- Style/fighting style bonus
	if styleBonus then base = base * styleBonus end

	return math.ceil(base)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Apply a hit to a defender
-- Returns { damage, blocked, parried, stunned }
-- ─────────────────────────────────────────────────────────────────────────────
function CombatSystem.ApplyHit(attacker, defender, moveType, styleBonus)
	if not defender:IsAlive() then
		return { damage = 0, blocked = false, parried = false, stunned = false }
	end

	local rawDamage = CombatSystem.CalcDamage(attacker.data, moveType, styleBonus)

	-- Parry check (defender initiated parry within window)
	if defender.isParrying and defender.parryTimer > 0 then
		-- Parry success: attacker is stunned, no damage
		attacker.stunDuration = 0.6
		attacker.comboCount   = 0
		return { damage = 0, blocked = false, parried = true, stunned = false }
	end

	-- Block check
	local finalDamage = rawDamage
	if defender.isBlocking then
		finalDamage = math.ceil(rawDamage * (1 - Constants.COMBAT.BLOCK_REDUCE))
		-- Drain stamina on block
		defender.stamina = math.max(0, defender.stamina - rawDamage * 0.4)
	end

	-- Stun on heavy hit if defender low stamina
	local stunned = false
	if moveType == "heavy" and defender.stamina < (defender.maxStamina * 0.2) then
		defender.stunDuration = 0.4
		stunned = true
	end

	-- Apply
	defender.health = math.max(0, defender.health - finalDamage)

	-- Attacker stamina cost
	local staminaCost = (moveType == "heavy") and 15 or (moveType == "grab") and 20 or 8
	attacker.stamina = math.max(0, attacker.stamina - staminaCost)

	return {
		damage  = finalDamage,
		blocked = defender.isBlocking,
		parried = false,
		stunned = stunned,
	}
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Combo tracking
-- ─────────────────────────────────────────────────────────────────────────────
function CombatSystem.RecordComboHit(combatant)
	combatant.comboCount = combatant.comboCount + 1
	combatant.comboTimer = Constants.COMBAT.COMBO_TIMEOUT
	return combatant.comboCount
end

function CombatSystem.TickCombo(combatant, dt)
	if combatant.comboTimer > 0 then
		combatant.comboTimer = combatant.comboTimer - dt
		if combatant.comboTimer <= 0 then
			combatant.comboCount = 0
		end
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Combo damage multiplier based on streak
-- ─────────────────────────────────────────────────────────────────────────────
function CombatSystem.GetComboMultiplier(comboCount)
	if comboCount <= 1 then return 1.0 end
	if comboCount <= 3 then return 1.1 end
	if comboCount <= 5 then return 1.25 end
	if comboCount <= 8 then return 1.4  end
	return 1.6  -- max
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Stamina regeneration
-- ─────────────────────────────────────────────────────────────────────────────
function CombatSystem.RegenStamina(combatant, dt)
	if combatant.isBlocking then return end  -- no regen while blocking
	local rate = 15 + combatant.data:GetStat("Guts") * 0.2  -- per second
	combatant.stamina = math.min(combatant.maxStamina, combatant.stamina + rate * dt)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Fighting style modifiers
-- ─────────────────────────────────────────────────────────────────────────────
local STYLE_MODS = {
	Striker   = { light = 1.2, heavy = 1.0, grab = 0.9, parryWindow = 0.3 },
	Kicker    = { light = 1.1, heavy = 1.15,grab = 0.8, parryWindow = 0.2 },
	Grappler  = { light = 0.9, heavy = 1.1, grab = 1.5, parryWindow = 0.2 },
	Duelist   = { light = 1.1, heavy = 1.2, grab = 0.8, parryWindow = 0.4 },
	Brawler   = { light = 1.0, heavy = 1.3, grab = 1.1, parryWindow = 0.15 },
	Acrobat   = { light = 1.15,heavy = 0.9, grab = 0.85,parryWindow = 0.35 },
	Captain   = { light = 1.0, heavy = 1.0, grab = 1.0, parryWindow = 0.25, teamBuff = 0.15 },
	Trickster = { light = 1.3, heavy = 0.85,grab = 0.9, parryWindow = 0.45 },
}

function CombatSystem.GetStyleMod(styleId, moveType)
	local mods = STYLE_MODS[styleId]
	if not mods then return 1.0 end
	return mods[moveType] or 1.0
end

function CombatSystem.GetParryWindow(styleId)
	local mods = STYLE_MODS[styleId]
	if not mods then return Constants.COMBAT.PARRY_WINDOW end
	return mods.parryWindow or Constants.COMBAT.PARRY_WINDOW
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Resolve end of fight and award progression
-- ─────────────────────────────────────────────────────────────────────────────
function CombatSystem.ResolveFight(winner, loser, strongerSystem)
	winner.data.combatWins   = winner.data.combatWins   + 1
	loser.data.combatLosses  = loser.data.combatLosses  + 1

	-- Stat gains from combat
	local winnerGains = {
		Power     = math.random(1, 2),
		Technique = math.random(1, 2),
		Guts      = 1,
	}
	local loserGains = {
		Guts      = math.random(1, 2),
		Power     = 1,
	}

	for stat, amount in pairs(winnerGains) do
		winner.data:GainStat(stat, amount)
	end
	for stat, amount in pairs(loserGains) do
		loser.data:GainStat(stat, amount)
	end

	-- Stronger
	local winnerResult = StrongerStrangerSystem.AwardStronger(winner.data, "fight_win")
	local loserResult  = StrongerStrangerSystem.AwardStronger(loser.data,  "fight_loss")

	-- Street rep
	winner.data.streetRep = winner.data.streetRep + 5
	loser.data.streetRep  = math.max(0, loser.data.streetRep - 2)

	return {
		winner = { statGains = winnerGains, strongerResult = winnerResult },
		loser  = { statGains = loserGains,  strongerResult = loserResult },
	}
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Expose Combatant constructor for server use
-- ─────────────────────────────────────────────────────────────────────────────
CombatSystem.Combatant = Combatant

return CombatSystem
