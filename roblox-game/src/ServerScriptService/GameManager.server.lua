-- GameManager.server.lua
-- Bootstrap script. Runs first on the server.
-- Responsibilities:
--   1. Create all RemoteEvent / RemoteFunction instances in ReplicatedStorage.Remotes
--   2. Wire Players.PlayerAdded / PlayerRemoving to PlayerManager
--   3. Spawn the prototype boss NPC
--   4. Start global Heartbeat tick loops (heat decay, resonance drain, guard regen)

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for the Remotes folder (created by rojo.json manifest)
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
if not RemotesFolder then
	RemotesFolder = Instance.new("Folder")
	RemotesFolder.Name = "Remotes"
	RemotesFolder.Parent = ReplicatedStorage
end

-- ── 1. Create all RemoteEvents ────────────────────────────────────────────────

local REMOTE_EVENTS = {
	-- Client → Server
	"RequestLightAttack",
	"RequestHeavyAttack",
	"RequestBlock",
	"RequestWeaponSummon",
	"RequestWeaponDismiss",
	-- Server → Client
	"StateChanged",
	"CombatHitConfirmed",
	"GuardBroken",
	"WeaponBroken",
	"PlayerCollapsed",
	"RankUp",
	"BossDefeated",
	"PromptCharacterSetup",
	-- Boss
	"BossSpawned",
	"BossHealthUpdate",
}

local REMOTE_FUNCTIONS = {
	"SubmitCharacterSetup",
	"GetPlayerState",
}

for _, name in ipairs(REMOTE_EVENTS) do
	if not RemotesFolder:FindFirstChild(name) then
		local re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = RemotesFolder
	end
end

for _, name in ipairs(REMOTE_FUNCTIONS) do
	if not RemotesFolder:FindFirstChild(name) then
		local rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = RemotesFolder
	end
end

print("[GameManager] All remotes created.")

-- ── 2. Load server managers (require after remotes exist) ─────────────────────

local PlayerManager = require(script.Parent.PlayerManager)
local WeaponServer  = require(script.Parent.WeaponServer)
local HeatServer    = require(script.Parent.HeatServer)
local RankServer    = require(script.Parent.RankServer)

-- Inject PlayerManager into sub-servers (avoids circular require at module level)
WeaponServer.SetPlayerManager(PlayerManager)
HeatServer.SetPlayerManager(PlayerManager)
RankServer.SetPlayerManager(PlayerManager)

-- CombatServer wires itself in its own module; we just require it to activate.
local CombatServer = require(script.Parent.CombatServer)
CombatServer.Init(PlayerManager, WeaponServer, HeatServer, RankServer)

-- ── 3. Wire player join / leave ───────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	PlayerManager.OnPlayerAdded(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerManager.OnPlayerRemoving(player)
end)

-- Handle players who joined before this script ran (Studio play-solo edge case)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(PlayerManager.OnPlayerAdded, player)
end

-- ── 4. Spawn prototype boss ───────────────────────────────────────────────────

task.delay(5, function()
	-- Boss is spawned after a brief delay so the arena has time to load.
	local BossAI = require(script.Parent.Boss.BossAI)
	BossAI.Spawn()
end)

-- ── 5. Global Heartbeat loops ─────────────────────────────────────────────────

RunService.Heartbeat:Connect(function(dt)
	HeatServer.Tick(dt)
	WeaponServer.Tick(dt)
	PlayerManager.TickGuardRegen(dt)
end)

print("[GameManager] Boot complete.")
