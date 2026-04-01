-- AugMenu.lua (LocalScript inside AugMenu ScreenGui)
-- The augmentation browsing and equipping interface.
-- Tabs: Arms | Legs | Spine | Head | Internals
-- Shows aug catalog, owned status, IL cost preview, stat delta preview,
-- purchase and equip buttons.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local player  = Players.LocalPlayer
local gui     = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
local Modules = ReplicatedStorage:WaitForChild("Modules")

local NetworkEvents    = require(Modules:WaitForChild("NetworkEvents"))
local GameData         = require(Modules:WaitForChild("GameData"))
local IdentityLoad     = require(Modules:WaitForChild("IdentityLoad"))
local AugmentationData = require(Modules:WaitForChild("AugmentationData"))

-- ── Layout References ─────────────────────────────────────────────────────────
local Panel          = gui:WaitForChild("Panel")
local CloseButton    = Panel:WaitForChild("CloseButton")
local TabContainer   = Panel:WaitForChild("TabContainer")
local AugList        = Panel:WaitForChild("AugList")    -- ScrollingFrame
local DetailPanel    = Panel:WaitForChild("DetailPanel")
local DetailTitle    = DetailPanel:WaitForChild("Title")
local DetailOrigin   = DetailPanel:WaitForChild("Origin")
local DetailTier     = DetailPanel:WaitForChild("Tier")
local DetailIL       = DetailPanel:WaitForChild("ILCost")
local DetailDesc     = DetailPanel:WaitForChild("Description")
local DetailStats    = DetailPanel:WaitForChild("Stats")
local PurchaseButton = DetailPanel:WaitForChild("PurchaseButton")
local EquipButton    = DetailPanel:WaitForChild("EquipButton")
local UnequipButton  = DetailPanel:WaitForChild("UnequipButton")
local CurrentAugsPanel = Panel:WaitForChild("CurrentAugs")
local ILPreviewLabel   = Panel:WaitForChild("ILPreview")
local CreditsLabel     = Panel:WaitForChild("CreditsLabel")

-- ── State ─────────────────────────────────────────────────────────────────────
local State = {
    ActiveTab       = "Arms",
    SelectedAug     = nil,    -- aug data table from catalog
    PlayerData      = nil,    -- cached from server
    CatalogBySlot   = {},
}

local SLOTS = { "Arms", "Legs", "Spine", "Head", "Internals" }
local ORIGIN_COLORS = {
    Corporate = Color3.fromRGB(100, 160, 220),
    Military  = Color3.fromRGB(200, 80, 60),
    Salvage   = Color3.fromRGB(200, 150, 50),
    Religious = Color3.fromRGB(180, 100, 220),
    Android   = Color3.fromRGB(80, 200, 180),
}

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function GetPlayerData()
    local clientMain = _G.ClientMain
    return clientMain and clientMain.State.PlayerData
end

local function GetCurrentIL()
    local data = GetPlayerData()
    if not data then return 0 end
    return data.IdentityLoad or 0
end

-- ── Load Catalog ──────────────────────────────────────────────────────────────
local function LoadCatalog(slot)
    -- Invoke server for enriched catalog (owned/equipped flags)
    local catalog = Remotes:WaitForChild(NetworkEvents.RF.GetAugCatalog):InvokeServer(slot)
    State.CatalogBySlot[slot] = catalog or {}
    return State.CatalogBySlot[slot]
end

-- ── Build Tab ─────────────────────────────────────────────────────────────────
local function BuildTabs()
    for _, child in ipairs(TabContainer:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    for i, slot in ipairs(SLOTS) do
        local btn = Instance.new("TextButton")
        btn.Name             = slot
        btn.Size             = UDim2.new(0.18, -4, 1, 0)
        btn.Position         = UDim2.new((i-1) * 0.20, 2, 0, 0)
        btn.BackgroundColor3 = (slot == State.ActiveTab)
            and Color3.fromRGB(40, 50, 70)
            or  Color3.fromRGB(25, 28, 38)
        btn.BorderSizePixel  = 1
        btn.BorderColor3     = Color3.fromRGB(60, 70, 90)
        btn.Text             = slot:upper()
        btn.TextColor3       = (slot == State.ActiveTab)
            and Color3.fromRGB(180, 210, 255)
            or  Color3.fromRGB(120, 130, 150)
        btn.Font             = Enum.Font.GothamBold
        btn.TextSize         = 13
        btn.AutoButtonColor  = false
        btn.Parent           = TabContainer

        btn.Activated:Connect(function()
            State.ActiveTab = slot
            BuildTabs()
            PopulateAugList(slot)
        end)
    end
end

-- ── Populate Aug List ─────────────────────────────────────────────────────────
local function PopulateAugList(slot)
    -- Clear existing
    for _, child in ipairs(AugList:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") then child:Destroy() end
    end

    local catalog = State.CatalogBySlot[slot]
    if not catalog then
        -- Load from server
        task.spawn(function()
            catalog = LoadCatalog(slot)
            PopulateAugList(slot)
        end)
        return
    end

    local yOffset = 0
    for _, aug in ipairs(catalog) do
        local row = Instance.new("TextButton")
        row.Name             = aug.Id
        row.Size             = UDim2.new(1, -8, 0, 52)
        row.Position         = UDim2.new(0, 4, 0, yOffset)
        row.BackgroundColor3 = aug.Equipped and Color3.fromRGB(30, 45, 55)
            or aug.Owned and Color3.fromRGB(25, 30, 40)
            or Color3.fromRGB(18, 20, 28)
        row.BorderColor3     = aug.Equipped and Color3.fromRGB(80, 180, 120)
            or Color3.fromRGB(40, 45, 60)
        row.BorderSizePixel  = 1
        row.AutoButtonColor  = false
        row.Text             = ""
        row.Parent           = AugList

        -- Name label
        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size      = UDim2.new(1, -70, 0, 22)
        nameLbl.Position  = UDim2.new(0, 8, 0, 4)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text      = aug.DisplayName
        nameLbl.TextColor3= aug.Equipped and Color3.fromRGB(120, 220, 150)
            or aug.Owned and Color3.fromRGB(200, 200, 220)
            or Color3.fromRGB(140, 145, 160)
        nameLbl.Font      = Enum.Font.GothamBold
        nameLbl.TextSize  = 13
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Parent    = row

        -- Origin tag
        local originLbl = Instance.new("TextLabel")
        originLbl.Size      = UDim2.new(0, 70, 0, 18)
        originLbl.Position  = UDim2.new(1, -75, 0, 4)
        originLbl.BackgroundTransparency = 1
        originLbl.Text      = aug.Origin:upper()
        originLbl.TextColor3= ORIGIN_COLORS[aug.Origin] or Color3.fromRGB(160, 160, 180)
        originLbl.Font      = Enum.Font.Gotham
        originLbl.TextSize  = 11
        originLbl.TextXAlignment = Enum.TextXAlignment.Right
        originLbl.Parent    = row

        -- Tier + IL cost
        local subLbl = Instance.new("TextLabel")
        subLbl.Size     = UDim2.new(1, -8, 0, 18)
        subLbl.Position = UDim2.new(0, 8, 0, 28)
        subLbl.BackgroundTransparency = 1
        subLbl.Text     = "T" .. aug.Tier .. "  ·  IL +" .. aug.ILBase .. "  ·  $" .. (aug.CreditCost or "?")
        subLbl.TextColor3 = Color3.fromRGB(100, 110, 130)
        subLbl.Font     = Enum.Font.Gotham
        subLbl.TextSize = 11
        subLbl.TextXAlignment = Enum.TextXAlignment.Left
        subLbl.Parent   = row

        -- Status badge
        if aug.Equipped then
            local badge = Instance.new("TextLabel")
            badge.Size      = UDim2.new(0, 60, 0, 16)
            badge.Position  = UDim2.new(0, 8, 0, 28)
            badge.BackgroundTransparency = 1
            badge.Text      = "EQUIPPED"
            badge.TextColor3= Color3.fromRGB(100, 220, 140)
            badge.Font      = Enum.Font.GothamBold
            badge.TextSize  = 11
            badge.Parent    = row
            subLbl.Visible  = false
        end

        row.Activated:Connect(function()
            State.SelectedAug = aug
            ShowDetail(aug)
        end)

        yOffset = yOffset + 56
    end

    AugList.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

-- ── Show Detail ───────────────────────────────────────────────────────────────
function ShowDetail(aug)
    DetailTitle.Text       = aug.DisplayName
    DetailOrigin.Text      = aug.Origin:upper()
    DetailOrigin.TextColor3= ORIGIN_COLORS[aug.Origin] or Color3.new(1, 1, 1)
    DetailTier.Text        = "Mark " .. ({ "I","II","III","IV","Apex" })[aug.Tier] or aug.Tier

    -- IL preview
    local currentIL = GetCurrentIL()
    local data      = GetPlayerData()
    local ilMult    = data and GameData.AugOriginILMult[aug.Origin] or 1.0
    local ilCost    = math.floor(aug.ILBase * ilMult)
    local projectedIL = currentIL + ilCost
    local thresh    = IdentityLoad.GetThreshold(projectedIL)

    DetailIL.Text = "IL COST: +" .. ilCost .. "  →  " .. projectedIL .. " (" .. thresh.label .. ")"
    DetailIL.TextColor3 = Color3.fromHex(thresh.colorHex)

    DetailDesc.Text = aug.Description or ""

    -- Stats text
    local statsText = ""
    for statName, val in pairs(aug.Stats or {}) do
        if type(val) == "number" then
            statsText = statsText .. statName .. ": " .. (val > 0 and "+" or "") .. val .. "\n"
        elseif type(val) == "boolean" and val then
            statsText = statsText .. "[ " .. statName .. " ]\n"
        end
    end
    DetailStats.Text = statsText ~= "" and statsText or "No numeric stats."

    -- Button states
    local owned    = aug.Owned
    local equipped = aug.Equipped

    PurchaseButton.Visible = not owned
    EquipButton.Visible    = owned and not equipped
    UnequipButton.Visible  = equipped

    if not owned then
        local credits = aug.CreditCost or 0
        local scrap   = aug.ScrapCost  or 0
        PurchaseButton.Text = "PURCHASE  $" .. credits .. (scrap > 0 and "  +" .. scrap .. " SCR" or "")
    end

    DetailPanel.Visible = true
end

-- ── Purchase ──────────────────────────────────────────────────────────────────
PurchaseButton.Activated:Connect(function()
    if not State.SelectedAug then return end
    Remotes:WaitForChild(NetworkEvents.C2S.RequestPurchaseAug):FireServer(State.SelectedAug.Id)

    -- Refresh catalog after brief delay
    task.wait(0.5)
    State.CatalogBySlot[State.ActiveTab] = nil
    PopulateAugList(State.ActiveTab)
end)

-- ── Equip ─────────────────────────────────────────────────────────────────────
EquipButton.Activated:Connect(function()
    if not State.SelectedAug then return end
    Remotes:WaitForChild(NetworkEvents.C2S.RequestEquipAug):FireServer(
        State.SelectedAug.Slot,
        State.SelectedAug.Id
    )
    task.wait(0.3)
    State.CatalogBySlot[State.ActiveTab] = nil
    PopulateAugList(State.ActiveTab)
    UpdateCurrentAugsPanel()
    UpdateILPreview()
end)

-- ── Unequip ───────────────────────────────────────────────────────────────────
UnequipButton.Activated:Connect(function()
    if not State.SelectedAug then return end
    Remotes:WaitForChild(NetworkEvents.C2S.RequestUnequipAug):FireServer(State.SelectedAug.Slot)
    task.wait(0.3)
    State.CatalogBySlot[State.ActiveTab] = nil
    PopulateAugList(State.ActiveTab)
    UpdateCurrentAugsPanel()
    UpdateILPreview()
end)

-- ── Current Augs Panel (sidebar showing what's equipped) ─────────────────────
function UpdateCurrentAugsPanel()
    local data = GetPlayerData()
    if not data then return end

    for _, child in ipairs(CurrentAugsPanel:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local yOff = 0
    for _, slot in ipairs(SLOTS) do
        local augId = data.Augmentations[slot]
        local aug   = augId and AugmentationData.GetById(augId)

        local row = Instance.new("Frame")
        row.Size   = UDim2.new(1, -8, 0, 26)
        row.Position = UDim2.new(0, 4, 0, yOff)
        row.BackgroundTransparency = 1

        local slotLbl = Instance.new("TextLabel")
        slotLbl.Size      = UDim2.new(0.35, 0, 1, 0)
        slotLbl.BackgroundTransparency = 1
        slotLbl.Text      = slot:upper()
        slotLbl.TextColor3= Color3.fromRGB(120, 130, 150)
        slotLbl.Font      = Enum.Font.GothamBold
        slotLbl.TextSize  = 11
        slotLbl.TextXAlignment = Enum.TextXAlignment.Left
        slotLbl.Parent    = row

        local augLbl = Instance.new("TextLabel")
        augLbl.Size       = UDim2.new(0.65, 0, 1, 0)
        augLbl.Position   = UDim2.new(0.35, 0, 0, 0)
        augLbl.BackgroundTransparency = 1
        augLbl.Text       = aug and aug.DisplayName or "— None —"
        augLbl.TextColor3 = aug and (ORIGIN_COLORS[aug.Origin] or Color3.new(1,1,1))
            or Color3.fromRGB(70, 75, 90)
        augLbl.Font       = Enum.Font.Gotham
        augLbl.TextSize   = 11
        augLbl.TextXAlignment = Enum.TextXAlignment.Left
        augLbl.Parent     = row

        row.Parent = CurrentAugsPanel
        yOff = yOff + 28
    end
end

-- ── IL Preview ────────────────────────────────────────────────────────────────
function UpdateILPreview()
    local data = GetPlayerData()
    if not data then return end

    local il     = data.IdentityLoad    or 0
    local ilMax  = data.IdentityLoadMax or 100
    local thresh = IdentityLoad.GetThreshold(il)

    ILPreviewLabel.Text       = "IDENTITY LOAD: " .. il .. " / " .. ilMax .. "  [" .. thresh.label .. "]"
    ILPreviewLabel.TextColor3 = Color3.fromHex(thresh.colorHex)

    -- Credits display
    CreditsLabel.Text = "$" .. (data.Credits or 0) .. "    SCR " .. (data.Scrap or 0)
end

-- ── Close ─────────────────────────────────────────────────────────────────────
CloseButton.Activated:Connect(function()
    gui.Enabled = false
end)

-- ── Open (toggle with keybind) ────────────────────────────────────────────────
local UserInputService2 = UserInputService
UserInputService2.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    -- T = aug menu
    if input.KeyCode == Enum.KeyCode.T then
        gui.Enabled = not gui.Enabled
        if gui.Enabled then
            State.PlayerData = GetPlayerData()
            BuildTabs()
            PopulateAugList(State.ActiveTab)
            UpdateCurrentAugsPanel()
            UpdateILPreview()
        end
    end
end)

-- ── React to aug events ───────────────────────────────────────────────────────
ReplicatedStorage:WaitForChild("Remotes", 30):WaitForChild(
    NetworkEvents.S2C.AugEquipped, 10
).OnClientEvent:Connect(function()
    if gui.Enabled then
        UpdateCurrentAugsPanel()
        UpdateILPreview()
        State.CatalogBySlot[State.ActiveTab] = nil
        PopulateAugList(State.ActiveTab)
    end
end)

-- ── Initialise ────────────────────────────────────────────────────────────────
DetailPanel.Visible = false
gui.Enabled         = false

print("[AugMenu] Initialised.")
