-- UIManager.client.lua
-- Mounts all ScreenGui panels and routes StateChanged patches to sub-controllers.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local UIManager = {}

-- ── Build ScreenGui ───────────────────────────────────────────────────────────

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "GameHUD"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

_G.ScreenGui = screenGui

-- ── Sub-controllers (required after ScreenGui exists) ────────────────────────

local HUDController    = require(script.Parent.HUDController)
local WeaponStateUI    = require(script.Parent.WeaponStateUI)
local CodexController  = require(script.Parent.CodexController)

_G.CodexController = CodexController

-- ── State routing ─────────────────────────────────────────────────────────────

local function RouteStateChange(state, patch)
	HUDController.OnStateChanged(state, patch)
	WeaponStateUI.OnStateChanged(state, patch)
end

-- Chain into global callback
local _prev = _G.OnStateChanged
_G.OnStateChanged = function(state, patch)
	RouteStateChange(state, patch)
	if _prev then _prev(state, patch) end
end

-- ── Character setup prompt ────────────────────────────────────────────────────
-- Simple race/family picker shown before the HUD is visible.

local function BuildSetupPanel()
	local frame = Instance.new("Frame")
	frame.Name = "SetupPanel"
	frame.Size = UDim2.new(0, 500, 0, 380)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 8)
	uiCorner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 50)
	title.BackgroundTransparency = 1
	title.Text = "Choose Your Form"
	title.TextColor3 = Color3.fromRGB(220, 220, 220)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 24
	title.Parent = frame

	-- Race buttons
	local gemBtn = Instance.new("TextButton")
	gemBtn.Size = UDim2.new(0.42, 0, 0, 60)
	gemBtn.Position = UDim2.new(0.05, 0, 0.18, 0)
	gemBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 140)
	gemBtn.Text = "GEM\n(Projection)"
	gemBtn.TextColor3 = Color3.fromRGB(200, 230, 255)
	gemBtn.Font = Enum.Font.GothamBold
	gemBtn.TextSize = 16
	gemBtn.Parent = frame

	local oreBtn = Instance.new("TextButton")
	oreBtn.Size = UDim2.new(0.42, 0, 0, 60)
	oreBtn.Position = UDim2.new(0.53, 0, 0.18, 0)
	oreBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 20)
	oreBtn.Text = "ORE\n(Extraction)"
	oreBtn.TextColor3 = Color3.fromRGB(255, 200, 150)
	oreBtn.Font = Enum.Font.GothamBold
	oreBtn.TextSize = 16
	oreBtn.Parent = frame

	-- Confirm button
	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Size = UDim2.new(0.5, 0, 0, 48)
	confirmBtn.Position = UDim2.new(0.25, 0, 0.82, 0)
	confirmBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 80)
	confirmBtn.Text = "CONFIRM"
	confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	confirmBtn.Font = Enum.Font.GothamBold
	confirmBtn.TextSize = 18
	confirmBtn.Parent = frame

	local selectedRace = "Gem"

	gemBtn.MouseButton1Click:Connect(function()
		selectedRace = "Gem"
		gemBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
		oreBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 20)
	end)

	oreBtn.MouseButton1Click:Connect(function()
		selectedRace = "Ore"
		oreBtn.BackgroundColor3 = Color3.fromRGB(180, 90, 30)
		gemBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 140)
	end)

	confirmBtn.MouseButton1Click:Connect(function()
		-- Defaults per race for prototype speed
		local defaults = {
			Gem = { family = "Diamond", trait = "Faceted", weapon = "Sword_Projection" },
			Ore = { family = "Iron",    trait = "Forged",  weapon = "Sword_Extraction" },
		}
		local d = defaults[selectedRace]
		local result = _G.Remotes.SubmitCharacterSetup:InvokeServer({
			race        = selectedRace,
			family      = d.family,
			trait       = d.trait,
			weaponStyle = d.weapon,
		})
		if result and result.success then
			frame:Destroy()
		else
			title.Text = "Error: " .. tostring(result and result.error or "retry")
		end
	end)

	return frame
end

-- Wire setup prompt
_G.OnShowCharacterSetup = function()
	BuildSetupPanel()
end

print("[UIManager] Mounted.")

return UIManager
