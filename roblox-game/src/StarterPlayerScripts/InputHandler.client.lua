-- InputHandler.client.lua
-- Maps UserInputService events to combat and UI intents.
-- Priority: UI-open states swallow combat inputs.

local UserInputService = game:GetService("UserInputService")

-- Lazy-load client modules (they're LocalScripts in sibling paths; use _G refs)
-- CombatClient and WeaponClient register themselves on _G after loading.
-- We wait for them here before binding.

local function WaitForGlobal(key, timeout)
	local t = 0
	while not _G[key] and t < timeout do
		task.wait(0.1)
		t = t + 0.1
	end
	return _G[key]
end

-- Hold detection for heavy attack
local _lmbHoldConn = nil
local _lmbHoldTime = 0
local HEAVY_HOLD_THRESHOLD = 0.35  -- seconds of hold to register heavy

task.defer(function()
	local CombatClient = require(script.Parent.CombatClient)
	local WeaponClient = require(script.Parent.WeaponClient)

	_G.CombatClient = CombatClient
	_G.WeaponClient = WeaponClient

	-- ── LMB: tap = light, hold = heavy ───────────────────────────────────────

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			_lmbHoldTime = 0
			_lmbHoldConn = game:GetService("RunService").RenderStepped:Connect(function(dt)
				_lmbHoldTime = _lmbHoldTime + dt
			end)
		end

		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			-- Begin block
			CombatClient.RequestBlock(true)
		end

		if input.UserInputType == Enum.UserInputType.Keyboard then
			local key = input.KeyCode
			if key == Enum.KeyCode.Q then
				-- Toggle weapon
				local state = _G.LocalPlayerState
				if state and state.WeaponActive then
					WeaponClient.RequestDismiss()
				else
					WeaponClient.RequestSummon()
				end
			elseif key == Enum.KeyCode.E then
				-- Toggle codex
				if _G.CodexController then
					_G.CodexController.Toggle()
				end
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if _lmbHoldConn then
				_lmbHoldConn:Disconnect()
				_lmbHoldConn = nil
			end
			if _lmbHoldTime >= HEAVY_HOLD_THRESHOLD then
				CombatClient.RequestHeavy()
			else
				CombatClient.RequestLight()
			end
			_lmbHoldTime = 0
		end

		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			CombatClient.RequestBlock(false)
		end
	end)
end)
