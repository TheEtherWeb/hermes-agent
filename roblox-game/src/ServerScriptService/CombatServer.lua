-- CombatServer.lua (ModuleScript — activated by GameManager)
-- Authoritative hit resolution. Listens to all combat RemoteEvents.
-- Validates, applies damage, manages guard break, weapon break, XP, and heat.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatUtils = require(ReplicatedStorage.Shared.CombatUtils)
local HeatUtils   = require(ReplicatedStorage.Shared.HeatUtils)
local Constants   = require(ReplicatedStorage.Data.Constants)
local WeaponTypes = require(ReplicatedStorage.Data.WeaponTypes)

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)

local CombatServer = {}

-- Injected by GameManager
local _pm, _weaponServer, _heatServer, _rankServer

-- Per-player attack cooldown timestamps
local _lastAttack = {}  -- [userId] = { light = tick, heavy = tick }

-- Per-weapon guard-break hit counters (tracks how many GB hits the defender's weapon has taken)
local _weaponHitCount = {}  -- [userId] = number

local function GetRemote(name)
	return RemotesFolder:WaitForChild(name, 5)
end

local function GetTargetPlayer(targetId)
	return Players:GetPlayerByUserId(targetId)
end

-- Validate attacker is ready to attack
local function CanAttack(attackerState, attackType)
	if not attackerState then return false end
	if attackerState.IsCollapsed then return false end
	if attackerState.IsStaggered then return false end
	if not attackerState.WeaponActive then return false end
	if attackerState.WeaponBroken then return false end
	return true
end

-- Rate-limit check using per-player cooldown map
local function CheckCooldown(userId, attackType)
	local now = tick()
	local record = _lastAttack[userId] or {}
	local cooldown = (attackType == "heavy") and Constants.HEAVY_ATTACK_COOLDOWN or Constants.LIGHT_ATTACK_COOLDOWN
	local last = record[attackType] or 0
	if (now - last) < cooldown then
		return false
	end
	record[attackType] = now
	_lastAttack[userId] = record
	return true
end

-- Proximity check between attacker and target characters
local function IsInRange(attacker, target, weaponTypeId)
	local aChar = attacker.Character
	local tChar = target.Character
	if not aChar or not tChar then return false end
	local aRoot = aChar:FindFirstChild("HumanoidRootPart")
	local tRoot = tChar:FindFirstChild("HumanoidRootPart")
	if not aRoot or not tRoot then return false end
	local range = CombatUtils.GetWeaponRange(weaponTypeId)
	return (aRoot.Position - tRoot.Position).Magnitude <= range
end

-- Apply a completed kill: grant XP, handle Ore extraction dismiss
local function HandleKill(attacker, defender)
	_rankServer.GrantXP(attacker, Constants.XP_PER_KILL)
end

-- Core hit resolution (shared by light and heavy)
local function ResolveHit(attacker, targetPlayer, attackType)
	local attackerState = _pm.GetState(attacker)
	local targetState   = _pm.GetState(targetPlayer)
	if not attackerState or not targetState then return end
	if not CanAttack(attackerState, attackType) then return end
	if not CheckCooldown(attacker.UserId, attackType) then return end
	if not IsInRange(attacker, targetPlayer, attackerState.WeaponStyle) then return end

	local weaponTypeId = attackerState.WeaponStyle

	-- Heat gained by attacker for attacking
	local attackHeat = HeatUtils.GetHeatGain(attackerState, attackType == "heavy" and "heavyAttack" or "lightAttack")
	_heatServer.AddHeat(attacker, attackHeat)

	-- Update last combat time for both players
	local now = tick()

	if targetState.IsBlocking and targetState.Guard > 0 then
		-- Hit is blocked — deal guard damage instead
		local guardDmg = CombatUtils.CalculateGuardDamage(attackerState, weaponTypeId, attackType)
		local newGuard = math.max(0, targetState.Guard - guardDmg)
		local patch = {
			Guard = newGuard,
			LastGuardHitTime = now,
			LastCombatTime   = now,
		}

		-- Heat for blocked attacker (attacker also gains some heat)
		local blockedHeat = HeatUtils.GetHeatGain(attackerState, "blocked")
		_heatServer.AddHeat(attacker, blockedHeat)

		if CombatUtils.IsGuardBroken(newGuard) then
			-- Guard break
			patch.Guard      = 0
			patch.IsBlocking = false
			patch.IsStaggered = true

			_pm.SetState(targetPlayer, patch)
			GetRemote("GuardBroken"):FireClient(targetPlayer, { targetId = targetPlayer.UserId })

			-- Check weapon break on heavy guard-break hit
			if attackType == "heavy" then
				local hitCount = (_weaponHitCount[targetPlayer.UserId] or 0) + 1
				_weaponHitCount[targetPlayer.UserId] = hitCount
				if CombatUtils.ShouldBreakWeapon(weaponTypeId, hitCount) then
					_weaponHitCount[targetPlayer.UserId] = 0
					_pm.SetState(targetPlayer, {
						WeaponActive  = false,
						WeaponBroken  = true,
						DisarmedTimer = Constants.DISARMED_DURATION,
					})
					GetRemote("WeaponBroken"):FireClient(targetPlayer, { targetId = targetPlayer.UserId })

					-- Schedule weapon recovery
					task.delay(Constants.DISARMED_DURATION, function()
						local cur = _pm.GetState(targetPlayer)
						if cur and cur.WeaponBroken then
							_pm.SetState(targetPlayer, { WeaponBroken = false, DisarmedTimer = 0 })
						end
					end)
				end
			end

			-- Unstagger after stun duration
			task.delay(Constants.GUARD_BREAK_STUN_TIME, function()
				local cur = _pm.GetState(targetPlayer)
				if cur and cur.IsStaggered then
					_pm.SetState(targetPlayer, { IsStaggered = false })
				end
			end)
		else
			_pm.SetState(targetPlayer, patch)
		end

	else
		-- Unblocked hit — deal full damage
		local damage = CombatUtils.CalculateDamage(attackerState, weaponTypeId, attackType)
		local newHealth = math.max(0, targetState.Health - damage)

		local targetPatch = {
			Health         = newHealth,
			LastCombatTime = now,
		}
		_pm.SetState(targetPlayer, targetPatch)

		-- Target takes heat from being hit
		local takenHeat = HeatUtils.GetHeatGain(targetState, "tookHit")
		_heatServer.AddHeat(targetPlayer, takenHeat)

		-- Notify nearby clients for VFX
		GetRemote("CombatHitConfirmed"):FireAllClients({
			attackerId = attacker.UserId,
			targetId   = targetPlayer.UserId,
			damage     = damage,
			attackType = attackType,
		})

		-- Kill check
		if newHealth <= 0 then
			HandleKill(attacker, targetPlayer)
		end
	end
end

-- ── Public initialiser ────────────────────────────────────────────────────────

function CombatServer.Init(pm, weaponServer, heatServer, rankServer)
	_pm           = pm
	_weaponServer = weaponServer
	_heatServer   = heatServer
	_rankServer   = rankServer

	-- ── Wire RemoteEvents ─────────────────────────────────────────────────────

	GetRemote("RequestLightAttack").OnServerEvent:Connect(function(player, data)
		if not data or not data.targetId then return end
		local target = GetTargetPlayer(data.targetId)
		if not target then return end
		ResolveHit(player, target, "light")
	end)

	GetRemote("RequestHeavyAttack").OnServerEvent:Connect(function(player, data)
		if not data or not data.targetId then return end
		local target = GetTargetPlayer(data.targetId)
		if not target then return end
		ResolveHit(player, target, "heavy")
	end)

	GetRemote("RequestBlock").OnServerEvent:Connect(function(player, isBlocking)
		local state = _pm.GetState(player)
		if not state then return end
		if state.IsCollapsed or state.IsStaggered then return end
		_pm.SetState(player, { IsBlocking = isBlocking == true })
	end)

	GetRemote("RequestWeaponSummon").OnServerEvent:Connect(function(player)
		local state = _pm.GetState(player)
		if not state then return end
		if state.WeaponBroken then return end
		_weaponServer.HandleSummon(player)
	end)

	GetRemote("RequestWeaponDismiss").OnServerEvent:Connect(function(player)
		_weaponServer.HandleDismiss(player)
	end)

	print("[CombatServer] Initialised and listening.")
end

return CombatServer
