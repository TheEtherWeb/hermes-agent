-- CombatClient.client.lua
-- Fires attack/block remotes and handles client-side combat feedback (VFX, screenshake).

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local Workspace        = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

-- ── Module API ────────────────────────────────────────────────────────────────

local CombatClient = {}

-- Current target (set by InputHandler or lock-on system)
local _currentTargetId = nil

function CombatClient.SetTarget(playerId)
	_currentTargetId = playerId
end

-- ── Auto-targeting: find nearest visible player in front of camera ─────────────

local function FindNearestTarget()
	local char = LocalPlayer.Character
	if not char then return nil end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local best, bestDist = nil, math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		local tChar = player.Character
		if not tChar then continue end
		local tRoot = tChar:FindFirstChild("HumanoidRootPart")
		if not tRoot then continue end
		local dist = (root.Position - tRoot.Position).Magnitude
		if dist < bestDist and dist <= 20 then
			best = player
			bestDist = dist
		end
	end
	return best and best.UserId or nil
end

-- ── Screen shake on heavy hit received ────────────────────────────────────────

local _shakeOffset = CFrame.new()
local _shakeTime   = 0
local _shakeDuration = 0

local function TriggerScreenShake(intensity, duration)
	_shakeDuration = duration
	_shakeTime = 0
	-- Apply shake via a RenderStepped hook (additive to CameraController)
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		_shakeTime = _shakeTime + dt
		if _shakeTime >= _shakeDuration then
			_shakeOffset = CFrame.new()
			conn:Disconnect()
			return
		end
		local t = 1 - (_shakeTime / _shakeDuration)
		local mag = intensity * t
		_shakeOffset = CFrame.new(
			math.random(-100, 100) * 0.001 * mag,
			math.random(-100, 100) * 0.001 * mag,
			0
		)
		Workspace.CurrentCamera.CFrame = Workspace.CurrentCamera.CFrame * _shakeOffset
	end)
end

-- ── Attack requests ───────────────────────────────────────────────────────────

function CombatClient.RequestLight()
	local state = _G.LocalPlayerState
	if not state or not state.WeaponActive or state.IsCollapsed then return end

	local targetId = _currentTargetId or FindNearestTarget()
	if not targetId then return end

	_G.Remotes.RequestLightAttack:FireServer({ targetId = targetId })
	-- Client-predicted animation trigger
	CombatClient.PlayLocalAnimation("LightAttack")
end

function CombatClient.RequestHeavy()
	local state = _G.LocalPlayerState
	if not state or not state.WeaponActive or state.IsCollapsed then return end

	local targetId = _currentTargetId or FindNearestTarget()
	if not targetId then return end

	_G.Remotes.RequestHeavyAttack:FireServer({ targetId = targetId })
	CombatClient.PlayLocalAnimation("HeavyAttack")
end

function CombatClient.RequestBlock(isBlocking)
	local state = _G.LocalPlayerState
	if not state or state.IsCollapsed or state.IsStaggered then return end
	_G.Remotes.RequestBlock:FireServer(isBlocking)
	CombatClient.PlayLocalAnimation(isBlocking and "BlockStart" or "BlockEnd")
end

-- ── Animation stubs (swap for Animator:LoadAnimation calls) ──────────────────

function CombatClient.PlayLocalAnimation(animName)
	-- Placeholder: print the animation trigger. Replace with Animator:Play() calls.
	-- print("[CombatClient] Play animation: " .. animName)
end

-- ── Hit confirmation listener ─────────────────────────────────────────────────

-- Wait for remotes to be ready before connecting
task.defer(function()
	-- Give PlayerInit time to populate _G.Remotes
	while not (_G.Remotes and _G.Remotes.CombatHitConfirmed) do task.wait(0.1) end

	_G.Remotes.CombatHitConfirmed.OnClientEvent:Connect(function(data)
		if data.targetId == LocalPlayer.UserId then
			-- We were hit
			if data.attackType == "heavy" then
				TriggerScreenShake(1.5, 0.25)
			else
				TriggerScreenShake(0.7, 0.12)
			end
		end

		-- Damage number billboard (for attacker or any nearby observer)
		local targetPlayer = Players:GetPlayerByUserId(data.targetId)
		if targetPlayer and targetPlayer.Character then
			CombatClient.SpawnDamageNumber(targetPlayer.Character, data.damage, data.attackType)
		end
	end)

	_G.Remotes.GuardBroken.OnClientEvent:Connect(function(_data)
		TriggerScreenShake(1.0, 0.2)
	end)
end)

-- ── Floating damage numbers ───────────────────────────────────────────────────

function CombatClient.SpawnDamageNumber(character, damage, attackType)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 80, 0, 40)
	billboard.StudsOffset = Vector3.new(
		math.random(-10, 10) * 0.1,
		3 + math.random(0, 10) * 0.1,
		0
	)
	billboard.AlwaysOnTop = false
	billboard.Adornee = root
	billboard.Parent = character

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = tostring(damage)
	label.TextColor3 = (attackType == "heavy") and Color3.fromRGB(255, 100, 0) or Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0
	label.Parent = billboard

	-- Float up and fade
	local floatTween = TweenService:Create(billboard, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = billboard.StudsOffset + Vector3.new(0, 3, 0),
	})
	local fadeTween = TweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Linear), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	floatTween:Play()
	fadeTween:Play()
	floatTween.Completed:Connect(function()
		billboard:Destroy()
	end)
end

return CombatClient
