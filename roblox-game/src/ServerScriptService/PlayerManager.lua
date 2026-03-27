-- PlayerManager.lua (ModuleScript — required by GameManager and other server scripts)
-- Manages all player states on the server.
-- Exposes GetState / SetState to other server-side modules.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants         = require(ReplicatedStorage.Data.Constants)
local PlayerStateSchema = require(ReplicatedStorage.Shared.PlayerStateSchema)
local Families          = require(ReplicatedStorage.Data.Families)
local Traits            = require(ReplicatedStorage.Data.Traits)
local WeaponTypes       = require(ReplicatedStorage.Data.WeaponTypes)

local RemotesFolder     = ReplicatedStorage:WaitForChild("Remotes", 10)

local PlayerManager = {}

-- server-side state store
local _states = {}  -- [userId] = PlayerState table

-- ── Internal helpers ──────────────────────────────────────────────────────────

local function GetRemote(name)
	return RemotesFolder:WaitForChild(name, 5)
end

-- ── Public API ────────────────────────────────────────────────────────────────

function PlayerManager.GetState(player)
	return _states[player.UserId]
end

-- Apply a patch to the player's state and notify their client.
function PlayerManager.SetState(player, patch)
	local state = _states[player.UserId]
	if not state then return end

	local oldState = {}
	for k, v in pairs(state) do oldState[k] = v end

	PlayerStateSchema.Apply(state, patch)

	local diff = PlayerStateSchema.Diff(oldState, state)
	if next(diff) then
		GetRemote("StateChanged"):FireClient(player, diff)
	end
end

-- ── Guard regen tick (called from GameManager Heartbeat) ─────────────────────

function PlayerManager.TickGuardRegen(dt)
	local now = tick()
	for userId, state in pairs(_states) do
		local player = Players:GetPlayerByUserId(userId)
		if not player then continue end

		if state.Guard < state.MaxGuard
			and not state.IsBlocking
			and not state.IsCollapsed
			and (now - state.LastGuardHitTime) >= Constants.GUARD_REGEN_DELAY
		then
			local newGuard = math.min(state.MaxGuard, state.Guard + Constants.GUARD_REGEN_RATE * dt)
			if newGuard ~= state.Guard then
				PlayerManager.SetState(player, { Guard = newGuard })
			end
		end
	end
end

-- ── Player join / leave ───────────────────────────────────────────────────────

function PlayerManager.OnPlayerAdded(player)
	-- Prompt character creation on the client
	task.spawn(function()
		local promptRemote = GetRemote("PromptCharacterSetup")
		local submitRemote = GetRemote("SubmitCharacterSetup") ---@type RemoteFunction

		-- Give the client a moment to initialise
		task.wait(1)
		promptRemote:FireClient(player)

		-- Block until the client submits a valid setup (timeout after 60s, use defaults)
		local race, familyId, traitId, weaponStyle
		local submitted = false

		submitRemote.OnServerInvoke = function(invokePlayer, setup)
			if invokePlayer ~= player then return { success = false, error = "Wrong player" } end

			-- Validate race
			if setup.race ~= "Gem" and setup.race ~= "Ore" then
				return { success = false, error = "Invalid race" }
			end
			-- Validate family
			local family = Families:Get(setup.race, setup.family)
			if not family then
				return { success = false, error = "Unknown family" }
			end
			-- Validate trait
			local traitDefs = Traits[setup.race]
			if not traitDefs or not traitDefs[setup.trait] then
				return { success = false, error = "Unknown trait" }
			end
			-- Validate weapon style
			if not WeaponTypes[setup.weaponStyle] then
				return { success = false, error = "Unknown weapon style" }
			end
			-- Race / weapon variant check
			local weaponDef = WeaponTypes[setup.weaponStyle]
			if weaponDef.race ~= setup.race then
				return { success = false, error = "Weapon variant does not match race" }
			end

			race        = setup.race
			familyId    = setup.family
			traitId     = setup.trait
			weaponStyle = setup.weaponStyle
			submitted   = true

			return { success = true }
		end

		-- Wait up to 60 seconds for the player to submit
		local waitStart = tick()
		while not submitted and (tick() - waitStart) < 60 do
			task.wait(0.5)
		end

		-- Defaults if player never submitted (useful for debugging)
		if not submitted then
			race        = "Gem"
			familyId    = "Diamond"
			traitId     = "Faceted"
			weaponStyle = "Sword_Projection"
			warn("[PlayerManager] " .. player.Name .. " timed out on setup. Using defaults.")
		end

		-- Construct and store state
		local state = PlayerStateSchema.New(player.UserId, race, familyId, traitId, weaponStyle)
		_states[player.UserId] = state

		-- Send initial full state to the client
		local getStateRemote = GetRemote("GetPlayerState") ---@type RemoteFunction
		getStateRemote.OnServerInvoke = function(invokePlayer)
			if invokePlayer ~= player then return nil end
			return _states[player.UserId]
		end

		-- Fire an initial StateChanged with the full state so the client mirror is populated
		GetRemote("StateChanged"):FireClient(player, state)
		print("[PlayerManager] State initialized for " .. player.Name .. " as " .. race .. " / " .. familyId)
	end)
end

function PlayerManager.OnPlayerRemoving(player)
	-- DataStore save stub
	local state = _states[player.UserId]
	if state then
		print("[PlayerManager] Saving state for " .. player.Name .. " (stub) - Rank " .. tostring(state.RankIndex) .. ", XP " .. tostring(state.XP))
	end
	_states[player.UserId] = nil
end

-- Direct-write for boss/server use (no patch diffing, forces full send)
function PlayerManager.SetStateRaw(player, state)
	_states[player.UserId] = state
	GetRemote("StateChanged"):FireClient(player, state)
end

return PlayerManager
