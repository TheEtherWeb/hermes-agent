-- Dream Delinquent: PlayerData Module
-- Defines the player's full character sheet and progression state.
-- This is the single source of truth for all player data on the server.

local Constants = require(script.Parent.Constants)

local PlayerData = {}
PlayerData.__index = PlayerData

-- ─────────────────────────────────────────────────────────────────────────────
-- Constructor: create a fresh character
-- ─────────────────────────────────────────────────────────────────────────────
function PlayerData.new(backgroundId)
	local self = setmetatable({}, PlayerData)

	-- Identity
	self.backgroundId   = backgroundId or "Transfer"
	self.age            = 15
	self.phase          = Constants.PHASES.FRESHMAN
	self.gradeYear      = 1   -- 1=Freshman, 2=Sophomore, 3=Junior, 4=Senior

	-- Academic
	self.gpa            = 3.0
	self.credits        = 0
	self.recoveryCredits= 0
	self.attendance     = 0      -- days attended class
	self.absences       = 0
	self.hasDiploma     = false
	self.conductPoints  = 100    -- 0-100, starts clean

	-- Dual axes
	self.stronger       = 0
	self.stranger       = 0

	-- Stats (unified for sports / fights / school / jobs)
	self.stats = {}
	for _, stat in ipairs(Constants.STATS) do
		self.stats[stat] = Constants.STAT_DEFAULT
	end

	-- Apply background bonuses
	self:_applyBackground(backgroundId)

	-- Clubs & teams
	self.activeClubId   = nil    -- currently joined club
	self.clubHistory    = {}     -- { clubId = dayCount }
	self.sportHistory   = {}     -- record of sports seasons played

	-- Combat
	self.fightingStyle  = nil    -- unlocked after training/route
	self.fightingStyleProficiency = 0
	self.combatWins     = 0
	self.combatLosses   = 0

	-- Psychic route
	self.psychicType    = nil
	self.psychicLevel   = 0
	self.strangeConditions = {}  -- list of active conditions
	self.manifestation  = nil    -- unlocked at ~age 18

	-- Rumor state
	self.rumorLog       = {}     -- { rumorId = state }
	self.rumorsSurvived = 0

	-- Reputation
	self.streetRep      = 0
	self.schoolRep      = 0
	self.agencyFlag     = false  -- agency is watching

	-- Items / inventory
	self.inventory      = {}     -- { itemId = count }

	-- Housing (adult phase)
	self.apartment      = nil
	self.trophies       = {}
	self.artifacts      = {}

	-- College / Career
	self.college        = nil
	self.major          = nil
	self.jobId          = nil

	-- Schedule state
	self.currentDayPhase = Constants.DAY_PHASES.MORNING
	self.dayCount        = 1

	return self
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Background application
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
-- Stat growth
-- ─────────────────────────────────────────────────────────────────────────────
function PlayerData:GainStat(statName, amount)
	assert(self.stats[statName] ~= nil, "Unknown stat: " .. tostring(statName))
	local prev = self.stats[statName]
	self.stats[statName] = math.clamp(
		self.stats[statName] + amount,
		0,
		Constants.STAT_MAX
	)
	return self.stats[statName] - prev  -- actual gain
end

function PlayerData:GetStat(statName)
	return self.stats[statName] or 0
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Stronger / Stranger progression
-- ─────────────────────────────────────────────────────────────────────────────
function PlayerData:AddStronger(amount)
	local prev = self.stronger
	self.stronger = math.clamp(self.stronger + amount, 0, Constants.STRONGER_MAX)
	return self.stronger - prev
end

function PlayerData:AddStranger(amount)
	local prev = self.stranger
	self.stranger = math.clamp(self.stranger + amount, 0, Constants.STRANGER_MAX)
	-- Check if a new condition should trigger (handled externally by StrangerSystem)
	return self.stranger - prev
end

-- Returns the most recent milestone label crossed (nil if none new)
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
	if not self.clubHistory[clubId] then
		self.clubHistory[clubId] = 0
	end
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
	-- Rolling average, score is 0-4
	local weight = 0.1
	self.gpa = math.clamp(self.gpa * (1 - weight) + score * weight, 0, 4.0)
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
-- Strange condition management
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

-- Check manifestation unlock
function PlayerData:CanUnlockManifestation()
	local m = Constants.MANIFESTATION_UNLOCK_THRESHOLD
	return self.age >= m.age
		and self.stranger >= m.stranger
		and self.stats.Psych >= m.psych
		and self.manifestation == nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Serialization (for DataStore saving)
-- ─────────────────────────────────────────────────────────────────────────────
function PlayerData:Serialize()
	return {
		backgroundId     = self.backgroundId,
		age              = self.age,
		phase            = self.phase,
		gradeYear        = self.gradeYear,
		gpa              = self.gpa,
		credits          = self.credits,
		recoveryCredits  = self.recoveryCredits,
		attendance       = self.attendance,
		conductPoints    = self.conductPoints,
		stronger         = self.stronger,
		stranger         = self.stranger,
		stats            = self.stats,
		activeClubId     = self.activeClubId,
		clubHistory      = self.clubHistory,
		fightingStyle    = self.fightingStyle,
		fightingStyleProficiency = self.fightingStyleProficiency,
		combatWins       = self.combatWins,
		combatLosses     = self.combatLosses,
		psychicType      = self.psychicType,
		psychicLevel     = self.psychicLevel,
		strangeConditions= self.strangeConditions,
		manifestation    = self.manifestation,
		rumorLog         = self.rumorLog,
		rumorsSurvived   = self.rumorsSurvived,
		streetRep        = self.streetRep,
		schoolRep        = self.schoolRep,
		agencyFlag       = self.agencyFlag,
		inventory        = self.inventory,
		apartment        = self.apartment,
		college          = self.college,
		major            = self.major,
		jobId            = self.jobId,
		dayCount         = self.dayCount,
		hasDiploma       = self.hasDiploma,
	}
end

function PlayerData.Deserialize(data)
	local self = setmetatable({}, PlayerData)
	for k, v in pairs(data) do
		self[k] = v
	end
	-- Ensure stats table is complete
	for _, stat in ipairs(Constants.STATS) do
		if not self.stats[stat] then
			self.stats[stat] = Constants.STAT_DEFAULT
		end
	end
	return self
end

return PlayerData
