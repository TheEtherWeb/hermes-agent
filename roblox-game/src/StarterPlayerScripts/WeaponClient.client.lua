-- WeaponClient.client.lua
-- Fires weapon summon/dismiss remotes, shows/hides local weapon model,
-- and reacts to WeaponBroken / state changes.

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponTypes = require(ReplicatedStorage.Data.WeaponTypes)
local LocalPlayer = Players.LocalPlayer

local WeaponClient = {}

-- Currently shown weapon Part (placeholder cube geometry)
local _weaponModel = nil

-- ── Weapon model helpers ──────────────────────────────────────────────────────

local function SpawnWeaponModel(weaponTypeId)
	local char = LocalPlayer.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- Destroy existing model if any
	if _weaponModel then
		_weaponModel:Destroy()
		_weaponModel = nil
	end

	local weaponDef = WeaponTypes[weaponTypeId]
	if not weaponDef then return end

	-- Placeholder geometry: a coloured brick in the right hand position
	local model = Instance.new("Part")
	model.Name = "WeaponModel_" .. weaponTypeId

	-- Size by weapon type
	local sizeMap = {
		Dagger    = Vector3.new(0.2, 0.8, 0.1),
		Sword     = Vector3.new(0.2, 2.0, 0.1),
		Greatsword = Vector3.new(0.3, 3.5, 0.15),
		Spear     = Vector3.new(0.15, 4.5, 0.15),
	}
	model.Size = sizeMap[weaponDef.baseType] or Vector3.new(0.2, 2, 0.1)

	-- Colour by variant
	model.BrickColor = (weaponDef.variant == "Projection")
		and BrickColor.new("Cyan")
		or BrickColor.new("Dark orange")

	model.Material = Enum.Material.Neon
	model.CanCollide = false
	model.Anchored = false

	-- Weld to right hand
	local rightArm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
	if rightArm then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = rightArm
		weld.Part1 = model
		weld.Parent = model
		model.CFrame = rightArm.CFrame * CFrame.new(0, -model.Size.Y * 0.5 - 0.5, 0)
	end

	model.Parent = char
	_weaponModel = model
end

local function DespawnWeaponModel()
	if _weaponModel then
		_weaponModel:Destroy()
		_weaponModel = nil
	end
end

local function ShowBrokenOverlay()
	if not _weaponModel then return end
	_weaponModel.BrickColor = BrickColor.new("Dark red")
	_weaponModel.Material   = Enum.Material.SmoothPlastic
end

-- ── Summon / dismiss requests ─────────────────────────────────────────────────

function WeaponClient.RequestSummon()
	local state = _G.LocalPlayerState
	if not state then return end
	if state.WeaponBroken or state.IsCollapsed then return end

	_G.Remotes.RequestWeaponSummon:FireServer()

	-- Optimistic client-side: show weapon immediately (server will confirm via StateChanged)
	SpawnWeaponModel(state.WeaponStyle)
end

function WeaponClient.RequestDismiss()
	_G.Remotes.RequestWeaponDismiss:FireServer()
	DespawnWeaponModel()
end

-- ── State change reactions ────────────────────────────────────────────────────

local function OnStateChanged(state, patch)
	if patch.WeaponActive ~= nil then
		if patch.WeaponActive then
			SpawnWeaponModel(state.WeaponStyle)
		else
			DespawnWeaponModel()
		end
	end

	if patch.WeaponBroken ~= nil then
		if patch.WeaponBroken then
			ShowBrokenOverlay()
		elseif state.WeaponActive then
			SpawnWeaponModel(state.WeaponStyle)
		end
	end
end

-- Chain into the global state changed callback
local _prev = _G.OnStateChanged
_G.OnStateChanged = function(state, patch)
	OnStateChanged(state, patch)
	if _prev then _prev(state, patch) end
end

-- Listen for WeaponBroken remote (direct notification, not via StateChanged)
task.defer(function()
	while not (_G.Remotes and _G.Remotes.WeaponBroken) do task.wait(0.1) end
	_G.Remotes.WeaponBroken.OnClientEvent:Connect(function(_data)
		ShowBrokenOverlay()
	end)
end)

return WeaponClient
