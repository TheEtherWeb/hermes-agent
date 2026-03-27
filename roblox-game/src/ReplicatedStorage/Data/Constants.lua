-- Constants.lua
-- All numeric tuning values in one place. Edit here to adjust game feel.

return {
	-- ── Health & Guard ───────────────────────────────────────────────────────
	MAX_HEALTH            = 100,
	MAX_GUARD             = 100,
	GUARD_REGEN_RATE      = 8,    -- guard points restored per second (out of block)
	GUARD_REGEN_DELAY     = 1.5,  -- seconds after last hit before guard regen starts

	-- ── Heat ─────────────────────────────────────────────────────────────────
	MAX_HEAT              = 100,
	HEAT_DECAY_RATE       = 3,    -- heat lost per second when out of combat
	HEAT_COMBAT_PAUSE     = 4,    -- seconds of no combat before decay resumes
	HEAT_COLLAPSE_PENALTY = 5,    -- seconds in collapse state before revival

	-- Quicksilver overrides (applied in HeatUtils)
	QUICKSILVER_HEAT_GAIN_MULT = 2.0,

	-- ── Resonance (Gem Projection resource) ──────────────────────────────────
	MAX_RESONANCE         = 100,
	RESONANCE_REGEN_RATE  = 6,    -- resonance per second when weapon is dismissed
	RESONANCE_BASE_DRAIN  = 2,    -- resonance per second at weapon weight = 1

	-- ── Extraction (Ore weapon cost) ─────────────────────────────────────────
	EXTRACTION_HEALTH_COST   = 20,  -- health paid on weapon summon
	ORE_HEALTH_REGEN_RATE    = 1.5, -- health per second while weapon is active

	-- ── Combat Timing ────────────────────────────────────────────────────────
	LIGHT_ATTACK_COOLDOWN  = 0.45,
	HEAVY_ATTACK_COOLDOWN  = 1.1,
	GUARD_BREAK_STUN_TIME  = 1.8,
	DISARMED_DURATION      = 8,    -- seconds until weapon can be re-summoned after break

	-- Heat gain per action
	HEAT_GAIN_LIGHT       = 4,
	HEAT_GAIN_HEAVY       = 9,
	HEAT_GAIN_BLOCKED     = 2,   -- attacker gains heat even when blocked
	HEAT_GAIN_TAKE_HIT    = 5,
	HEAT_GAIN_EXTRACTION  = 10,  -- heat spike from pulling out a weapon

	-- ── Rank / XP ────────────────────────────────────────────────────────────
	XP_PER_KILL            = 50,
	XP_PER_BOSS_KILL       = 300,

	-- ── Proximity checks ─────────────────────────────────────────────────────
	MELEE_RANGE_DAGGER    = 8,
	MELEE_RANGE_SWORD     = 10,
	MELEE_RANGE_GREATSWORD = 12,
	MELEE_RANGE_SPEAR     = 16,

	-- ── Collapse revival state ───────────────────────────────────────────────
	COLLAPSE_REVIVAL_HEALTH = 0.5,  -- fraction of MaxHealth on revival
	COLLAPSE_REVIVAL_HEAT   = 30,   -- heat after revival
}
