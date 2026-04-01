-- MovementClient.client.lua
-- Enhanced movement system for Last Sector.
-- Handles: slide, wall-kick, burst-step, jump jet, air dash, magnetic perch,
-- mantle shots, and grapple movement.
-- Movement capabilities are gated by the player's equipped leg augmentations.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local player   = Players.LocalPlayer
local camera   = workspace.CurrentCamera
local character= nil
local humanoid = nil
local hrp      = nil

-- ── Modules ───────────────────────────────────────────────────────────────────
local Modules       = ReplicatedStorage:WaitForChild("Modules")
local NetworkEvents = require(Modules:WaitForChild("NetworkEvents"))

-- ── Movement Capabilities ──────────────────────────────────────────────────────
-- Set when player data loads or augs change.
local Capabilities = {
    canSlide        = true,     -- everyone can slide
    canWallKick     = false,    -- leg aug
    canBurstStep    = false,    -- leg aug
    burstCount      = 3,
    canJumpJet      = false,    -- leg aug
    jumpJetHeight   = 20,
    canAirDash      = false,    -- leg aug (android/cult only)
    airDashCount    = 1,
    canMagneticPerch= false,    -- leg aug
    canGrapple      = false,    -- arm aug (tether harpoon)
    grappleRange    = 35,
    hasCrawlerLegs  = false,
    hasShockwaveLanding = false,
    shockwaveDamage = 40,
    shockwaveRadius = 8,
    isSilent        = false,
}

-- ── State ─────────────────────────────────────────────────────────────────────
local MoveState = {
    isSliding        = false,
    slideTimer       = 0,
    slideDuration    = 0.8,
    slideCooldown    = 0,
    slideCooldownMax = 2.0,
    slideDirection   = Vector3.zero,

    burstCharges     = 0,
    burstCooldown    = 0,

    airDashCharges   = 0,
    airDashCooldown  = 0,

    jumpJetCooldown  = 0,

    lastGrounded     = true,
    wasGrounded      = true,
    landHeight       = 0,

    isMagPerched     = false,
    grappleActive    = false,
    grappleTarget    = nil,

    wallKickCooldown = 0,
}

-- ── Character Setup ───────────────────────────────────────────────────────────
local function OnCharacterAdded(char)
    character = char
    humanoid  = char:WaitForChild("Humanoid")
    hrp       = char:WaitForChild("HumanoidRootPart")

    MoveState.isSliding   = false
    MoveState.burstCharges= Capabilities.burstCount
    MoveState.airDashCharges = Capabilities.airDashCount
    MoveState.landHeight  = hrp.Position.Y
end

player.CharacterAdded:Connect(OnCharacterAdded)
if player.Character then OnCharacterAdded(player.Character) end

-- ── Load Capabilities from Player Data ────────────────────────────────────────
local function RefreshCapabilities()
    local clientMain = _G.ClientMain
    if not clientMain or not clientMain.State.PlayerData then return end
    local data = clientMain.State.PlayerData
    local augs = data.Augmentations or {}

    -- Reset
    for k in pairs(Capabilities) do
        if type(Capabilities[k]) == "boolean" then Capabilities[k] = false end
        if type(Capabilities[k]) == "number" and k ~= "grappleRange" then Capabilities[k] = 0 end
    end
    Capabilities.canSlide   = true
    Capabilities.grappleRange = 35

    local AugmentationData = require(Modules:WaitForChild("AugmentationData"))

    for slot, augId in pairs(augs) do
        if not augId then continue end
        local aug = AugmentationData.GetById(augId)
        if not aug then continue end
        local s = aug.Stats

        if s.WallKick        then Capabilities.canWallKick  = true end
        if s.BurstStep       then Capabilities.canBurstStep = true; Capabilities.burstCount = s.BurstCount or 3 end
        if s.JumpJet         then Capabilities.canJumpJet   = true; Capabilities.jumpJetHeight = s.JumpJetHeight or 20 end
        if s.AirDash         then Capabilities.canAirDash   = true; Capabilities.airDashCount = s.AirDashCount or 1 end
        if s.MagneticPerch   then Capabilities.canMagneticPerch = true end
        if s.TetherHarpoon   then Capabilities.canGrapple   = true; Capabilities.grappleRange = s.TetherRange or 35 end
        if s.CrawlerLegs     then Capabilities.hasCrawlerLegs = true end
        if s.LandingShockwave then
            Capabilities.hasShockwaveLanding = true
            Capabilities.shockwaveDamage = s.ShockwaveDamage or 40
            Capabilities.shockwaveRadius = s.ShockwaveRadius or 8
        end
        if s.SilentMovement  then Capabilities.isSilent = true end
        if s.SlideDistance   then
            MoveState.slideDuration = 0.8 + (s.SlideDistance or 0) * 0.5
        end
    end

    MoveState.burstCharges   = Capabilities.burstCount
    MoveState.airDashCharges = Capabilities.airDashCount
    print("[MovementClient] Capabilities refreshed.")
end

-- Refresh 2s after start and when stats change
task.delay(2.5, RefreshCapabilities)
ReplicatedStorage:WaitForChild("Remotes", 30):WaitForChild(
    NetworkEvents.S2C.StatsRecalculated, 10
).OnClientEvent:Connect(RefreshCapabilities)

-- ── Slide ──────────────────────────────────────────────────────────────────────
local function StartSlide()
    if not character or not humanoid or not hrp then return end
    if MoveState.isSliding then return end
    if MoveState.slideCooldown > 0 then return end
    if humanoid.FloorMaterial == Enum.Material.Air then return end

    -- Slide direction = camera look projected on XZ plane
    local lookDir = camera.CFrame.LookVector
    MoveState.slideDirection = Vector3.new(lookDir.X, 0, lookDir.Z).Unit

    MoveState.isSliding  = true
    MoveState.slideTimer = MoveState.slideDuration

    -- Reduce character height for crouch
    humanoid.HipHeight = humanoid.HipHeight - 1.5

    -- Apply velocity burst
    local bv = Instance.new("BodyVelocity")
    bv.Name      = "SlideVelocity"
    bv.Velocity  = MoveState.slideDirection * 50
    bv.MaxForce  = Vector3.new(1e5, 0, 1e5)
    bv.Parent    = hrp
    game:GetService("Debris"):AddItem(bv, MoveState.slideDuration)
end

local function EndSlide()
    if not MoveState.isSliding then return end
    MoveState.isSliding  = false
    MoveState.slideCooldown = MoveState.slideCooldownMax

    if humanoid then
        humanoid.HipHeight = humanoid.HipHeight + 1.5
    end

    -- Remove any lingering velocity
    local bv = hrp and hrp:FindFirstChild("SlideVelocity")
    if bv then bv:Destroy() end
end

-- ── Wall Kick ─────────────────────────────────────────────────────────────────
local function TryWallKick()
    if not Capabilities.canWallKick then return end
    if MoveState.wallKickCooldown > 0 then return end
    if humanoid.FloorMaterial ~= Enum.Material.Air then return end

    -- Raycast sideways to find a wall
    local directions = {
        hrp.CFrame.RightVector,
        -hrp.CFrame.RightVector,
        hrp.CFrame.LookVector,
    }

    for _, dir in ipairs(directions) do
        local result = workspace:Raycast(hrp.Position, dir * 3, RaycastParams.new())
        if result then
            -- Kick off the wall
            local kickDir = -dir + Vector3.new(0, 1, 0)
            local bv = Instance.new("BodyVelocity")
            bv.Velocity = kickDir.Unit * 55
            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bv.Parent   = hrp
            game:GetService("Debris"):AddItem(bv, 0.3)

            MoveState.wallKickCooldown = 0.5
            return
        end
    end
end

-- ── Burst Step ────────────────────────────────────────────────────────────────
local function TryBurstStep()
    if not Capabilities.canBurstStep then return end
    if MoveState.burstCharges <= 0 then return end
    if MoveState.burstCooldown > 0 then return end

    MoveState.burstCharges  = MoveState.burstCharges - 1
    MoveState.burstCooldown = 0.3

    -- Dash in camera look direction
    local dashDir = camera.CFrame.LookVector
    dashDir = Vector3.new(dashDir.X, 0, dashDir.Z).Unit

    local bv = Instance.new("BodyVelocity")
    bv.Velocity = dashDir * 60
    bv.MaxForce = Vector3.new(1e5, 0, 1e5)
    bv.Parent   = hrp
    game:GetService("Debris"):AddItem(bv, 0.18)

    -- Recharge burst charges after cooldown
    if MoveState.burstCharges == 0 then
        MoveState.burstCooldown = 4.0  -- full recharge after spending all
    end
end

-- ── Jump Jet ─────────────────────────────────────────────────────────────────
local function TryJumpJet()
    if not Capabilities.canJumpJet then return end
    if MoveState.jumpJetCooldown > 0 then return end
    if humanoid.FloorMaterial ~= Enum.Material.Air then return end  -- only in air

    local bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.new(0, Capabilities.jumpJetHeight * 3, 0)
    bv.MaxForce = Vector3.new(0, 1e5, 0)
    bv.Parent   = hrp
    game:GetService("Debris"):AddItem(bv, 0.4)

    MoveState.jumpJetCooldown = 6.0
end

-- ── Air Dash ─────────────────────────────────────────────────────────────────
local function TryAirDash()
    if not Capabilities.canAirDash then return end
    if MoveState.airDashCharges <= 0 then return end
    if humanoid.FloorMaterial ~= Enum.Material.Air then return end

    MoveState.airDashCharges = MoveState.airDashCharges - 1

    local dashDir = camera.CFrame.LookVector
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = dashDir * 65
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Parent   = hrp
    game:GetService("Debris"):AddItem(bv, 0.25)

    -- Restore on landing
end

-- ── Magnetic Perch ────────────────────────────────────────────────────────────
local function TryMagPerch()
    if not Capabilities.canMagneticPerch then return end

    -- Check if near a metal surface (any Part)
    local origin = hrp.Position
    local dirs   = {
        Vector3.new(0, -1, 0),    -- floor
        Vector3.new(0, 1, 0),     -- ceiling
        hrp.CFrame.RightVector,
        -hrp.CFrame.RightVector,
    }

    for _, dir in ipairs(dirs) do
        local result = workspace:Raycast(origin, dir * 2.5, RaycastParams.new())
        if result then
            MoveState.isMagPerched = true
            humanoid.PlatformStand = true
            hrp.Anchored = true
            hrp.CFrame = CFrame.new(result.Position - dir * 1.5)

            -- Auto-release after 5 seconds or on jump input
            task.delay(5, function()
                if MoveState.isMagPerched then
                    MoveState.isMagPerched   = false
                    humanoid.PlatformStand   = false
                    hrp.Anchored             = false
                end
            end)
            return
        end
    end
end

local function ReleaseMagPerch()
    if not MoveState.isMagPerched then return end
    MoveState.isMagPerched   = false
    humanoid.PlatformStand   = false
    hrp.Anchored             = false
end

-- ── Shockwave Landing ─────────────────────────────────────────────────────────
local function CheckLanding()
    if not character or not hrp then return end
    local isGrounded = humanoid.FloorMaterial ~= Enum.Material.Air

    if not MoveState.wasGrounded and isGrounded then
        -- Just landed
        local fallHeight = MoveState.landHeight - hrp.Position.Y
        MoveState.landHeight = hrp.Position.Y

        if fallHeight > 5 and Capabilities.hasShockwaveLanding then
            -- AoE shockwave
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Humanoid") and obj.Parent ~= character then
                    local target = obj.Parent:FindFirstChild("HumanoidRootPart")
                    if target and (target.Position - hrp.Position).Magnitude <= Capabilities.shockwaveRadius then
                        obj:TakeDamage(Capabilities.shockwaveDamage)

                        -- Apply foam root effect via combat client
                        local bv = Instance.new("BodyVelocity")
                        bv.Velocity = (target.Position - hrp.Position).Unit * 20 + Vector3.new(0, 10, 0)
                        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                        bv.Parent   = target
                        game:GetService("Debris"):AddItem(bv, 0.3)
                    end
                end
            end

            -- Visual shockwave ring
            local ring = Instance.new("Part")
            ring.Shape        = Enum.PartType.Cylinder
            ring.Size         = Vector3.new(0.5, Capabilities.shockwaveRadius * 2, Capabilities.shockwaveRadius * 2)
            ring.Position     = hrp.Position
            ring.Anchored     = true
            ring.CanCollide   = false
            ring.Material     = Enum.Material.Neon
            ring.BrickColor   = BrickColor.new("Bright orange")
            ring.Transparency = 0.5
            ring.CFrame       = hrp.CFrame * CFrame.Angles(0, 0, math.pi/2)
            ring.Parent       = workspace
            game:GetService("Debris"):AddItem(ring, 0.4)
        else
            MoveState.landHeight = hrp.Position.Y
        end
    elseif not isGrounded then
        if MoveState.wasGrounded then
            MoveState.landHeight = hrp.Position.Y  -- track height at liftoff
        end
    end

    -- Restore air charges on landing
    if not MoveState.wasGrounded and isGrounded then
        MoveState.airDashCharges = Capabilities.airDashCount
        MoveState.burstCharges   = math.max(MoveState.burstCharges, Capabilities.burstCount)
    end

    MoveState.wasGrounded = isGrounded
end

-- ── Input ─────────────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if not humanoid or humanoid.Health <= 0 then return end

    -- Slide: Left Control while moving
    if input.KeyCode == Enum.KeyCode.LeftControl then
        if humanoid.MoveDirection.Magnitude > 0.1 then
            StartSlide()
        else
            TryMagPerch()
        end
    end

    -- Wall Kick: Space while in air and near wall
    if input.KeyCode == Enum.KeyCode.Space then
        if humanoid.FloorMaterial == Enum.Material.Air then
            if MoveState.isMagPerched then
                ReleaseMagPerch()
            elseif Capabilities.canWallKick then
                TryWallKick()
            elseif Capabilities.canJumpJet then
                TryJumpJet()
            elseif Capabilities.canAirDash then
                TryAirDash()
            end
        end
    end

    -- Burst Step: Left Shift double-tap (handled via timer)
    if input.KeyCode == Enum.KeyCode.LeftShift then
        TryBurstStep()
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.LeftControl then
        if MoveState.isSliding then EndSlide() end
    end
end)

-- ── Per-Frame Update ──────────────────────────────────────────────────────────
RunService.RenderStepped:Connect(function(dt)
    if not character or not humanoid or not hrp then return end

    -- Slide tick
    if MoveState.isSliding then
        MoveState.slideTimer = MoveState.slideTimer - dt
        if MoveState.slideTimer <= 0 then
            EndSlide()
        end
    end

    -- Cooldowns
    if MoveState.slideCooldown    > 0 then MoveState.slideCooldown    = math.max(0, MoveState.slideCooldown    - dt) end
    if MoveState.burstCooldown    > 0 then MoveState.burstCooldown    = math.max(0, MoveState.burstCooldown    - dt) end
    if MoveState.airDashCooldown  > 0 then MoveState.airDashCooldown  = math.max(0, MoveState.airDashCooldown  - dt) end
    if MoveState.jumpJetCooldown  > 0 then MoveState.jumpJetCooldown  = math.max(0, MoveState.jumpJetCooldown  - dt) end
    if MoveState.wallKickCooldown > 0 then MoveState.wallKickCooldown = math.max(0, MoveState.wallKickCooldown - dt) end

    -- Landing detection
    CheckLanding()

    -- Crawler legs: crouch speed modifier
    if Capabilities.hasCrawlerLegs and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        humanoid.WalkSpeed = (humanoid.WalkSpeed > 12) and 12 or humanoid.WalkSpeed
    end

    -- Silent movement: reduce footstep volume (handled via animation weight)
end)

print("[MovementClient] Initialised.")
