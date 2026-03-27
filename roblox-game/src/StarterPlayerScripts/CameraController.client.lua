-- CameraController.client.lua
-- Third-person orbit camera with smooth lerp.
-- Replaces the default Roblox camera for more control over feel.

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace    = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

-- ── Configuration ─────────────────────────────────────────────────────────────

local CAMERA_DISTANCE    = 18    -- default distance behind character
local CAMERA_HEIGHT      = 5     -- vertical offset from root
local CAMERA_SENSITIVITY = 0.003 -- mouse delta → angle (radians per pixel)
local LERP_SPEED         = 12    -- how fast camera snaps to target

-- ── State ─────────────────────────────────────────────────────────────────────

local camX = 0  -- horizontal angle (yaw)
local camY = 0.3  -- vertical angle (pitch), positive = looking down

local isLocked = false  -- future lock-on mode

Camera.CameraType = Enum.CameraType.Scriptable

-- ── Mouse delta input ─────────────────────────────────────────────────────────

UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
UserInputService.MouseIconEnabled = false

local function OnInputChanged(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		camX = camX - input.Delta.X * CAMERA_SENSITIVITY
		camY = math.clamp(camY - input.Delta.Y * CAMERA_SENSITIVITY, -0.3, 1.2)
	end
end
UserInputService.InputChanged:Connect(OnInputChanged)

-- ── RenderStepped update ──────────────────────────────────────────────────────

local lastCF = CFrame.new()

RunService.RenderStepped:Connect(function(dt)
	local char = LocalPlayer.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- Compute desired camera CFrame
	local lookDir = CFrame.Angles(0, camX, 0) * CFrame.Angles(-camY, 0, 0)
	local offset  = lookDir * Vector3.new(0, 0, CAMERA_DISTANCE)
	local targetPos = root.Position + Vector3.new(0, CAMERA_HEIGHT, 0) + offset

	local targetCF = CFrame.lookAt(targetPos, root.Position + Vector3.new(0, CAMERA_HEIGHT * 0.5, 0))

	-- Lerp smoothly
	local alpha = math.min(1, LERP_SPEED * dt)
	lastCF = lastCF:Lerp(targetCF, alpha)
	Camera.CFrame = lastCF
end)
