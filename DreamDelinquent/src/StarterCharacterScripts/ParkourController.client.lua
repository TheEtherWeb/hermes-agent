-- Dream Delinquent: ParkourController
-- Handles character movement augmentation: vaults, wall-runs, slides, rolls.
-- Runs as a LocalScript inside StarterCharacterScripts.

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local CollectionService= game:GetService("CollectionService")
local TweenService     = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Character   = script.Parent
local Humanoid    = Character:WaitForChild("Humanoid")
local HRP         = Character:WaitForChild("HumanoidRootPart")
local Animator    = Humanoid:WaitForChild("Animator")

local Modules  = ReplicatedStorage:WaitForChild("Modules")
local Remotes  = ReplicatedStorage:WaitForChild("Remotes")
local Constants= require(Modules.Constants)
local Parkour  = require(Modules.ParkourSystem)

local RE_ParkourResult = Remotes:WaitForChild("ParkourResult", 10)

-- ─────────────────────────────────────────────────────────────────────────────
-- State
-- ─────────────────────────────────────────────────────────────────────────────
local stamina      = 100
local maxStamina   = 100
local isVaulting   = false
local isWallRunning= false
local isSliding    = false
local isSprinting  = false
local wallRunTimer = 0
local lastMoveDirection = Vector3.new(0,0,0)

local BASE_WALK_SPEED  = 16
local SPRINT_SPEED     = 26

-- ─────────────────────────────────────────────────────────────────────────────
-- Raycast helpers
-- ─────────────────────────────────────────────────────────────────────────────
local rayParams = RaycastParams.new()
rayParams.FilterDescendantsInstances = { Character }
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function rayForward(length)
	local origin = HRP.Position
	local dir    = HRP.CFrame.LookVector * length
	return workspace:Raycast(origin, dir, rayParams)
end

local function rayDown(length)
	local origin = HRP.Position
	return workspace:Raycast(origin, Vector3.new(0,-length,0), rayParams)
end

local function rayLeft(length)
	local origin = HRP.Position
	local dir    = -HRP.CFrame.RightVector * length
	return workspace:Raycast(origin, dir, rayParams)
end

local function rayRight(length)
	local origin = HRP.Position
	local dir    = HRP.CFrame.RightVector * length
	return workspace:Raycast(origin, dir, rayParams)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Vault detection
-- ─────────────────────────────────────────────────────────────────────────────
local function tryVault()
	if isVaulting or stamina < Constants.PARKOUR.STAMINA_VAULT_COST then return end
	if Humanoid.MoveDirection.Magnitude < 0.1 then return end

	-- Detect a vaultable obstacle ahead and slightly below chest height
	local fwd   = rayForward(3)
	local fwdHi = workspace:Raycast(
		HRP.Position + Vector3.new(0,0.5,0),
		HRP.CFrame.LookVector * 3,
		rayParams
	)

	if not fwd or not fwdHi then return end

	-- Check if obstacle top is below waist level (can vault over)
	local hitPos = fwd.Position
	if hitPos.Y > HRP.Position.Y + 1.2 then return end  -- too high to vault

	-- Check CollectionService tag
	local hitPart = fwd.Instance
	if not CollectionService:HasTag(hitPart, "VaultObject")
		and not CollectionService:HasTag(hitPart, "Ledge") then
		-- Untagged objects: still try if height is right
		if hitPos.Y > HRP.Position.Y + 0.8 then return end
	end

	-- Execute vault
	isVaulting   = true
	stamina      = stamina - Constants.PARKOUR.STAMINA_VAULT_COST

	-- Lerp character over obstacle
	local vaultTarget = HRP.Position
		+ HRP.CFrame.LookVector * 4
		+ Vector3.new(0,1,0)

	local vaultTween = TweenService:Create(HRP,
		TweenInfo.new(0.35, Enum.EasingStyle.Sine),
		{ CFrame = CFrame.new(vaultTarget) * (HRP.CFrame - HRP.CFrame.Position) }
	)
	vaultTween:Play()
	vaultTween.Completed:Connect(function()
		isVaulting = false
	end)

	RE_ParkourResult:FireServer({ moveType = "Vault" })
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Wall-run detection
-- ─────────────────────────────────────────────────────────────────────────────
local function tryWallRun()
	if isWallRunning or isSliding then return end
	if stamina < Constants.PARKOUR.STAMINA_WALLRUN_COST then return end
	if Humanoid.FloorMaterial ~= Enum.Material.Air then return end  -- must be airborne

	local leftHit  = rayLeft(1.8)
	local rightHit = rayRight(1.8)

	local wallHit  = leftHit or rightHit
	if not wallHit then return end

	-- Check tag
	local part = wallHit.Instance
	if not CollectionService:HasTag(part, "WallRunSurface")
		and not CollectionService:HasTag(part, "Building") then
		return
	end

	-- Wall run
	isWallRunning   = true
	wallRunTimer    = Constants.PARKOUR.WALL_RUN_DURATION
	stamina         = stamina - Constants.PARKOUR.STAMINA_WALLRUN_COST

	Humanoid.WalkSpeed = BASE_WALK_SPEED * 1.2
	-- Zero out gravity effect
	local bodyVel = Instance.new("BodyVelocity")
	bodyVel.Velocity      = HRP.CFrame.LookVector * 22 + Vector3.new(0,8,0)
	bodyVel.MaxForce      = Vector3.new(0,math.huge,0)
	bodyVel.P             = 1000
	bodyVel.Parent        = HRP

	RE_ParkourResult:FireServer({ moveType = "WallRun" })

	task.delay(Constants.PARKOUR.WALL_RUN_DURATION, function()
		bodyVel:Destroy()
		isWallRunning = false
		Humanoid.WalkSpeed = BASE_WALK_SPEED
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Slide
-- ─────────────────────────────────────────────────────────────────────────────
local function trySlide()
	if isSliding then return end
	if stamina < 5 then return end
	if Humanoid.MoveDirection.Magnitude < 0.5 then return end
	if Humanoid.FloorMaterial == Enum.Material.Air then return end

	isSliding = true
	stamina   = stamina - 5

	local bv = Instance.new("BodyVelocity")
	bv.Velocity  = Humanoid.MoveDirection * (Constants.PARKOUR.SLIDE_SPEED_BONUS * BASE_WALK_SPEED)
	bv.MaxForce  = Vector3.new(math.huge, 0, math.huge)
	bv.P         = 800
	bv.Parent    = HRP

	RE_ParkourResult:FireServer({ moveType = "Slide" })

	task.delay(0.7, function()
		bv:Destroy()
		isSliding = false
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Roll on landing
-- ─────────────────────────────────────────────────────────────────────────────
local airTime = 0
local wasInAir = false

RunService.Heartbeat:Connect(function(dt)
	local inAir = (Humanoid.FloorMaterial == Enum.Material.Air)

	if inAir then
		airTime = airTime + dt
		wasInAir = true
	elseif wasInAir then
		wasInAir = false
		local fallHeight = airTime * 30  -- rough estimate in studs
		if fallHeight >= Constants.PARKOUR.ROLL_FALL_THRESHOLD * 0.5 then
			-- Auto-roll if sprint key held
			if isSprinting then
				RE_ParkourResult:FireServer({ moveType = "Roll" })
			end
		end
		airTime = 0
	end

	-- Sprint
	if isSprinting and not isSliding and not isVaulting then
		Humanoid.WalkSpeed = SPRINT_SPEED
	elseif not isWallRunning and not isSliding and not isVaulting then
		Humanoid.WalkSpeed = BASE_WALK_SPEED
	end

	-- Stamina regen
	if not isSprinting and not isWallRunning and not isSliding then
		stamina = math.min(maxStamina, stamina + 12 * dt)
	elseif isSprinting then
		stamina = math.max(0, stamina - 8 * dt)
		if stamina <= 0 then
			isSprinting = false
		end
	end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Input
-- ─────────────────────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end

	if input.KeyCode == Enum.KeyCode.LeftShift then
		isSprinting = true
	elseif input.KeyCode == Enum.KeyCode.Q then
		tryVault()
	elseif input.KeyCode == Enum.KeyCode.C then
		trySlide()
	elseif input.KeyCode == Enum.KeyCode.Space then
		tryWallRun()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		isSprinting = false
	end
end)

print("[ParkourController] Initialised.")
