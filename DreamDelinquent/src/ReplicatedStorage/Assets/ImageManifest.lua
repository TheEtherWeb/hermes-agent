-- Dream Delinquent: Image Manifest
-- Central reference for all asset IDs used in the game.
-- Replace placeholder values with actual uploaded Roblox asset IDs.
-- All values tagged with [PLACEHOLDER] need real uploads via Roblox Studio.

local ImageManifest = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- UI ICONS
-- ─────────────────────────────────────────────────────────────────────────────
ImageManifest.Icons = {
	-- Stat icons (16x16 or 32x32 suggested)
	Athletics  = "rbxassetid://0",  -- [PLACEHOLDER] running figure icon
	Power      = "rbxassetid://0",  -- [PLACEHOLDER] fist icon
	Technique  = "rbxassetid://0",  -- [PLACEHOLDER] target/crosshair icon
	Psych      = "rbxassetid://0",  -- [PLACEHOLDER] eye/aura icon
	Charisma   = "rbxassetid://0",  -- [PLACEHOLDER] speech bubble icon
	Guts       = "rbxassetid://0",  -- [PLACEHOLDER] flame/heart icon
	Insight    = "rbxassetid://0",  -- [PLACEHOLDER] lightbulb icon
	Style      = "rbxassetid://0",  -- [PLACEHOLDER] star/diamond icon
	Tech       = "rbxassetid://0",  -- [PLACEHOLDER] gear icon

	-- Phase icons
	Morning    = "rbxassetid://0",  -- [PLACEHOLDER] sunrise
	Afternoon  = "rbxassetid://0",  -- [PLACEHOLDER] sun
	Night      = "rbxassetid://0",  -- [PLACEHOLDER] moon/stars
	School     = "rbxassetid://0",  -- [PLACEHOLDER] building
	City       = "rbxassetid://0",  -- [PLACEHOLDER] cityscape

	-- Rumor icons
	RumorNew   = "rbxassetid://0",  -- [PLACEHOLDER] speech bubble with !
	RumorActive= "rbxassetid://0",  -- [PLACEHOLDER] magnifying glass
	RumorDone  = "rbxassetid://0",  -- [PLACEHOLDER] checkmark
	RumorFail  = "rbxassetid://0",  -- [PLACEHOLDER] X mark

	-- Combat icons
	LightHit   = "rbxassetid://0",  -- [PLACEHOLDER] small impact
	HeavyHit   = "rbxassetid://0",  -- [PLACEHOLDER] large impact
	Grab       = "rbxassetid://0",  -- [PLACEHOLDER] hands grabbing
	Block      = "rbxassetid://0",  -- [PLACEHOLDER] shield
	Parry      = "rbxassetid://0",  -- [PLACEHOLDER] deflect arrow

	-- Club icons
	Basketball = "rbxassetid://0",
	Soccer     = "rbxassetid://0",
	Baseball   = "rbxassetid://0",
	Parkour    = "rbxassetid://0",
	Boxing     = "rbxassetid://0",
	Wrestling  = "rbxassetid://0",
	Kendo      = "rbxassetid://0",
	Chivalry   = "rbxassetid://0",
	Culinary   = "rbxassetid://0",
	Tech       = "rbxassetid://0",
	Debate     = "rbxassetid://0",
	Journalism = "rbxassetid://0",
	Occult     = "rbxassetid://0",
	Theater    = "rbxassetid://0",
	Fashion    = "rbxassetid://0",
	Reading    = "rbxassetid://0",
	Music      = "rbxassetid://0",
	Art        = "rbxassetid://0",
	StudentCouncil = "rbxassetid://0",
}

-- ─────────────────────────────────────────────────────────────────────────────
-- PORTRAIT STATES
-- Facial expression sprites for the portrait panel
-- Suggested: 120x160 PNGs, transparent background
-- ─────────────────────────────────────────────────────────────────────────────
ImageManifest.Portraits = {
	-- Base character faces per background (customize per player avatar later)
	Neutral    = "rbxassetid://0",  -- [PLACEHOLDER] neutral expression
	Focused    = "rbxassetid://0",  -- [PLACEHOLDER] determined look
	Smirk      = "rbxassetid://0",  -- [PLACEHOLDER] confident smirk
	Tense      = "rbxassetid://0",  -- [PLACEHOLDER] jaw clenched, alert
	Bruised    = "rbxassetid://0",  -- [PLACEHOLDER] eye bruised, tired
	Sweating   = "rbxassetid://0",  -- [PLACEHOLDER] sweat drops, effort
	Afraid     = "rbxassetid://0",  -- [PLACEHOLDER] eyes wide, pale
	Distorted  = "rbxassetid://0",  -- [PLACEHOLDER] glitchy/strange effect
	Glowing    = "rbxassetid://0",  -- [PLACEHOLDER] eyes glowing, aura visible
}

-- ─────────────────────────────────────────────────────────────────────────────
-- BACKGROUNDS (full screen / panel backgrounds)
-- ─────────────────────────────────────────────────────────────────────────────
ImageManifest.Backgrounds = {
	-- Character select screen
	CharSelectBG  = "rbxassetid://0",  -- [PLACEHOLDER] dark urban night cityscape
	-- School interior
	ClassroomBG   = "rbxassetid://0",  -- [PLACEHOLDER] classroom with chalkboard
	CafeteriaBG   = "rbxassetid://0",  -- [PLACEHOLDER] cafeteria interior
	GymBG         = "rbxassetid://0",  -- [PLACEHOLDER] gym floor
	-- City
	AlleyBG       = "rbxassetid://0",  -- [PLACEHOLDER] dark alley night
	ArcadeBG      = "rbxassetid://0",  -- [PLACEHOLDER] neon arcade interior
	-- Diploma
	ParchmentTexture = "rbxassetid://0",  -- [PLACEHOLDER] aged paper texture
}

-- ─────────────────────────────────────────────────────────────────────────────
-- SUPERNATURAL / RUMOR IMAGERY
-- ─────────────────────────────────────────────────────────────────────────────
ImageManifest.Supernatural = {
	GhostSilhouette   = "rbxassetid://0",  -- [PLACEHOLDER] ghost outline
	VampireMark       = "rbxassetid://0",  -- [PLACEHOLDER] bite mark symbol
	DemonBrand        = "rbxassetid://0",  -- [PLACEHOLDER] cursed sigil
	AlienSignal       = "rbxassetid://0",  -- [PLACEHOLDER] signal wave icon
	CurseSymbol       = "rbxassetid://0",  -- [PLACEHOLDER] ominous mark
	AgencyBadge       = "rbxassetid://0",  -- [PLACEHOLDER] clean official badge
	PsychicAura       = "rbxassetid://0",  -- [PLACEHOLDER] energy ripple
}

-- ─────────────────────────────────────────────────────────────────────────────
-- MINIGAME ASSETS
-- ─────────────────────────────────────────────────────────────────────────────
ImageManifest.Minigame = {
	-- Rhythm hit markers
	RhythmMarkerGood  = "rbxassetid://0",
	RhythmMarkerMiss  = "rbxassetid://0",
	-- Math/sequence
	NumberPadBG       = "rbxassetid://0",
	-- Timer
	TimerFill         = "rbxassetid://0",
}

-- ─────────────────────────────────────────────────────────────────────────────
-- NPC PORTRAITS
-- For dialogue boxes. Suggested: 80x80 PNGs
-- ─────────────────────────────────────────────────────────────────────────────
ImageManifest.NPCPortraits = {
	cafeteria_npc_1     = "rbxassetid://0",  -- [PLACEHOLDER] gossipy student
	cafeteria_npc_2     = "rbxassetid://0",  -- [PLACEHOLDER] pale nervous student
	journalism_club_npc = "rbxassetid://0",  -- [PLACEHOLDER] reporter type
	occult_club_npc     = "rbxassetid://0",  -- [PLACEHOLDER] mysterious club member
	basketball_court_npc= "rbxassetid://0",  -- [PLACEHOLDER] athlete
	delinquent_npc_1    = "rbxassetid://0",  -- [PLACEHOLDER] tough street type
}

-- ─────────────────────────────────────────────────────────────────────────────
-- SPECIAL EFFECT OVERLAYS
-- ─────────────────────────────────────────────────────────────────────────────
ImageManifest.Effects = {
	-- Stronger milestone flash
	StrongerFlash    = "rbxassetid://0",   -- golden burst
	-- Stranger milestone
	StrangerFlash    = "rbxassetid://0",   -- purple distortion
	-- Combat
	HitSpark         = "rbxassetid://0",   -- impact spark
	BlockSpark       = "rbxassetid://0",   -- block glint
	ParrySpark       = "rbxassetid://0",   -- parry ring
	-- Condition received
	BittenOverlay    = "rbxassetid://0",   -- blood-red vignette
	CursedOverlay    = "rbxassetid://0",   -- dark vignette with symbols
	HauntedOverlay   = "rbxassetid://0",   -- ghost flicker
}

-- ─────────────────────────────────────────────────────────────────────────────
-- How to add images in Roblox Studio:
-- 1. Open Studio -> Game Explorer -> Images -> Import (PNG, JPG, TGA, BMP)
-- 2. Copy the resulting asset ID (e.g. rbxassetid://12345678)
-- 3. Replace the "rbxassetid://0" placeholders above
-- 4. For decals/textures on 3D parts, use Decal or Texture instances
--    with the Texture property set to the asset ID
-- ─────────────────────────────────────────────────────────────────────────────

return ImageManifest
