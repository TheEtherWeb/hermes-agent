-- CodexController.client.lua
-- In-game Codex panel: Families tab and Factions tab.
-- Pure client — reads data directly from ReplicatedStorage/Data. No remotes needed.

local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Families = require(ReplicatedStorage.Data.Families)
local Factions = require(ReplicatedStorage.Data.Factions)
local Traits   = require(ReplicatedStorage.Data.Traits)

local CodexController = {}

local codexFrame
local isOpen = false

-- ── Build panel ───────────────────────────────────────────────────────────────

local function MakeButton(parent, text, pos, size, color)
	local btn = Instance.new("TextButton")
	btn.Size = size or UDim2.new(0, 120, 0, 36)
	btn.Position = pos
	btn.BackgroundColor3 = color or Color3.fromRGB(40, 40, 50)
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(220, 220, 220)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.BorderSizePixel = 0
	btn.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = btn
	return btn
end

local function MakeLabel(parent, text, pos, size, color, fontSize)
	local lbl = Instance.new("TextLabel")
	lbl.Size = size or UDim2.new(1, 0, 0, 20)
	lbl.Position = pos or UDim2.new(0, 0, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color or Color3.fromRGB(200, 200, 200)
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = fontSize or 13
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextWrapped = true
	lbl.Parent = parent
	return lbl
end

local function BuildCodex(gui)
	codexFrame = Instance.new("Frame")
	codexFrame.Name = "Codex_Frame"
	codexFrame.Size = UDim2.new(0, 700, 0, 520)
	codexFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	codexFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	codexFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
	codexFrame.BorderSizePixel = 0
	codexFrame.Visible = false
	codexFrame.ZIndex = 10
	codexFrame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = codexFrame

	-- Header
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 44)
	title.Position = UDim2.new(0, 16, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "CODEX"
	title.TextColor3 = Color3.fromRGB(200, 180, 100)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 26
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 11
	title.Parent = codexFrame

	local closeBtn = MakeButton(codexFrame, "✕", UDim2.new(1, -46, 0, 6), UDim2.new(0, 36, 0, 36), Color3.fromRGB(140, 30, 30))
	closeBtn.ZIndex = 11
	closeBtn.MouseButton1Click:Connect(function()
		CodexController.Close()
	end)

	-- Tab buttons
	local familiesTab = MakeButton(codexFrame, "FAMILIES", UDim2.new(0, 10, 0, 52), UDim2.new(0, 110, 0, 32))
	local factionsTab = MakeButton(codexFrame, "FACTIONS", UDim2.new(0, 130, 0, 52), UDim2.new(0, 110, 0, 32))
	familiesTab.ZIndex = 11
	factionsTab.ZIndex = 11

	-- Content area
	local contentArea = Instance.new("Frame")
	contentArea.Name = "Content"
	contentArea.Size = UDim2.new(1, -20, 1, -96)
	contentArea.Position = UDim2.new(0, 10, 0, 90)
	contentArea.BackgroundTransparency = 1
	contentArea.ZIndex = 11
	contentArea.Parent = codexFrame

	-- ── Families tab ─────────────────────────────────────────────────────────

	local familiesContent = Instance.new("Frame")
	familiesContent.Size = UDim2.new(1, 0, 1, 0)
	familiesContent.BackgroundTransparency = 1
	familiesContent.Visible = true
	familiesContent.ZIndex = 11
	familiesContent.Parent = contentArea

	-- Left: scrolling family list
	local listFrame = Instance.new("ScrollingFrame")
	listFrame.Size = UDim2.new(0, 200, 1, 0)
	listFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
	listFrame.BorderSizePixel = 0
	listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	listFrame.ScrollBarThickness = 4
	listFrame.ZIndex = 11
	listFrame.Parent = familiesContent

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = listFrame

	-- Right: detail panel
	local detailFrame = Instance.new("Frame")
	detailFrame.Size = UDim2.new(1, -210, 1, 0)
	detailFrame.Position = UDim2.new(0, 210, 0, 0)
	detailFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
	detailFrame.BorderSizePixel = 0
	detailFrame.ZIndex = 11
	detailFrame.Parent = familiesContent

	local detailName  = MakeLabel(detailFrame, "Select a family", UDim2.new(0, 10, 0, 8), UDim2.new(1, -20, 0, 28), Color3.fromRGB(255, 220, 100), 18)
	local detailRace  = MakeLabel(detailFrame, "", UDim2.new(0, 10, 0, 38), UDim2.new(1, -20, 0, 20), Color3.fromRGB(140, 200, 255), 13)
	local detailLore  = MakeLabel(detailFrame, "", UDim2.new(0, 10, 0, 62), UDim2.new(1, -20, 0, 100), Color3.fromRGB(180, 180, 180), 12)
	local detailTrait = MakeLabel(detailFrame, "", UDim2.new(0, 10, 0, 168), UDim2.new(1, -20, 0, 20), Color3.fromRGB(160, 255, 160), 12)
	local detailWeap  = MakeLabel(detailFrame, "", UDim2.new(0, 10, 0, 192), UDim2.new(1, -20, 0, 60), Color3.fromRGB(200, 200, 200), 12)
	detailName.ZIndex  = 12
	detailRace.ZIndex  = 12
	detailLore.ZIndex  = 12
	detailTrait.ZIndex = 12
	detailWeap.ZIndex  = 12

	local function ShowFamilyDetail(family)
		detailName.Text  = family.displayName
		detailRace.Text  = family.race .. (family.casteTier and ("  |  Caste " .. family.casteTier) or "")
		detailLore.Text  = family.lore or ""
		detailTrait.Text = "Default Trait: " .. (family.defaultTrait or "—")
		local weapons = {}
		for rankIdx, wid in pairs(family.weaponUnlocks or {}) do
			table.insert(weapons, "Rank " .. rankIdx .. ": " .. wid)
		end
		table.sort(weapons)
		detailWeap.Text = "Weapons:\n" .. table.concat(weapons, "\n")
	end

	-- Populate list
	local allFamilies = {}
	for id, fam in pairs(Families.Gem) do table.insert(allFamilies, fam) end
	for id, fam in pairs(Families.Ore) do table.insert(allFamilies, fam) end
	table.sort(allFamilies, function(a, b) return a.displayName < b.displayName end)

	for i, family in ipairs(allFamilies) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -4, 0, 30)
		btn.BackgroundColor3 = (family.race == "Gem") and Color3.fromRGB(30, 50, 80) or Color3.fromRGB(70, 40, 20)
		btn.Text = family.displayName
		btn.TextColor3 = Color3.fromRGB(210, 210, 210)
		btn.Font = Enum.Font.Gotham
		btn.TextSize = 13
		btn.BorderSizePixel = 0
		btn.LayoutOrder = i
		btn.ZIndex = 12
		btn.Parent = listFrame
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 4)
		bc.Parent = btn

		btn.MouseButton1Click:Connect(function()
			ShowFamilyDetail(family)
		end)
	end

	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		listFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 8)
	end)

	-- ── Factions tab ──────────────────────────────────────────────────────────

	local factionsContent = Instance.new("Frame")
	factionsContent.Size = UDim2.new(1, 0, 1, 0)
	factionsContent.BackgroundTransparency = 1
	factionsContent.Visible = false
	factionsContent.ZIndex = 11
	factionsContent.Parent = contentArea

	local facScroll = Instance.new("ScrollingFrame")
	facScroll.Size = UDim2.new(1, 0, 1, 0)
	facScroll.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
	facScroll.BorderSizePixel = 0
	facScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	facScroll.ScrollBarThickness = 4
	facScroll.ZIndex = 11
	facScroll.Parent = factionsContent

	local facLayout = Instance.new("UIListLayout")
	facLayout.SortOrder = Enum.SortOrder.LayoutOrder
	facLayout.Padding = UDim.new(0, 8)
	facLayout.Parent = facScroll

	local facPad = Instance.new("UIPadding")
	facPad.PaddingAll = UDim.new(0, 8)
	facPad.Parent = facScroll

	local factionList = {}
	for _, fac in pairs(Factions) do table.insert(factionList, fac) end
	table.sort(factionList, function(a, b) return a.race < b.race or (a.race == b.race and a.displayName < b.displayName) end)

	for i, fac in ipairs(factionList) do
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -16, 0, 90)
		card.BackgroundColor3 = (fac.race == "Gem") and Color3.fromRGB(25, 40, 70) or Color3.fromRGB(55, 30, 12)
		card.BorderSizePixel = 0
		card.LayoutOrder = i
		card.ZIndex = 12
		card.Parent = facScroll

		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(0, 6)
		cc.Parent = card

		MakeLabel(card, fac.displayName, UDim2.new(0, 8, 0, 6), UDim2.new(1, -16, 0, 22), Color3.fromRGB(255, 200, 80), 15).ZIndex = 13
		MakeLabel(card, fac.race, UDim2.new(0, 8, 0, 28), UDim2.new(0, 80, 0, 18), Color3.fromRGB(140, 180, 255), 11).ZIndex = 13
		MakeLabel(card, fac.lore or "", UDim2.new(0, 8, 0, 46), UDim2.new(1, -16, 0, 40), Color3.fromRGB(170, 170, 170), 11).ZIndex = 13
	end

	facLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		facScroll.CanvasSize = UDim2.new(0, 0, 0, facLayout.AbsoluteContentSize.Y + 16)
	end)

	-- ── Tab switching ─────────────────────────────────────────────────────────

	familiesTab.MouseButton1Click:Connect(function()
		familiesContent.Visible = true
		factionsContent.Visible = false
		familiesTab.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
		factionsTab.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	end)

	factionsTab.MouseButton1Click:Connect(function()
		familiesContent.Visible = false
		factionsContent.Visible = true
		factionsTab.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
		familiesTab.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	end)
end

-- ── Public API ────────────────────────────────────────────────────────────────

function CodexController.Toggle()
	if not codexFrame then
		BuildCodex(_G.ScreenGui)
	end
	if isOpen then
		CodexController.Close()
	else
		CodexController.Open()
	end
end

function CodexController.Open()
	if not codexFrame then
		BuildCodex(_G.ScreenGui)
	end
	isOpen = true
	codexFrame.Visible = true
	codexFrame.Size = UDim2.new(0, 680, 0, 500)
	TweenService:Create(codexFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 700, 0, 520),
	}):Play()
end

function CodexController.Close()
	if not codexFrame then return end
	isOpen = false
	TweenService:Create(codexFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 680, 0, 480),
	}):Play()
	task.delay(0.2, function()
		codexFrame.Visible = false
	end)
end

return CodexController
