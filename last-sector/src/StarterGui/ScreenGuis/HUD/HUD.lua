-- HUD.lua (LocalScript inside HUD ScreenGui)
-- Builds all HUD frame elements programmatically at runtime.
-- This is the layout layer; all data updates go through HUDClient.lua via
-- the HUDController interface stored in _G.HUDController.

local Players     = game:GetService("Players")
local TweenService= game:GetService("TweenService")

local gui    = script.Parent   -- HUD ScreenGui
local player = Players.LocalPlayer

-- ── Color palette ─────────────────────────────────────────────────────────────
local C = {
    BG          = Color3.fromRGB(10, 12, 18),
    PANEL       = Color3.fromRGB(16, 18, 26),
    BORDER      = Color3.fromRGB(40, 45, 60),
    TEXT        = Color3.fromRGB(200, 205, 220),
    MUTED       = Color3.fromRGB(100, 110, 130),
    HEALTH      = Color3.fromRGB(80, 200, 100),
    ARMOR       = Color3.fromRGB(100, 160, 220),
    ENERGY      = Color3.fromRGB(60, 180, 220),
    IL          = Color3.fromRGB(168, 230, 207),
    OVERDRIVE   = Color3.fromRGB(255, 140, 0),
    DANGER      = Color3.fromRGB(220, 60, 60),
    SUCCESS     = Color3.fromRGB(80, 220, 130),
    ACCENT      = Color3.fromRGB(80, 120, 200),
}

-- ── Utility: make bar ─────────────────────────────────────────────────────────
local function MakeBar(parent, name, pos, size, fillColor, label)
    local frame = Instance.new("Frame")
    frame.Name             = name
    frame.Size             = size
    frame.Position         = pos
    frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
    frame.BorderColor3     = C.BORDER
    frame.BorderSizePixel  = 1
    frame.Parent           = parent

    local fill = Instance.new("Frame")
    fill.Name             = "Fill"
    fill.Size             = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = fillColor
    fill.BorderSizePixel  = 0
    fill.Parent           = frame

    if label then
        local lbl = Instance.new("TextLabel")
        lbl.Name              = "Label"
        lbl.Size              = UDim2.new(0, 50, 1, 0)
        lbl.Position          = UDim2.new(0, 4, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text              = label
        lbl.TextColor3        = C.TEXT
        lbl.Font              = Enum.Font.Gotham
        lbl.TextSize          = 11
        lbl.ZIndex            = 2
        lbl.Parent            = frame
    end

    return frame
end

-- ── Utility: make label ────────────────────────────────────────────────────────
local function MakeLabel(parent, name, pos, size, text, textSize, color, font, xAlign)
    local lbl = Instance.new("TextLabel")
    lbl.Name              = name
    lbl.Size              = size
    lbl.Position          = pos
    lbl.BackgroundTransparency = 1
    lbl.Text              = text or ""
    lbl.TextColor3        = color or C.TEXT
    lbl.Font              = font or Enum.Font.Gotham
    lbl.TextSize          = textSize or 14
    lbl.TextXAlignment    = xAlign or Enum.TextXAlignment.Left
    lbl.Parent            = parent
    return lbl
end

-- ── Main frame (bottom-left corner) ──────────────────────────────────────────
local Main = Instance.new("Frame")
Main.Name             = "Main"
Main.Size             = UDim2.new(0, 340, 0, 130)
Main.Position         = UDim2.new(0, 16, 1, -146)
Main.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
Main.BackgroundTransparency = 0.3
Main.BorderColor3     = C.BORDER
Main.BorderSizePixel  = 1
Main.Parent           = gui

-- Health bar
local HealthBar = MakeBar(Main, "HealthBar",
    UDim2.new(0, 8, 0, 8), UDim2.new(1, -16, 0, 18), C.HEALTH, nil)
MakeLabel(HealthBar, "Label", UDim2.new(0, 4, 0, 1), UDim2.new(0.5, 0, 1, -2), "HP", 10, C.MUTED)

-- Armor bar
local ArmorBar = MakeBar(Main, "ArmorBar",
    UDim2.new(0, 8, 0, 30), UDim2.new(1, -16, 0, 12), C.ARMOR, nil)
MakeLabel(ArmorBar, "Label", UDim2.new(0, 4, 0, 0), UDim2.new(0.5, 0, 1, 0), "ARM", 9, C.MUTED)

-- Energy bar
local EnergyBar = MakeBar(Main, "EnergyBar",
    UDim2.new(0, 8, 0, 46), UDim2.new(1, -16, 0, 12), C.ENERGY, nil)
MakeLabel(EnergyBar, "Label", UDim2.new(0, 4, 0, 0), UDim2.new(0.5, 0, 1, 0), "EN", 9, C.MUTED)

-- Identity Load bar
local ILBar = MakeBar(Main, "IdentityLoadBar",
    UDim2.new(0, 8, 0, 62), UDim2.new(1, -16, 0, 12), C.IL, nil)
ILBar:FindFirstChild("Fill").BackgroundColor3 = C.IL

-- IL Label
local ILLabel = MakeLabel(Main, "ILLabel",
    UDim2.new(0, 8, 0, 78), UDim2.new(1, -16, 0, 16),
    "IDENTITY LOAD: 0 / 100 [Intact]", 11, C.IL)

-- Ammo display (bottom right of Main)
local AmmoFrame = Instance.new("Frame")
AmmoFrame.Name             = "AmmoDisplay"
AmmoFrame.Size             = UDim2.new(0, 160, 0, 32)
AmmoFrame.Position         = UDim2.new(1, -168, 0, 90)
AmmoFrame.BackgroundTransparency = 1
AmmoFrame.Parent           = Main

local AmmoCount = Instance.new("TextLabel")
AmmoCount.Name         = "Count"
AmmoCount.Size         = UDim2.new(1, 0, 1, 0)
AmmoCount.BackgroundTransparency = 1
AmmoCount.Text         = "30 / 30"
AmmoCount.TextColor3   = C.TEXT
AmmoCount.Font         = Enum.Font.GothamBold
AmmoCount.TextSize     = 24
AmmoCount.TextXAlignment = Enum.TextXAlignment.Right
AmmoCount.Parent       = AmmoFrame

-- Low health pulse overlay
local LowHealthPulse = Instance.new("Frame")
LowHealthPulse.Name             = "LowHealthPulse"
LowHealthPulse.Size             = UDim2.new(1, 0, 1, 0)
LowHealthPulse.BackgroundColor3 = C.DANGER
LowHealthPulse.BackgroundTransparency = 0.85
LowHealthPulse.BorderSizePixel  = 0
LowHealthPulse.Visible          = false
LowHealthPulse.ZIndex           = 10
LowHealthPulse.Parent           = gui

-- ── Overdrive Gauge (bottom center) ──────────────────────────────────────────
local OverdriveGauge = MakeBar(gui, "OverdriveGauge",
    UDim2.new(0.5, -100, 1, -50), UDim2.new(0, 200, 0, 14),
    C.OVERDRIVE, nil)
OverdriveGauge.Visible = false

local OverdriveTimer = MakeLabel(gui, "OverdriveTimer",
    UDim2.new(0.5, -30, 1, -68), UDim2.new(0, 60, 0, 18),
    "", 16, C.OVERDRIVE, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
OverdriveTimer.Visible = false

-- ── Notification Frame (top center) ──────────────────────────────────────────
local NotifFrame = Instance.new("Frame")
NotifFrame.Name             = "NotificationFrame"
NotifFrame.Size             = UDim2.new(0, 520, 0, 36)
NotifFrame.Position         = UDim2.new(0.5, -260, 0, 24)
NotifFrame.BackgroundColor3 = C.PANEL
NotifFrame.BackgroundTransparency = 1
NotifFrame.BorderColor3     = C.ACCENT
NotifFrame.BorderSizePixel  = 1
NotifFrame.Visible          = false
NotifFrame.Parent           = gui

local NotifLabel = Instance.new("TextLabel")
NotifLabel.Name              = "NotifLabel"
NotifLabel.Size              = UDim2.new(1, -16, 1, 0)
NotifLabel.Position          = UDim2.new(0, 8, 0, 0)
NotifLabel.BackgroundTransparency = 1
NotifLabel.Text              = ""
NotifLabel.TextColor3        = C.TEXT
NotifLabel.Font              = Enum.Font.Gotham
NotifLabel.TextSize          = 14
NotifLabel.TextXAlignment    = Enum.TextXAlignment.Center
NotifLabel.Parent            = NotifFrame

-- ── Objective Panel (right side) ─────────────────────────────────────────────
local ObjectivePanel = Instance.new("ScrollingFrame")
ObjectivePanel.Name             = "ObjectivePanel"
ObjectivePanel.Size             = UDim2.new(0, 320, 0, 200)
ObjectivePanel.Position         = UDim2.new(1, -336, 0.5, -100)
ObjectivePanel.BackgroundColor3 = C.PANEL
ObjectivePanel.BackgroundTransparency = 0.4
ObjectivePanel.BorderColor3     = C.BORDER
ObjectivePanel.BorderSizePixel  = 1
ObjectivePanel.ScrollBarThickness = 4
ObjectivePanel.Visible          = false
ObjectivePanel.Parent           = gui

MakeLabel(ObjectivePanel, "Header",
    UDim2.new(0, 8, 0, 4), UDim2.new(1, -16, 0, 18),
    "OBJECTIVES", 11, C.MUTED, Enum.Font.GothamBold)

-- ── Boss Panel (top center, replaces notif during boss) ───────────────────────
local BossPanel = Instance.new("Frame")
BossPanel.Name             = "BossPanel"
BossPanel.Size             = UDim2.new(0, 500, 0, 56)
BossPanel.Position         = UDim2.new(0.5, -250, 0, 12)
BossPanel.BackgroundColor3 = Color3.fromRGB(14, 8, 12)
BossPanel.BackgroundTransparency = 0.2
BossPanel.BorderColor3     = C.DANGER
BossPanel.BorderSizePixel  = 1
BossPanel.Visible          = false
BossPanel.Parent           = gui

MakeLabel(BossPanel, "BossName",
    UDim2.new(0, 8, 0, 4), UDim2.new(1, -16, 0, 18),
    "BOSS", 15, C.DANGER, Enum.Font.GothamBold, Enum.TextXAlignment.Center)

local BossBar = MakeBar(BossPanel, "BossBar",
    UDim2.new(0, 8, 0, 26), UDim2.new(1, -16, 0, 16),
    C.DANGER, nil)

MakeLabel(BossPanel, "BossPhase",
    UDim2.new(0, 8, 0, 42), UDim2.new(1, -16, 0, 14),
    "Phase 1", 11, C.MUTED, nil, Enum.TextXAlignment.Center)

-- ── Incursion Alert (top, flashing) ──────────────────────────────────────────
local IncursionAlert = Instance.new("Frame")
IncursionAlert.Name             = "IncursionAlert"
IncursionAlert.Size             = UDim2.new(0, 420, 0, 32)
IncursionAlert.Position         = UDim2.new(0.5, -210, 0, 80)
IncursionAlert.BackgroundColor3 = Color3.fromRGB(60, 10, 10)
IncursionAlert.BackgroundTransparency = 0.4
IncursionAlert.BorderColor3     = C.DANGER
IncursionAlert.BorderSizePixel  = 2
IncursionAlert.Visible          = false
IncursionAlert.Parent           = gui

MakeLabel(IncursionAlert, "IncursionLabel",
    UDim2.new(0, 8, 0, 4), UDim2.new(1, -16, 0, 24),
    "INCURSION EVENT", 15, C.DANGER, Enum.Font.GothamBold, Enum.TextXAlignment.Center)

-- ── Damage Flash overlay ──────────────────────────────────────────────────────
local DamageFlash = Instance.new("Frame")
DamageFlash.Name             = "DamageFlash"
DamageFlash.Size             = UDim2.new(1, 0, 1, 0)
DamageFlash.BackgroundColor3 = C.DANGER
DamageFlash.BackgroundTransparency = 1
DamageFlash.BorderSizePixel  = 0
DamageFlash.ZIndex           = 5
DamageFlash.Visible          = false
DamageFlash.Parent           = gui

-- ── EMP Glitch overlay ────────────────────────────────────────────────────────
local EMPGlitch = Instance.new("Frame")
EMPGlitch.Name             = "EMPGlitch"
EMPGlitch.Size             = UDim2.new(1, 0, 1, 0)
EMPGlitch.BackgroundColor3 = Color3.fromRGB(0, 200, 220)
EMPGlitch.BackgroundTransparency = 0.85
EMPGlitch.BorderSizePixel  = 0
EMPGlitch.ZIndex           = 6
EMPGlitch.Visible          = false
EMPGlitch.Parent           = gui

-- Static noise label
local glitchLabel = Instance.new("TextLabel")
glitchLabel.Size   = UDim2.new(1, 0, 1, 0)
glitchLabel.BackgroundTransparency = 1
glitchLabel.Text   = "EMP DISRUPTION ACTIVE"
glitchLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
glitchLabel.Font   = Enum.Font.GothamBold
glitchLabel.TextSize = 18
glitchLabel.ZIndex = 7
glitchLabel.Parent = EMPGlitch

-- ── Flashback Frame ───────────────────────────────────────────────────────────
local FlashbackFrame = Instance.new("Frame")
FlashbackFrame.Name        = "FlashbackFrame"
FlashbackFrame.Size        = UDim2.new(1, 0, 1, 0)
FlashbackFrame.BackgroundColor3 = Color3.fromRGB(180, 160, 200)
FlashbackFrame.BackgroundTransparency = 0.75
FlashbackFrame.BorderSizePixel = 0
FlashbackFrame.ZIndex      = 8
FlashbackFrame.Visible     = false
FlashbackFrame.Parent      = gui

MakeLabel(FlashbackFrame, "FlashbackText",
    UDim2.new(0.5, -200, 0.5, -20), UDim2.new(0, 400, 0, 40),
    "MEMORY FRAGMENT DETECTED", 22, Color3.fromRGB(220, 200, 240),
    Enum.Font.GothamBold, Enum.TextXAlignment.Center)

-- ── Status Effects list (bottom left, above vitals) ──────────────────────────
local StatusEffects = Instance.new("Frame")
StatusEffects.Name             = "StatusEffects"
StatusEffects.Size             = UDim2.new(0, 200, 0, 40)
StatusEffects.Position         = UDim2.new(0, 16, 1, -160)
StatusEffects.BackgroundTransparency = 1
StatusEffects.Parent           = gui

-- Auto-layout for status effect icons
local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection  = Enum.FillDirection.Horizontal
listLayout.Padding        = UDim.new(0, 4)
listLayout.Parent         = StatusEffects

-- ── Damage Numbers anchor ─────────────────────────────────────────────────────
-- Actual damage number labels are created dynamically as BillboardGuis on the character
local DamageNumbers = Instance.new("Frame")
DamageNumbers.Name             = "DamageNumbers"
DamageNumbers.Size             = UDim2.new(0, 1, 0, 1)
DamageNumbers.BackgroundTransparency = 1
DamageNumbers.Parent           = gui

-- ── Reload Indicator ─────────────────────────────────────────────────────────
local ReloadIndicator = Instance.new("TextLabel")
ReloadIndicator.Name        = "ReloadIndicator"
ReloadIndicator.Size        = UDim2.new(0, 120, 0, 24)
ReloadIndicator.Position    = UDim2.new(0.5, -60, 1, -90)
ReloadIndicator.BackgroundTransparency = 1
ReloadIndicator.Text        = "RELOADING..."
ReloadIndicator.TextColor3  = C.ENERGY
ReloadIndicator.Font        = Enum.Font.GothamBold
ReloadIndicator.TextSize    = 16
ReloadIndicator.TextXAlignment = Enum.TextXAlignment.Center
ReloadIndicator.Visible     = false
ReloadIndicator.Parent      = gui

-- ── Rep Toast ────────────────────────────────────────────────────────────────
local RepToast = Instance.new("Frame")
RepToast.Name             = "RepToast"
RepToast.Size             = UDim2.new(0, 260, 0, 30)
RepToast.Position         = UDim2.new(1, -280, 1, -190)
RepToast.BackgroundColor3 = C.PANEL
RepToast.BackgroundTransparency = 1
RepToast.BorderColor3     = C.BORDER
RepToast.BorderSizePixel  = 1
RepToast.Visible          = false
RepToast.Parent           = gui

local RepLabel = Instance.new("TextLabel")
RepLabel.Size   = UDim2.new(1, -8, 1, 0)
RepLabel.Position = UDim2.new(0, 8, 0, 0)
RepLabel.BackgroundTransparency = 1
RepLabel.Text   = ""
RepLabel.Font   = Enum.Font.Gotham
RepLabel.TextSize = 13
RepLabel.TextXAlignment = Enum.TextXAlignment.Right
RepLabel.Parent = RepToast

-- ── Crosshair (center dot) ────────────────────────────────────────────────────
local CrosshairFrame = Instance.new("Frame")
CrosshairFrame.Name             = "Crosshair"
CrosshairFrame.Size             = UDim2.new(0, 10, 0, 10)
CrosshairFrame.Position         = UDim2.new(0.5, -5, 0.5, -5)
CrosshairFrame.BackgroundTransparency = 1
CrosshairFrame.Parent           = gui

-- Dot
local dot = Instance.new("Frame")
dot.Size             = UDim2.new(0, 4, 0, 4)
dot.Position         = UDim2.new(0.5, -2, 0.5, -2)
dot.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
dot.BackgroundTransparency = 0.2
dot.BorderSizePixel  = 0
dot.Parent           = CrosshairFrame

-- Corners
local corners = {
    { UDim2.new(0, 0, 0, 0),  UDim2.new(0, 3, 0, 1) },
    { UDim2.new(1, -3, 0, 0), UDim2.new(0, 3, 0, 1) },
    { UDim2.new(0, 0, 1, -1), UDim2.new(0, 3, 0, 1) },
    { UDim2.new(1, -3, 1, -1),UDim2.new(0, 3, 0, 1) },
    { UDim2.new(0.5, -0.5, 0, 0), UDim2.new(0, 1, 0, 3) },
    { UDim2.new(0.5, -0.5, 1, -3),UDim2.new(0, 1, 0, 3) },
}
for _, c in ipairs(corners) do
    local line = Instance.new("Frame")
    line.Position           = c[1]
    line.Size               = c[2]
    line.BackgroundColor3   = Color3.fromRGB(220, 220, 220)
    line.BackgroundTransparency = 0.2
    line.BorderSizePixel    = 0
    line.Parent             = CrosshairFrame
end

-- ── Key Binds Reminder (bottom right, small) ─────────────────────────────────
local KeyHints = Instance.new("Frame")
KeyHints.Name             = "KeyHints"
KeyHints.Size             = UDim2.new(0, 180, 0, 80)
KeyHints.Position         = UDim2.new(1, -194, 1, -96)
KeyHints.BackgroundColor3 = C.PANEL
KeyHints.BackgroundTransparency = 0.6
KeyHints.BorderColor3     = C.BORDER
KeyHints.BorderSizePixel  = 1
KeyHints.Parent           = gui

local hints = {
    "[Q] Overdrive",
    "[E] Secondary",
    "[F] Body System",
    "[T] Aug Menu  [M] Missions",
}
for i, hint in ipairs(hints) do
    MakeLabel(KeyHints, "Hint" .. i,
        UDim2.new(0, 6, 0, (i - 1) * 18 + 4), UDim2.new(1, -12, 0, 16),
        hint, 10, C.MUTED, Enum.Font.Gotham, Enum.TextXAlignment.Left)
end

print("[HUD] Layout built.")
