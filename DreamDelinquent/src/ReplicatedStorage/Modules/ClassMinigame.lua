-- Dream Delinquent: Class Minigame Module
-- Defines minigame data and result scoring for each school subject.
-- Actual input handling is on the client; this module provides server-side
-- scoring and reward tables.

local Constants = require(script.Parent.Constants)
local StrongerStrangerSystem = require(script.Parent.StrongerStrangerSystem)

local ClassMinigame = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Minigame definitions (type, params, rewards)
-- ─────────────────────────────────────────────────────────────────────────────
ClassMinigame.GAMES = {

	Math = {
		id         = "Math",
		gameType   = "sequence",     -- press keys in the correct order before timer
		rounds     = 5,
		timePerRound = 3.5,          -- seconds
		difficulty = "scaling",      -- increases each round
		description= "Solve the pattern before time runs out.",
		rewards    = {
			pass = { Tech = 2, Insight = 1, credits = 2, gpaBonus = 0.05 },
			ace  = { Tech = 3, Insight = 2, credits = 4, gpaBonus = 0.10 },
			fail = { credits = 0, gpaPenalty = 0.03 },
		},
		strongerOnAce = "class_ace",
		strongerOnPass= "class_pass",
	},

	Lit = {
		id         = "Lit",
		gameType   = "keyword",      -- highlight correct keywords in a text passage
		rounds     = 1,
		timePerRound = 20,
		description= "Find all highlighted concepts in the passage.",
		rewards    = {
			pass = { Insight = 2, credits = 2, gpaBonus = 0.05 },
			ace  = { Insight = 3, credits = 4, gpaBonus = 0.10 },
			fail = { credits = 0, gpaPenalty = 0.03 },
		},
		strongerOnAce = "class_ace",
		strongerOnPass= "class_pass",
	},

	Gym = {
		id         = "Gym",
		gameType   = "rhythm",       -- hit spacebar/button in time with indicators
		rounds     = 3,
		timePerRound = 8,
		description= "Keep pace with the drill.",
		rewards    = {
			pass = { Athletics = 2, Guts = 1, credits = 2, gpaBonus = 0.04 },
			ace  = { Athletics = 3, Guts = 2, credits = 3, gpaBonus = 0.08 },
			fail = { credits = 0, gpaPenalty = 0.02 },
		},
		subGames   = { "dodgeball", "sprints", "drills" },
		strongerOnAce = "gym_drill",
		strongerOnPass= "class_attend",
	},

	Sci = {
		id         = "Sci",
		gameType   = "match",        -- match pairs within a grid
		rounds     = 4,
		timePerRound = 10,
		description= "Match the concepts before time is up.",
		rewards    = {
			pass = { Tech = 1, Insight = 2, credits = 2, gpaBonus = 0.05 },
			ace  = { Tech = 2, Insight = 3, credits = 4, gpaBonus = 0.10 },
			fail = { credits = 0, gpaPenalty = 0.03 },
		},
		strongerOnAce = "class_ace",
		strongerOnPass= "class_pass",
	},

	Art = {
		id         = "Art",
		gameType   = "trace",        -- trace a shape within tolerance
		rounds     = 3,
		timePerRound = 12,
		description= "Reproduce the composition accurately.",
		rewards    = {
			pass = { Style = 2, Insight = 1, credits = 2, gpaBonus = 0.04 },
			ace  = { Style = 3, Insight = 2, credits = 3, gpaBonus = 0.08 },
			fail = { credits = 0, gpaPenalty = 0.02 },
		},
		strongerOnAce = "class_ace",
		strongerOnPass= "class_attend",
	},

	History = {
		id         = "History",
		gameType   = "timeline",     -- drag events to correct order
		rounds     = 1,
		timePerRound = 18,
		description= "Order the events correctly.",
		rewards    = {
			pass = { Insight = 2, Charisma = 1, credits = 2, gpaBonus = 0.05 },
			ace  = { Insight = 3, Charisma = 2, credits = 4, gpaBonus = 0.10 },
			fail = { credits = 0, gpaPenalty = 0.03 },
		},
		strongerOnAce = "class_ace",
		strongerOnPass= "class_pass",
	},

	Music = {
		id         = "Music",
		gameType   = "rhythm",
		rounds     = 4,
		timePerRound = 6,
		description= "Hit the notes in time.",
		rewards    = {
			pass = { Style = 1, Charisma = 2, credits = 2, gpaBonus = 0.04 },
			ace  = { Style = 2, Charisma = 3, credits = 3, gpaBonus = 0.08 },
			fail = { credits = 0, gpaPenalty = 0.02 },
		},
		strongerOnAce = "class_ace",
		strongerOnPass= "class_attend",
	},
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Score thresholds (0-100)
-- ─────────────────────────────────────────────────────────────────────────────
ClassMinigame.GRADE = {
	ACE  = 85,
	PASS = 50,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Process a completed minigame (server call)
-- score: 0-100
-- Returns reward table to apply to playerData
-- ─────────────────────────────────────────────────────────────────────────────
function ClassMinigame.ProcessResult(subjectId, score, playerData)
	local game = ClassMinigame.GAMES[subjectId]
	if not game then return nil end

	local tier, rewards, strongerAction
	if score >= ClassMinigame.GRADE.ACE then
		tier    = "ace"
		rewards = game.rewards.ace
		strongerAction = game.strongerOnAce
	elseif score >= ClassMinigame.GRADE.PASS then
		tier    = "pass"
		rewards = game.rewards.pass
		strongerAction = game.strongerOnPass
	else
		tier    = "fail"
		rewards = game.rewards.fail
		strongerAction = nil
	end

	-- Apply stat gains
	local statGains = {}
	for stat, amount in pairs(rewards) do
		if playerData.stats[stat] ~= nil then
			local actual = playerData:GainStat(stat, amount)
			statGains[stat] = actual
		end
	end

	-- Credits
	playerData:AddCredits(rewards.credits or 0)

	-- GPA
	local gpaScore = (score / 100) * 4.0  -- 0-4 scale
	playerData:UpdateGPA(gpaScore)

	-- Attendance
	playerData.attendance = playerData.attendance + 1

	-- Stronger
	local strongerResult = nil
	if strongerAction then
		strongerResult = StrongerStrangerSystem.AwardStronger(playerData, strongerAction)
	end

	return {
		tier          = tier,
		score         = score,
		statGains     = statGains,
		credits       = rewards.credits or 0,
		newGPA        = playerData.gpa,
		strongerResult= strongerResult,
	}
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Generate a minigame prompt (for UI to render)
-- ─────────────────────────────────────────────────────────────────────────────
function ClassMinigame.GeneratePrompt(subjectId, difficulty)
	difficulty = difficulty or 1  -- 1-5

	-- Math: produce a sequence of N numbers, player must enter next
	if subjectId == "Math" then
		local patterns = {
			{ 2, 4, 6, 8 },       -- even
			{ 1, 3, 6, 10 },      -- triangular
			{ 1, 1, 2, 3, 5 },    -- fibonacci-ish
			{ 5, 10, 20, 40 },    -- doubling
			{ 3, 9, 27, 81 },     -- powers of 3
		}
		local idx = math.random(1, math.min(difficulty, #patterns))
		local seq = patterns[idx]
		local answer = seq[#seq]
		local display = {}
		for i = 1, #seq - 1 do table.insert(display, seq[i]) end
		return { type = "sequence", display = display, answer = answer }
	end

	-- Gym: generate rhythm indicators (1=hit, 0=skip)
	if subjectId == "Gym" then
		local pattern = {}
		for _ = 1, 8 do
			table.insert(pattern, math.random() < 0.6 and 1 or 0)
		end
		return { type = "rhythm", pattern = pattern }
	end

	-- Default: return generic prompt
	return { type = "generic", prompt = "Pay attention in class." }
end

return ClassMinigame
