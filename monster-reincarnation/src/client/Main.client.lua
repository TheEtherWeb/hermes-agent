--!strict
-- Client entry. Boots the UI layers and input controllers. Profile-driven.

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes: any = require(Shared:WaitForChild("Remotes"))

local UI = script.Parent:WaitForChild("UI")
local Controllers = script.Parent:WaitForChild("Controllers")

local HUD              = require(UI:WaitForChild("HUD"))
local InventoryUI      = require(UI:WaitForChild("InventoryUI"))
local CraftingUI       = require(UI:WaitForChild("CraftingUI"))
local EvolutionUI      = require(UI:WaitForChild("EvolutionUI"))
local GuildUI          = require(UI:WaitForChild("GuildUI"))
local MarketplaceUI    = require(UI:WaitForChild("MarketplaceUI"))
local DungeonUI        = require(UI:WaitForChild("DungeonUI"))
local ContractUI       = require(UI:WaitForChild("ContractUI"))
local NotificationUI   = require(UI:WaitForChild("NotificationUI"))

local CombatController = require(Controllers:WaitForChild("CombatController"))
local CameraController = require(Controllers:WaitForChild("CameraController"))

local localPlayer = Players.LocalPlayer

-- Hide the default leaderboard; we present our own overlay.
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)

-- Fetch profile, then initialise UIs with layered reveal: HUD first, then
-- inventory & combat, then crafting / evolution / guild / economy.
local profile = Remotes.func("Profile_Get"):InvokeServer()

HUD.init(profile)
NotificationUI.init()
CombatController.init(profile)
CameraController.init()

task.defer(function()
	InventoryUI.init(profile)
	CraftingUI.init(profile)
	EvolutionUI.init(profile)
end)

task.delay(0.5, function()
	GuildUI.init(profile)
	MarketplaceUI.init(profile)
	DungeonUI.init(profile)
	ContractUI.init(profile)
end)

-- Live profile updates from server
Remotes.event("Profile_Replicate").OnClientEvent:Connect(function(newProfile)
	HUD.onProfile(newProfile)
	InventoryUI.onProfile(newProfile)
	EvolutionUI.onProfile(newProfile)
	GuildUI.onProfile(newProfile)
end)

-- Notifications
Remotes.event("UI_SendNotification").OnClientEvent:Connect(function(payload)
	NotificationUI.show(payload)
end)

print("[MonsterReincarnation] Client ready.")
