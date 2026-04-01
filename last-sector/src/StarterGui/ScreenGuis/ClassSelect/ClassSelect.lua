-- ClassSelect.lua (LocalScript inside ClassSelect ScreenGui)
-- The class selection screen shown on first login.
-- Human / Cyborg / Android — each with full descriptor, stat preview,
-- and starting loadout information before the player commits.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player  = Players.LocalPlayer
local gui     = script.Parent  -- ClassSelect ScreenGui
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
local Modules = ReplicatedStorage:WaitForChild("Modules")

local GameData     = require(Modules:WaitForChild("GameData"))
local WeaponData   = require(Modules:WaitForChild("WeaponData"))
local NetworkEvents= require(Modules:WaitForChild("NetworkEvents"))

-- ── Layout References (expected in the ScreenGui) ─────────────────────────────
local Background     = gui:WaitForChild("Background")
local Title          = Background:WaitForChild("Title")
local Subtitle       = Background:WaitForChild("Subtitle")
local ClassContainer = Background:WaitForChild("ClassContainer")
local ConfirmButton  = Background:WaitForChild("ConfirmButton")
local DetailPanel    = Background:WaitForChild("DetailPanel")
local DetailTitle    = DetailPanel:WaitForChild("Title")
local DetailLore     = DetailPanel:WaitForChild("Lore")
local DetailStats    = DetailPanel:WaitForChild("Stats")
local DetailLoadout  = DetailPanel:WaitForChild("Loadout")

-- ── Class Configuration ────────────────────────────────────────────────────────
local ClassConfig = {
    {
        Id       = "Human",
        Label    = "HUMAN",
        Tagline  = "Volatile. Adaptable. Intact.",
        Lore     = [[
You are still mostly you. That is either your greatest strength or your single greatest liability depending on the next thirty minutes.

Humans have the best social blend — you can still walk through civilian checkpoints. You rely on gear, tactics, and contracts rather than installed systems. You recover faster from psychological damage. You can go places androids can't.

Late-game Human builds are terrifying specialists, not peasants with rifles. The operators who make it to high level as Human do so by understanding everything about how the augmented world works and weaponizing that understanding from the outside.

Overdrive: Break State
Near-death adrenaline cascade. Accuracy peaks. Pain suppression activates. You become horrifyingly precise right when everything else has gone wrong.
        ]],
        Stats    = GameData.ClassBaseStats.Human,
        Color    = Color3.fromRGB(160, 200, 160),
        Loadout  = WeaponData.StartingLoadouts.Human,
    },
    {
        Id       = "Cyborg",
        Label    = "CYBORG",
        Tagline  = "Flesh remains. Systems take over.",
        Lore     = [[
The broad path. The one most people end up on. You kept something biological, which means you kept something human — and everything that word costs.

Arms can be swapped. Legs overclocked. Optics replaced. Spine batteries installed. Bone armor threaded in. Reflex governors shattered. The toolkit is enormous and the expression is yours.

Cyborg builds range from blade-shooter hybrids to mobile suppression platforms to near-invisible infiltration systems. The same chassis can do any of it depending on how you build.

Overdrive: Overclock
Governor limiters shatter. Recoil becomes momentum. Heat vents blow. Every system pushes past rated capacity for as long as the body can hold it.
        ]],
        Stats    = GameData.ClassBaseStats.Cyborg,
        Color    = Color3.fromRGB(100, 160, 220),
        Loadout  = WeaponData.StartingLoadouts.Cyborg,
    },
    {
        Id       = "Android",
        Label    = "ANDROID",
        Tagline  = "The question is whether you count.",
        Lore     = [[
Synthetic replacement, memory-backed chassis, or reconstructed person whose original humanity is now legally questionable. You are the most capable operator in the Strata and the most surveilled.

Best system integration. Weirdest module compatibility. Strongest synergy with machine networks, drones, and ghost-memory weapons. Overseers recognize you as something approaching kin. The Machine Cult calls you halfway there.

Anti-synth laws mean corporate districts are dangerous. Factions distrust you until they don't. Identity Load hits harder and faster. Some humans will never stop asking whether you are real.

You probably are. But you will have to decide what that means.

Overdrive: Ghost Sync
Memory lattice expands. Ghost routines deploy simultaneously. You become multiple, occupying tactical space in ways that defy targeting logic.
        ]],
        Stats    = GameData.ClassBaseStats.Android,
        Color    = Color3.fromRGB(180, 100, 220),
        Loadout  = WeaponData.StartingLoadouts.Android,
    },
}

-- ── State ─────────────────────────────────────────────────────────────────────
local selectedClass = nil
local classButtons  = {}

-- ── Build Class Buttons ────────────────────────────────────────────────────────
local function BuildClassButton(config, index)
    local btn = Instance.new("TextButton")
    btn.Name             = config.Id
    btn.Size             = UDim2.new(0.3, -10, 1, 0)
    btn.Position         = UDim2.new((index - 1) * 0.333, 5, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
    btn.BorderColor3     = Color3.fromRGB(60, 65, 80)
    btn.BorderSizePixel  = 2
    btn.AutoButtonColor  = false
    btn.Text             = ""
    btn.Parent           = ClassContainer

    -- Label
    local label = Instance.new("TextLabel")
    label.Size             = UDim2.new(1, 0, 0, 40)
    label.Position         = UDim2.new(0, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text             = config.Label
    label.TextColor3       = config.Color
    label.Font             = Enum.Font.GothamBold
    label.TextSize         = 24
    label.Parent           = btn

    -- Tagline
    local tagline = Instance.new("TextLabel")
    tagline.Size             = UDim2.new(1, -10, 0, 30)
    tagline.Position         = UDim2.new(0, 5, 0, 65)
    tagline.BackgroundTransparency = 1
    tagline.Text             = config.Tagline
    tagline.TextColor3       = Color3.fromRGB(160, 160, 180)
    tagline.Font             = Enum.Font.Gotham
    tagline.TextSize         = 14
    tagline.TextWrapped      = true
    tagline.Parent           = btn

    -- Stat strip
    local statStrip = Instance.new("Frame")
    statStrip.Size            = UDim2.new(1, -10, 0, 90)
    statStrip.Position        = UDim2.new(0, 5, 0, 110)
    statStrip.BackgroundTransparency = 1
    statStrip.Parent          = btn

    local statNames = { "MaxHealth", "MaxArmor", "MaxEnergy", "MoveSpeed", "IdentityLoadMax" }
    local statLabels= { "HEALTH", "ARMOR", "ENERGY", "SPEED", "IL MAX" }
    for i, statName in ipairs(statNames) do
        local statLabel = Instance.new("TextLabel")
        statLabel.Size      = UDim2.new(1, 0, 0, 16)
        statLabel.Position  = UDim2.new(0, 0, 0, (i-1) * 17)
        statLabel.BackgroundTransparency = 1
        statLabel.Text      = statLabels[i] .. ":  " .. (config.Stats[statName] or "--")
        statLabel.TextColor3= Color3.fromRGB(140, 145, 160)
        statLabel.Font      = Enum.Font.Gotham
        statLabel.TextSize  = 12
        statLabel.TextXAlignment = Enum.TextXAlignment.Left
        statLabel.Parent    = statStrip
    end

    classButtons[config.Id] = btn

    -- Hover effect
    btn.MouseEnter:Connect(function()
        if selectedClass ~= config.Id then
            TweenService:Create(btn, TweenInfo.new(0.15),
                { BackgroundColor3 = Color3.fromRGB(30, 32, 45) }):Play()
        end
        ShowDetail(config)
    end)
    btn.MouseLeave:Connect(function()
        if selectedClass ~= config.Id then
            TweenService:Create(btn, TweenInfo.new(0.15),
                { BackgroundColor3 = Color3.fromRGB(20, 22, 30) }):Play()
        end
    end)

    btn.Activated:Connect(function()
        SelectClass(config)
    end)

    return btn
end

-- ── Show Detail Panel ─────────────────────────────────────────────────────────
function ShowDetail(config)
    DetailTitle.Text       = config.Label
    DetailTitle.TextColor3 = config.Color
    DetailLore.Text        = config.Lore:match("^%s*(.-)%s*$")

    -- Loadout
    local primary   = WeaponData.GetById(config.Loadout.primary)
    local secondary = WeaponData.GetById(config.Loadout.secondary)
    DetailLoadout.Text =
        "Starting Primary:    " .. (primary and primary.DisplayName or "Unknown") ..
        "\nStarting Secondary: " .. (secondary and secondary.DisplayName or "Unknown")

    -- Stats
    local s = config.Stats
    DetailStats.Text =
        string.format("HP: %d    ARMOR: %d    ENERGY: %d\nSPEED: %d    IL MAX: %d    REGEN: %.1f/s",
            s.MaxHealth, s.MaxArmor, s.MaxEnergy,
            s.MoveSpeed, s.IdentityLoadMax, s.RegenRate
        )

    DetailPanel.Visible = true
end

-- ── Select Class ───────────────────────────────────────────────────────────────
function SelectClass(config)
    selectedClass = config.Id

    for id, btn in pairs(classButtons) do
        local isSelected = (id == config.Id)
        TweenService:Create(btn, TweenInfo.new(0.2),
            { BackgroundColor3 = isSelected and Color3.fromRGB(30, 38, 55) or Color3.fromRGB(20, 22, 30) }):Play()
        btn.BorderColor3 = isSelected and config.Color or Color3.fromRGB(60, 65, 80)
    end

    ConfirmButton.Visible  = true
    ConfirmButton.Text     = "DEPLOY AS " .. config.Label
    ConfirmButton.TextColor3 = config.Color
    ShowDetail(config)
end

-- ── Confirm ───────────────────────────────────────────────────────────────────
ConfirmButton.Activated:Connect(function()
    if not selectedClass then return end

    -- Lock button
    ConfirmButton.Text    = "DEPLOYING..."
    ConfirmButton.Active  = false

    -- Send class selection to server
    Remotes:WaitForChild(NetworkEvents.C2S.SelectClass):FireServer(selectedClass)

    -- Fade out
    TweenService:Create(Background, TweenInfo.new(1.0), { BackgroundTransparency = 1 }):Play()
    task.wait(1.0)
    gui.Enabled = false
end)

-- ── Initialise ────────────────────────────────────────────────────────────────
ConfirmButton.Visible = false
DetailPanel.Visible   = false

Title.Text    = "LAST SECTOR"
Subtitle.Text = "SELECT OPERATIONAL CHASSIS"

for i, config in ipairs(ClassConfig) do
    BuildClassButton(config, i)
end

-- Auto-show detail for Cyborg (default hover)
ShowDetail(ClassConfig[2])

print("[ClassSelect] Initialised.")
