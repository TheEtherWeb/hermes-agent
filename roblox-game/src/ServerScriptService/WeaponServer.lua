-- WeaponServer.lua (ModuleScript — ticked by GameManager Heartbeat)
-- Manages per-frame weapon resource ticking:
--   Gem: drain Resonance while weapon is active; force-dismiss at 0.
--   Ore: regen health while weapon is active.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaceConfig  = require(ReplicatedStorage.Shared.RaceConfig)
local WeaponTypes = require(ReplicatedStorage.Data.WeaponTypes)
local Constants   = require(ReplicatedStorage.Data.Constants)

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)

local WeaponServer = {}

-- Set by GameManager after PlayerManager is loaded
local _playerManager

function WeaponServer.SetPlayerManager(pm)
	_playerManager = pm
end

local function GetRemote(name)
	return RemotesFolder:WaitForChild(name, 5)
end

function WeaponServer.Tick(dt)
	if not _playerManager then return end

	for _, player in ipairs(Players:GetPlayers()) do
		local state = _playerManager.GetState(player)
		if not state or not state.WeaponActive then continue end
		if state.IsCollapsed then continue end

		local weaponDef = WeaponTypes[state.WeaponStyle]
		if not weaponDef then continue end

		local raceConf = RaceConfig[state.Race]
		if not raceConf then continue end

		if state.Race == "Gem" then
			-- Drain resonance
			local drain = raceConf.TickDrain(weaponDef, dt)
			local newResonance = math.max(0, (state.Resonance or 0) - drain)

			if newResonance == 0 and state.Resonance > 0 then
				-- Force-dismiss weapon; Gem ran out of resonance
				_playerManager.SetState(player, {
					Resonance   = 0,
					WeaponActive = false,
					WeaponBroken = true,
				})
				-- Schedule auto-recovery (resonance returns, weapon can be re-summoned)
				task.delay(Constants.DISARMED_DURATION * 0.5, function()
					local current = _playerManager.GetState(player)
					if current then
						_playerManager.SetState(player, { WeaponBroken = false })
					end
				end)
			elseif newResonance ~= state.Resonance then
				_playerManager.SetState(player, { Resonance = newResonance })
			end

		elseif state.Race == "Ore" then
			-- Regen health while weapon is active
			local regenDelta = raceConf.ResourceRegen(state, dt)
			if regenDelta > 0 then
				local newHealth = math.min(state.MaxHealth - Constants.EXTRACTION_HEALTH_COST, state.Health + regenDelta)
				if newHealth ~= state.Health then
					_playerManager.SetState(player, { Health = newHealth })
				end
			end
		end
	end
end

-- Called by CombatServer when a player summons their weapon
function WeaponServer.HandleSummon(player)
	if not _playerManager then return false end
	local state = _playerManager.GetState(player)
	if not state then return false end

	local raceConf = RaceConfig[state.Race]
	if not raceConf.CanSummon(state) then
		return false
	end

	local weaponDef = WeaponTypes[state.WeaponStyle]
	local cost = raceConf.SummonCost(weaponDef)
	local heatCost = raceConf.SummonHeatCost(weaponDef)

	local patch = {
		WeaponActive = true,
		WeaponBroken = false,
		Heat = math.min(Constants.MAX_HEAT, state.Heat + heatCost),
	}

	if state.Race == "Ore" and cost > 0 then
		patch.Health = math.max(1, state.Health - cost)
	end

	_playerManager.SetState(player, patch)
	return true
end

-- Called by CombatServer when a player dismisses their weapon
function WeaponServer.HandleDismiss(player)
	if not _playerManager then return end
	local state = _playerManager.GetState(player)
	if not state or not state.WeaponActive then return end
	_playerManager.SetState(player, { WeaponActive = false })
end

return WeaponServer
