-- MovementController.client.lua
-- Adjusts WalkSpeed based on player state flags.

local Players  = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local BASE_SPEED     = 16
local BLOCK_SPEED    = BASE_SPEED * 0.60   -- 60% speed while blocking
local COLLAPSE_SPEED = 0

local function GetHumanoid()
	local char = LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function UpdateSpeed(state)
	local humanoid = GetHumanoid()
	if not humanoid then return end

	if state.IsCollapsed then
		humanoid.WalkSpeed = COLLAPSE_SPEED
	elseif state.IsBlocking then
		humanoid.WalkSpeed = BLOCK_SPEED
	elseif state.IsStaggered then
		humanoid.WalkSpeed = 0
	else
		humanoid.WalkSpeed = BASE_SPEED
	end
end

-- Hook into the global state change signal set by PlayerInit
_G.OnStateChanged = (function(prevCallback)
	return function(state, patch)
		-- Only act if relevant flags changed
		if patch.IsBlocking ~= nil or patch.IsCollapsed ~= nil or patch.IsStaggered ~= nil then
			UpdateSpeed(state)
		end
		-- Chain other callbacks
		if prevCallback then prevCallback(state, patch) end
	end
end)(_G.OnStateChanged)

-- Also update on character respawn
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.1)
	if _G.LocalPlayerState then
		UpdateSpeed(_G.LocalPlayerState)
	end
end)
