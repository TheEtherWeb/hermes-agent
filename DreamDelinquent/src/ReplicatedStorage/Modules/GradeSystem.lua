-- Dream Delinquent: Grade Progression System
-- Handles end-of-year exams, grade advancement, GPA, and graduation.

local Constants = require(script.Parent.Constants)

local GradeSystem = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Exam definitions per grade
-- ─────────────────────────────────────────────────────────────────────────────
GradeSystem.EXAMS = {
	Freshman = {
		id          = "ExamFreshman",
		name        = "Year 1 Finals",
		description = "Subjects: Math, Literature, Gym, and your chosen elective.",
		minCredits  = 40,
		subjects    = { "Math", "Lit", "Gym" },
		passScore   = 55,
		rewards     = {
			pass = { credits=10, gpaBonus=0.1, schoolRep=10 },
			ace  = { credits=20, gpaBonus=0.2, schoolRep=20, streetRep=5 },
		},
		failConsequence = "repeat_or_recovery",
	},
	Sophomore = {
		id          = "ExamSophomore",
		name        = "Year 2 Finals",
		description = "Track identity starts to show. Club route affects available questions.",
		minCredits  = 80,
		subjects    = { "Math", "Sci", "Lit" },
		passScore   = 55,
		rewards     = {
			pass = { credits=10, gpaBonus=0.1, schoolRep=10 },
			ace  = { credits=20, gpaBonus=0.2, schoolRep=25, streetRep=8 },
		},
		failConsequence = "repeat_or_recovery",
	},
	Junior = {
		id          = "ExamJunior",
		name        = "Year 3 Finals",
		description = "Route identity serious now. Delinquents must prove credit completion.",
		minCredits  = 120,
		subjects    = { "Math", "History", "Sci" },
		passScore   = 60,
		rewards     = {
			pass = { credits=15, gpaBonus=0.1, schoolRep=15 },
			ace  = { credits=25, gpaBonus=0.25, schoolRep=30, streetRep=10 },
		},
		failConsequence = "probation",
	},
	Senior = {
		id          = "ExamSenior",
		name        = "Graduation Exam",
		description = "The final gate. Pass with any valid route to earn your diploma.",
		minCredits  = 160,
		subjects    = { "Math", "History", "Lit", "Sci" },
		passScore   = 60,
		rewards     = {
			pass = { credits=25, gpaBonus=0.2, schoolRep=50, hasDiploma=true },
			ace  = { credits=40, gpaBonus=0.4, schoolRep=80, streetRep=20, hasDiploma=true },
		},
		failConsequence = "summer_recovery",
	},
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Recovery paths (for delinquents / underachievers)
-- ─────────────────────────────────────────────────────────────────────────────
GradeSystem.RECOVERY_PATHS = {
	repeat_or_recovery = {
		description  = "Attend 5 recovery sessions and pass a make-up exam.",
		recoveryCost = 20,   -- recovery credits needed
		makeUpPassScore = 50,
	},
	probation = {
		description  = "Maintain conduct above 50 and attend all remaining sessions.",
		conductMin   = 50,
	},
	summer_recovery = {
		description  = "Complete summer school and pass the re-examination.",
		recoveryCost = 30,
		makeUpPassScore = 55,
	},
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Check if player is eligible to sit the exam
-- ─────────────────────────────────────────────────────────────────────────────
function GradeSystem.IsEligible(playerData)
	local exam = GradeSystem.EXAMS[playerData.phase]
	if not exam then return false, "No exam for this phase." end

	local totalCredits = playerData.credits + playerData.recoveryCredits
	if totalCredits < exam.minCredits then
		return false,
			("Need %d credits (have %d)."):format(exam.minCredits, totalCredits)
	end

	return true, exam
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Process exam result
-- examScore: 0-100 composite from all minigame rounds
-- ─────────────────────────────────────────────────────────────────────────────
function GradeSystem.ProcessExamResult(examScore, playerData)
	local exam = GradeSystem.EXAMS[playerData.phase]
	if not exam then return nil end

	local passed = examScore >= exam.passScore
	local aced   = examScore >= 90

	local tier    = aced and "ace" or passed and "pass" or "fail"
	local rewards = (tier ~= "fail") and exam.rewards[tier] or nil

	local result = {
		examId       = exam.id,
		examName     = exam.name,
		score        = examScore,
		tier         = tier,
		passed       = passed,
		consequence  = passed and nil or exam.failConsequence,
	}

	if passed and rewards then
		-- Apply credits
		playerData:AddCredits(rewards.credits or 0)
		-- GPA
		if rewards.gpaBonus then
			playerData.gpa = math.clamp(playerData.gpa + rewards.gpaBonus, 0, 4.0)
		end
		-- Rep
		if rewards.schoolRep then
			playerData.schoolRep = playerData.schoolRep + rewards.schoolRep
		end
		if rewards.streetRep then
			playerData.streetRep = playerData.streetRep + rewards.streetRep
		end
		-- Diploma
		if rewards.hasDiploma then
			playerData.hasDiploma = true
			result.diplomaAwarded = true
		end

		-- Advance phase
		result.oldPhase = playerData.phase
		result.newPhase = GradeSystem.AdvancePhase(playerData)
	end

	result.rewards = rewards
	return result
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Advance to next life phase
-- ─────────────────────────────────────────────────────────────────────────────
function GradeSystem.AdvancePhase(playerData)
	local order = Constants.PHASE_ORDER
	for i, phase in ipairs(order) do
		if phase == playerData.phase then
			local next = order[i + 1]
			if next then
				playerData.phase = next
				playerData.gradeYear = playerData.gradeYear + 1
				playerData.age       = playerData.age + 1
				-- Reset credits for the new year (keep total for reference but reset annual counter)
				playerData.credits   = 0
				return next
			end
		end
	end
	return playerData.phase
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Generate a diploma summary string
-- ─────────────────────────────────────────────────────────────────────────────
function GradeSystem.GenerateDiploma(playerData)
	local routeSummary = "General Studies"
	if playerData.activeClubId or next(playerData.clubHistory) then
		local topClub, topDays = nil, 0
		for cid, days in pairs(playerData.clubHistory) do
			if days > topDays then topClub = cid; topDays = days end
		end
		if topClub then
			routeSummary = topClub .. " Route"
		end
	end

	local conditionNote = ""
	if #playerData.strangeConditions > 0 then
		conditionNote = " [Anomaly Record Filed]"
	end

	return {
		name         = "Dream Delinquent High School",
		gpa          = ("%.2f"):format(playerData.gpa),
		route        = routeSummary,
		conduct      = playerData.conductPoints,
		streetRep    = playerData.streetRep,
		schoolRep    = playerData.schoolRep,
		rumorsSurv   = playerData.rumorsSurvived,
		conditions   = table.concat(playerData.strangeConditions, ", "),
		conditionNote= conditionNote,
		dayCompleted = playerData.dayCount,
	}
end

-- ─────────────────────────────────────────────────────────────────────────────
-- College eligibility (GPA + diploma)
-- ─────────────────────────────────────────────────────────────────────────────
GradeSystem.COLLEGE_TIERS = {
	{ name = "City University",       minGPA = 3.5, description = "Full curriculum. Best job access." },
	{ name = "Community College",     minGPA = 2.0, description = "Flexible. Good for specific tracks." },
	{ name = "Trade Institute",       minGPA = 0.0, description = "Skills-focused. Connects to service jobs." },
	{ name = "Online / Correspondence", minGPA = 0.0, description = "NEET-compatible. Slow but valid." },
}

function GradeSystem.GetCollegeOptions(playerData)
	if not playerData.hasDiploma then
		return { GradeSystem.COLLEGE_TIERS[4] }  -- online only without diploma
	end
	local options = {}
	for _, tier in ipairs(GradeSystem.COLLEGE_TIERS) do
		if playerData.gpa >= tier.minGPA then
			table.insert(options, tier)
		end
	end
	return options
end

return GradeSystem
