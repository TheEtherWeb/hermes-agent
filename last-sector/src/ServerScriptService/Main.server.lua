-- Main.server.lua
-- Server bootstrap for Last Sector.
-- Initialises all server systems in dependency order, then wires RemoteEvents.

local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local ServerScriptService= game:GetService("ServerScriptService")
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")

-- ── Modules ──────────────────────────────────────────────────────────────────
local Modules       = ReplicatedStorage:WaitForChild("Modules")
local NetworkEvents = require(Modules:WaitForChild("NetworkEvents"))

-- ── Create all RemoteEvents and RemoteFunctions ───────────────────────────────
local RemoteFolder = Instance.new("Folder")
RemoteFolder.Name  = "Remotes"
RemoteFolder.Parent = ReplicatedStorage

local function makeRemoteEvent(name)
    local re = Instance.new("RemoteEvent")
    re.Name   = name
    re.Parent = RemoteFolder
    return re
end

local function makeRemoteFunction(name)
    local rf = Instance.new("RemoteFunction")
    rf.Name   = name
    rf.Parent = RemoteFolder
    return rf
end

-- S2C events
for _, name in pairs(NetworkEvents.S2C) do
    makeRemoteEvent(name)
end
-- C2S events
for _, name in pairs(NetworkEvents.C2S) do
    makeRemoteEvent(name)
end
-- Remote functions
for _, name in pairs(NetworkEvents.RF) do
    makeRemoteFunction(name)
end

print("[LastSector] Remotes created.")

-- ── Load Sub-Systems ─────────────────────────────────────────────────────────
-- Each manager module returns an object with an :Init() method.
local SSS       = ServerScriptService

local PlayerManager      = require(SSS:WaitForChild("PlayerManager"))
local CombatManager      = require(SSS:WaitForChild("CombatManager"))
local AugmentationManager= require(SSS:WaitForChild("AugmentationManager"))
local MissionManager     = require(SSS:WaitForChild("MissionManager"))
local FactionManager     = require(SSS:WaitForChild("FactionManager"))
local EnemyAI            = require(SSS:WaitForChild("EnemyAI"))

-- Initialise in dependency order
PlayerManager:Init(RemoteFolder)
print("[LastSector] PlayerManager ready.")

CombatManager:Init(RemoteFolder, PlayerManager)
print("[LastSector] CombatManager ready.")

AugmentationManager:Init(RemoteFolder, PlayerManager)
print("[LastSector] AugmentationManager ready.")

FactionManager:Init(RemoteFolder, PlayerManager)
print("[LastSector] FactionManager ready.")

MissionManager:Init(RemoteFolder, PlayerManager, FactionManager)
print("[LastSector] MissionManager ready.")

EnemyAI:Init(PlayerManager, CombatManager)
print("[LastSector] EnemyAI ready.")

print("[LastSector] Server fully initialised. Waiting for contractors.")

-- ── Global tick ──────────────────────────────────────────────────────────────
-- Used for passive systems: regen, IL passives, incursion timers.
local TICK_RATE = 1  -- seconds between server ticks

local lastTick = 0
RunService.Heartbeat:Connect(function(dt)
    local now = tick()
    if now - lastTick < TICK_RATE then return end
    lastTick = now

    PlayerManager:Tick(TICK_RATE)
    MissionManager:Tick(TICK_RATE)
    EnemyAI:Tick(TICK_RATE)
end)
