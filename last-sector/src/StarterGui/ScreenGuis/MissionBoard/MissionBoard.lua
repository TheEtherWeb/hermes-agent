-- MissionBoard.lua (LocalScript inside MissionBoard ScreenGui)
-- The contract board interface. Shows all available missions sorted by faction,
-- difficulty, and type. Also shows active incursion events and boss encounters.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local player  = Players.LocalPlayer
local gui     = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
local Modules = ReplicatedStorage:WaitForChild("Modules")

local NetworkEvents = require(Modules:WaitForChild("NetworkEvents"))
local GameData      = require(Modules:WaitForChild("GameData"))
local FactionData   = require(Modules:WaitForChild("FactionData"))
local MissionData   = require(Modules:WaitForChild("MissionData"))

-- ── Layout References ─────────────────────────────────────────────────────────
local Panel            = gui:WaitForChild("Panel")
local CloseButton      = Panel:WaitForChild("CloseButton")
local FactionFilter    = Panel:WaitForChild("FactionFilter")    -- dropdown or tab row
local MissionList      = Panel:WaitForChild("MissionList")      -- ScrollingFrame
local DetailPanel      = Panel:WaitForChild("DetailPanel")
local DetailTitle      = DetailPanel:WaitForChild("Title")
local DetailFaction    = DetailPanel:WaitForChild("Faction")
local DetailDifficulty = DetailPanel:WaitForChild("Difficulty")
local DetailDesc       = DetailPanel:WaitForChild("Description")
local DetailObjectives = DetailPanel:WaitForChild("Objectives")
local DetailRewards    = DetailPanel:WaitForChild("Rewards")
local AcceptButton     = DetailPanel:WaitForChild("AcceptButton")
local AbandonButton    = Panel:WaitForChild("AbandonButton")
local ActiveMissionPanel = Panel:WaitForChild("ActiveMissionPanel")
local ActiveMissionLabel = ActiveMissionPanel:WaitForChild("ActiveLabel")

-- ── State ─────────────────────────────────────────────────────────────────────
local State = {
    ActiveFactionFilter = nil,  -- nil = all
    SelectedMission     = nil,
    MissionList         = {},
}

local DIFFICULTY_COLORS = {
    Grey   = Color3.fromRGB(160, 165, 170),
    Yellow = Color3.fromRGB(230, 210, 60),
    Orange = Color3.fromRGB(230, 130, 50),
    Red    = Color3.fromRGB(220, 60,  60),
    Black  = Color3.fromRGB(200, 80, 220),
}

local TYPE_ICONS = {
    Assassination  = "[ASN]",
    Retrieval      = "[RTV]",
    Purge          = "[PRG]",
    DataTheft      = "[DAT]",
    ConvoyHit      = "[CNV]",
    AndroidHunt    = "[AND]",
    Salvage        = "[SAL]",
    Interception   = "[INT]",
    Survival       = "[SRV]",
    Exploration    = "[EXP]",
    BossSuppression= "[BOS]",
    Diplomacy      = "[DPL]",
    Incursion      = "[INC]",
}

-- ── Load Missions ──────────────────────────────────────────────────────────────
local function LoadMissions(factionId)
    local list = Remotes:WaitForChild(NetworkEvents.RF.GetMissionList):InvokeServer(factionId)
    State.MissionList = list or {}
    return State.MissionList
end

-- ── Build Faction Filter ───────────────────────────────────────────────────────
local function BuildFactionFilter()
    for _, child in ipairs(FactionFilter:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    -- "ALL" button
    local allBtn = Instance.new("TextButton")
    allBtn.Size             = UDim2.new(0, 60, 1, -4)
    allBtn.Position         = UDim2.new(0, 2, 0, 2)
    allBtn.BackgroundColor3 = (State.ActiveFactionFilter == nil)
        and Color3.fromRGB(50, 60, 80)
        or  Color3.fromRGB(25, 28, 38)
    allBtn.Text             = "ALL"
    allBtn.TextColor3       = Color3.new(1, 1, 1)
    allBtn.Font             = Enum.Font.GothamBold
    allBtn.TextSize         = 12
    allBtn.AutoButtonColor  = false
    allBtn.BorderSizePixel  = 1
    allBtn.Parent           = FactionFilter

    allBtn.Activated:Connect(function()
        State.ActiveFactionFilter = nil
        BuildFactionFilter()
        PopulateMissionList()
    end)

    local xPos = 64
    for _, faction in ipairs(FactionData.Factions) do
        local btn = Instance.new("TextButton")
        btn.Size             = UDim2.new(0, 90, 1, -4)
        btn.Position         = UDim2.new(0, xPos, 0, 2)
        btn.BackgroundColor3 = (State.ActiveFactionFilter == faction.Id)
            and Color3.fromHex(faction.ColorHex)
            or  Color3.fromRGB(25, 28, 38)
        btn.Text             = faction.Alias or faction.Id
        btn.TextColor3       = (State.ActiveFactionFilter == faction.Id)
            and Color3.new(0, 0, 0)
            or  Color3.fromHex(faction.ColorHex)
        btn.Font             = Enum.Font.GothamBold
        btn.TextSize         = 11
        btn.AutoButtonColor  = false
        btn.BorderColor3     = Color3.fromHex(faction.ColorHex)
        btn.BorderSizePixel  = 1
        btn.Parent           = FactionFilter

        local fId = faction.Id
        btn.Activated:Connect(function()
            State.ActiveFactionFilter = fId
            BuildFactionFilter()
            task.spawn(function()
                LoadMissions(fId)
                PopulateMissionList()
            end)
        end)

        xPos = xPos + 94
    end
end

-- ── Populate Mission List ─────────────────────────────────────────────────────
function PopulateMissionList()
    for _, child in ipairs(MissionList:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("Frame") then child:Destroy() end
    end

    local missions = State.MissionList
    local yOff = 0

    for _, m in ipairs(missions) do
        local diffColor = DIFFICULTY_COLORS[m.Difficulty] or Color3.new(1, 1, 1)
        local typeIcon  = TYPE_ICONS[m.Type] or "[???]"

        local row = Instance.new("TextButton")
        row.Name             = m.Id
        row.Size             = UDim2.new(1, -8, 0, 58)
        row.Position         = UDim2.new(0, 4, 0, yOff)
        row.BackgroundColor3 = m.IsActive and Color3.fromRGB(30, 50, 40)
            or m.Completed and Color3.fromRGB(20, 25, 20)
            or Color3.fromRGB(20, 22, 30)
        row.BorderColor3     = m.IsActive and Color3.fromRGB(80, 200, 120)
            or m.Completed and Color3.fromRGB(60, 80, 60)
            or Color3.fromRGB(40, 45, 60)
        row.BorderSizePixel  = 1
        row.AutoButtonColor  = false
        row.Text             = ""
        row.Parent           = MissionList

        -- Type icon + title
        local titleLbl = Instance.new("TextLabel")
        titleLbl.Size      = UDim2.new(1, -90, 0, 22)
        titleLbl.Position  = UDim2.new(0, 8, 0, 6)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text      = typeIcon .. " " .. m.DisplayName
        titleLbl.TextColor3= m.Completed and Color3.fromRGB(100, 130, 100)
            or Color3.fromRGB(200, 205, 220)
        titleLbl.Font      = Enum.Font.GothamBold
        titleLbl.TextSize  = 13
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Parent    = row

        -- Difficulty badge
        local diffLbl = Instance.new("TextLabel")
        diffLbl.Size      = UDim2.new(0, 80, 0, 18)
        diffLbl.Position  = UDim2.new(1, -85, 0, 6)
        diffLbl.BackgroundTransparency = 1
        diffLbl.Text      = m.Difficulty:upper()
        diffLbl.TextColor3= diffColor
        diffLbl.Font      = Enum.Font.GothamBold
        diffLbl.TextSize  = 12
        diffLbl.TextXAlignment = Enum.TextXAlignment.Right
        diffLbl.Parent    = row

        -- Sub info
        local faction  = m.Faction and FactionData.GetById(m.Faction)
        local factionName = faction and faction.Alias or "OPEN CONTRACT"
        local rewardText  = "$" .. (m.Rewards.credits or 0) .. "  +" .. (m.Rewards.xp or 0) .. " XP"

        local subLbl = Instance.new("TextLabel")
        subLbl.Size      = UDim2.new(1, -8, 0, 16)
        subLbl.Position  = UDim2.new(0, 8, 0, 30)
        subLbl.BackgroundTransparency = 1
        subLbl.Text      = factionName .. "  ·  LVL " .. (m.MinLevel or 1) .. "+  ·  " .. rewardText
        subLbl.TextColor3= faction and Color3.fromHex(faction.ColorHex) or Color3.fromRGB(120, 130, 150)
        subLbl.Font      = Enum.Font.Gotham
        subLbl.TextSize  = 11
        subLbl.TextXAlignment = Enum.TextXAlignment.Left
        subLbl.Parent    = row

        -- Status badge
        if m.IsActive then
            local badge = Instance.new("TextLabel")
            badge.Size  = UDim2.new(0, 70, 0, 16)
            badge.Position = UDim2.new(0, 8, 0, 36)
            badge.BackgroundTransparency = 1
            badge.Text  = "► ACTIVE"
            badge.TextColor3 = Color3.fromRGB(80, 220, 120)
            badge.Font  = Enum.Font.GothamBold
            badge.TextSize = 11
            badge.Parent= row
        elseif m.Completed then
            local badge = Instance.new("TextLabel")
            badge.Size  = UDim2.new(0, 80, 0, 16)
            badge.Position = UDim2.new(0, 8, 0, 36)
            badge.BackgroundTransparency = 1
            badge.Text  = "✓ COMPLETED"
            badge.TextColor3 = Color3.fromRGB(80, 140, 80)
            badge.Font  = Enum.Font.Gotham
            badge.TextSize = 11
            badge.Parent= row
        end

        local mData = m
        row.Activated:Connect(function()
            State.SelectedMission = mData
            ShowMissionDetail(mData)
        end)

        yOff = yOff + 62
    end

    MissionList.CanvasSize = UDim2.new(0, 0, 0, yOff)
end

-- ── Show Mission Detail ───────────────────────────────────────────────────────
function ShowMissionDetail(m)
    DetailTitle.Text       = m.DisplayName
    DetailTitle.TextColor3 = DIFFICULTY_COLORS[m.Difficulty] or Color3.new(1, 1, 1)

    local faction = m.Faction and FactionData.GetById(m.Faction)
    DetailFaction.Text       = faction and faction.DisplayName or "Open Contract"
    DetailFaction.TextColor3 = faction and Color3.fromHex(faction.ColorHex) or Color3.new(1, 1, 1)

    DetailDifficulty.Text       = m.Difficulty:upper() .. "  ·  LVL " .. (m.MinLevel or 1) .. "+"
    DetailDifficulty.TextColor3 = DIFFICULTY_COLORS[m.Difficulty] or Color3.new(1, 1, 1)

    DetailDesc.Text = m.Description or ""

    -- Objectives
    local objText = ""
    for _, obj in ipairs(MissionData.GetById(m.Id) and MissionData.GetById(m.Id).Objectives or {}) do
        objText = objText .. "• " .. obj.Label .. "\n"
    end
    DetailObjectives.Text = objText ~= "" and objText or "See briefing."

    -- Rewards
    DetailRewards.Text =
        "CREDITS: $" .. (m.Rewards.credits or 0) ..
        "\nEXPERIENCE: +" .. (m.Rewards.xp or 0) ..
        (m.Rewards.scrap and "\nSCRAP: +" .. m.Rewards.scrap or "") ..
        "\n\n[Bonus objectives grant additional credits]"

    AcceptButton.Visible = not m.Completed and not m.IsActive
    AcceptButton.Text    = (m.Type == "Incursion") and "JOIN INCURSION" or "ACCEPT CONTRACT"

    DetailPanel.Visible = true
end

-- ── Accept Mission ────────────────────────────────────────────────────────────
AcceptButton.Activated:Connect(function()
    if not State.SelectedMission then return end
    Remotes:WaitForChild(NetworkEvents.C2S.AcceptMission):FireServer(State.SelectedMission.Id)

    -- Refresh list
    task.wait(0.3)
    task.spawn(function()
        LoadMissions(State.ActiveFactionFilter)
        PopulateMissionList()
        UpdateActiveMissionPanel()
    end)
end)

-- ── Abandon Mission ───────────────────────────────────────────────────────────
AbandonButton.Activated:Connect(function()
    Remotes:WaitForChild(NetworkEvents.C2S.AbandonMission):FireServer()
    task.wait(0.3)
    task.spawn(function()
        LoadMissions(State.ActiveFactionFilter)
        PopulateMissionList()
        UpdateActiveMissionPanel()
    end)
end)

-- ── Active Mission Panel ──────────────────────────────────────────────────────
function UpdateActiveMissionPanel()
    local data = _G.ClientMain and _G.ClientMain.State.PlayerData
    if data and data.ActiveMission then
        local mission = MissionData.GetById(data.ActiveMission)
        ActiveMissionPanel.Visible = true
        ActiveMissionLabel.Text    = "ACTIVE: " .. (mission and mission.DisplayName or data.ActiveMission)
        AbandonButton.Visible      = true
    else
        ActiveMissionPanel.Visible = false
        AbandonButton.Visible      = false
    end
end

-- ── React to server events ────────────────────────────────────────────────────
Remotes:WaitForChild(NetworkEvents.S2C.MissionCompleted, 10).OnClientEvent:Connect(function()
    if gui.Enabled then
        task.spawn(function()
            LoadMissions(State.ActiveFactionFilter)
            PopulateMissionList()
            UpdateActiveMissionPanel()
        end)
    end
end)

Remotes:WaitForChild(NetworkEvents.S2C.IncursionTriggered, 10).OnClientEvent:Connect(function(id, data)
    -- Add incursion to list dynamically
    if gui.Enabled then
        task.spawn(function()
            LoadMissions(nil)
            PopulateMissionList()
        end)
    end
end)

-- ── Close ─────────────────────────────────────────────────────────────────────
CloseButton.Activated:Connect(function()
    gui.Enabled = false
end)

-- ── Toggle (M key) ────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.M then
        gui.Enabled = not gui.Enabled
        if gui.Enabled then
            DetailPanel.Visible = false
            task.spawn(function()
                LoadMissions(State.ActiveFactionFilter)
                BuildFactionFilter()
                PopulateMissionList()
                UpdateActiveMissionPanel()
            end)
        end
    end
end)

-- ── Initialise ────────────────────────────────────────────────────────────────
DetailPanel.Visible        = false
ActiveMissionPanel.Visible = false
AbandonButton.Visible      = false
gui.Enabled                = false

print("[MissionBoard] Initialised.")
