-- Dream Delinquent: Constants
-- Central config for all game values

local Constants = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- STATS
-- ─────────────────────────────────────────────────────────────────────────────
Constants.STATS = {
	"Athletics",
	"Power",
	"Technique",
	"Psych",
	"Charisma",
	"Guts",
	"Insight",
	"Style",
	"Tech",
}

Constants.STAT_MAX = 100
Constants.STAT_DEFAULT = 5

-- ─────────────────────────────────────────────────────────────────────────────
-- STRONGER / STRANGER
-- ─────────────────────────────────────────────────────────────────────────────
Constants.STRONGER_MAX = 1000
Constants.STRANGER_MAX = 1000

-- Milestone breakpoints for display text
Constants.STRONGER_MILESTONES = {
	{ threshold = 50,  label = "You feel a little stronger." },
	{ threshold = 150, label = "You feel stronger." },
	{ threshold = 300, label = "You feel much stronger." },
	{ threshold = 500, label = "You feel powerful." },
	{ threshold = 750, label = "You feel unstoppable." },
	{ threshold = 1000, label = "You feel like a force of nature." },
}

Constants.STRANGER_MILESTONES = {
	{ threshold = 50,  label = "Something feels off." },
	{ threshold = 150, label = "You feel stranger." },
	{ threshold = 300, label = "The city sees you differently." },
	{ threshold = 500, label = "You feel deeply strange." },
	{ threshold = 750, label = "You are no longer entirely yourself." },
	{ threshold = 1000, label = "You feel like something the city made." },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- LIFE PHASES
-- ─────────────────────────────────────────────────────────────────────────────
Constants.PHASES = {
	FRESHMAN   = "Freshman",
	SOPHOMORE  = "Sophomore",
	JUNIOR     = "Junior",
	SENIOR     = "Senior",
	POST_HS    = "PostHighSchool",
	ADULT      = "Adult",
}

Constants.PHASE_ORDER = {
	"Freshman", "Sophomore", "Junior", "Senior", "PostHighSchool", "Adult"
}

-- Credits required to advance grades (academic + recovery paths)
Constants.GRADE_CREDIT_REQUIREMENT = {
	Freshman  = 40,
	Sophomore = 80,
	Junior    = 120,
	Senior    = 160,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- SCHEDULE
-- ─────────────────────────────────────────────────────────────────────────────
-- In-game time units (1 unit ≈ game tick)
Constants.DAY_PHASES = {
	MORNING     = "Morning",
	CLASS_1     = "Class1",
	CLASS_2     = "Class2",
	LUNCH       = "Lunch",
	CLASS_3     = "Class3",
	CLASS_4     = "Class4",
	AFTERSCHOOL = "AfterSchool",
	EVENING     = "Evening",
	NIGHT       = "Night",
	LATE_NIGHT  = "LateNight",
}

-- Duration of each phase in seconds (real time, adjust per feel)
Constants.PHASE_DURATION = {
	Morning     = 60,
	Class1      = 120,
	Class2      = 120,
	Lunch       = 90,
	Class3      = 120,
	Class4      = 120,
	AfterSchool = 180,
	Evening     = 180,
	Night       = 240,
	LateNight   = 120,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- CLASSES (SCHOOL)
-- ─────────────────────────────────────────────────────────────────────────────
Constants.CLASS_SUBJECTS = {
	{ id = "Math",   name = "Mathematics",      statGains = { Tech = 3, Insight = 2 } },
	{ id = "Lit",    name = "Literature",       statGains = { Insight = 3 } },
	{ id = "Gym",    name = "Physical Education", statGains = { Athletics = 3, Guts = 2 } },
	{ id = "Sci",    name = "Science",          statGains = { Tech = 2, Insight = 2 } },
	{ id = "Art",    name = "Art",              statGains = { Style = 3, Insight = 1 } },
	{ id = "History", name = "History",         statGains = { Insight = 2, Charisma = 1 } },
	{ id = "Music",  name = "Music",            statGains = { Style = 2, Charisma = 2 } },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- CLUBS
-- ─────────────────────────────────────────────────────────────────────────────
Constants.CLUBS = {
	-- Sports
	{ id = "Basketball", name = "Basketball Team",
	  statGains = { Athletics=3, Technique=2, Insight=2, Charisma=1, Style=1 },
	  type = "sport", description = "Movement, spacing, rhythm, aerial confidence." },

	{ id = "Soccer", name = "Soccer Team",
	  statGains = { Athletics=3, Technique=2, Guts=2, Power=2, Insight=1 },
	  type = "sport", description = "Burst movement, pursuit, lower-body pressure." },

	{ id = "Baseball", name = "Baseball Team",
	  statGains = { Technique=3, Power=2, Insight=2, Guts=2 },
	  type = "sport", description = "Timing, stance, throws, patience." },

	{ id = "Parkour", name = "Parkour Group",
	  statGains = { Athletics=3, Insight=2, Style=2, Guts=1 },
	  type = "street", description = "Traversal, rooftop access, escape routes." },

	-- Combat clubs
	{ id = "Boxing", name = "Boxing Club",
	  statGains = { Power=3, Technique=2, Guts=2, Athletics=2 },
	  type = "combat", description = "Hands, counters, pressure fighting." },

	{ id = "Wrestling", name = "Wrestling Club",
	  statGains = { Power=3, Guts=2, Athletics=2, Insight=2 },
	  type = "combat", description = "Grapples, slams, clinch control." },

	{ id = "Kendo", name = "Kendo Club",
	  statGains = { Technique=3, Insight=3, Guts=2 },
	  type = "combat", description = "Disciplined katana-style combat, timing, focus." },

	{ id = "Chivalry", name = "Chivalry Club",
	  statGains = { Technique=3, Charisma=2, Insight=2, Style=2 },
	  type = "combat", description = "Rapier and sword dueling. Elegant and maddening." },

	-- Intellectual & Social
	{ id = "Culinary", name = "Culinary Club",
	  statGains = { Technique=2, Insight=2, Charisma=2 },
	  type = "social", description = "Food buffs, recovery items, morale boosts, gossip." },

	{ id = "Tech", name = "Tech Club",
	  statGains = { Tech=3, Insight=2, Style=1 },
	  type = "social", description = "Gadgets, signal analysis, rumor tracing." },

	{ id = "Debate", name = "Debate Club",
	  statGains = { Charisma=3, Insight=2, Guts=2 },
	  type = "social", description = "Persuasion, verbal pressure, social contests." },

	{ id = "Journalism", name = "Journalism Club",
	  statGains = { Insight=3, Tech=2, Charisma=1 },
	  type = "social", description = "Rumor verification, witness gathering, investigation." },

	{ id = "Occult", name = "Occult Club",
	  statGains = { Insight=3, Psych=3 },
	  type = "strange", strangerGain = 5,
	  description = "Weird-city literacy. Bridges normal and Stranger progression." },

	{ id = "Theater", name = "Theater Club",
	  statGains = { Charisma=3, Style=2, Insight=2 },
	  type = "social", description = "Performance confidence, expressive identity, mimicry." },

	{ id = "Fashion", name = "Fashion Club",
	  statGains = { Style=3, Charisma=2 },
	  type = "social", description = "Aura, first impressions, social pressure." },

	{ id = "Reading", name = "Reading Club",
	  statGains = { Insight=2, Tech=1 },
	  type = "social", description = "Reflection, academics, psychic resilience." },

	{ id = "Music", name = "Music Club",
	  statGains = { Style=2, Charisma=2 },
	  type = "social", description = "Rhythm, social links, anomaly interactions." },

	{ id = "Art", name = "Art Club",
	  statGains = { Style=3, Insight=2 },
	  type = "social", description = "Creativity, environmental noticing." },

	{ id = "StudentCouncil", name = "Student Council",
	  statGains = { Charisma=3, Insight=2, Technique=1 },
	  type = "social", description = "Discipline, leadership, school politics, clean-route access." },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- COMBAT
-- ─────────────────────────────────────────────────────────────────────────────
Constants.COMBAT = {
	BASE_HEALTH       = 100,
	HEALTH_PER_GUTS   = 2,
	BASE_STAMINA      = 100,
	STAMINA_PER_ATH   = 1.5,
	LIGHT_HIT_DAMAGE  = 8,
	HEAVY_HIT_DAMAGE  = 18,
	GRAB_DAMAGE       = 12,
	BLOCK_REDUCE      = 0.6,    -- 60% damage reduction
	PARRY_WINDOW      = 0.25,   -- seconds
	COMBO_TIMEOUT     = 1.5,    -- seconds between combo inputs
}

-- Human fighting styles
Constants.FIGHTING_STYLES = {
	Striker  = { primaryStats = {"Power","Technique"},    description = "Fast, direct, personal." },
	Kicker   = { primaryStats = {"Athletics","Technique"},description = "Predatory angle pressure." },
	Grappler = { primaryStats = {"Power","Guts"},         description = "Clinch control, throws." },
	Duelist  = { primaryStats = {"Technique","Insight"},  description = "Elegant, exact, spacing." },
	Brawler  = { primaryStats = {"Guts","Power"},         description = "Improvised, chaotic, alive." },
	Acrobat  = { primaryStats = {"Athletics","Insight"},  description = "City-assisted, evasive offense." },
	Captain  = { primaryStats = {"Charisma","Guts"},      description = "Leadership combat, morale pressure." },
	Trickster= { primaryStats = {"Insight","Style"},      description = "Baiting, fakeouts, playful viciousness." },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- PSYCHIC EXPRESSIONS
-- ─────────────────────────────────────────────────────────────────────────────
Constants.PSYCHIC_TYPES = {
	"Force","Signal","Memory","Vow","Hunger","Reflection","Rhythm","Beast",
	"Bloom","Decay","Gaze","Idol","Shade","Ember","Thread","Name",
}

-- ─────────────────────────────────────────────────────────────────────────────
-- STRANGE CONDITIONS
-- ─────────────────────────────────────────────────────────────────────────────
Constants.STRANGE_CONDITIONS = {
	"Cursed","Bitten","Branded","Taken","Haunted","Beastblooded","Hollowed","Resonant","Hybrid",
}

-- ─────────────────────────────────────────────────────────────────────────────
-- MANIFESTATIONS (Persona-equiv)
-- ─────────────────────────────────────────────────────────────────────────────
Constants.MANIFESTATIONS = {
	"Sovereign","Executioner","Trickster","Beast","Mourner","Idol",
	"Saint","Machine","HungerKing","Witness","MirrorLord","BloomQueen",
}

Constants.MANIFESTATION_UNLOCK_THRESHOLD = {
	stranger = 600,
	psych    = 60,
	age      = 18,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- RUMORS
-- ─────────────────────────────────────────────────────────────────────────────
Constants.RUMOR_STATES = {
	UNHEARD   = "Unheard",
	HEARD     = "Heard",
	ACTIVE    = "Active",
	RESOLVED  = "Resolved",
	FAILED    = "Failed",
}

-- ─────────────────────────────────────────────────────────────────────────────
-- BACKGROUNDS (Character creation)
-- ─────────────────────────────────────────────────────────────────────────────
Constants.BACKGROUNDS = {
	{ id = "Athlete",    name = "Athlete Family",    statBonus = { Athletics=3, Power=2 },    psychicBias = "Beast" },
	{ id = "Orphan",     name = "Orphan",            statBonus = { Guts=4 },                  psychicBias = "Shade" },
	{ id = "Prodigy",    name = "Prodigy",           statBonus = { Insight=3, Tech=2 },        psychicBias = "Signal" },
	{ id = "Transfer",   name = "Transfer Student",  statBonus = { Charisma=2, Guts=2 },       psychicBias = "Memory" },
	{ id = "StreetKid",  name = "Street Kid",        statBonus = { Guts=3, Power=2 },          psychicBias = "Ember" },
	{ id = "Legacy",     name = "Legacy Student",    statBonus = { Charisma=3, Style=2 },      psychicBias = "Vow" },
	{ id = "Scholarship",name = "Scholarship Case",  statBonus = { Insight=2, Tech=2 },        psychicBias = "Thread" },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- UI COLORS / THEME
-- ─────────────────────────────────────────────────────────────────────────────
Constants.THEME = {
	BG_PRIMARY        = Color3.fromRGB(12, 12, 20),
	BG_SECONDARY      = Color3.fromRGB(20, 20, 35),
	ACCENT_STRONGER   = Color3.fromRGB(255, 200, 50),
	ACCENT_STRANGER   = Color3.fromRGB(160, 80, 255),
	ACCENT_DANGER     = Color3.fromRGB(220, 50, 50),
	TEXT_PRIMARY      = Color3.fromRGB(240, 235, 220),
	TEXT_SECONDARY    = Color3.fromRGB(160, 155, 140),
	TEXT_HIGHLIGHT    = Color3.fromRGB(255, 230, 100),
	HEALTH_COLOR      = Color3.fromRGB(80, 200, 100),
	STAMINA_COLOR     = Color3.fromRGB(80, 160, 220),
	STAT_BAR_BG       = Color3.fromRGB(30, 30, 45),
	PANEL_BORDER      = Color3.fromRGB(60, 55, 80),
}

-- Font tokens
Constants.FONT_TITLE    = Enum.Font.GothamBold
Constants.FONT_BODY     = Enum.Font.Gotham
Constants.FONT_MONO     = Enum.Font.Code

-- ─────────────────────────────────────────────────────────────────────────────
-- PORTRAIT STATES
-- ─────────────────────────────────────────────────────────────────────────────
Constants.PORTRAIT_STATES = {
	NEUTRAL    = "Neutral",
	FOCUSED    = "Focused",
	SMIRK      = "Smirk",
	TENSE      = "Tense",
	BRUISED    = "Bruised",
	SWEATING   = "Sweating",
	AFRAID     = "Afraid",
	DISTORTED  = "Distorted",  -- high Stranger
	GLOWING    = "Glowing",    -- near manifestation
}

-- ─────────────────────────────────────────────────────────────────────────────
-- PARKOUR
-- ─────────────────────────────────────────────────────────────────────────────
Constants.PARKOUR = {
	VAULT_SPEED_BONUS   = 1.4,
	WALL_RUN_DURATION   = 1.8,
	SLIDE_SPEED_BONUS   = 1.6,
	ROLL_FALL_THRESHOLD = 20,    -- studs
	STAMINA_VAULT_COST  = 8,
	STAMINA_WALLRUN_COST= 12,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- JOBS (sample list for adult phase)
-- ─────────────────────────────────────────────────────────────────────────────
Constants.JOB_CATEGORIES = {
	"Investigative","Sports","Culinary","Tech","Emergency","Hospitality",
	"Underground","Agency","NEET","Supernatural",
}

return Constants
