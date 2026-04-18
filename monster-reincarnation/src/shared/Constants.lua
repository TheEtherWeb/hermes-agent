--!strict
-- Central constants. Change gameplay tuning here.

local Constants = {}

Constants.GAME_VERSION = "0.1.0"

-- Combat ---------------------------------------------------------------------
Constants.Combat = {
	BASE_STAMINA = 100,
	STAMINA_REGEN_PER_SEC = 15,
	POSTURE_MAX = 100,
	POSTURE_REGEN_PER_SEC = 8,
	POSTURE_BROKEN_STUN_SEC = 2.0,

	-- Stance tuning: [damageMul, postureMul, speedMul, staminaCostMul, canParry, canShield]
	Stances = {
		TwoHand   = { dmg = 1.25, posture = 1.6, speed = 0.85, stamina = 1.25, parry = false, shield = false },
		OneHand   = { dmg = 1.00, posture = 1.0, speed = 1.00, stamina = 1.00, parry = true,  shield = true  },
		DualWield = { dmg = 0.85, posture = 0.9, speed = 1.35, stamina = 1.40, parry = false, shield = false },
		SpellGrip = { dmg = 0.70, posture = 0.4, speed = 1.10, stamina = 0.75, parry = false, shield = false },
	},

	-- How many successful hits in a stance until the mastery rank ticks.
	HITS_PER_MASTERY_RANK = 50,
}

-- Progression ----------------------------------------------------------------
Constants.Progression = {
	MAX_STAT_POINTS_PER_LEVEL = 3,
	LEVEL_XP_CURVE = function(level: number): number
		return math.floor(100 * (level ^ 1.6))
	end,
	HIDDEN_STAT_THRESHOLDS = {
		AmbushesSurvived = { 5, 25, 100 },
		PoisonsConsumed  = { 10, 50, 250 },
		DarknessAdapted  = { 10, 60, 300 },
	},
}

-- Economy --------------------------------------------------------------------
Constants.Economy = {
	AUCTION_LISTING_FEE_PCT = 0.05,      -- 5% fee locked at listing time
	AUCTION_SALE_TAX_PCT   = 0.025,      -- 2.5% tax on sale, AO-inspired
	MAX_LISTINGS_PER_PLAYER = 12,
	MAX_LISTING_DURATION_SEC = 60 * 60 * 48, -- 48h
}

-- Guilds ---------------------------------------------------------------------
Constants.Guild = {
	MAX_MEMBERS = 50,
	GUILD_SCORE_RESET_INTERVAL_SEC = 60 * 60 * 24 * 30, -- monthly
	BASE_TOKEN_NAME = "Guild Chime",
}

-- Dynasty --------------------------------------------------------------------
Constants.Dynasty = {
	INHERITANCE_GOLD_PCT      = 0.5,
	INHERITANCE_STAT_PCT      = 0.15,
	HEIRLOOM_SLOTS            = 2,
	MAX_GENERATIONS_TRACKED   = 20,
}

-- Contracts ------------------------------------------------------------------
Constants.Contract = {
	MAX_ACTIVE_PER_PLAYER = 1,
	MIN_DURATION_SEC      = 60,
	MAX_DURATION_SEC      = 60 * 60 * 24, -- 24h
}

-- Anti-exploit ---------------------------------------------------------------
Constants.AntiExploit = {
	MAX_DAMAGE_PER_HIT       = 5000,
	MAX_ATTACKS_PER_SEC      = 8,
	MAX_STAT_GAIN_PER_SEC    = 5,
	MAX_INVENTORY_SIZE       = 400,
}

-- DataStore ------------------------------------------------------------------
Constants.DataStore = {
	PROFILE_STORE   = "ProfilePersistV1",
	DYNASTY_STORE   = "DynastyPersistV1",
	GUILD_STORE     = "GuildPersistV1",
	MARKET_STORE    = "MarketListingsV1",
	SAVE_COOLDOWN_SEC = 60,
	AUTOSAVE_INTERVAL_SEC = 180,
}

return Constants
