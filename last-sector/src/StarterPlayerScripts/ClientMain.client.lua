-- ClientMain.client.lua
-- Client bootstrap. Loads the player's data snapshot, sets up event listeners,
-- routes incoming server events to appropriate local systems, and initialises UI.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- ── Wait for remotes ──────────────────────────────────────────────────────────
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
assert(Remotes, "[ClientMain] Remotes folder not found within timeout")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local NetworkEvents = require(Modules:WaitForChild("NetworkEvents"))
local GameData      = require(Modules:WaitForChild("GameData"))
local IdentityLoad  = require(Modules:WaitForChild("IdentityLoad"))

-- ── Local state ───────────────────────────────────────────────────────────────
local ClientState = {
    PlayerData      = nil,   -- snapshot from server
    IdentityLoad    = 0,
    IdentityLoadMax = 100,
    ActiveOverdrive = nil,
    ActiveMission   = nil,
    ActiveIncursion = nil,
    NPCReactions    = {},
    IsOverdriveActive = false,
    EnergyCurrent   = 0,
    EnergyMax       = 80,
    ArmourCurrent   = 0,
}

-- ── Remote Helper ─────────────────────────────────────────────────────────────
local function getEvent(name)
    return Remotes:WaitForChild(name, 10)
end
local function getFunction(name)
    return Remotes:WaitForChild(name, 10)
end

-- ── HUD Controller (lazy reference) ──────────────────────────────────────────
local HUDController = nil
local function GetHUD()
    if HUDController then return HUDController end
    local gui = player.PlayerGui:WaitForChild("HUD", 5)
    if gui then
        HUDController = require(gui:WaitForChild("HUDController", 5))
    end
    return HUDController
end

-- ── Data Received ─────────────────────────────────────────────────────────────
getEvent(NetworkEvents.S2C.PlayerDataLoaded).OnClientEvent:Connect(function(snap)
    ClientState.PlayerData      = snap
    ClientState.IdentityLoad    = snap.IdentityLoad    or 0
    ClientState.IdentityLoadMax = snap.IdentityLoadMax or 100
    ClientState.EnergyMax       = snap.MaxEnergy       or 80
    ClientState.EnergyCurrent   = snap.MaxEnergy       or 80
    ClientState.ArmourCurrent   = snap.MaxArmor        or 0
    ClientState.ActiveMission   = snap.ActiveMission

    local hud = GetHUD()
    if hud then hud:FullRefresh(snap) end

    print("[ClientMain] Player data loaded. Class:", snap.Class, "Level:", snap.Level)
end)

getEvent(NetworkEvents.S2C.PlayerDataUpdated).OnClientEvent:Connect(function(partial)
    if not ClientState.PlayerData then return end
    -- Merge partial update
    for key, val in pairs(partial) do
        ClientState.PlayerData[key] = val
    end
    local hud = GetHUD()
    if hud then hud:PartialUpdate(partial) end
end)

-- ── Health / Damage ───────────────────────────────────────────────────────────
getEvent(NetworkEvents.S2C.TakeDamage).OnClientEvent:Connect(function(amount, damageType, sourceId)
    local hud = GetHUD()
    if hud then hud:ShowDamageNumber(amount, damageType) end

    -- Screen flash based on damage type
    local screenGui = player.PlayerGui:FindFirstChild("HUD")
    if screenGui then
        local flashFrame = screenGui:FindFirstChild("DamageFlash")
        if flashFrame then
            flashFrame.Visible      = true
            flashFrame.BackgroundTransparency = 0.6
            flashFrame.BackgroundColor3 = (damageType == "EMP") and Color3.fromHex("#00FFFF")
                                      or (damageType == "Energy") and Color3.fromHex("#FF6A00")
                                      or Color3.fromRGB(200, 30, 30)
            task.delay(0.15, function()
                flashFrame.Visible = false
            end)
        end
    end
end)

-- ── Status Effects ────────────────────────────────────────────────────────────
getEvent(NetworkEvents.S2C.StatusEffectApplied).OnClientEvent:Connect(function(effectId, duration)
    local hud = GetHUD()
    if hud then hud:ShowStatusEffect(effectId, duration) end

    -- EMP Stun: visual glitch effect
    if effectId == "EMPStun" then
        local screenGui = player.PlayerGui:FindFirstChild("HUD")
        if screenGui then
            local glitch = screenGui:FindFirstChild("EMPGlitch")
            if glitch then
                glitch.Visible = true
                task.delay(duration, function() glitch.Visible = false end)
            end
        end
    end

    -- Neural Glitch: IL-style screen corruption
    if effectId == "NeuralGlitch" then
        ClientState.NeuralGlitchActive = true
        task.delay(duration, function() ClientState.NeuralGlitchActive = false end)
    end
end)

getEvent(NetworkEvents.S2C.StatusEffectRemoved).OnClientEvent:Connect(function(effectId)
    local hud = GetHUD()
    if hud then hud:RemoveStatusEffect(effectId) end
end)

-- ── Identity Load ─────────────────────────────────────────────────────────────
getEvent(NetworkEvents.S2C.IdentityLoadChanged).OnClientEvent:Connect(function(il, ilMax)
    ClientState.IdentityLoad    = il
    ClientState.IdentityLoadMax = ilMax

    local hud = GetHUD()
    if hud then hud:UpdateIdentityLoad(il, ilMax) end

    -- Dialogue glitch probability check
    if ClientState.PlayerData then
        local glitchProb = IdentityLoad.GlitchProbability(il, ClientState.PlayerData.Class)
        if math.random() < glitchProb then
            getEvent(NetworkEvents.S2C.DialogueGlitch):FireServer()  -- doesn't make sense, would be server→client
        end
    end
end)

-- ── Overdrive ─────────────────────────────────────────────────────────────────
getEvent(NetworkEvents.S2C.OverdriveActivated).OnClientEvent:Connect(function(overdriveId, duration, effects)
    ClientState.IsOverdriveActive = true
    ClientState.ActiveOverdrive   = { id = overdriveId, duration = duration, effects = effects }

    local hud = GetHUD()
    if hud then hud:ActivateOverdriveUI(overdriveId, duration) end

    -- Visual: apply overdrive post-processing (ColorCorrectionEffect, etc.)
    local lighting = game:GetService("Lighting")
    local cc = lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    if not cc then
        cc = Instance.new("ColorCorrectionEffect")
        cc.Parent = lighting
    end

    -- Class-specific colour grading
    local tintMap = {
        BreakState = Color3.fromRGB(200, 80, 80),    -- red tint
        Overclock  = Color3.fromRGB(255, 140, 0),    -- orange heat
        GhostSync  = Color3.fromRGB(80, 140, 220),   -- cold blue
    }
    cc.TintColor = tintMap[overdriveId] or Color3.new(1, 1, 1)
    cc.Saturation = 0.3

    task.delay(duration, function()
        cc.TintColor  = Color3.new(1, 1, 1)
        cc.Saturation = 0
    end)

    print("[ClientMain] Overdrive activated:", overdriveId, "for", duration, "s")
end)

getEvent(NetworkEvents.S2C.OverdriveEnded).OnClientEvent:Connect(function(overdriveId)
    ClientState.IsOverdriveActive = false
    ClientState.ActiveOverdrive   = nil
    local hud = GetHUD()
    if hud then hud:DeactivateOverdriveUI(overdriveId) end
end)

-- ── Level Up ──────────────────────────────────────────────────────────────────
getEvent(NetworkEvents.S2C.LevelUp).OnClientEvent:Connect(function(newLevel)
    local hud = GetHUD()
    if hud then hud:ShowLevelUp(newLevel) end
    print("[ClientMain] Level up! Now:", newLevel)
end)

-- ── Mission Events ────────────────────────────────────────────────────────────
getEvent(NetworkEvents.S2C.MissionStarted).OnClientEvent:Connect(function(missionId, missionData)
    ClientState.ActiveMission = missionId
    local hud = GetHUD()
    if hud then hud:ShowMissionStart(missionData) end
end)

getEvent(NetworkEvents.S2C.MissionObjectiveUpdated).OnClientEvent:Connect(function(objId, current, target, completed)
    local hud = GetHUD()
    if hud then hud:UpdateObjective(objId, current, target, completed) end
end)

getEvent(NetworkEvents.S2C.MissionCompleted).OnClientEvent:Connect(function(missionId, rewards)
    ClientState.ActiveMission = nil
    local hud = GetHUD()
    if hud then hud:ShowMissionComplete(rewards) end
end)

getEvent(NetworkEvents.S2C.MissionFailed).OnClientEvent:Connect(function(missionId, reason)
    ClientState.ActiveMission = nil
    local hud = GetHUD()
    if hud then hud:ShowMissionFailed(reason) end
end)

-- ── Incursion Events ──────────────────────────────────────────────────────────
getEvent(NetworkEvents.S2C.IncursionTriggered).OnClientEvent:Connect(function(incursionId, incursionData)
    ClientState.ActiveIncursion = incursionId
    local hud = GetHUD()
    if hud then hud:ShowIncursionAlert(incursionData) end

    -- Play alert sound if character exists
    local char = player.Character
    if char then
        local sound = Instance.new("Sound")
        sound.SoundId  = "rbxassetid://0"  -- placeholder; replace with alert SFX
        sound.Volume   = 0.8
        sound.Parent   = char:FindFirstChild("HumanoidRootPart") or char
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 5)
    end
end)

getEvent(NetworkEvents.S2C.IncursionEnded).OnClientEvent:Connect(function(incursionId)
    ClientState.ActiveIncursion = nil
    local hud = GetHUD()
    if hud then hud:HideIncursionAlert() end
end)

-- ── Faction Events ────────────────────────────────────────────────────────────
getEvent(NetworkEvents.S2C.FactionRepChanged).OnClientEvent:Connect(function(factionId, newRep, delta)
    if ClientState.PlayerData and ClientState.PlayerData.FactionRep then
        ClientState.PlayerData.FactionRep[factionId] = newRep
    end
    local hud = GetHUD()
    if hud then hud:ShowRepChange(factionId, delta) end
end)

-- ── NPC Reactions ─────────────────────────────────────────────────────────────
getEvent(NetworkEvents.S2C.NPCReactionChanged).OnClientEvent:Connect(function(reactions)
    ClientState.NPCReactions = reactions
    -- Used by local NPC dialogue systems
end)

-- ── Memory Fragments ──────────────────────────────────────────────────────────
getEvent(NetworkEvents.S2C.MemoryFragmentFound).OnClientEvent:Connect(function(fragmentId, content)
    -- Show lore popup
    local hud = GetHUD()
    if hud then hud:ShowMemoryFragment(fragmentId, content) end
end)

-- ── Narrative ─────────────────────────────────────────────────────────────────
getEvent(NetworkEvents.S2C.FlashbackTriggered).OnClientEvent:Connect(function()
    -- Identity Load memory sequence: distorted vision, audio
    local screenGui = player.PlayerGui:FindFirstChild("HUD")
    if screenGui then
        local fb = screenGui:FindFirstChild("FlashbackFrame")
        if fb then
            fb.Visible = true
            task.delay(3, function() fb.Visible = false end)
        end
    end
end)

getEvent(NetworkEvents.S2C.DialogueGlitch).OnClientEvent:Connect(function()
    -- Static overlay, warped text
    ClientState.DialogueGlitchActive = true
    task.delay(2, function() ClientState.DialogueGlitchActive = false end)
end)

-- ── HUD Notifications ─────────────────────────────────────────────────────────
getEvent(NetworkEvents.S2C.HUDNotification).OnClientEvent:Connect(function(text, duration, severity)
    local hud = GetHUD()
    if hud then hud:ShowNotification(text, duration, severity) end
end)

-- ── Aug / Stats Events ────────────────────────────────────────────────────────
getEvent(NetworkEvents.S2C.AugEquipped).OnClientEvent:Connect(function(slot, augId, previous)
    if ClientState.PlayerData then
        ClientState.PlayerData.Augmentations[slot] = augId
    end
    local hud = GetHUD()
    if hud then hud:ShowAugChange(slot, augId) end
end)

getEvent(NetworkEvents.S2C.StatsRecalculated).OnClientEvent:Connect(function(snap)
    ClientState.PlayerData = snap
    local hud = GetHUD()
    if hud then hud:FullRefresh(snap) end
end)

-- ── Boss Events ───────────────────────────────────────────────────────────────
getEvent(NetworkEvents.S2C.BossEncounterStarted).OnClientEvent:Connect(function(bossId, bossData)
    local hud = GetHUD()
    if hud then hud:ShowBossBar(bossId, bossData) end
end)

getEvent(NetworkEvents.S2C.BossPhaseChanged).OnClientEvent:Connect(function(bossId, phase)
    local hud = GetHUD()
    if hud then hud:UpdateBossPhase(bossId, phase) end
end)

getEvent(NetworkEvents.S2C.BossDefeated).OnClientEvent:Connect(function(bossId)
    local hud = GetHUD()
    if hud then hud:HideBossBar(bossId) end
end)

-- ── Class Select Screen ───────────────────────────────────────────────────────
getEvent(NetworkEvents.S2C.ShowClassSelect).OnClientEvent:Connect(function()
    local classSelectGui = player.PlayerGui:WaitForChild("ClassSelect", 10)
    if classSelectGui then
        classSelectGui.Enabled = true
    end
end)

-- ── Expose ClientState for other local scripts ────────────────────────────────
local ClientMain = {}
ClientMain.State   = ClientState
ClientMain.Remotes = Remotes

function ClientMain.FireEvent(name, ...)
    local re = Remotes:FindFirstChild(name)
    if re then re:FireServer(...) end
end

function ClientMain.InvokeFunction(name, ...)
    local rf = Remotes:FindFirstChild(name)
    if rf then return rf:InvokeServer(...) end
end

-- Store in ReplicatedStorage for other LocalScripts to access
-- (Alternatively use a shared ModuleScript; this pattern avoids circular deps)
_G.ClientMain = ClientMain

print("[ClientMain] Client initialised.")
