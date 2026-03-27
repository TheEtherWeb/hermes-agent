-- HeatServer.lua (ModuleScript — ticked by GameManager Heartbeat)
-- Manages heat decay and collapse triggering for all players.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeatUtils   = require(ReplicatedStorage.Shared.HeatUtils)
local Constants   = require(ReplicatedStorage.Data.Constants)

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)

local HeatServer = {}

local _playerManager
local _collapsingPlayers = {}  -- [userId] = true while collapse task is running

function HeatServer.SetPlayerManager(pm)
	_playerManager = pm
end

local function GetRemote(name)
	return RemotesFolder:WaitForChild(name, 5)
end

function HeatServer.Tick(dt)
	if not _playerManager then return end

	for _, player in ipairs(Players:GetPlayers()) do
		local state = _playerManager.GetState(player)
		if not state then continue end
		if _collapsingPlayers[player.UserId] then continue end

		-- Check collapse first
		if HeatUtils.IsCollapse(state.Heat) then
			HeatServer.TriggerCollapse(player)
			continue
		end

		-- Decay heat if out of combat
		if state.Heat > 0 and HeatUtils.ShouldDecayHeat(state.LastCombatTime) then
			local newHeat = math.max(0, state.Heat - HeatUtils.DecayDelta(dt))
			if newHeat ~= state.Heat then
				_playerManager.SetState(player, { Heat = newHeat })
			end
		end
	end
end

function HeatServer.AddHeat(player, amount)
	if not _playerManager then return end
	local state = _playerManager.GetState(player)
	if not state or state.IsCollapsed then return end

	local newHeat = math.min(Constants.MAX_HEAT, state.Heat + amount)
	_playerManager.SetState(player, {
		Heat = newHeat,
		LastCombatTime = tick(),
	})
end

function HeatServer.TriggerCollapse(player)
	if _collapsingPlayers[player.UserId] then return end
	_collapsingPlayers[player.UserId] = true

	local state = _playerManager.GetState(player)
	if not state then
		_collapsingPlayers[player.UserId] = nil
		return
	end

	_playerManager.SetState(player, {
		IsCollapsed  = true,
		Health       = 0,
		WeaponActive = false,
		IsBlocking   = false,
	})

	GetRemote("PlayerCollapsed"):FireClient(player, { duration = Constants.HEAT_COLLAPSE_PENALTY })

	task.delay(Constants.HEAT_COLLAPSE_PENALTY, function()
		local current = _playerManager.GetState(player)
		if not current then
			_collapsingPlayers[player.UserId] = nil
			return
		end
		_playerManager.SetState(player, {
			IsCollapsed = false,
			Health = math.floor(current.MaxHealth * Constants.COLLAPSE_REVIVAL_HEALTH),
			Heat = Constants.COLLAPSE_REVIVAL_HEAT,
			WeaponBroken = false,
		})
		_collapsingPlayers[player.UserId] = nil
	end)
end

return HeatServer
