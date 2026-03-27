-- WeaponStateUI.client.lua
-- Displays weapon name, broken overlay, and disarmed countdown.

local TweenService     = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponTypes       = require(ReplicatedStorage.Data.WeaponTypes)

local WeaponStateUI = {}

local frame, nameLabel, brokenOverlay, brokenLabel, disarmedLabel
local _disarmedConn

local function BuildPanel(gui)
	frame = Instance.new("Frame")
	frame.Name = "WeaponState_Frame"
	frame.Size = UDim2.new(0, 180, 0, 70)
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -10, 0, 10)
	frame.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	frame.BackgroundTransparency = 0.4
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "NO WEAPON"
	nameLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 15
	nameLabel.Parent = frame

	disarmedLabel = Instance.new("TextLabel")
	disarmedLabel.Size = UDim2.new(1, 0, 0.45, 0)
	disarmedLabel.Position = UDim2.new(0, 0, 0.55, 0)
	disarmedLabel.BackgroundTransparency = 1
	disarmedLabel.Text = ""
	disarmedLabel.TextColor3 = Color3.fromRGB(200, 200, 60)
	disarmedLabel.Font = Enum.Font.Gotham
	disarmedLabel.TextSize = 13
	disarmedLabel.Parent = frame

	-- Broken overlay (hidden by default)
	brokenOverlay = Instance.new("Frame")
	brokenOverlay.Size = UDim2.new(1, 0, 1, 0)
	brokenOverlay.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
	brokenOverlay.BackgroundTransparency = 0.3
	brokenOverlay.BorderSizePixel = 0
	brokenOverlay.Visible = false
	brokenOverlay.Parent = frame

	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = brokenOverlay

	brokenLabel = Instance.new("TextLabel")
	brokenLabel.Size = UDim2.new(1, 0, 1, 0)
	brokenLabel.BackgroundTransparency = 1
	brokenLabel.Text = "BROKEN"
	brokenLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	brokenLabel.Font = Enum.Font.GothamBold
	brokenLabel.TextSize = 20
	brokenLabel.Parent = brokenOverlay
end

local function StartDisarmedCountdown(duration)
	if _disarmedConn then _disarmedConn:Disconnect() end
	local remaining = duration
	local step = 0.1
	_disarmedConn = game:GetService("RunService").Heartbeat:Connect(function(dt)
		remaining = remaining - dt
		if remaining <= 0 then
			disarmedLabel.Text = ""
			_disarmedConn:Disconnect()
			_disarmedConn = nil
		else
			disarmedLabel.Text = string.format("DISARMED %.1fs", remaining)
		end
	end)
end

function WeaponStateUI.OnStateChanged(state, patch)
	if not frame then
		BuildPanel(_G.ScreenGui)
	end

	-- Weapon name
	if patch.WeaponStyle or patch.WeaponActive ~= nil then
		if state.WeaponActive then
			local def = WeaponTypes[state.WeaponStyle]
			nameLabel.Text = def and def.displayName or state.WeaponStyle
			nameLabel.TextColor3 = (state.Race == "Gem")
				and Color3.fromRGB(120, 220, 255)
				or Color3.fromRGB(255, 160, 80)
		else
			nameLabel.Text = "NO WEAPON"
			nameLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
		end
	end

	-- Broken overlay
	if patch.WeaponBroken ~= nil then
		if patch.WeaponBroken then
			brokenOverlay.Visible = true
			StartDisarmedCountdown(state.DisarmedTimer > 0 and state.DisarmedTimer or 8)
		else
			brokenOverlay.Visible = false
			disarmedLabel.Text = ""
		end
	end
end

return WeaponStateUI
