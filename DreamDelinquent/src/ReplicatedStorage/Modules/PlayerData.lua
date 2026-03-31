-- Dream Delinquent: PlayerData Module
-- The player's full character sheet.
-- Canon update: two separate stat sheets (Stronger / Stranger) + Psych bridge.

local Constants = require(script.Parent.Constants)

local PlayerData = {}
PlayerData.__index = PlayerData

-- ─────────────────────────────────────────────────────────────────────────────
-- Constructor
-- ─────────────────────────────────────────────────────────────────────────────
function PlayerData.new(backgroundId)
	local self = setmetatable({}, PlayerData)

	-- Identity
	self.backgroundId   = backgroundId or "Transfer"
	self.age            = 15
	self.phase          = Constants.PHASES.FRESHMAN
	self.gradeYear      = 1

	-- Academic
	self.gpa            = 3.0
	self.credits        = 0
	self.recoveryCredits= 0
	self.attendance     = 0
	self.absences       = 0
	self.hasDiploma     = false
	self.conductPoints  = 100

	-- ── Dual-axis totals (shown on HUD as running progress meters) ──
	self.stronger       = 0   -- total human-growth score
	self.stranger       = 0   -- total supernatural-exposure score

	-- ── STRONGER stat sheet (human growth) ──────────────────────────
	self.stats = {}
	for _, stat in ipairs(Constants.STRONGER_STATS) do
		self.stats[stat] = Constants.STAT_DEFAULT
	end

	-- ── Psych (bridge) ───────────────────────────────────────────────
	self.psych = Constants.PSYCH_DEFAULT

	-- ── STRANGER stat sheet (supernatural transformation) ───────────
	self.strangerStats = {}
	for _, stat in ipairs(Constants.STRANGER_STATS) do
		self.strangerStats[stat] = 0   -- all start at zero; grow through exposure
	end

	-- Apply background bonuses (Stronger stats only)
	self:_applyBackground(backgroundId)

	-- Clubs & teams
	self.activeClubId  = nil
	self.clubHistory   = {}   -- { clubId = dayCount }
	self.sportHistory  = {}

	-- Combat
	self.fightingStyle             = nil
	self.fightingStyleProficiency  = 0
	self.combatWins                = 0
	self.combatLosses              = 0

	-- Psychic route
	self.psychicType       = nil
	self.psychicLevel      = 0
	self.strangeConditions = {}    -- list of active condition strings
	self.manifestation     = nil

	-- Pressure Arts
	self.pressureArts  = {}   -- list of unlocked art ids
	self.editInventory = {}   -- list of edit ids available for equipping

	-- Rumor state
	self.rumorLog      = {}   -- { rumorId = state }
	self.rumorsSurvived= 0

	-- Reputation
	self.streetRep  = 0
	self.schoolRep  = 0
	self.agencyFlag = false

	-- Inventory
	self.inventory  = {}

	-- Housing & adult artefacts
	self.apartment  = nil
	self.trophies   = {}
	self.artifacts  = {}

	-- College / career
	self.college = nil
	self.major   = nil
	self.jobId   = nil

	-- Schedule
	self.currentDayPhase = Constants.DAY_PHASES.MORNING
	self.dayCount        = 1

	return self
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Background application  (Stronger stats only)
-- ─────────────────────────────────────────────────────────────────────────────
function PlayerData:_applyBackground(backgroundId)
	for _, bg in ipairs(Constants.BACKGROUNDS) do
		if bg.id == backgroundId then
			for stat, bonus in pairs(bg.statBonus) do
				if self.stats[stat] then
					self.stats[stat] = self.stats[stat] + bonus
				end
			end
			self.psychicBias = bg.psychicBias
			return
		end
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Stronger stat access
-- ─────────────────────────────────────────────────────────────────────────────
function PlayerData:GainStat(statName, amount)
	if self.stats[statName] ~= nil then
		local prev = self.stats[statName]
		self.stats[statName] = math.clamp(self.stats[statName] + amount, 0, Constants.STAT_MAX)
		return self.stats[statName] - prev
	end
	return 0
end

function PlayerData:GetStat(statName)
	if statName == "Psych" then return self.psych end
	if self.stats[statName]        ~= nil then return self.stats[statName] end
	if self.strangerStats[statName] ~= nil then return self.strangerStats[statName] end
	return 0
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Stranger stat access  (with condition modifiers applied)
-- ─────────────────────────────────────────────────────────────────────────────
function PlayerData:GainStrangerStat(statName, amount)
	if self.strangerStats[statName] == nil then return 0 end
	local prev = self.strangerStats[statName]
	self.strangerStats[statName] = math.clamp(
		self.strangerStats[statName] + amount,
		0,
		Constants.STAT_MAX
	)
	return self.strangerStats[statName] - prev
end

-- Returns effective value with condition multipliers applied
function PlayerData:GetStrangerStat(statName)
	local base = self.strangerStats[statName] or 0
	local mult = 1.0
	for _, condId in ipairs(self.strangeConditions) do
		local mods = Constants.CONDITION_MODIFIERS[condId]
		if mods and mods[statName] then
			mult = mult * mods[statName]
		end
	end
	return base * mult
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Psych bridge
-- ─────────────────────────────────────────────────────────────────────────────
function PlayerData:GainPsych(amount)
	local prev = self.psych
	self.psych = math.clamp(self.psych + amount, 0, Constants.PSYCH_MAX)
	return self.psych - prev
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Stronger / Stranger axis totals
-- ─────────────────────────────────────────────────────────────────────────────
function PlayerData:AddStronger(amount)
	local prev = self.stronger
	self.stronger = math.clamp(self.stronger + amount, 0, Constants.STRONGER_MAX)
	return self.stronger - prev
end

function PlayerData:AddStranger(amount)
	local prev = self.stranger
	self.stranger = math.clamp(self.stranger + amount, 0, Constants.STRANGER_MAX)
	return self.stranger - prev
end

function PlayerData:CheckStrongerMilestone(prevValue)
	for i = #Constants.STRONGER_MILESTONES, 1, -1 do
		local m = Constants.STRONGER_MILESTONES[i]
		if prevValue < m.threshold and self.stronger >= m.threshold then
			return m.label
		end
	end
	return nil
end

function PlayerData:CheckStrangerMilestone(prevValue)
	for i = #Constants.STRANGER_MILESTONES, 1, -1 do
		local m = Constants.STRANGER_MILESTONES[i]
		if prevValue < m.threshold and self.stranger >= m.threshold then
			return m.label
		end
	end
	return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Club management
-- ─────────────────────────────────────────────────────────────────────────────
function PlayerData:JoinClub(clubId)
	self.activeClubId = clubId
	self.clubHistory[clubId] = self.clubHistory[clubId] or 0
end

function PlayerData:LeaveClub()
	self.activeClubId = nil
end

function PlayerData:RecordClubDay()
	if self.activeClubId then
		self.clubHistory[self.activeClubId] = (self.clubHistory[self.activeClubId] or 0) + 1
	end
end

function PlayerData:GetClubDays(clubId)
	return self.clubHistory[clubId] or 0
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Credits & GPA
-- ─────────────────────────────────────────────────────────────────────────────
function PlayerData:AddCredits(amount)
	self.credits = self.credits + amount
end

function PlayerData:UpdateGPA(score)
	self.gpa = math.clamp(self.gpa * 0.9 + score * 0.1, 0, 4.0)
end

function PlayerData:CanAdvanceGrade()
	local req = Constants.GRADE_CREDIT_REQUIREMENT[self.phase]
	if not req then return false end
	return (self.credits + self.recoveryCredits) >= req
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Rumor tracking
-- ─────────────────────────────────────────────────────────────────────────────
function PlayerData:SetRumorState(rumorId, state)
	self.rumorLog[rumorId] = state
end

function PlayerData:GetRumorState(rumorId)
	return self.rumorLog[rumorId] or Constants.RUMOR_STATES.UNHEARD
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Conditions  (modifiers, not stats)
-- ─────────────────────────────────────────────────────────────────────────────
function PlayerData:HasCondition(conditionId)
	for _, c in ipairs(self.strangeConditions) do
		if c == conditionId then return true end
	end
	return false
end

function PlayerData:AddCondition(conditionId)
	if not self:HasCondition(conditionId) then
		table.insert(self.strangeConditions, conditionId)
		return true
	end
	return false
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Pressure Arts
-- ─────────────────────────────────────────────────────────────────────────────
function PlayerData:HasPressureArt(artId)
	for _, a in ipairs(self.pressureArts) do
		if a == artId then return true end
	end
	return false
end

function PlayerData:UnlockPressureArt(artId)
	if not self:HasPressureArt(artId) then
		table.insert(self.pressureArts, artId)
		return true
	end
	return false
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Manifestation check
-- ─────────────────────────────────────────────────────────────────────────────
function PlayerData:CanUnlockManifestation()
	local m = Constants.MANIFESTATION_UNLOCK_THRESHOLD
	return self.age >= m.age
		and self.stranger >= m.stranger
		and self.psych >= m.psych
		and self:GetStrangerStat("Threshold") >= m.threshold
		and self.manifestation == nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Serialization
-- ─────────────────────────────────────────────────────────────────────────────
function PlayerData:Serialize()
	return {
		backgroundId            = self.backgroundId,
		age                     = self.age,
		phase                   = self.phase,
		gradeYear               = self.gradeYear,
		gpa                     = self.gpa,
		credits                 = self.credits,
		recoveryCredits         = self.recoveryCredits,
		attendance              = self.attendance,
		conductPoints           = self.conductPoints,
		stronger                = self.stronger,
		stranger                = self.stranger,
		stats                   = self.stats,
		psych                   = self.psych,
		strangerStats           = self.strangerStats,
		activeClubId            = self.activeClubId,
		clubHistory             = self.clubHistory,
		fightingStyle           = self.fightingStyle,
		fightingStyleProficiency= self.fightingStyleProficiency,
		combatWins              = self.combatWins,
		combatLosses            = self.combatLosses,
		psychicType             = self.psychicType,
		psychicLevel            = self.psychicLevel,
		strangeConditions       = self.strangeConditions,
		manifestation           = self.manifestation,
		pressureArts            = self.pressureArts,
		editInventory           = self.editInventory,
		rumorLog                = self.rumorLog,
		rumorsSurvived          = self.rumorsSurvived,
		streetRep               = self.streetRep,
		schoolRep               = self.schoolRep,
		agencyFlag              = self.agencyFlag,
		inventory               = self.inventory,
		apartment               = self.apartment,
		college                 = self.college,
		major                   = self.major,
		jobId                   = self.jobId,
		dayCount                = self.dayCount,
		hasDiploma              = self.hasDiploma,
		psychicBias             = self.psychicBias,
	}
end

function PlayerData.Deserialize(data)
	local self = setmetatable({}, PlayerData)
	for k, v in pairs(data) do
		self[k] = v
	end
	-- Ensure all stat tables are complete
	self.stats          = self.stats          or {}
	self.strangerStats  = self.strangerStats  or {}
	self.pressureArts   = self.pressureArts   or {}
	self.editInventory  = self.editInventory  or {}
	self.strangeConditions = self.strangeConditions or {}

	for _, stat in ipairs(Constants.STRONGER_STATS) do
		if not self.stats[stat] then self.stats[stat] = Constants.STAT_DEFAULT end
	end
	for _, stat in ipairs(Constants.STRANGER_STATS) do
		if not self.strangerStats[stat] then self.strangerStats[stat] = 0 end
	end
	self.psych = self.psych or Constants.PSYCH_DEFAULT

	return self
end

return PlayerData
