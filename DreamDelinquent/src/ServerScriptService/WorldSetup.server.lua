-- Dream Delinquent: WorldSetup
-- Creates the prototype school district and city block using procedural geometry.
-- Replaces need for manual studio building during prototype phase.

local CollectionService = game:GetService("CollectionService")
local Lighting          = game:GetService("Lighting")

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────
local function part(parent, size, cframe, color, material, name, transparency)
	local p = Instance.new("Part")
	p.Name          = name or "Part"
	p.Size          = size
	p.CFrame        = cframe
	p.BrickColor    = BrickColor.new(color or "Medium stone grey")
	p.Material      = material or Enum.Material.SmoothPlastic
	p.Anchored      = true
	p.CanCollide    = true
	p.Transparency  = transparency or 0
	p.Parent        = parent
	return p
end

local function wedge(parent, size, cframe, color, name)
	local p = Instance.new("WedgePart")
	p.Name      = name or "Wedge"
	p.Size      = size
	p.CFrame    = cframe
	p.BrickColor= BrickColor.new(color or "Medium stone grey")
	p.Anchored  = true
	p.CanCollide= true
	p.Parent    = parent
	return p
end

local function label3D(parent, text, cframe, size)
	local sg = Instance.new("SurfaceGui")
	sg.Face  = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(400, 100)
	local lbl = Instance.new("TextLabel")
	lbl.Size          = UDim2.new(1,0,1,0)
	lbl.Text          = text
	lbl.TextColor3    = Color3.fromRGB(255,240,200)
	lbl.BackgroundTransparency = 1
	lbl.Font          = Enum.Font.GothamBold
	lbl.TextScaled    = true
	lbl.Parent        = sg
	local p = part(parent, size or Vector3.new(8,2,0.2),
		cframe, "Reddish brown", Enum.Material.SmoothPlastic, text)
	sg.Parent = p
	return p
end

local function tagPart(p, tags)
	for _, tag in ipairs(tags) do
		CollectionService:AddTag(p, tag)
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Workspace folder structure
-- ─────────────────────────────────────────────────────────────────────────────
local worldFolder = Instance.new("Folder")
worldFolder.Name  = "World"
worldFolder.Parent = workspace

local schoolFolder = Instance.new("Folder")
schoolFolder.Name  = "School"
schoolFolder.Parent = worldFolder

local cityFolder = Instance.new("Folder")
cityFolder.Name   = "City"
cityFolder.Parent = worldFolder

local npcFolder = Instance.new("Folder")
npcFolder.Name    = "NPCs"
npcFolder.Parent  = worldFolder

-- ─────────────────────────────────────────────────────────────────────────────
-- GROUND PLANE
-- ─────────────────────────────────────────────────────────────────────────────
local ground = part(worldFolder,
	Vector3.new(400,2,400),
	CFrame.new(0,-1,0),
	"Dark grey metallic",
	Enum.Material.Asphalt, "Ground")

-- ─────────────────────────────────────────────────────────────────────────────
-- SCHOOL BUILDING
-- Origin: (0,0,0), spreads toward positive Z
-- ─────────────────────────────────────────────────────────────────────────────

-- Main school block (3 floors)
local schoolMain = part(schoolFolder,
	Vector3.new(100, 36, 50),
	CFrame.new(0, 19, -30),
	"Light stone grey", Enum.Material.Concrete, "SchoolMain")

-- Windows (decorative strips)
for floor = 1, 3 do
	for col = -4, 4, 2 do
		part(schoolFolder,
			Vector3.new(4, 5, 0.5),
			CFrame.new(col * 10, 4 + (floor-1)*12, -5.1),
			"Bright blue", Enum.Material.Glass, "Window_"..floor.."_"..col,
			0.3)
	end
end

-- School entrance steps
for step = 1, 4 do
	part(schoolFolder,
		Vector3.new(16, step * 0.8, 2),
		CFrame.new(0, step * 0.4, -4 + step * 2),
		"Medium stone grey", Enum.Material.Concrete, "Step"..step)
end

-- School entrance sign
label3D(schoolFolder, "DREAM HIGH", CFrame.new(0, 26, -5.2), Vector3.new(20,4,0.3))

-- Front courtyard
part(schoolFolder,
	Vector3.new(80,1,40),
	CFrame.new(0, 0.5, 20),
	"Sand yellow", Enum.Material.Cobblestone, "Courtyard")

-- Basketball court markings (lines as thin parts)
local court = part(schoolFolder,
	Vector3.new(28, 0.3, 15),
	CFrame.new(40, 0.65, 20),
	"White", Enum.Material.SmoothPlastic, "BasketballCourt")
tagPart(court, {"SportZone","BasketballCourt"})

-- Hoops (simple cylinders + posts)
for _, side in ipairs({-10, 10}) do
	part(schoolFolder,
		Vector3.new(0.5, 8, 0.5),
		CFrame.new(40 + side, 4.5, 20),
		"Dark orange", Enum.Material.SmoothPlastic, "HoopPost"..side)
	part(schoolFolder,
		Vector3.new(4, 0.3, 4),
		CFrame.new(40 + side, 8.5, 20),
		"Dark orange", Enum.Material.Neon, "HoopRing"..side)
end

-- Soccer field
local soccerField = part(schoolFolder,
	Vector3.new(50, 0.3, 30),
	CFrame.new(-60, 0.65, 20),
	"Bright green", Enum.Material.Grass, "SoccerField")
tagPart(soccerField, {"SportZone","SoccerField"})

-- Soccer goals
for _, side in ipairs({-14, 14}) do
	for _, post in ipairs({-4, 4}) do
		part(schoolFolder,
			Vector3.new(0.5, 4, 0.5),
			CFrame.new(-60 + post, 2.5, 20 + side),
			"White", Enum.Material.SmoothPlastic, "GoalPost")
	end
end

-- School gym (annex)
local gym = part(schoolFolder,
	Vector3.new(30, 20, 28),
	CFrame.new(75, 11, -25),
	"Warm grey metallic", Enum.Material.Concrete, "Gym")
tagPart(gym, {"Building"})

label3D(schoolFolder, "GYM", CFrame.new(75, 18, -10.6), Vector3.new(8,3,0.3))

-- Club rooms (row of small rooms on east side)
local clubNames = {"Boxing","Kendo","Occult","Debate","Culinary"}
for i, club in ipairs(clubNames) do
	local clubRoom = part(schoolFolder,
		Vector3.new(14, 10, 12),
		CFrame.new(-70, 6, -20 + (i-1)*14),
		"Light bluish violet", Enum.Material.SmoothPlastic, "ClubRoom_"..club)
	tagPart(clubRoom, {"ClubRoom", "ClubRoom_"..club})
	label3D(schoolFolder, club, CFrame.new(-70, 8, -14 + (i-1)*14), Vector3.new(10,2.5,0.3))
end

-- Cafeteria
local cafeteria = part(schoolFolder,
	Vector3.new(40, 10, 20),
	CFrame.new(0, 6, -70),
	"Sand green", Enum.Material.Concrete, "Cafeteria")
tagPart(cafeteria, {"Building","Cafeteria","RumorZone"})
label3D(schoolFolder, "CAFETERIA", CFrame.new(0, 8, -59.6), Vector3.new(14,3,0.3))

-- Rooftop access (stairs at back of building)
local roofStairs = part(schoolFolder,
	Vector3.new(4, 20, 4),
	CFrame.new(48, 11, -55),
	"Medium stone grey", Enum.Material.Concrete, "RoofAccessStairs")

-- Rooftop
local rooftop = part(schoolFolder,
	Vector3.new(100, 2, 50),
	CFrame.new(0, 37, -30),
	"Dark grey metallic", Enum.Material.Concrete, "Rooftop")
tagPart(rooftop, {"Rooftop","WallRunSurface","VaultObject"})

-- Rooftop water tower
part(schoolFolder,
	Vector3.new(6,8,6),
	CFrame.new(40, 42, -30),
	"Brown", Enum.Material.Wood, "WaterTower")

-- Rooftop rumor trigger zone
local roofRumor = part(schoolFolder,
	Vector3.new(6,0.1,6),
	CFrame.new(40, 38.1, -10),
	"Bright violet", Enum.Material.Neon, "RoofRumorZone",
	0.7)
tagPart(roofRumor, {"RumorTrigger","R003"})  -- triggers SevenFloors chain

-- ─────────────────────────────────────────────────────────────────────────────
-- CITY BLOCK
-- East of school
-- ─────────────────────────────────────────────────────────────────────────────

-- Sidewalk strip
part(cityFolder,
	Vector3.new(4, 0.5, 200),
	CFrame.new(120, 0.25, 0),
	"Light grey", Enum.Material.Cobblestone, "Sidewalk")

-- Road
part(cityFolder,
	Vector3.new(20, 0.3, 200),
	CFrame.new(140, 0.15, 0),
	"Dark grey metallic", Enum.Material.Asphalt, "Road")

-- Streetlights
for z = -80, 80, 30 do
	local pole = part(cityFolder,
		Vector3.new(0.5, 10, 0.5),
		CFrame.new(120, 5.5, z),
		"Black", Enum.Material.Metal, "StreetPole"..z)
	local light = part(cityFolder,
		Vector3.new(3,0.5,1),
		CFrame.new(122, 10.5, z),
		"Cool yellow", Enum.Material.Neon, "StreetLight"..z)
	local pl = Instance.new("PointLight")
	pl.Brightness = 2; pl.Range = 20; pl.Color = Color3.fromRGB(255,240,160)
	pl.Parent = light
end

-- ARCADE building
local arcade = part(cityFolder,
	Vector3.new(24, 16, 20),
	CFrame.new(155, 9, -60),
	"Bright violet", Enum.Material.SmoothPlastic, "Arcade")
tagPart(arcade, {"Building","ArcadeBuilding","RumorZone"})

label3D(cityFolder, "ARCADE", CFrame.new(155, 14, -49.6), Vector3.new(14,3,0.3))

-- Arcade neon signs
local neon1 = part(cityFolder,
	Vector3.new(6,1,0.3),
	CFrame.new(152, 16, -49.7),
	"Hot pink", Enum.Material.Neon, "NeonSign1")
local pl1 = Instance.new("PointLight"); pl1.Range=8; pl1.Brightness=3
pl1.Color=Color3.fromRGB(255,60,200); pl1.Parent=neon1

local neon2 = part(cityFolder,
	Vector3.new(4,1,0.3),
	CFrame.new(158, 14, -49.7),
	"Bright yellow", Enum.Material.Neon, "NeonSign2")

-- CONVENIENCE STORE
local convStore = part(cityFolder,
	Vector3.new(16, 12, 16),
	CFrame.new(155, 7, -20),
	"Pastel yellow", Enum.Material.SmoothPlastic, "ConvStore")
tagPart(convStore, {"Building","Shop"})
label3D(cityFolder, "7-FORTY", CFrame.new(155, 10, -11.6), Vector3.new(10,2.5,0.3))

-- BACK ALLEY (rumor zone - Alley King)
local alley = part(cityFolder,
	Vector3.new(8, 0.3, 30),
	CFrame.new(165, 0.65, 30),
	"Dark grey metallic", Enum.Material.Concrete, "BackAlley")
tagPart(alley, {"RumorZone","RumorTrigger","R006","FightZone"})

-- Alley walls
part(cityFolder, Vector3.new(0.5,8,30), CFrame.new(169,5,30), "Medium stone grey", Enum.Material.Brick, "AlleyWall_R")
part(cityFolder, Vector3.new(0.5,8,30), CFrame.new(161,5,30), "Medium stone grey", Enum.Material.Brick, "AlleyWall_L")
tagPart(cityFolder:FindFirstChild("AlleyWall_R"), {"WallRunSurface"})
tagPart(cityFolder:FindFirstChild("AlleyWall_L"), {"WallRunSurface"})

-- Dumpsters (vault objects)
for z = 20, 40, 8 do
	local dump = part(cityFolder,
		Vector3.new(4,3,2.5),
		CFrame.new(163, 2, z),
		"Sand green", Enum.Material.Metal, "Dumpster"..z)
	tagPart(dump, {"VaultObject"})
end

-- APARTMENT BLOCK (adult route preview)
local apt = part(cityFolder,
	Vector3.new(28, 40, 20),
	CFrame.new(155, 21, 80),
	"Warm grey metallic", Enum.Material.Concrete, "ApartmentBlock")
tagPart(apt, {"Building","Housing"})
label3D(cityFolder, "CITY FLATS", CFrame.new(155, 32, 90.1), Vector3.new(12,3,0.3))

-- Apartment windows (many floors)
for floor = 1, 4 do
	for col = -2, 2 do
		part(cityFolder,
			Vector3.new(3, 4, 0.3),
			CFrame.new(155 + col*5.5, 6 + (floor-1)*10, 90.1),
			"Bright blue", Enum.Material.Glass, "AptWindow",
			0.4)
	end
end

-- ROOFTOP PARKOUR CHAIN (city side)
local roofs = {
	{ pos = Vector3.new(135, 16,  -55), size = Vector3.new(10, 2, 8)  },
	{ pos = Vector3.new(128, 12,  -38), size = Vector3.new(6,  2, 6)  },
	{ pos = Vector3.new(122, 18,  -20), size = Vector3.new(8,  2, 10) },
	{ pos = Vector3.new(115, 14,    5), size = Vector3.new(6,  2, 6)  },
}

for i, r in ipairs(roofs) do
	local roof = part(cityFolder, r.size,
		CFrame.new(r.pos),
		"Dark grey metallic", Enum.Material.Concrete, "CityRoof"..i)
	tagPart(roof, {"Rooftop","VaultObject","WallRunSurface"})
end

-- ─────────────────────────────────────────────────────────────────────────────
-- NPC SPAWN POINTS (tagged models; AI handled separately)
-- ─────────────────────────────────────────────────────────────────────────────
local function spawnPoint(name, pos, tags)
	local sp = Instance.new("Part")
	sp.Name          = name
	sp.Size          = Vector3.new(2,0.5,2)
	sp.CFrame        = CFrame.new(pos)
	sp.Transparency  = 1
	sp.Anchored      = true
	sp.CanCollide    = false
	sp.Parent        = npcFolder
	for _, t in ipairs(tags) do CollectionService:AddTag(sp, t) end
	return sp
end

spawnPoint("CafeteriaGossip1",    Vector3.new(0,2,-68),    {"NPC","RumorSource","cafeteria_npc_1"})
spawnPoint("CafeteriaGossip2",    Vector3.new(8,2,-68),    {"NPC","RumorSource","cafeteria_npc_2"})
spawnPoint("JournalismNPC",       Vector3.new(-70,2,-20),  {"NPC","RumorSource","journalism_club_npc"})
spawnPoint("OccultNPC",           Vector3.new(-70,2,-6),   {"NPC","RumorSource","occult_club_npc"})
spawnPoint("BasketballNPC",       Vector3.new(40,2,14),    {"NPC","RumorSource","basketball_court_npc"})
spawnPoint("DelinquentNPC",       Vector3.new(163,2,28),   {"NPC","RumorSource","delinquent_npc_1","FightNPC"})
spawnPoint("AlleyKingNPC",        Vector3.new(165,2,35),   {"NPC","BossNPC","AlleyKing"})

-- ─────────────────────────────────────────────────────────────────────────────
-- LIGHTING SETUP
-- ─────────────────────────────────────────────────────────────────────────────
Lighting.Ambient         = Color3.fromRGB(200,195,185)
Lighting.Brightness      = 2.0
Lighting.ColorShift_Top  = Color3.fromRGB(220,210,190)
Lighting.ColorShift_Bottom = Color3.fromRGB(140,130,120)
Lighting.OutdoorAmbient  = Color3.fromRGB(180,175,160)
Lighting.ShadowSoftness  = 0.5

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density    = 0.3
atmosphere.Offset     = 0.1
atmosphere.Color      = Color3.fromRGB(199,199,199)
atmosphere.Decay      = Color3.fromRGB(100,100,110)
atmosphere.Glare      = 0
atmosphere.Haze       = 0.2
atmosphere.Parent     = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Intensity    = 0.3
bloom.Size         = 24
bloom.Threshold    = 0.95
bloom.Parent       = Lighting

local colorCorrect = Instance.new("ColorCorrectionEffect")
colorCorrect.Contrast   = 0.1
colorCorrect.Saturation = -0.05
colorCorrect.TintColor  = Color3.fromRGB(245,240,230)
colorCorrect.Parent     = Lighting

print("[WorldSetup] Prototype world constructed.")
