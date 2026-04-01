-- CombatClient.client.lua
-- Handles all client-side combat input: aiming, shooting, reloading,
-- secondary tool usage, body-system activations, and overdrive triggering.
-- Sends validated input events to server via RemoteEvents.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse  = player:GetMouse()

-- ── Remotes ───────────────────────────────────────────────────────────────────
local Remotes       = ReplicatedStorage:WaitForChild("Remotes", 30)
local Modules       = ReplicatedStorage:WaitForChild("Modules")
local NetworkEvents = require(Modules:WaitForChild("NetworkEvents"))
local WeaponData    = require(Modules:WaitForChild("WeaponData"))
local GameData      = require(Modules:WaitForChild("GameData"))

local function fire(name, ...)
    local re = Remotes:FindFirstChild(name)
    if re then re:FireServer(...) end
end

-- ── Combat State ──────────────────────────────────────────────────────────────
local State = {
    -- Weapon
    CurrentWeapon   = nil,   -- weapon definition
    CurrentAmmo     = 0,
    MaxAmmo         = 0,
    IsReloading     = false,
    ReloadTimer     = 0,
    FireTimer       = 0,     -- time since last shot (for fire rate limit)
    IsTriggerHeld   = false,

    -- Secondary
    CurrentSecondary= nil,
    SecondaryCharges= 0,

    -- Overdrive
    OverdriveCooldown= 0,
    OverdriveActive  = false,

    -- Aim
    IsAiming        = false,
    AimFOV          = 70,
    HipFOV          = 90,
    CurrentFOV      = 90,

    -- Crosshair spread
    Spread          = 0,
    MaxSpread       = 10,
    SpreadDecay     = 8,

    -- Recoil
    RecoilX         = 0,
    RecoilY         = 0,
}

-- ── Weapon Setup ──────────────────────────────────────────────────────────────
local function SetupWeapon(weaponId)
    local wDef = WeaponData.GetById(weaponId)
    if not wDef then return end

    State.CurrentWeapon = wDef
    State.CurrentAmmo   = wDef.Stats.MagSize or 30
    State.MaxAmmo       = wDef.Stats.MagSize or 30
    State.IsReloading   = false
    State.FireTimer     = 0
    State.Spread        = 0

    -- Update HUD ammo
    local clientMain = _G.ClientMain
    if clientMain then
        local hud = player.PlayerGui:FindFirstChild("HUD")
        if hud and hud:FindFirstChild("HUDController") then
            -- HUD update handled by HUDClient
        end
    end
end

local function SetupSecondary(toolId)
    local tool = WeaponData.GetById(toolId)
    if not tool then return end

    State.CurrentSecondary = tool
    State.SecondaryCharges = tool.Stats.CarryCount or 1
end

-- Wait for player data to set initial loadout
task.delay(2, function()
    local clientMain = _G.ClientMain
    if clientMain and clientMain.State.PlayerData then
        local pData = clientMain.State.PlayerData
        SetupWeapon(pData.Weapons.Primary)
        SetupSecondary(pData.Weapons.Secondary)
    end
end)

-- ── Raycast Fire ──────────────────────────────────────────────────────────────
local function DoRaycast()
    local char = player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    -- Calculate spread offset
    local spread = math.rad(State.Spread * 0.1)
    local direction = camera.CFrame.LookVector

    if spread > 0 then
        local rx = (math.random() - 0.5) * 2 * spread
        local ry = (math.random() - 0.5) * 2 * spread
        direction = (camera.CFrame * CFrame.Angles(rx, ry, 0)).LookVector
    end

    local origin = camera.CFrame.Position
    local rayDir = direction * GameData.Combat.MaxDamageDistance

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { char }
    params.FilterType = Enum.RaycastFilterType.Exclude

    local result = workspace:Raycast(origin, rayDir, params)

    if not result then
        return { type = "none" }
    end

    local hitInstance = result.Instance
    local hitChar     = hitInstance.Parent

    -- Check if we hit a player character
    local hitPlayer = Players:GetPlayerFromCharacter(hitChar)
    if hitPlayer and hitPlayer ~= player then
        return {
            type        = "character",
            targetId    = hitChar.Name,
            hitPartName = hitInstance.Name,
            distance    = result.Distance,
        }
    end

    -- Check if we hit an NPC
    local hitHum = hitChar:FindFirstChildOfClass("Humanoid")
    if hitHum then
        return {
            type        = "character",
            targetId    = hitChar.Name,
            hitPartName = hitInstance.Name,
            distance    = result.Distance,
        }
    end

    return {
        type     = "part",
        partName = hitInstance.Name,
        position = result.Position,
        distance = result.Distance,
    }
end

-- ── Fire Weapon ───────────────────────────────────────────────────────────────
local function TryFire()
    if not State.CurrentWeapon then return end
    if State.IsReloading then return end
    if State.CurrentAmmo <= 0 then
        TryReload()
        return
    end

    local wDef = State.CurrentWeapon
    local minInterval = 60 / (wDef.Stats.FireRate or 600)
    if State.FireTimer < minInterval then return end

    -- Consume ammo
    State.CurrentAmmo = State.CurrentAmmo - 1
    State.FireTimer   = 0

    -- Add recoil
    State.RecoilY = State.RecoilY + (wDef.Stats.Recoil or 0.3) * (State.IsAiming and 0.5 or 1.0)
    State.Spread  = math.min(State.MaxSpread, State.Spread + (wDef.Stats.Recoil or 0.3) * 2)

    -- Shotgun: multiple pellets
    local pellets = wDef.Stats.PelletCount or 1
    for _ = 1, pellets do
        local hitData = DoRaycast()
        if hitData and hitData.type ~= "none" then
            fire(NetworkEvents.C2S.FireWeapon, {
                weaponId  = wDef.Id,
                origin    = camera.CFrame.Position,
                direction = camera.CFrame.LookVector,
                hitData   = hitData,
            })
        else
            fire(NetworkEvents.C2S.FireWeapon, {
                weaponId  = wDef.Id,
                origin    = camera.CFrame.Position,
                direction = camera.CFrame.LookVector,
                hitData   = { type = "none" },
            })
        end
    end

    -- Muzzle flash / local visual (placeholder)
    -- In full implementation: spawn a muzzle part or play VFX

    -- Update HUD
    local hud = player.PlayerGui:FindFirstChild("HUD")
    if hud then
        local ammoLabel = hud:FindFirstChild("AmmoDisplay", true)
        if ammoLabel then
            ammoLabel.Text = State.CurrentAmmo .. " / " .. State.MaxAmmo
        end
    end
end

-- ── Reload ────────────────────────────────────────────────────────────────────
function TryReload()
    if State.IsReloading then return end
    if State.CurrentAmmo >= State.MaxAmmo then return end
    if not State.CurrentWeapon then return end

    State.IsReloading = true
    local reloadTime  = State.CurrentWeapon.Stats.ReloadTime or 2.0

    fire(NetworkEvents.C2S.ReloadWeapon, State.CurrentWeapon.Id)

    task.delay(reloadTime, function()
        State.CurrentAmmo = State.MaxAmmo
        State.IsReloading = false

        local hud = player.PlayerGui:FindFirstChild("HUD")
        if hud then
            local ammoLabel = hud:FindFirstChild("AmmoDisplay", true)
            if ammoLabel then
                ammoLabel.Text = State.CurrentAmmo .. " / " .. State.MaxAmmo
            end
            local reloadIndicator = hud:FindFirstChild("ReloadIndicator", true)
            if reloadIndicator then reloadIndicator.Visible = false end
        end
    end)

    local hud = player.PlayerGui:FindFirstChild("HUD")
    if hud then
        local ri = hud:FindFirstChild("ReloadIndicator", true)
        if ri then ri.Visible = true end
    end
end

-- ── Use Secondary ──────────────────────────────────────────────────────────────
local function UseSecondary()
    if not State.CurrentSecondary then return end
    if State.SecondaryCharges <= 0 then return end

    local tool = State.CurrentSecondary
    State.SecondaryCharges = State.SecondaryCharges - 1

    local targetPos = mouse.Hit.Position

    fire(NetworkEvents.C2S.UseSecondary, tool.Id, targetPos)
end

-- ── Overdrive ─────────────────────────────────────────────────────────────────
local function TryActivateOverdrive()
    if State.OverdriveActive then return end
    if State.OverdriveCooldown > 0 then return end

    fire(NetworkEvents.C2S.ActivateOverdrive)
end

-- ── Aim Down Sights ───────────────────────────────────────────────────────────
local function SetAiming(aiming)
    State.IsAiming = aiming
    local targetFOV = aiming and State.AimFOV or State.HipFOV

    -- Smooth FOV transition
    local tween = game:GetService("TweenService"):Create(
        camera,
        TweenInfo.new(0.15, Enum.EasingStyle.Quad),
        { FieldOfView = targetFOV }
    )
    tween:Play()
end

-- ── Input Handling ────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        State.IsTriggerHeld = true

    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        SetAiming(true)

    elseif input.KeyCode == Enum.KeyCode.R then
        TryReload()

    elseif input.KeyCode == Enum.KeyCode.E then
        UseSecondary()

    elseif input.KeyCode == Enum.KeyCode.Q then
        TryActivateOverdrive()

    elseif input.KeyCode == Enum.KeyCode.F then
        -- Activate body-system aug
        local clientMain = _G.ClientMain
        if clientMain and clientMain.State.PlayerData then
            local augs = clientMain.State.PlayerData.Augmentations
            -- Prioritise active-use aug in Arms slot
            local activeAug = augs.Arms or augs.Head
            if activeAug then
                fire(NetworkEvents.C2S.ActivateBodySystem, activeAug)
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        State.IsTriggerHeld = false
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        SetAiming(false)
    end
end)

-- ── Overdrive server sync ─────────────────────────────────────────────────────
local Remotes2 = Remotes
Remotes2:WaitForChild(NetworkEvents.S2C.OverdriveActivated).OnClientEvent:Connect(function(overdriveId, duration, effects)
    State.OverdriveActive    = true
    State.OverdriveCooldown  = 0

    -- Overclock: recoil → momentum (visual: camera shake on fire)
    if overdriveId == "Overclock" then
        State.RecoilRecoilToMomentum = true
    end

    task.delay(duration, function()
        State.OverdriveActive           = false
        State.RecoilRecoilToMomentum    = false
    end)
end)

Remotes2:WaitForChild(NetworkEvents.S2C.OverdriveEnded).OnClientEvent:Connect(function()
    State.OverdriveActive = false
    -- Cooldown starts here (server manages authoritative cooldown; this is UI only)
    local clientMain = _G.ClientMain
    if clientMain and clientMain.State.PlayerData then
        local od = GameData.Overdrives[GameData.ClassBaseStats[clientMain.State.PlayerData.Class].OverdriveId]
        if od then
            State.OverdriveCooldown = od.Cooldown
        end
    end
end)

-- ── Per-Frame Update ──────────────────────────────────────────────────────────
RunService.RenderStepped:Connect(function(dt)
    -- Fire rate timer
    State.FireTimer = State.FireTimer + dt

    -- Overdrive cooldown timer
    if State.OverdriveCooldown > 0 then
        State.OverdriveCooldown = math.max(0, State.OverdriveCooldown - dt)
    end

    -- Held trigger: auto-fire for full-auto weapons
    if State.IsTriggerHeld and State.CurrentWeapon then
        if State.CurrentWeapon.Flags.fullAuto then
            TryFire()
        end
    end

    -- Spread decay
    if State.Spread > 0 then
        State.Spread = math.max(0, State.Spread - State.SpreadDecay * dt)
    end

    -- Recoil recovery (camera)
    if State.RecoilY > 0 then
        local recovery = dt * 3
        State.RecoilY = math.max(0, State.RecoilY - recovery)
        camera.CFrame = camera.CFrame * CFrame.Angles(-recovery * 0.5, 0, 0)
    end
end)

-- ── Single-shot on click (semi-auto / pump) ───────────────────────────────────
mouse.Button1Down:Connect(function()
    if not State.CurrentWeapon then return end
    if State.CurrentWeapon.Flags.fullAuto then return  -- handled by held trigger
    elseif State.CurrentWeapon.Flags.semiAuto
        or State.CurrentWeapon.Flags.pumpAction
        or State.CurrentWeapon.Flags.boltAction then
        TryFire()
    end
end)

print("[CombatClient] Initialised.")
