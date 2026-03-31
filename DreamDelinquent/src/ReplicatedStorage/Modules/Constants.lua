-- Dream Delinquent: Constants
-- Central config for all game values.
-- Canon update: Stronger and Stranger are now two separate stat sheets.
-- Psych is the bridge between them.

local Constants = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- STRONGER STATS  (human growth: school, sports, clubs, combat, city life)
-- ─────────────────────────────────────────────────────────────────────────────
Constants.STRONGER_STATS = {
	"Athletics",  -- movement, stamina, speed, parkour fluidity, sports mobility
	"Power",      -- raw force, grapples, heavy hits, explosive impact
	"Technique",  -- precision, form, timing, ball control, clean combos
	"Guts",       -- pain tolerance, toughness, comeback energy, fear resistance
	"Charisma",   -- leadership, persuasion, crowd influence, social links
	"Insight",    -- tactical reading, awareness, pattern recognition, rumor interpretation
	"Style",      -- aura, fashion pressure, visual presence, expressive confidence
	"Tech",       -- gadgets, signal literacy, academic logic, digital aptitude
}

-- ─────────────────────────────────────────────────────────────────────────────
-- STRANGER STATS  (supernatural transformation: rumors, curses, bites, exposure)
-- These grow from supernatural encounters, not from ordinary life.
-- ─────────────────────────────────────────────────────────────────────────────
Constants.STRANGER_STATS = {
	"Pressure",    -- raw psychic force output; involuntary leakage of will
	"Control",     -- precision of psychic expression; discipline of strange ability
	"Resonance",   -- attunement to hidden-city signals, anomalies, and rumor patterns
	"Instinct",    -- feral supernatural awareness; reading threats before they manifest
	"Distortion",  -- reality-warping potential; how much the player bends what's around them
	"Mask",        -- ability to appear normal; social concealment of strangeness
	"Hunger",      -- pull of obsession, appetite, and supernatural desire
	"Threshold",   -- how far gone; proximity to manifestation; point of no return
}

-- ─────────────────────────────────────────────────────────────────────────────
-- PSYCH  (bridge stat)
-- The hinge between Stronger and Stranger.
-- Measures inner pressure, psychic potential, and how much the human self
-- can fuse with the strange without breaking.
-- Grows from both sides: emotional extremes, training under pressure, and
-- deep supernatural exposure.
-- ─────────────────────────────────────────────────────────────────────────────
Constants.PSYCH_MAX     = 100
Constants.PSYCH_DEFAULT = 5

-- Combined list used where a flat loop is needed (not for display splits)
Constants.ALL_STATS = {}
for _, s in ipairs(Constants.STRONGER_STATS) do table.insert(Constants.ALL_STATS, s) end
table.insert(Constants.ALL_STATS, "Psych")
for _, s in ipairs(Constants.STRANGER_STATS) do table.insert(Constants.ALL_STATS, s) end

Constants.STAT_MAX     = 100
Constants.STAT_DEFAULT = 5

-- ─────────────────────────────────────────────────────────────────────────────
-- STRONGER / STRANGER AXES  (the running totals shown on the main HUD)
-- ─────────────────────────────────────────────────────────────────────────────
Constants.STRONGER_MAX = 1000
Constants.STRANGER_MAX = 1000

Constants.STRONGER_MILESTONES = {
	{ threshold = 50,   label = "You feel a little stronger." },
	{ threshold = 150,  label = "You feel stronger." },
	{ threshold = 300,  label = "You feel much stronger." },
	{ threshold = 500,  label = "You feel powerful." },
	{ threshold = 750,  label = "You feel unstoppable." },
	{ threshold = 1000, label = "You feel like a force of nature." },
}

Constants.STRANGER_MILESTONES = {
	{ threshold = 50,   label = "Something feels off." },
	{ threshold = 150,  label = "You feel stranger." },
	{ threshold = 300,  label = "The city sees you differently." },
	{ threshold = 500,  label = "You feel deeply strange." },
	{ threshold = 750,  label = "You are no longer entirely yourself." },
	{ threshold = 1000, label = "You feel like something the city made." },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- CONDITIONS  (not stats — they modify how Stranger behaves)
-- ─────────────────────────────────────────────────────────────────────────────
Constants.STRANGE_CONDITIONS = {
	"Cursed",       -- rumor, object, phrase, or place has marked the player
	"Bitten",       -- vampiric infection; hunger mechanics, sensory enhancement
	"Branded",      -- demon-contract mark; power through conditions and bad choices
	"Taken",        -- alien contact; missing time, altered nerves, wrong memories
	"Haunted",      -- ghost or dead emotion has attached; protection and instability
	"Beastblooded", -- feral contamination; body and instincts leaning toward creature logic
	"Hollowed",     -- something was taken out; composure through emptiness
	"Resonant",     -- clean psychic path; becoming more psychically real without infection
	"Hybrid",       -- multiple conditions; harder to stabilize, stronger in some cases
}

-- Which Stranger stats each condition amplifies
Constants.CONDITION_MODIFIERS = {
	Cursed       = { Distortion = 1.3, Hunger = 1.2 },
	Bitten       = { Instinct = 1.4, Hunger = 1.5, Mask = 0.8 },
	Branded      = { Pressure = 1.3, Threshold = 1.2 },
	Taken        = { Resonance = 1.5, Distortion = 1.3 },
	Haunted      = { Resonance = 1.4, Instinct = 1.2 },
	Beastblooded = { Instinct = 1.5, Pressure = 1.2, Mask = 0.7 },
	Hollowed     = { Control = 1.4, Mask = 1.5, Hunger = 0.8 },
	Resonant     = { Control = 1.3, Resonance = 1.3, Threshold = 1.2 },
	Hybrid       = { Threshold = 1.6 },
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
	"Freshman","Sophomore","Junior","Senior","PostHighSchool","Adult"
}

Constants.GRADE_CREDIT_REQUIREMENT = {
	Freshman  = 40,
	Sophomore = 80,
	Junior    = 120,
	Senior    = 160,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- SCHEDULE
-- ─────────────────────────────────────────────────────────────────────────────
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
	{ id="Math",    name="Mathematics",        statGains={ Tech=3, Insight=2 } },
	{ id="Lit",     name="Literature",         statGains={ Insight=3 } },
	{ id="Gym",     name="Physical Education", statGains={ Athletics=3, Guts=2 } },
	{ id="Sci",     name="Science",            statGains={ Tech=2, Insight=2 } },
	{ id="Art",     name="Art",                statGains={ Style=3, Insight=1 } },
	{ id="History", name="History",            statGains={ Insight=2, Charisma=1 } },
	{ id="Music",   name="Music",              statGains={ Style=2, Charisma=2 } },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- CLUBS
-- statGains = Stronger stat gains per session
-- strangerGains = Stranger stat gains per session (only for unusual clubs)
-- ─────────────────────────────────────────────────────────────────────────────
Constants.CLUBS = {
	-- Sports
	{ id="Basketball", name="Basketball Team",
	  statGains={ Athletics=3, Technique=2, Insight=2, Charisma=1, Style=1 },
	  type="sport", description="Movement, spacing, rhythm, aerial confidence." },
	{ id="Soccer",     name="Soccer Team",
	  statGains={ Athletics=3, Technique=2, Guts=2, Power=2, Insight=1 },
	  type="sport", description="Burst movement, pursuit, lower-body pressure." },
	{ id="Baseball",   name="Baseball Team",
	  statGains={ Technique=3, Power=2, Insight=2, Guts=2 },
	  type="sport", description="Timing, stance, throws, patience." },
	{ id="Parkour",    name="Parkour Group",
	  statGains={ Athletics=3, Insight=2, Style=2, Guts=1 },
	  type="street", description="Traversal, rooftop access, escape routes." },
	-- Combat clubs
	{ id="Boxing",     name="Boxing Club",
	  statGains={ Power=3, Technique=2, Guts=2, Athletics=2 },
	  type="combat", description="Hands, counters, pressure fighting." },
	{ id="Wrestling",  name="Wrestling Club",
	  statGains={ Power=3, Guts=2, Athletics=2, Insight=2 },
	  type="combat", description="Grapples, slams, clinch control." },
	{ id="Kendo",      name="Kendo Club",
	  statGains={ Technique=3, Insight=3, Guts=2 },
	  type="combat", description="Disciplined katana-style combat, timing, focus." },
	{ id="Chivalry",   name="Chivalry Club",
	  statGains={ Technique=3, Charisma=2, Insight=2, Style=2 },
	  type="combat", description="Rapier and sword dueling. Elegant and maddening." },
	-- Intellectual & Social
	{ id="Culinary",    name="Culinary Club",
	  statGains={ Technique=2, Insight=2, Charisma=2 },
	  type="social", description="Food buffs, recovery, morale, gossip." },
	{ id="Tech",        name="Tech Club",
	  statGains={ Tech=3, Insight=2, Style=1 },
	  type="social", description="Gadgets, signal analysis, rumor tracing." },
	{ id="Debate",      name="Debate Club",
	  statGains={ Charisma=3, Insight=2, Guts=2 },
	  type="social", description="Persuasion, verbal pressure, social contests." },
	{ id="Journalism",  name="Journalism Club",
	  statGains={ Insight=3, Tech=2, Charisma=1 },
	  type="social", description="Rumor verification, witness gathering." },
	{ id="Occult",      name="Occult Club",
	  statGains={ Insight=2 },
	  strangerGains={ Resonance=3, Control=1 },
	  psychGain=2,
	  type="strange", description="Weird-city literacy. Bridges Stronger and Stranger." },
	{ id="Theater",     name="Theater Club",
	  statGains={ Charisma=3, Style=2, Insight=2 },
	  type="social", description="Performance confidence, expressive identity, mimicry." },
	{ id="Fashion",     name="Fashion Club",
	  statGains={ Style=3, Charisma=2 },
	  type="social", description="Aura, first impressions, social pressure." },
	{ id="Reading",     name="Reading Club",
	  statGains={ Insight=2, Tech=1 },
	  type="social", description="Reflection, academics, psychic resilience." },
	{ id="Music",       name="Music Club",
	  statGains={ Style=2, Charisma=2 },
	  type="social", description="Rhythm, social links, anomaly interactions." },
	{ id="Art",         name="Art Club",
	  statGains={ Style=3, Insight=2 },
	  type="social", description="Creativity, environmental noticing." },
	{ id="StudentCouncil", name="Student Council",
	  statGains={ Charisma=3, Insight=2, Technique=1 },
	  type="social", description="Discipline, leadership, school politics." },
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
	BLOCK_REDUCE      = 0.6,
	PARRY_WINDOW      = 0.25,
	COMBO_TIMEOUT     = 1.5,
}

-- Human fighting styles
Constants.FIGHTING_STYLES = {
	Striker   = { primaryStats={"Power","Technique"},    description="Fast, direct, personal." },
	Kicker    = { primaryStats={"Athletics","Technique"},description="Predatory angle pressure." },
	Grappler  = { primaryStats={"Power","Guts"},         description="Clinch control, throws." },
	Duelist   = { primaryStats={"Technique","Insight"},  description="Elegant, exact, spacing." },
	Brawler   = { primaryStats={"Guts","Power"},         description="Improvised, chaotic, alive." },
	Acrobat   = { primaryStats={"Athletics","Insight"},  description="City-assisted, evasive offense." },
	Captain   = { primaryStats={"Charisma","Guts"},      description="Leadership combat, morale pressure." },
	Trickster = { primaryStats={"Insight","Style"},      description="Baiting, fakeouts, playful viciousness." },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- PSYCHIC EXPRESSIONS  (how the player's will leaks into the world)
-- ─────────────────────────────────────────────────────────────────────────────
Constants.PSYCHIC_TYPES = {
	"Force","Signal","Memory","Vow","Hunger","Reflection","Rhythm","Beast",
	"Bloom","Decay","Gaze","Idol","Shade","Ember","Thread","Name",
}

-- Which Stranger stats feed each psychic type
Constants.PSYCHIC_STAT_AFFINITY = {
	Force      = { "Pressure","Control" },
	Signal     = { "Resonance","Distortion" },
	Memory     = { "Resonance","Instinct" },
	Vow        = { "Control","Threshold" },
	Hunger     = { "Hunger","Pressure" },
	Reflection = { "Mask","Distortion" },
	Rhythm     = { "Control","Instinct" },
	Beast      = { "Instinct","Hunger" },
	Bloom      = { "Resonance","Threshold" },
	Decay      = { "Distortion","Hunger" },
	Gaze       = { "Pressure","Mask" },
	Idol       = { "Mask","Resonance" },
	Shade      = { "Instinct","Mask" },
	Ember      = { "Pressure","Threshold" },
	Thread     = { "Resonance","Control" },
	Name       = { "Threshold","Distortion" },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- MANIFESTATIONS  (late-game, ~age 18, Persona-equivalent)
-- ─────────────────────────────────────────────────────────────────────────────
Constants.MANIFESTATIONS = {
	"Sovereign","Executioner","Trickster","Beast","Mourner","Idol",
	"Saint","Machine","HungerKing","Witness","MirrorLord","BloomQueen",
}

Constants.MANIFESTATION_UNLOCK_THRESHOLD = {
	stranger    = 600,   -- total Stranger axis
	psych       = 60,    -- Psych bridge stat
	threshold   = 50,    -- Threshold Stranger stat
	age         = 18,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- PRESSURE ARTS  (active techniques; NOT spells)
-- Shaped by route, club, sports identity, conditions, and training.
-- Move categories and the Edit modifier system.
-- ─────────────────────────────────────────────────────────────────────────────
Constants.PRESSURE_ART_CATEGORIES = {
	"Strike",     -- direct offense; damage
	"Dash",       -- repositioning; gap-close or escape
	"Counter",    -- reaction window; punish after block or parry
	"Zone",       -- area control; space denial
	"Launcher",   -- lifts opponent; opens air combos
	"Trap",       -- delayed effect; lingering hitbox
	"Buff",       -- self-enhancement; timed stat boost
	"Debuff",     -- opponent weakening; stat drain or stagger
	"Movement",   -- pure traversal; does not deal damage
	"TagMove",    -- party-synergy; requires ally nearby
	"Finisher",   -- high-cost, high-power ender; ends combos
}

-- Edit system: modifiers that customize how a Pressure Art behaves
Constants.PRESSURE_ART_EDITS = {
	-- Behavioral
	{ id="Extended",   description="Increases range or area." },
	{ id="Prolonged",  description="Lingers longer." },
	{ id="Delayed",    description="Triggers after a short pause." },
	{ id="Repeated",   description="Fires multiple times." },
	{ id="Silent",     description="No visible tell; surprises opponent." },
	{ id="Seeking",    description="Tracks or curves toward target." },
	-- Cost
	{ id="Efficient",  description="Reduces stamina cost." },
	{ id="Costly",     description="Higher cost; significantly increased power." },
	-- Effect
	{ id="Draining",   description="Restores stamina on hit." },
	{ id="Piercing",   description="Ignores a portion of block." },
	{ id="Breaking",   description="Inflicts stagger on hit." },
	{ id="Marking",    description="Tags target; subsequent arts do more to them." },
	-- Style
	{ id="Flashy",     description="Increases Style presence on hit." },
	{ id="Brutal",     description="Reduces opponent Guts on hit." },
}

-- Sources that unlock Pressure Arts
Constants.PRESSURE_ART_SOURCES = {
	"SportsIdentity",     -- unlocked through team/sport commitment
	"MartialTraining",    -- unlocked through club practice milestones
	"RumorSurvival",      -- unlocked by surviving specific rumor chains
	"SupernaturalExposure",-- unlocked by Stranger encounters
	"MajorBreakthrough",  -- unlocked by emotional/story threshold events
	"Awakening",          -- psychic route milestones
}

-- ─────────────────────────────────────────────────────────────────────────────
-- RUMOR STATES
-- ─────────────────────────────────────────────────────────────────────────────
Constants.RUMOR_STATES = {
	UNHEARD  = "Unheard",
	HEARD    = "Heard",
	ACTIVE   = "Active",
	RESOLVED = "Resolved",
	FAILED   = "Failed",
}

-- ─────────────────────────────────────────────────────────────────────────────
-- BACKGROUNDS  (character creation — not a path, just a starting lean)
-- ─────────────────────────────────────────────────────────────────────────────
Constants.BACKGROUNDS = {
	{ id="Athlete",     name="Athlete Family",   statBonus={ Athletics=3, Power=2 },
	  psychicBias="Beast",   description="You grew up in motion." },
	{ id="Orphan",      name="Orphan",           statBonus={ Guts=4 },
	  psychicBias="Shade",   description="You learned to read rooms before you learned to read." },
	{ id="Prodigy",     name="Prodigy",          statBonus={ Insight=3, Tech=2 },
	  psychicBias="Signal",  description="You were told you were special early. You stopped trusting that." },
	{ id="Transfer",    name="Transfer Student", statBonus={ Charisma=2, Guts=2 },
	  psychicBias="Memory",  description="You've started over before." },
	{ id="StreetKid",   name="Street Kid",       statBonus={ Guts=3, Power=2 },
	  psychicBias="Ember",   description="The city raised you." },
	{ id="Legacy",      name="Legacy Student",   statBonus={ Charisma=3, Style=2 },
	  psychicBias="Vow",     description="Someone in this school shares your last name." },
	{ id="Scholarship", name="Scholarship Case", statBonus={ Insight=2, Tech=2 },
	  psychicBias="Thread",  description="You earned this. You know what it cost." },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- SUPERNATURAL CATEGORIES
-- ─────────────────────────────────────────────────────────────────────────────
Constants.SUPERNATURAL_TYPES = {
	Demon    = { vibe="Temptation, names, bargains, obsession, conditions.",
	             strangerGains={ Hunger=3, Threshold=2, Distortion=1 } },
	Vampire  = { vibe="Urban, predatory, social, hungry, physically seductive.",
	             strangerGains={ Instinct=3, Hunger=2, Mask=2 } },
	Alien    = { vibe="Uncanny, signal-heavy, disruptive, wrong.",
	             strangerGains={ Resonance=4, Distortion=2 } },
	Ghost    = { vibe="Place-bound, emotional, memory-driven.",
	             strangerGains={ Resonance=3, Instinct=2 } },
	RoguePsychic = { vibe="Unstable, tragic, dangerous, institutionally hunted.",
	             strangerGains={ Pressure=3, Control=1, Threshold=2 } },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- JOBS  (adult route; samples only)
-- ─────────────────────────────────────────────────────────────────────────────
Constants.JOB_CATEGORIES = {
	"Investigative","Sports","Culinary","Tech","Emergency","Hospitality",
	"Underground","Agency","NEET","Supernatural",
}

-- ─────────────────────────────────────────────────────────────────────────────
-- UI COLORS / THEME
-- ─────────────────────────────────────────────────────────────────────────────
Constants.THEME = {
	BG_PRIMARY        = Color3.fromRGB(12, 12, 20),
	BG_SECONDARY      = Color3.fromRGB(20, 20, 35),
	BG_DARKER         = Color3.fromRGB(8,  8,  14),
	ACCENT_STRONGER   = Color3.fromRGB(255, 200, 50),   -- gold
	ACCENT_STRANGER   = Color3.fromRGB(160, 80,  255),  -- violet
	ACCENT_PSYCH      = Color3.fromRGB(80,  200, 200),  -- cyan bridge
	ACCENT_DANGER     = Color3.fromRGB(220, 50,  50),
	TEXT_PRIMARY      = Color3.fromRGB(240, 235, 220),
	TEXT_SECONDARY    = Color3.fromRGB(160, 155, 140),
	TEXT_HIGHLIGHT    = Color3.fromRGB(255, 230, 100),
	HEALTH_COLOR      = Color3.fromRGB(80,  200, 100),
	STAMINA_COLOR     = Color3.fromRGB(80,  160, 220),
	STAT_BAR_BG       = Color3.fromRGB(30,  30,  45),
	PANEL_BORDER      = Color3.fromRGB(60,  55,  80),
	-- Stronger stat bar gradient (warm)
	STRONGER_BAR      = Color3.fromRGB(240, 170, 40),
	-- Stranger stat bar gradient (cool violet)
	STRANGER_BAR      = Color3.fromRGB(130, 60,  220),
	-- Psych bridge bar
	PSYCH_BAR         = Color3.fromRGB(60,  200, 200),
}

Constants.FONT_TITLE = Enum.Font.GothamBold
Constants.FONT_BODY  = Enum.Font.Gotham
Constants.FONT_MONO  = Enum.Font.Code

-- ─────────────────────────────────────────────────────────────────────────────
-- PORTRAIT STATES
-- ─────────────────────────────────────────────────────────────────────────────
Constants.PORTRAIT_STATES = {
	NEUTRAL   = "Neutral",
	FOCUSED   = "Focused",
	SMIRK     = "Smirk",
	TENSE     = "Tense",
	BRUISED   = "Bruised",
	SWEATING  = "Sweating",
	AFRAID    = "Afraid",
	DISTORTED = "Distorted",  -- high Stranger axis
	GLOWING   = "Glowing",    -- near manifestation
}

-- ─────────────────────────────────────────────────────────────────────────────
-- PARKOUR
-- ─────────────────────────────────────────────────────────────────────────────
Constants.PARKOUR = {
	VAULT_SPEED_BONUS    = 1.4,
	WALL_RUN_DURATION    = 1.8,
	SLIDE_SPEED_BONUS    = 1.6,
	ROLL_FALL_THRESHOLD  = 20,
	STAMINA_VAULT_COST   = 8,
	STAMINA_WALLRUN_COST = 12,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- MUSIC VIBE NOTES  (for future audio system)
-- Stronger music: human, kinetic, cool, social, athletic, expressive.
-- Stranger music: uncanny, emotional, haunted, surreal, dangerous, beautiful.
-- Both share the same world — never fully separate.
-- ─────────────────────────────────────────────────────────────────────────────
Constants.MUSIC_ZONES = {
	School     = "StrongerTheme",
	Court      = "StrongerTheme",
	Alley      = "StrangerTheme",
	Night      = "StrangerTheme",
	Arcade     = "StrongerTheme",
	OldDistrict= "StrangerTheme",
	Rooftop    = "BridgeTheme",   -- both axes present
	Cafeteria  = "StrongerTheme",
}

return Constants
