-- Dream Delinquent: Schedule System
-- Drives the in-game clock and day phase transitions.
-- Emits phase change events that all other systems listen to.

local Constants = require(script.Parent.Constants)

local ScheduleSystem = {}
ScheduleSystem.__index = ScheduleSystem

-- Phase order
local PHASE_ORDER = {
	Constants.DAY_PHASES.MORNING,
	Constants.DAY_PHASES.CLASS_1,
	Constants.DAY_PHASES.CLASS_2,
	Constants.DAY_PHASES.LUNCH,
	Constants.DAY_PHASES.CLASS_3,
	Constants.DAY_PHASES.CLASS_4,
	Constants.DAY_PHASES.AFTERSCHOOL,
	Constants.DAY_PHASES.EVENING,
	Constants.DAY_PHASES.NIGHT,
	Constants.DAY_PHASES.LATE_NIGHT,
}

-- Which phases are "school hours" — player must be in school
ScheduleSystem.SCHOOL_PHASES = {
	[Constants.DAY_PHASES.CLASS_1]  = true,
	[Constants.DAY_PHASES.CLASS_2]  = true,
	[Constants.DAY_PHASES.LUNCH]    = true,
	[Constants.DAY_PHASES.CLASS_3]  = true,
	[Constants.DAY_PHASES.CLASS_4]  = true,
}

-- Phases that unlock city / street activity
ScheduleSystem.CITY_PHASES = {
	[Constants.DAY_PHASES.AFTERSCHOOL] = true,
	[Constants.DAY_PHASES.EVENING]     = true,
	[Constants.DAY_PHASES.NIGHT]       = true,
	[Constants.DAY_PHASES.LATE_NIGHT]  = true,
}

-- Night-only rumor/encounter trigger
ScheduleSystem.NIGHT_PHASES = {
	[Constants.DAY_PHASES.NIGHT]      = true,
	[Constants.DAY_PHASES.LATE_NIGHT] = true,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Constructor: one clock per server
-- ─────────────────────────────────────────────────────────────────────────────
function ScheduleSystem.new()
	local self = setmetatable({}, ScheduleSystem)
	self.phaseIndex    = 1
	self.phaseTimer    = 0
	self.currentPhase  = PHASE_ORDER[1]
	self.currentDay    = 1
	self.listeners     = {}   -- fn(newPhase, prevPhase, day)
	return self
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Register a listener called on every phase change
-- ─────────────────────────────────────────────────────────────────────────────
function ScheduleSystem:OnPhaseChange(fn)
	table.insert(self.listeners, fn)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Tick: call every RunService.Heartbeat
-- ─────────────────────────────────────────────────────────────────────────────
function ScheduleSystem:Tick(dt)
	local phaseDuration = Constants.PHASE_DURATION[self.currentPhase] or 120

	self.phaseTimer = self.phaseTimer + dt
	if self.phaseTimer >= phaseDuration then
		self.phaseTimer = 0
		self:_AdvancePhase()
	end
end

function ScheduleSystem:_AdvancePhase()
	local prev = self.currentPhase
	self.phaseIndex = self.phaseIndex + 1

	if self.phaseIndex > #PHASE_ORDER then
		-- New day
		self.phaseIndex = 1
		self.currentDay = self.currentDay + 1
	end

	self.currentPhase = PHASE_ORDER[self.phaseIndex]

	for _, fn in ipairs(self.listeners) do
		fn(self.currentPhase, prev, self.currentDay)
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────
function ScheduleSystem:IsSchoolHours()
	return ScheduleSystem.SCHOOL_PHASES[self.currentPhase] == true
end

function ScheduleSystem:IsCityHours()
	return ScheduleSystem.CITY_PHASES[self.currentPhase] == true
end

function ScheduleSystem:IsNight()
	return ScheduleSystem.NIGHT_PHASES[self.currentPhase] == true
end

function ScheduleSystem:GetPhaseProgress()
	local dur = Constants.PHASE_DURATION[self.currentPhase] or 120
	return self.phaseTimer / dur  -- 0-1
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Class schedule (which subject plays during which class slot)
-- Rotates so each day has a different pair of subjects
-- ─────────────────────────────────────────────────────────────────────────────
local CLASS_ROTATION = {
	{ "Math",    "Lit"  },
	{ "Gym",     "Sci"  },
	{ "Art",     "Math" },
	{ "History", "Gym"  },
	{ "Lit",     "Music"},
}

function ScheduleSystem:GetTodaysSubjects()
	local idx = ((self.currentDay - 1) % #CLASS_ROTATION) + 1
	return CLASS_ROTATION[idx]   -- { morningSubject, afternoonSubject }
end

function ScheduleSystem:GetCurrentSubject()
	local subjects = self:GetTodaysSubjects()
	if self.currentPhase == Constants.DAY_PHASES.CLASS_1
		or self.currentPhase == Constants.DAY_PHASES.CLASS_2 then
		return subjects[1]
	elseif self.currentPhase == Constants.DAY_PHASES.CLASS_3
		or self.currentPhase == Constants.DAY_PHASES.CLASS_4 then
		return subjects[2]
	end
	return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Ambient lighting hint (for client skybox/atmosphere)
-- ─────────────────────────────────────────────────────────────────────────────
ScheduleSystem.LIGHTING_PROFILE = {
	Morning     = { ambient = Color3.fromRGB(180,170,160), brightness = 1.5 },
	Class1      = { ambient = Color3.fromRGB(200,195,185), brightness = 2.0 },
	Class2      = { ambient = Color3.fromRGB(210,200,190), brightness = 2.2 },
	Lunch       = { ambient = Color3.fromRGB(215,205,195), brightness = 2.5 },
	Class3      = { ambient = Color3.fromRGB(200,190,175), brightness = 2.0 },
	Class4      = { ambient = Color3.fromRGB(180,165,145), brightness = 1.6 },
	AfterSchool = { ambient = Color3.fromRGB(160,140,110), brightness = 1.2 },
	Evening     = { ambient = Color3.fromRGB(120,90,70),   brightness = 0.8 },
	Night       = { ambient = Color3.fromRGB(30,30,55),    brightness = 0.3 },
	LateNight   = { ambient = Color3.fromRGB(15,15,35),    brightness = 0.15 },
}

function ScheduleSystem:GetLightingProfile()
	return ScheduleSystem.LIGHTING_PROFILE[self.currentPhase]
		or ScheduleSystem.LIGHTING_PROFILE.Class1
end

return ScheduleSystem
