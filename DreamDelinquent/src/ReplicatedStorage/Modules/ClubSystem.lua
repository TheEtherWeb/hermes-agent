-- Dream Delinquent: Club System
-- Manages enrollment, session progression, proficiency, and club events.

local Constants = require(script.Parent.Constants)
local StrongerStrangerSystem = require(script.Parent.StrongerStrangerSystem)

local ClubSystem = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Get club definition by id
-- ─────────────────────────────────────────────────────────────────────────────
function ClubSystem.GetClub(clubId)
	for _, club in ipairs(Constants.CLUBS) do
		if club.id == clubId then return club end
	end
	return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Attempt to join a club (returns success + reason)
-- ─────────────────────────────────────────────────────────────────────────────
function ClubSystem.TryJoin(clubId, playerData)
	local club = ClubSystem.GetClub(clubId)
	if not club then return false, "Club not found." end

	if playerData.activeClubId == clubId then
		return false, "Already in this club."
	end

	-- Some clubs require a minimum relevant stat
	local minReqs = {
		Basketball    = { Athletics = 8 },
		Soccer        = { Athletics = 8 },
		Baseball      = { Technique = 7 },
		Boxing        = { Power = 8 },
		Wrestling     = { Power = 8 },
		Kendo         = { Technique = 8 },
		Chivalry      = { Technique = 8, Charisma = 6 },
		StudentCouncil= { Charisma = 12, Insight = 10 },
	}

	local req = minReqs[clubId]
	if req then
		for stat, minVal in pairs(req) do
			if playerData:GetStat(stat) < minVal then
				return false,
					("You need at least %d %s to join %s."):format(minVal, stat, club.name)
			end
		end
	end

	-- Leave current club first (no penalty; just a switch)
	playerData:LeaveClub()
	playerData:JoinClub(clubId)

	return true, ("Joined %s."):format(club.name)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Run a club session (AfterSchool phase)
-- Returns progression results for server to broadcast
-- ─────────────────────────────────────────────────────────────────────────────
function ClubSystem.RunSession(clubId, playerData)
	local club = ClubSystem.GetClub(clubId)
	if not club then return nil end
	if playerData.activeClubId ~= clubId then return nil end

	playerData:RecordClubDay()
	local days = playerData:GetClubDays(clubId)

	-- Stat gains (scale slightly with commitment)
	local loyaltyMult = 1 + math.min(days / 100, 0.5)   -- up to 1.5x after 100 sessions
	local statGains = {}

	for stat, baseGain in pairs(club.statGains) do
		local gain = math.ceil(baseGain * loyaltyMult * (0.8 + math.random() * 0.4))
		local actual = playerData:GainStat(stat, gain)
		if actual > 0 then
			statGains[stat] = actual
		end
	end

	-- Stronger gain
	local strongerResult = StrongerStrangerSystem.AwardStronger(playerData, "club_session")

	-- Stranger gain for occult club
	local strangerResult = nil
	if clubId == "Occult" and club.strangerGain then
		strangerResult = StrongerStrangerSystem.AwardStranger(playerData, "occult_session")
	end

	-- Credits for discipline
	playerData:AddCredits(2)

	-- Milestone text override for special clubs
	local flavourText = ClubSystem._GetSessionFlavour(clubId, days)

	return {
		clubId        = clubId,
		clubName      = club.name,
		days          = days,
		statGains     = statGains,
		strongerResult= strongerResult,
		strangerResult= strangerResult,
		flavourText   = flavourText,
	}
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Flavour lines per club (returned on session completion)
-- ─────────────────────────────────────────────────────────────────────────────
ClubSystem.FLAVOUR = {
	Basketball = {
		"The footwork is starting to feel natural.",
		"You read the lane before it opened.",
		"Coach noticed.",
	},
	Soccer = {
		"The burst came from nowhere. Your legs are remembering.",
		"First touch, clean.",
		"You cut the angle before the defender could think.",
	},
	Baseball = {
		"You waited. That's the whole game.",
		"The rotation is starting to feel right.",
		"Timing. Everything is timing.",
	},
	Parkour = {
		"The rooftop edge stopped looking scary.",
		"You found a new line.",
		"Three vaults, no hesitation.",
	},
	Boxing = {
		"Your counters are getting mean.",
		"Body shot. They folded.",
		"You kept your hands up the whole round.",
	},
	Wrestling = {
		"You got the takedown on the third try. It will be the second next time.",
		"Clinch work is starting to feel like a conversation.",
		"They never got back up from that slam.",
	},
	Kendo = {
		"The cut was clean. One movement.",
		"Discipline is not slow. You're starting to understand.",
		"Sensei did not correct you today.",
	},
	Chivalry = {
		"Your form is becoming something people stare at.",
		"The riposte landed perfectly.",
		"Even your footwork is starting to look deliberate.",
	},
	Culinary = {
		"The sauce came together.",
		"You timed the reduction without watching it.",
		"Three people asked for your recipe.",
	},
	Tech = {
		"You traced the signal three nodes deep.",
		"The device you built actually worked.",
		"You found the pattern before anyone else noticed it.",
	},
	Debate = {
		"You made them admit they were wrong without raising your voice.",
		"The argument was airtight.",
		"Everyone in the room went quiet when you finished.",
	},
	Journalism = {
		"The source talked. You listened.",
		"The story checked out.",
		"You found a detail no one else caught.",
	},
	Occult = {
		"The symbol in the book looked back.",
		"Something about the city makes more sense now.",
		"You feel like the rumors are starting to find you.",
	},
	Theater = {
		"You disappeared into the character.",
		"Nobody coughed during your monologue.",
		"You made the audience uncomfortable. That's correct.",
	},
	Fashion = {
		"The fit was right.",
		"You walked in and the room shifted.",
		"Three people asked where you got it.",
	},
	Reading = {
		"You finished the chapter before the session ended.",
		"A passage stayed with you.",
		"Something clicked about the subtext.",
	},
	Music = {
		"The rhythm held.",
		"You played the difficult part twice without stopping.",
		"Someone listened from outside the door.",
	},
	Art = {
		"The composition came together without forcing it.",
		"You noticed something in the reference you hadn't seen before.",
		"A piece you made ended up on the wall.",
	},
	StudentCouncil = {
		"The vote went your way.",
		"You managed the meeting without losing anyone.",
		"You fixed the problem before it became one.",
	},
}

function ClubSystem._GetSessionFlavour(clubId, days)
	local lines = ClubSystem.FLAVOUR[clubId]
	if not lines then return nil end
	-- Cycle through lines as days increase
	local idx = ((days - 1) % #lines) + 1
	return lines[idx]
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Get fighting style unlock based on club history
-- ─────────────────────────────────────────────────────────────────────────────
function ClubSystem.GetFightingStyleFromHistory(playerData)
	local best, bestDays = nil, 0

	local styleMap = {
		Boxing   = "Striker",
		Wrestling= "Grappler",
		Kendo    = "Duelist",
		Chivalry = "Duelist",
		Parkour  = "Acrobat",
		Soccer   = "Kicker",
		Basketball="Acrobat",
		Baseball = "Striker",
		Theater  = "Trickster",
		StudentCouncil = "Captain",
	}

	for clubId, days in pairs(playerData.clubHistory) do
		local style = styleMap[clubId]
		if style and days > bestDays then
			best     = style
			bestDays = days
		end
	end

	-- Minimum 10 sessions to develop a style
	if bestDays >= 10 then
		return best
	end
	return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Club events (weekly special sessions)
-- ─────────────────────────────────────────────────────────────────────────────
ClubSystem.EVENTS = {
	{
		id       = "TourneyBasketball",
		clubId   = "Basketball",
		name     = "Intra-School Tournament",
		dayTrigger = 14,   -- day 14 of term
		rewards  = { Athletics=3, Charisma=2, credits=8, streetRep=5 },
	},
	{
		id       = "KendoTest",
		clubId   = "Kendo",
		name     = "Dan Examination",
		dayTrigger = 21,
		rewards  = { Technique=4, Guts=2, credits=6 },
	},
	{
		id       = "OccultRitual",
		clubId   = "Occult",
		name     = "The Reading",
		dayTrigger = 7,
		rewards  = { Psych=3, Insight=2 },
		strangerGain = "occult_session",
	},
	{
		id       = "CulinaryComp",
		clubId   = "Culinary",
		name     = "School Cook-Off",
		dayTrigger = 18,
		rewards  = { Technique=3, Charisma=3, credits=6 },
	},
}

function ClubSystem.GetTodayEvents(currentDay, clubId)
	local events = {}
	for _, event in ipairs(ClubSystem.EVENTS) do
		if event.clubId == clubId and event.dayTrigger == currentDay then
			table.insert(events, event)
		end
	end
	return events
end

return ClubSystem
