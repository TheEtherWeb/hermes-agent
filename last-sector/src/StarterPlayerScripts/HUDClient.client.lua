-- HUDClient.client.lua
-- Drives the Last Sector HUD: health bar, armor bar, energy bar,
-- Identity Load bar, ammo display, objective tracker, overdrive gauge,
-- notifications, boss health bar, and incursion alert.
-- The actual ScreenGui lives in StarterGui/HUD; this script populates and
-- animates it.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")

local player = Players.LocalPlayer
local Modules = ReplicatedStorage:WaitForChild("Modules")

local GameData     = require(Modules:WaitForChild("GameData"))
local IdentityLoad = require(Modules:WaitForChild("IdentityLoad"))

-- Wait for HUD gui
local HUDGui = player.PlayerGui:WaitForChild("HUD", 15)
assert(HUDGui, "[HUDClient] HUD ScreenGui not found")

-- ── Reference all HUD elements ────────────────────────────────────────────────
local Main         = HUDGui:WaitForChild("Main")
local HealthBar    = Main:WaitForChild("HealthBar")
local ArmorBar     = Main:WaitForChild("ArmorBar")
local EnergyBar    = Main:WaitForChild("EnergyBar")
local ILBar        = Main:WaitForChild("IdentityLoadBar")
local ILLabel      = Main:WaitForChild("ILLabel")
local AmmoDisplay  = Main:WaitForChild("AmmoDisplay")
local OverdriveGauge    = Main:WaitForChild("OverdriveGauge")
local OverdriveTimerLabel = Main:WaitForChild("OverdriveTimer")
local NotifFrame   = Main:WaitForChild("NotificationFrame")
local NotifLabel   = NotifFrame:WaitForChild("NotifLabel")
local ObjectivePanel = Main:WaitForChild("ObjectivePanel")
local BossPanel    = Main:WaitForChild("BossPanel")
local BossBar      = BossPanel:WaitForChild("BossBar")
local BossNameLabel= BossPanel:WaitForChild("BossName")
local BossPhaseLabel = BossPanel:WaitForChild("BossPhase")
local IncursionAlert = Main:WaitForChild("IncursionAlert")
local IncursionLabel = IncursionAlert:WaitForChild("IncursionLabel")
local DamageNumbers  = Main:WaitForChild("DamageNumbers")
local StatusEffectList = Main:WaitForChild("StatusEffects")
local RepToast     = Main:WaitForChild("RepToast")

-- ── State ─────────────────────────────────────────────────────────────────────
local HUDState = {
    CurrentHP       = 150,
    MaxHP           = 150,
    CurrentArmor    = 40,
    MaxArmor        = 40,
    CurrentEnergy   = 80,
    MaxEnergy       = 80,
    IdentityLoad    = 0,
    IdentityLoadMax = 100,
    OverdriveActive = false,
    OverdriveDuration= 0,
    OverdriveTimer  = 0,
    ActiveObjectives= {},
    BossVisible     = false,
    BossHP          = 0,
    BossMaxHP       = 0,
    NotifQueue      = {},
    StatusEffects   = {},
}

-- ── Color constants ────────────────────────────────────────────────────────────
local COLOR_HEALTH_HIGH  = Color3.fromRGB(80,  200, 100)
local COLOR_HEALTH_MED   = Color3.fromRGB(220, 180, 60)
local COLOR_HEALTH_LOW   = Color3.fromRGB(220, 60,  60)
local COLOR_ARMOR        = Color3.fromRGB(100, 160, 220)
local COLOR_ENERGY       = Color3.fromRGB(60,  180, 220)
local COLOR_IL_INTACT    = Color3.fromHex("#A8E6CF")
local COLOR_OVERDRIVE    = Color3.fromRGB(255, 140, 0)

local SEVERITY_COLORS = {
    info     = Color3.fromRGB(160, 200, 220),
    warning  = Color3.fromRGB(220, 180, 50),
    error    = Color3.fromRGB(220, 60,  60),
    unlock   = Color3.fromRGB(100, 220, 150),
    narrative= Color3.fromRGB(180, 100, 220),
}

-- ── Bar Update Helpers ────────────────────────────────────────────────────────
local function SetBarValue(bar, current, max)
    local pct = max > 0 and (current / max) or 0
    pct = math.clamp(pct, 0, 1)
    local fill = bar:FindFirstChild("Fill")
    if fill then
        TweenService:Create(fill, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Size = UDim2.new(pct, 0, 1, 0) }):Play()
    end
end

local function SetHealthBarColor(pct)
    local fill = HealthBar:FindFirstChild("Fill")
    if not fill then return end
    local color
    if pct > 0.5 then
        color = COLOR_HEALTH_HIGH:Lerp(COLOR_HEALTH_MED, (1 - pct) * 2)
    else
        color = COLOR_HEALTH_MED:Lerp(COLOR_HEALTH_LOW, (0.5 - pct) * 2)
    end
    fill.BackgroundColor3 = color
end

-- ── Public HUD Controller ─────────────────────────────────────────────────────
local HUDController = {}

function HUDController:FullRefresh(snap)
    HUDState.MaxHP           = snap.MaxHealth  or 150
    HUDState.MaxArmor        = snap.MaxArmor   or 40
    HUDState.MaxEnergy       = snap.MaxEnergy  or 80
    HUDState.IdentityLoadMax = snap.IdentityLoadMax or 100
    HUDState.IdentityLoad    = snap.IdentityLoad    or 0

    self:UpdateIdentityLoad(HUDState.IdentityLoad, HUDState.IdentityLoadMax)
    self:UpdateAmmo()
end

function HUDController:PartialUpdate(partial)
    -- Nothing needed here; individual event handlers cover specifics.
end

-- ── Health / Armor updates (driven by Humanoid on client) ─────────────────────
local function TrackCharacterHealth()
    local char = player.Character or player.CharacterAdded:Wait()
    local hum  = char:WaitForChild("Humanoid")

    hum.HealthChanged:Connect(function(hp)
        HUDState.CurrentHP = hp
        local pct = HUDState.MaxHP > 0 and (hp / HUDState.MaxHP) or 0
        SetBarValue(HealthBar, hp, HUDState.MaxHP)
        SetHealthBarColor(pct)

        local label = HealthBar:FindFirstChild("Label")
        if label then label.Text = math.floor(hp) .. " / " .. HUDState.MaxHP end

        -- Low health pulse
        if pct < 0.25 then
            local pulse = Main:FindFirstChild("LowHealthPulse")
            if pulse then pulse.Visible = true end
        else
            local pulse = Main:FindFirstChild("LowHealthPulse")
            if pulse then pulse.Visible = false end
        end
    end)
end

player.CharacterAdded:Connect(function(char)
    task.wait(0.2)
    TrackCharacterHealth()
end)
if player.Character then TrackCharacterHealth() end

-- ── Identity Load ─────────────────────────────────────────────────────────────
function HUDController:UpdateIdentityLoad(il, ilMax)
    HUDState.IdentityLoad    = il
    HUDState.IdentityLoadMax = ilMax

    SetBarValue(ILBar, il, ilMax)

    local thresh  = IdentityLoad.GetThreshold(il)
    local color   = Color3.fromHex(thresh.colorHex)
    local ilFill  = ILBar:FindFirstChild("Fill")
    if ilFill then
        TweenService:Create(ilFill, TweenInfo.new(0.3), { BackgroundColor3 = color }):Play()
    end

    ILLabel.Text = thresh.label .. " [" .. il .. "/" .. ilMax .. "]"
    ILLabel.TextColor3 = color
end

-- ── Energy Bar (updated by overdrive and tool use) ────────────────────────────
function HUDController:UpdateEnergy(current, max)
    HUDState.CurrentEnergy = current
    HUDState.MaxEnergy     = max or HUDState.MaxEnergy
    SetBarValue(EnergyBar, current, HUDState.MaxEnergy)
    local label = EnergyBar:FindFirstChild("Label")
    if label then label.Text = math.floor(current) end
end

-- ── Ammo Display ──────────────────────────────────────────────────────────────
function HUDController:UpdateAmmo(current, max, isReloading)
    local label = AmmoDisplay:FindFirstChild("Count")
    if label then
        if isReloading then
            label.Text = "RELOAD"
            label.TextColor3 = COLOR_ENERGY
        else
            label.Text = (current or "--") .. " / " .. (max or "--")
            label.TextColor3 = Color3.new(1, 1, 1)
        end
    end
end

function HUDController:ShowDamageNumber(amount, damageType)
    -- Create a billboard label that floats upward
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local bb = Instance.new("BillboardGui")
    bb.Size           = UDim2.new(0, 80, 0, 30)
    bb.AlwaysOnTop    = false
    bb.StudsOffset    = Vector3.new(math.random(-3, 3), 4 + math.random(0, 2), 0)
    bb.Adornee        = hrp
    bb.Parent         = hrp

    local lbl = Instance.new("TextLabel")
    lbl.Size              = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text              = "-" .. tostring(math.floor(amount))
    lbl.TextColor3        = (damageType == "Energy") and Color3.fromRGB(255, 120, 30)
                         or (damageType == "Neural") and Color3.fromRGB(180, 60, 220)
                         or Color3.fromRGB(220, 60, 60)
    lbl.TextStrokeTransparency = 0.4
    lbl.Font              = Enum.Font.GothamBold
    lbl.TextSize          = 18
    lbl.Parent            = bb

    TweenService:Create(bb, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { StudsOffset = Vector3.new(bb.StudsOffset.X, 8, 0) }):Play()
    TweenService:Create(lbl, TweenInfo.new(1.2), { TextTransparency = 1 }):Play()
    game:GetService("Debris"):AddItem(bb, 1.3)
end

-- ── Notifications ──────────────────────────────────────────────────────────────
function HUDController:ShowNotification(text, duration, severity)
    NotifFrame.Visible = true
    NotifLabel.Text    = text
    NotifLabel.TextColor3 = SEVERITY_COLORS[severity] or Color3.new(1, 1, 1)

    TweenService:Create(NotifFrame, TweenInfo.new(0.2), { BackgroundTransparency = 0.3 }):Play()

    task.delay(duration or 4, function()
        TweenService:Create(NotifFrame, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
        task.wait(0.4)
        NotifFrame.Visible = false
    end)
end

-- ── Status Effects ────────────────────────────────────────────────────────────
function HUDController:ShowStatusEffect(effectId, duration)
    -- Add icon to status effect list
    local existing = StatusEffectList:FindFirstChild(effectId)
    if existing then existing:Destroy() end

    local frame = Instance.new("Frame")
    frame.Name   = effectId
    frame.Size   = UDim2.new(0, 36, 0, 36)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 60)

    local label = Instance.new("TextLabel")
    label.Size              = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text              = effectId:sub(1, 3)
    label.TextColor3        = Color3.new(1, 1, 1)
    label.Font              = Enum.Font.Gotham
    label.TextSize          = 11
    label.Parent            = frame

    frame.Parent = StatusEffectList

    task.delay(duration, function()
        if frame and frame.Parent then frame:Destroy() end
    end)
end

function HUDController:RemoveStatusEffect(effectId)
    local f = StatusEffectList:FindFirstChild(effectId)
    if f then f:Destroy() end
end

-- ── Overdrive UI ──────────────────────────────────────────────────────────────
function HUDController:ActivateOverdriveUI(overdriveId, duration)
    HUDState.OverdriveActive   = true
    HUDState.OverdriveDuration = duration
    HUDState.OverdriveTimer    = duration

    OverdriveGauge.Visible      = true
    OverdriveTimerLabel.Visible = true

    local fill = OverdriveGauge:FindFirstChild("Fill")
    if fill then
        fill.BackgroundColor3 = COLOR_OVERDRIVE
        fill.Size = UDim2.new(1, 0, 1, 0)
    end
end

function HUDController:DeactivateOverdriveUI(overdriveId)
    HUDState.OverdriveActive = false
    OverdriveTimerLabel.Visible = false

    local fill = OverdriveGauge:FindFirstChild("Fill")
    if fill then
        TweenService:Create(fill, TweenInfo.new(0.5), { Size = UDim2.new(0, 0, 1, 0) }):Play()
    end
end

-- ── Mission UI ────────────────────────────────────────────────────────────────
function HUDController:ShowMissionStart(missionData)
    self:ShowNotification("OPERATION ACCEPTED: " .. (missionData.DisplayName or "Unknown"), 5, "unlock")

    -- Clear and rebuild objective panel
    for _, child in ipairs(ObjectivePanel:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    ObjectivePanel.Visible = true
    HUDState.ActiveObjectives = {}

    for _, obj in ipairs(missionData.Objectives or {}) do
        HUDState.ActiveObjectives[obj.Id] = { label = obj.Label, current = 0, target = obj.Count or 1, done = false }

        local objFrame = Instance.new("Frame")
        objFrame.Name            = obj.Id
        objFrame.Size            = UDim2.new(1, 0, 0, 22)
        objFrame.BackgroundTransparency = 1

        local objLabel = Instance.new("TextLabel")
        objLabel.Size              = UDim2.new(1, -10, 1, 0)
        objLabel.Position          = UDim2.new(0, 10, 0, 0)
        objLabel.BackgroundTransparency = 1
        objLabel.Text              = "[ ] " .. obj.Label
        objLabel.TextColor3        = Color3.fromRGB(180, 180, 200)
        objLabel.Font              = Enum.Font.Gotham
        objLabel.TextSize          = 13
        objLabel.TextXAlignment    = Enum.TextXAlignment.Left
        objLabel.Parent            = objFrame
        objFrame.Parent            = ObjectivePanel
    end
end

function HUDController:UpdateObjective(objId, current, target, completed)
    local state = HUDState.ActiveObjectives[objId]
    if state then
        state.current = current
        state.done    = completed
    end

    local objFrame = ObjectivePanel:FindFirstChild(objId)
    if not objFrame then return end
    local lbl = objFrame:FindFirstChildOfClass("TextLabel")
    if not lbl then return end

    if completed then
        lbl.Text       = "[X] " .. (state and state.label or objId)
        lbl.TextColor3 = Color3.fromRGB(100, 220, 130)
    else
        lbl.Text = "[ ] " .. (state and state.label or objId) .. " (" .. current .. "/" .. target .. ")"
    end
end

function HUDController:ShowMissionComplete(rewards)
    ObjectivePanel.Visible = false
    self:ShowNotification(
        "OPERATION COMPLETE  +$" .. (rewards.credits or 0) .. "  +" .. (rewards.xp or 0) .. " XP",
        7, "unlock"
    )
end

function HUDController:ShowMissionFailed(reason)
    ObjectivePanel.Visible = false
    self:ShowNotification("OPERATION FAILED: " .. (reason or "Unknown"), 5, "error")
end

-- ── Incursion Alert ───────────────────────────────────────────────────────────
function HUDController:ShowIncursionAlert(incursionData)
    IncursionAlert.Visible = true
    IncursionLabel.Text    = "INCURSION: " .. (incursionData.DisplayName or "Event")
    IncursionLabel.TextColor3 = Color3.fromRGB(220, 60, 60)

    -- Pulse animation
    local tween = TweenService:Create(IncursionAlert, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { BackgroundTransparency = 0.8 })
    tween:Play()
end

function HUDController:HideIncursionAlert()
    IncursionAlert.Visible = false
end

-- ── Boss Bar ──────────────────────────────────────────────────────────────────
function HUDController:ShowBossBar(bossId, bossData)
    HUDState.BossVisible = true
    HUDState.BossMaxHP   = bossData.HP or 1000
    HUDState.BossHP      = bossData.HP or 1000

    BossPanel.Visible    = true
    BossNameLabel.Text   = bossData.DisplayName or bossId
    BossPhaseLabel.Text  = "Phase 1"
    SetBarValue(BossBar, 1, 1)
end

function HUDController:UpdateBossHP(current, max)
    HUDState.BossHP    = current
    HUDState.BossMaxHP = max
    SetBarValue(BossBar, current, max)
    local fill = BossBar:FindFirstChild("Fill")
    if fill then
        local pct = max > 0 and (current / max) or 0
        fill.BackgroundColor3 = pct > 0.5 and Color3.fromRGB(200, 80, 80)
            or Color3.fromRGB(220, 30, 30)
    end
end

function HUDController:UpdateBossPhase(bossId, phase)
    BossPhaseLabel.Text = "Phase: " .. (phase.label or "?")
    self:ShowNotification(phase.label .. " — " .. (phase.note or ""), 5, "warning")
end

function HUDController:HideBossBar(bossId)
    HUDState.BossVisible = false
    BossPanel.Visible    = false
end

-- ── Level Up ─────────────────────────────────────────────────────────────────
function HUDController:ShowLevelUp(newLevel)
    self:ShowNotification("LEVEL UP → " .. newLevel, 5, "unlock")
end

-- ── Rep Change Toast ──────────────────────────────────────────────────────────
function HUDController:ShowRepChange(factionId, delta)
    if math.abs(delta) < 5 then return end

    local sign   = delta > 0 and "+" or ""
    local text   = factionId .. "  " .. sign .. delta

    RepToast.Visible    = true
    local lbl = RepToast:FindFirstChildOfClass("TextLabel")
    if lbl then
        lbl.Text       = text
        lbl.TextColor3 = delta > 0 and Color3.fromRGB(100, 220, 130) or Color3.fromRGB(220, 80, 80)
    end

    TweenService:Create(RepToast, TweenInfo.new(0.3), { BackgroundTransparency = 0.4 }):Play()
    task.delay(3, function()
        TweenService:Create(RepToast, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
        task.wait(0.5)
        RepToast.Visible = false
    end)
end

-- ── Memory Fragment ──────────────────────────────────────────────────────────
function HUDController:ShowMemoryFragment(fragmentId, content)
    self:ShowNotification("[MEMORY] " .. (content or fragmentId), 8, "narrative")
end

-- ── Aug Change ───────────────────────────────────────────────────────────────
function HUDController:ShowAugChange(slot, augId)
    self:ShowNotification("Aug equipped: " .. slot .. " → " .. augId, 3, "info")
end

-- ── Per-Frame ─────────────────────────────────────────────────────────────────
RunService.RenderStepped:Connect(function(dt)
    -- Overdrive timer countdown
    if HUDState.OverdriveActive then
        HUDState.OverdriveTimer = math.max(0, HUDState.OverdriveTimer - dt)
        OverdriveTimerLabel.Text = string.format("%.1fs", HUDState.OverdriveTimer)

        local fill = OverdriveGauge:FindFirstChild("Fill")
        if fill and HUDState.OverdriveDuration > 0 then
            fill.Size = UDim2.new(HUDState.OverdriveTimer / HUDState.OverdriveDuration, 0, 1, 0)
        end
    end
end)

-- ── Expose as module ─────────────────────────────────────────────────────────
-- Stored in the HUD gui itself so ClientMain can get a reference
local controllerValue = Instance.new("ObjectValue")
controllerValue.Name   = "HUDControllerRef"
controllerValue.Parent = HUDGui
-- The _G table reference is used by ClientMain's GetHUD()
_G.HUDController = HUDController

print("[HUDClient] Initialised.")
