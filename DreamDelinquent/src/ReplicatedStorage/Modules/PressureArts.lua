-- Dream Delinquent: Pressure Arts System
-- Active techniques shaped by route, clubs, rumor survival, and supernatural exposure.
-- These are NOT spells. They are route-based expressions of style and pressure.
--
-- Four-layer power model:
--   Layer 1  Human Style     (fighting root: how you move)
--   Layer 2  Psychic Type    (how your will leaks into the world)
--   Layer 3  Strange Condition (what the city has done to you)
--   Layer 4  Manifestation   (late-game Persona-equivalent, ~age 18)
--
-- Pressure Arts sit across layers 1–3 and scale into layer 4.

local Constants = require(script.Parent.Constants)

local PressureArts = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- ART DATABASE
-- Each art has:
--   id          string
--   name        string
--   category    one of Constants.PRESSURE_ART_CATEGORIES
--   source      one of Constants.PRESSURE_ART_SOURCES
--   description string
--   unlockReq   { stat/strangerStat/condition/club/rumor conditions }
--   baseCost    stamina cost
--   scalingStat string  (which stat primarily scales damage/effect)
--   scaleType   "stronger" | "stranger" | "psych"
--   defaultEdits { list of Edit ids pre-applied }
--   effect      function(attacker, defender) → effectTable  (resolved server-side)
-- ─────────────────────────────────────────────────────────────────────────────
PressureArts.ARTS = {

	-- ── STRIKER ROOT ────────────────────────────────────────────────────────

	["ImpactFive"] = {
		id          = "ImpactFive",
		name        = "Impact Five",
		category    = "Strike",
		source      = "MartialTraining",
		description = "A rapid five-hit sequence that drives the opponent back. Comes naturally after enough boxing sessions.",
		unlockReq   = { club="Boxing", clubDays=10 },
		baseCost    = 18,
		scalingStat = "Power",
		scaleType   = "stronger",
		defaultEdits= {},
	},

	["CounterHook"] = {
		id          = "CounterHook",
		name        = "Counter Hook",
		category    = "Counter",
		source      = "MartialTraining",
		description = "A perfectly-timed cross that converts the opponent's momentum into your damage.",
		unlockReq   = { club="Boxing", clubDays=20 },
		baseCost    = 14,
		scalingStat = "Technique",
		scaleType   = "stronger",
		defaultEdits= { "Breaking" },
	},

	-- ── KICKER ROOT ─────────────────────────────────────────────────────────

	["LaneCutter"] = {
		id          = "LaneCutter",
		name        = "Lane Cutter",
		category    = "Dash",
		source      = "SportsIdentity",
		description = "A burst dash through opponent spacing rooted in soccer footwork. Covers distance before they read the angle.",
		unlockReq   = { club="Soccer", clubDays=8 },
		baseCost    = 12,
		scalingStat = "Athletics",
		scaleType   = "stronger",
		defaultEdits= {},
	},

	["ChaseBreaker"] = {
		id          = "ChaseBreaker",
		name        = "Chase Breaker",
		category    = "Strike",
		source      = "SportsIdentity",
		description = "A running kick that punishes retreating opponents. Soccer players discover it instinctively.",
		unlockReq   = { club="Soccer", clubDays=15 },
		baseCost    = 16,
		scalingStat = "Power",
		scaleType   = "stronger",
		defaultEdits= { "Extended" },
	},

	-- ── GRAPPLER ROOT ───────────────────────────────────────────────────────

	["FullMount"] = {
		id          = "FullMount",
		name        = "Full Mount",
		category    = "Strike",
		source      = "MartialTraining",
		description = "A wrestling takedown that pins the opponent. Follow-up strikes deal increased damage.",
		unlockReq   = { club="Wrestling", clubDays=10 },
		baseCost    = 22,
		scalingStat = "Power",
		scaleType   = "stronger",
		defaultEdits= { "Breaking" },
	},

	-- ── DUELIST ROOT ────────────────────────────────────────────────────────

	["IaiCross"] = {
		id          = "IaiCross",
		name        = "Iai Cross",
		category    = "Counter",
		source      = "MartialTraining",
		description = "A Kendo draw-strike executed at the exact moment the opponent commits. Brutal if timed correctly.",
		unlockReq   = { club="Kendo", clubDays=15 },
		baseCost    = 15,
		scalingStat = "Technique",
		scaleType   = "stronger",
		defaultEdits= { "Piercing" },
	},

	["RiposteGrace"] = {
		id          = "RiposteGrace",
		name        = "Riposte Grace",
		category    = "Counter",
		source      = "MartialTraining",
		description = "A Chivalry-rooted parry into a lunging thrust. Makes the opponent feel like they did it to themselves.",
		unlockReq   = { club="Chivalry", clubDays=15 },
		baseCost    = 14,
		scalingStat = "Technique",
		scaleType   = "stronger",
		defaultEdits= { "Flashy" },
	},

	-- ── ACROBAT ROOT ────────────────────────────────────────────────────────

	["WallKick"] = {
		id          = "WallKick",
		name        = "Wall Kick",
		category    = "Launcher",
		source      = "SportsIdentity",
		description = "A parkour-rooted wall-jump into a descending kick. The city is the weapon.",
		unlockReq   = { club="Parkour", clubDays=12 },
		baseCost    = 20,
		scalingStat = "Athletics",
		scaleType   = "stronger",
		defaultEdits= {},
	},

	["RooflineEscape"] = {
		id          = "RooflineEscape",
		name        = "Roofline Escape",
		category    = "Movement",
		source      = "SportsIdentity",
		description = "A mid-combat vault that repositions the player above the opponent. Not an attack — the position is the threat.",
		unlockReq   = { club="Parkour", clubDays=20 },
		baseCost    = 14,
		scalingStat = "Athletics",
		scaleType   = "stronger",
		defaultEdits= { "Silent" },
	},

	-- ── PSYCHIC ROOT: FORCE ─────────────────────────────────────────────────

	["PressureWave"] = {
		id          = "PressureWave",
		name        = "Pressure Wave",
		category    = "Zone",
		source      = "Awakening",
		description = "An involuntary burst of psychic pressure. The player doesn't always mean to do it. The opponent doesn't care.",
		unlockReq   = { psychicType="Force", stranger=100 },
		baseCost    = 25,
		scalingStat = "Pressure",
		scaleType   = "stranger",
		defaultEdits= { "Breaking" },
	},

	["SuspendPoint"] = {
		id          = "SuspendPoint",
		name        = "Suspend Point",
		category    = "Trap",
		source      = "Awakening",
		description = "A localized force pocket that holds an object — or a person — briefly in place.",
		unlockReq   = { psychicType="Force", stranger=150 },
		baseCost    = 28,
		scalingStat = "Control",
		scaleType   = "stranger",
		defaultEdits= { "Prolonged" },
	},

	-- ── PSYCHIC ROOT: SIGNAL ────────────────────────────────────────────────

	["StaticBurst"] = {
		id          = "StaticBurst",
		name        = "Static Burst",
		category    = "Debuff",
		source      = "Awakening",
		description = "Floods the opponent's senses with psychic signal noise. Disrupts their attack timing for several seconds.",
		unlockReq   = { psychicType="Signal", stranger=100 },
		baseCost    = 20,
		scalingStat = "Resonance",
		scaleType   = "stranger",
		defaultEdits= { "Delayed" },
	},

	-- ── PSYCHIC ROOT: MEMORY ────────────────────────────────────────────────

	["EchoStrike"] = {
		id          = "EchoStrike",
		name        = "Echo Strike",
		category    = "Strike",
		source      = "Awakening",
		description = "A hit that reaches back into the opponent's recent pain. Deals more damage if they've been hit before in this fight.",
		unlockReq   = { psychicType="Memory", stranger=120 },
		baseCost    = 22,
		scalingStat = "Resonance",
		scaleType   = "stranger",
		defaultEdits= { "Marking" },
	},

	-- ── PSYCHIC ROOT: VOW ───────────────────────────────────────────────────

	["OathStrike"] = {
		id          = "OathStrike",
		name        = "Oath Strike",
		category    = "Finisher",
		source      = "Awakening",
		description = "Requires the player to have taken at least one hit this fight. The more they've endured, the harder it lands.",
		unlockReq   = { psychicType="Vow", stranger=150 },
		baseCost    = 35,
		scalingStat = "Control",
		scaleType   = "stranger",
		defaultEdits= { "Costly", "Piercing" },
	},

	-- ── PSYCHIC ROOT: BEAST ─────────────────────────────────────────────────

	["InstinctPounce"] = {
		id          = "InstinctPounce",
		name        = "Instinct Pounce",
		category    = "Dash",
		source      = "Awakening",
		description = "The body moves before the mind decides. Closes distance faster than telegraphing allows. Comes from Beastblooded or Beast psychic route.",
		unlockReq   = { psychicType="Beast", stranger=100 },
		baseCost    = 16,
		scalingStat = "Instinct",
		scaleType   = "stranger",
		defaultEdits= { "Silent" },
	},

	-- ── RUMOR SURVIVAL ARTS ─────────────────────────────────────────────────

	["SevenFloorDash"] = {
		id          = "SevenFloorDash",
		name        = "Seven Floor Dash",
		category    = "Movement",
		source      = "RumorSurvival",
		description = "Something about surviving the Seven Floors chain changed how you move through enclosed spaces. You don't freeze anymore.",
		unlockReq   = { rumor="R004", survived=true },
		baseCost    = 10,
		scalingStat = "Athletics",
		scaleType   = "stronger",
		defaultEdits= { "Silent" },
	},

	["DeepNightCounter"] = {
		id          = "DeepNightCounter",
		name        = "Deep Night Counter",
		category    = "Counter",
		source      = "RumorSurvival",
		description = "Surviving dangerous night encounters has tuned your reflexes to the specific rhythms of dark-city threats.",
		unlockReq   = { nightRumorsCleared=2 },
		baseCost    = 18,
		scalingStat = "Instinct",
		scaleType   = "stranger",
		defaultEdits= {},
	},

	-- ── BREAKTHROUGH ARTS (story events) ────────────────────────────────────

	["FirstBreak"] = {
		id          = "FirstBreak",
		name        = "First Break",
		category    = "Strike",
		source      = "MajorBreakthrough",
		description = "The first time something cracked open inside and let the pressure out. Everyone gets this differently. It always hits hard.",
		unlockReq   = { stronger=150 },
		baseCost    = 20,
		scalingStat = "Guts",
		scaleType   = "stronger",
		defaultEdits= { "Breaking" },
	},

	["StrangerMark"] = {
		id          = "StrangerMark",
		name        = "Stranger Mark",
		category    = "Debuff",
		source      = "SupernaturalExposure",
		description = "Something the hidden city left on you. You can push it onto others. It disrupts them in ways that are hard to explain.",
		unlockReq   = { stranger=200, conditions=1 },
		baseCost    = 24,
		scalingStat = "Distortion",
		scaleType   = "stranger",
		defaultEdits= { "Marking", "Delayed" },
	},
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Check unlock eligibility
-- ─────────────────────────────────────────────────────────────────────────────
function PressureArts.CanUnlock(artId, playerData)
	local art = PressureArts.ARTS[artId]
	if not art then return false, "Art not found." end
	if playerData:HasPressureArt(artId) then return false, "Already unlocked." end

	local req = art.unlockReq
	if not req then return true end

	-- Club + day requirement
	if req.club then
		local days = playerData:GetClubDays(req.club)
		if days < (req.clubDays or 1) then
			return false, ("Need %d days in %s (have %d)."):format(
				req.clubDays or 1, req.club, days)
		end
	end

	-- Stronger stat requirement
	if req.stronger then
		if playerData.stronger < req.stronger then
			return false, ("Need Stronger %d."):format(req.stronger)
		end
	end

	-- Stranger axis requirement
	if req.stranger then
		if playerData.stranger < req.stranger then
			return false, ("Need Stranger %d."):format(req.stranger)
		end
	end

	-- Psychic type requirement
	if req.psychicType then
		if playerData.psychicType ~= req.psychicType then
			return false, ("Requires psychic type: %s."):format(req.psychicType)
		end
	end

	-- Condition count requirement
	if req.conditions then
		if #playerData.strangeConditions < req.conditions then
			return false, ("Need %d condition(s)."):format(req.conditions)
		end
	end

	-- Rumor survival requirement
	if req.rumor then
		local state = playerData:GetRumorState(req.rumor)
		if req.survived and state ~= "Resolved" then
			return false, "Must survive a specific rumor first."
		end
	end

	-- Night rumors
	if req.nightRumorsCleared then
		if playerData.rumorsSurvived < req.nightRumorsCleared then
			return false, ("Need to survive %d rumors."):format(req.nightRumorsCleared)
		end
	end

	return true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Attempt unlock (server-side; also fires on milestone breakthroughs)
-- ─────────────────────────────────────────────────────────────────────────────
function PressureArts.TryUnlock(artId, playerData)
	local ok, reason = PressureArts.CanUnlock(artId, playerData)
	if not ok then return false, reason end
	playerData:UnlockPressureArt(artId)
	return true, PressureArts.ARTS[artId].name .. " unlocked."
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Compute art damage / effect magnitude (server-side resolve)
-- ─────────────────────────────────────────────────────────────────────────────
function PressureArts.Resolve(artId, playerData, equippedEdits)
	local art = PressureArts.ARTS[artId]
	if not art then return nil end
	if not playerData:HasPressureArt(artId) then return nil end

	-- Base power
	local basePower = 20
	local scalingStat

	if art.scaleType == "stronger" then
		scalingStat = playerData:GetStat(art.scalingStat)
		local mult  = 1 + (scalingStat / 60)
		basePower   = basePower * mult
	elseif art.scaleType == "stranger" then
		scalingStat = playerData:GetStrangerStat(art.scalingStat)
		local mult  = 1 + (scalingStat / 80)
		basePower   = basePower * mult
	elseif art.scaleType == "psych" then
		local mult  = 1 + (playerData.psych / 60)
		basePower   = basePower * mult
	end

	-- Apply default edits
	local allEdits = {}
	for _, e in ipairs(art.defaultEdits or {}) do allEdits[e] = true end
	for _, e in ipairs(equippedEdits   or {}) do allEdits[e] = true end

	-- Edit modifiers
	if allEdits["Costly"]    then basePower = basePower * 1.6 end
	if allEdits["Piercing"]  then basePower = basePower * 1.2 end
	if allEdits["Draining"]  then basePower = basePower * 0.85 end  -- trade power for regen

	local staminaCost = art.baseCost
	if allEdits["Efficient"] then staminaCost = math.floor(staminaCost * 0.7) end
	if allEdits["Costly"]    then staminaCost = math.ceil(staminaCost * 1.4)  end

	-- Boolean flags
	local breaks   = allEdits["Breaking"]  or false
	local marks    = allEdits["Marking"]   or false
	local flashy   = allEdits["Flashy"]    or false
	local silent   = allEdits["Silent"]    or false
	local seeking  = allEdits["Seeking"]   or false
	local repeated = allEdits["Repeated"]  or false

	return {
		artId       = artId,
		artName     = art.name,
		category    = art.category,
		power       = math.ceil(basePower),
		staminaCost = staminaCost,
		breaks      = breaks,
		marks       = marks,
		flashy      = flashy,
		silent      = silent,
		seeking     = seeking,
		repeated    = repeated,
		draining    = allEdits["Draining"] or false,
		brutal      = allEdits["Brutal"]   or false,
	}
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Auto-scan for newly unlockable arts after a stat / rumor / condition event
-- Returns list of artIds now eligible
-- ─────────────────────────────────────────────────────────────────────────────
function PressureArts.ScanForUnlocks(playerData)
	local eligible = {}
	for artId, _ in pairs(PressureArts.ARTS) do
		if not playerData:HasPressureArt(artId) then
			local ok = PressureArts.CanUnlock(artId, playerData)
			if ok then
				table.insert(eligible, artId)
			end
		end
	end
	return eligible
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Edit loadout management (up to 2 edits per art in prototype)
-- ─────────────────────────────────────────────────────────────────────────────
PressureArts.MAX_EDITS_PER_ART = 2

function PressureArts.ValidateEditLoadout(artId, editList)
	if #editList > PressureArts.MAX_EDITS_PER_ART then
		return false, ("Max %d edits per art."):format(PressureArts.MAX_EDITS_PER_ART)
	end
	-- Validate each edit id
	local validIds = {}
	for _, ed in ipairs(Constants.PRESSURE_ART_EDITS) do validIds[ed.id] = true end
	for _, eid in ipairs(editList) do
		if not validIds[eid] then
			return false, ("Unknown edit: %s"):format(eid)
		end
	end
	return true
end

return PressureArts
