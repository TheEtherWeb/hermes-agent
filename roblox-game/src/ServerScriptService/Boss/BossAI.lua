-- BossAI.lua (ModuleScript — spawned by GameManager after delay)
-- Prototype boss NPC state machine with 4 states: Idle, Engage, Attack, Recover.
-- Boss runs entirely server-side and applies damage directly via PlayerManager.

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local PathfindingService  = game:GetService("PathfindingService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Workspace           = game:GetService("Workspace")

local Constants     = require(ReplicatedStorage.Data.Constants)
local CombatUtils   = require(ReplicatedStorage.Shared.CombatUtils)

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)

local BossAI = {}

-- Boss internal state (plain table, not a PlayerState)
local _boss = nil

-- ── Boss configuration ────────────────────────────────────────────────────────

local BOSS_CONFIG = {
	Name            = "The Alloyguard",
	MaxHealth       = 500,
	MoveSpeed       = 14,
	EngageRange     = 40,   -- studs: begin chasing
	AttackRange     = 12,   -- studs: begin attacking
	LightDamage     = 15,
	HeavyDamage     = 35,
	GuardDamage     = 20,
	AttackCooldown  = 1.2,
	HeavyChance     = 0.35, -- 35% chance to throw a heavy
	PhaseThreshold  = 0.5,  -- switch to Phase 2 at 50% HP
	Phase2SpeedMult = 1.3,
	Phase2CooldownMult = 0.75,
	RecoverTime     = 2.0,
	SpawnCFrame     = CFrame.new(0, 5, -60),  -- adjust to match your arena
}

local function GetRemote(name)
	return RemotesFolder:WaitForChild(name, 5)
end

-- ── Boss model construction (placeholder geometry) ───────────────────────────

local function BuildBossModel()
	local model = Instance.new("Model")
	model.Name = BOSS_CONFIG.Name

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Anchored = false
	root.CanCollide = true
	root.BrickColor = BrickColor.new("Dark stone grey")
	root.CFrame = BOSS_CONFIG.SpawnCFrame
	root.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = BOSS_CONFIG.MaxHealth
	humanoid.Health    = BOSS_CONFIG.MaxHealth
	humanoid.WalkSpeed = BOSS_CONFIG.MoveSpeed
	humanoid.Parent = model

	model.PrimaryPart = root
	model.Parent = Workspace

	return model, humanoid, root
end

-- ── Nearest player helper ─────────────────────────────────────────────────────

local function GetNearestPlayer(bossRoot)
	local nearest, nearestDist = nil, math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if not char then continue end
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then continue end
		local dist = (bossRoot.Position - root.Position).Magnitude
		if dist < nearestDist then
			nearest = player
			nearestDist = dist
		end
	end
	return nearest, nearestDist
end

-- ── Boss damage application (server-side, bypasses RemoteEvents) ──────────────

local function BossHitPlayer(targetPlayer, attackType)
	-- Requires PlayerManager; we load it lazily to avoid circular issues at module load time
	local PlayerManager = require(script.Parent.Parent.PlayerManager)
	local state = PlayerManager.GetState(targetPlayer)
	if not state or state.IsCollapsed then return end

	local damage = (attackType == "heavy") and BOSS_CONFIG.HeavyDamage or BOSS_CONFIG.LightDamage
	local newHealth = math.max(0, state.Health - damage)

	PlayerManager.SetState(targetPlayer, {
		Health = newHealth,
		LastCombatTime = tick(),
	})

	GetRemote("CombatHitConfirmed"):FireAllClients({
		attackerId = -1,  -- -1 signals boss
		targetId   = targetPlayer.UserId,
		damage     = damage,
		attackType = attackType,
	})
end

-- ── Pathfinding helper ────────────────────────────────────────────────────────

local function MoveToward(humanoid, targetPosition)
	local path = PathfindingService:CreatePath({
		AgentRadius    = 2,
		AgentHeight    = 5,
		AgentCanJump   = true,
		AgentMaxSlope  = 45,
	})
	local ok, err = pcall(function()
		path:ComputeAsync(humanoid.Parent.HumanoidRootPart.Position, targetPosition)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		-- Fallback: move directly
		humanoid:MoveTo(targetPosition)
		return
	end
	local waypoints = path:GetWaypoints()
	for _, wp in ipairs(waypoints) do
		humanoid:MoveTo(wp.Position)
		humanoid.MoveToFinished:Wait()
	end
end

-- ── State machine ─────────────────────────────────────────────────────────────

local function RunBossLoop(model, humanoid, bossRoot)
	local state = {
		currentState   = "Idle",
		health         = BOSS_CONFIG.MaxHealth,
		phase          = 1,
		attackTimer    = 0,
		recoverTimer   = 0,
		target         = nil,
	}

	local function IsPhase2()
		return state.health <= (BOSS_CONFIG.MaxHealth * BOSS_CONFIG.PhaseThreshold)
	end

	local function GetAttackCooldown()
		local base = BOSS_CONFIG.AttackCooldown
		return IsPhase2() and (base * BOSS_CONFIG.Phase2CooldownMult) or base
	end

	local function GetMoveSpeed()
		return IsPhase2() and (BOSS_CONFIG.MoveSpeed * BOSS_CONFIG.Phase2SpeedMult) or BOSS_CONFIG.MoveSpeed
	end

	-- Sync boss HP to the Humanoid and fire the UI event
	local function SyncHealth()
		humanoid.Health = math.max(0, state.health)
		GetRemote("BossHealthUpdate"):FireAllClients({
			health    = state.health,
			maxHealth = BOSS_CONFIG.MaxHealth,
			phase     = IsPhase2() and 2 or 1,
		})
	end

	-- Connect Humanoid health changes from boss taking damage (placeholder: boss is invincible in prototype;
	-- swap for real damage logic when adding player-to-boss attack handling)
	humanoid.HealthChanged:Connect(function(newHp)
		state.health = newHp
		SyncHealth()
		if newHp <= 0 then
			state.currentState = "Dead"
		end
	end)

	GetRemote("BossSpawned"):FireAllClients({
		name      = BOSS_CONFIG.Name,
		health    = state.health,
		maxHealth = BOSS_CONFIG.MaxHealth,
	})

	local lastTick = tick()

	RunService.Heartbeat:Connect(function()
		if state.currentState == "Dead" then
			-- Grant XP to all players in range and broadcast defeat
			for _, player in ipairs(Players:GetPlayers()) do
				local char = player.Character
				if char then
					local root = char:FindFirstChild("HumanoidRootPart")
					if root and (bossRoot.Position - root.Position).Magnitude <= 80 then
						local RankServer = require(script.Parent.Parent.RankServer)
						RankServer.GrantXP(player, Constants.XP_PER_BOSS_KILL)
					end
				end
			end
			GetRemote("BossDefeated"):FireAllClients({})
			model:Destroy()
			return
		end

		local now = tick()
		local dt = now - lastTick
		lastTick = now

		humanoid.WalkSpeed = GetMoveSpeed()

		if state.currentState == "Idle" then
			local nearest, dist = GetNearestPlayer(bossRoot)
			if nearest and dist <= BOSS_CONFIG.EngageRange then
				state.target = nearest
				state.currentState = "Engage"
			end

		elseif state.currentState == "Engage" then
			if not state.target or not state.target.Character then
				state.currentState = "Idle"
				return
			end
			local tRoot = state.target.Character:FindFirstChild("HumanoidRootPart")
			if not tRoot then
				state.currentState = "Idle"
				return
			end
			local dist = (bossRoot.Position - tRoot.Position).Magnitude
			if dist <= BOSS_CONFIG.AttackRange then
				state.currentState = "Attack"
				state.attackTimer = 0
			else
				task.spawn(MoveToward, humanoid, tRoot.Position)
			end

		elseif state.currentState == "Attack" then
			state.attackTimer = state.attackTimer + dt
			if state.attackTimer >= GetAttackCooldown() then
				state.attackTimer = 0
				-- Pick attack type
				local attackType = (math.random() < BOSS_CONFIG.HeavyChance) and "heavy" or "light"
				if state.target and state.target.Character then
					local tRoot = state.target.Character:FindFirstChild("HumanoidRootPart")
					if tRoot and (bossRoot.Position - tRoot.Position).Magnitude <= BOSS_CONFIG.AttackRange + 2 then
						BossHitPlayer(state.target, attackType)
					else
						-- Target moved away
						state.currentState = "Engage"
					end
				end
				state.currentState = "Recover"
				state.recoverTimer = 0
			end

		elseif state.currentState == "Recover" then
			state.recoverTimer = state.recoverTimer + dt
			if state.recoverTimer >= BOSS_CONFIG.RecoverTime then
				-- Re-check if target is still valid
				local nearest, dist = GetNearestPlayer(bossRoot)
				if nearest and dist <= BOSS_CONFIG.EngageRange then
					state.target = nearest
					state.currentState = (dist <= BOSS_CONFIG.AttackRange) and "Attack" or "Engage"
				else
					state.currentState = "Idle"
				end
			end
		end
	end)
end

-- ── Public API ────────────────────────────────────────────────────────────────

function BossAI.Spawn()
	if _boss then return end  -- already spawned

	local model, humanoid, bossRoot = BuildBossModel()
	_boss = { model = model, humanoid = humanoid }

	print("[BossAI] " .. BOSS_CONFIG.Name .. " has appeared.")
	RunBossLoop(model, humanoid, bossRoot)
end

return BossAI
