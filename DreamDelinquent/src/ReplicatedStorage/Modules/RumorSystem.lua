-- Dream Delinquent: Rumor System
-- Defines rumor data, chain logic, and encounter resolution.

local Constants = require(script.Parent.Constants)

local RumorSystem = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- RUMOR DATABASE (Vertical Slice: 8 initial rumors, one full chain)
-- ─────────────────────────────────────────────────────────────────────────────
RumorSystem.RUMORS = {

	-- ── Chain 1: "The Seven Floors" (supernatural escalation chain) ──────────

	R001 = {
		id          = "R001",
		chain       = "SevenFloors",
		order       = 1,
		title       = "The Empty Classroom",
		body        = "Someone said Room 407 is always locked, but you can hear talking inside after school.",
		source      = "cafeteria_npc_1",
		hearPhase   = { "Class2", "Lunch" },  -- day phases when it can be heard
		pursuePhase = { "AfterSchool", "Evening" },
		isTrue      = true,
		consequence = "ghost_encounter_mild",
		strangerGain= "encounter_ghost",
		trueFalse   = "true",
		hint        = "Room 407 is on the fourth floor east wing.",
		nextRumor   = "R002",
	},

	R002 = {
		id          = "R002",
		chain       = "SevenFloors",
		order       = 2,
		title       = "The Teacher Who Didn't Leave",
		body        = "A student who went in said they saw a teacher sitting at the desk. But that teacher died three years ago.",
		source      = "journalism_club_npc",
		hearPhase   = { "Lunch", "AfterSchool" },
		pursuePhase = { "AfterSchool", "Evening" },
		isTrue      = true,
		consequence = "ghost_encounter_moderate",
		strangerGain= "encounter_ghost",
		prerequisite= "R001",
		nextRumor   = "R003",
	},

	R003 = {
		id          = "R003",
		chain       = "SevenFloors",
		order       = 3,
		title       = "The Class List",
		body        = "A list of names appeared on the board in 407. Every student on it transferred out within the week. Except the last name.",
		source      = "occult_club_npc",
		hearPhase   = { "Morning", "Lunch" },
		pursuePhase = { "Night" },
		isTrue      = true,
		consequence = "haunted_condition_trigger",
		strangerGain= "haunted",
		prerequisite= "R002",
		dangerLevel = 3,
		nextRumor   = "R004",
	},

	R004 = {
		id          = "R004",
		chain       = "SevenFloors",
		order       = 4,
		title       = "The Seven Floors",
		body        = "Someone counted the school's floors at night. There are seven. The building only has five.",
		source      = "anonymous_note",
		hearPhase   = { "Lunch" },
		pursuePhase = { "Night", "LateNight" },
		isTrue      = true,
		consequence = "anomaly_space_encounter",
		strangerGain= "anomaly_site",
		prerequisite= "R003",
		dangerLevel = 5,
		agencyAlert = true,   -- agency notices the player after this
		nextRumor   = nil,    -- chain resolved here
	},

	-- ── Standalone rumors ────────────────────────────────────────────────────

	R005 = {
		id          = "R005",
		chain       = nil,
		title       = "The Fast Kid",
		body        = "There's a freshman running the rooftop circuit after school. Nobody knows how he got up there.",
		source      = "basketball_court_npc",
		hearPhase   = { "Lunch", "AfterSchool" },
		pursuePhase = { "AfterSchool" },
		isTrue      = true,
		consequence = "parkour_npc_unlock",
		strangerGain= nil,
		strongerGain= "escape_chase",
	},

	R006 = {
		id          = "R006",
		chain       = nil,
		title       = "The Alley King",
		body        = "A guy who got expelled last year still hangs around the back lots. He beats seniors without blinking.",
		source      = "delinquent_npc_1",
		hearPhase   = { "AfterSchool", "Evening" },
		pursuePhase = { "AfterSchool", "Evening" },
		isTrue      = true,
		consequence = "fight_npc_hard",
		strangerGain= nil,
		strongerGain= "fight_win",
		requirement = { stat = "Guts", value = 10 },
	},

	R007 = {
		id          = "R007",
		chain       = nil,
		title       = "The Vending Machine",
		body        = "The vending machine on the second floor gives you things that aren't on the menu if you tap it in the right order.",
		source      = "random_student",
		hearPhase   = { "Morning", "Class1" },
		pursuePhase = { "Morning", "Lunch" },
		isTrue      = false,  -- a false rumor
		consequence = "nothing",
		hint        = "Some rumors are just rumors.",
		strangerGain= nil,
	},

	R008 = {
		id          = "R008",
		chain       = nil,
		title       = "The Bite Marks",
		body        = "A junior showed up with bite marks on her wrist she can't explain. She looks pale. She looks happy about it.",
		source      = "cafeteria_npc_2",
		hearPhase   = { "Morning", "Lunch" },
		pursuePhase = { "Evening", "Night" },
		isTrue      = true,
		consequence = "vampire_introduction",
		strangerGain= "encounter_vampire",
		dangerLevel = 4,
		nextRumor   = nil,
	},
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Runtime: get rumors available to hear given current day phase
-- ─────────────────────────────────────────────────────────────────────────────
function RumorSystem.GetHearableRumors(currentPhase, playerData)
	local available = {}
	for _, rumor in pairs(RumorSystem.RUMORS) do
		-- Already heard or resolved?
		local state = playerData:GetRumorState(rumor.id)
		if state ~= Constants.RUMOR_STATES.UNHEARD then continue end

		-- Phase check
		local inPhase = false
		for _, p in ipairs(rumor.hearPhase) do
			if p == currentPhase then inPhase = true break end
		end
		if not inPhase then continue end

		-- Prerequisite check
		if rumor.prerequisite then
			local prereqState = playerData:GetRumorState(rumor.prerequisite)
			if prereqState ~= Constants.RUMOR_STATES.RESOLVED then continue end
		end

		table.insert(available, rumor)
	end
	return available
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Runtime: get rumors available to pursue given current day phase
-- ─────────────────────────────────────────────────────────────────────────────
function RumorSystem.GetPursuableRumors(currentPhase, playerData)
	local available = {}
	for _, rumor in pairs(RumorSystem.RUMORS) do
		local state = playerData:GetRumorState(rumor.id)
		if state ~= Constants.RUMOR_STATES.HEARD then continue end

		local inPhase = false
		for _, p in ipairs(rumor.pursuePhase) do
			if p == currentPhase then inPhase = true break end
		end
		if not inPhase then continue end

		-- Stat requirement check
		if rumor.requirement then
			if playerData:GetStat(rumor.requirement.stat) < rumor.requirement.value then
				continue
			end
		end

		table.insert(available, rumor)
	end
	return available
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Mark a rumor as heard and return its teaser text
-- ─────────────────────────────────────────────────────────────────────────────
function RumorSystem.HearRumor(rumorId, playerData)
	local rumor = RumorSystem.RUMORS[rumorId]
	if not rumor then return nil end
	if playerData:GetRumorState(rumorId) ~= Constants.RUMOR_STATES.UNHEARD then return nil end

	playerData:SetRumorState(rumorId, Constants.RUMOR_STATES.HEARD)
	return rumor
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Pursue a rumor; returns outcome table for server to process
-- ─────────────────────────────────────────────────────────────────────────────
function RumorSystem.PursueRumor(rumorId, playerData)
	local rumor = RumorSystem.RUMORS[rumorId]
	if not rumor then return nil end
	if playerData:GetRumorState(rumorId) ~= Constants.RUMOR_STATES.HEARD then return nil end

	playerData:SetRumorState(rumorId, Constants.RUMOR_STATES.ACTIVE)

	-- Danger check: low guts / bad stats may cause failure
	local danger = rumor.dangerLevel or 0
	local gutsCheck = playerData:GetStat("Guts")
	local insightCheck = playerData:GetStat("Insight")
	local survived = true

	if danger >= 4 then
		-- Hard check
		local roll = (gutsCheck + insightCheck) / 2
		if roll < (danger * 6) then
			survived = false
		end
	end

	return {
		rumor     = rumor,
		survived  = survived,
		isTrue    = rumor.isTrue,
		consequence = rumor.consequence,
		strangerAction = rumor.strangerGain,
		strongerAction = rumor.strongerGain,
		agencyAlert    = rumor.agencyAlert,
		nextRumorId    = rumor.nextRumor,
	}
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Resolve a rumor after encounter
-- ─────────────────────────────────────────────────────────────────────────────
function RumorSystem.ResolveRumor(rumorId, survived, playerData)
	local state = survived
		and Constants.RUMOR_STATES.RESOLVED
		or  Constants.RUMOR_STATES.FAILED

	playerData:SetRumorState(rumorId, state)

	if survived then
		playerData.rumorsSurvived = playerData.rumorsSurvived + 1
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Dialogue generation for rumor source NPCs
-- ─────────────────────────────────────────────────────────────────────────────
RumorSystem.NPC_DIALOGUE = {
	cafeteria_npc_1 = {
		"Hey, you heard about Room 407?",
		"I'm not saying it's haunted. I'm saying the door is always locked and we can hear someone in there.",
		"You go to class four floors up, you'll hear it.",
	},
	journalism_club_npc = {
		"I've been trying to confirm this for two weeks.",
		"Every teacher who hears about it changes the subject. That's confirmation enough for me.",
	},
	occult_club_npc = {
		"The names on the board appeared once before, ten years ago.",
		"The students transferred. All of them. One didn't go home first.",
	},
	delinquent_npc_1 = {
		"You want to see something real? Back lot, after four.",
		"He doesn't hold back for freshmen. Just so you know.",
	},
	basketball_court_npc = {
		"Bro was running on the roof like it was nothing.",
		"I saw him at lunch the next day. Normal. Like it was nothing.",
	},
	cafeteria_npc_2 = {
		"She sat down right there.",
		"She wasn't scared. That's the part that got me.",
	},
}

return RumorSystem
