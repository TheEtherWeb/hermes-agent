--!strict
-- Client-side input for combat. Predicts stance switch locally for responsive
-- feel; authoritative resolution is server-side.

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes: any = require(Shared:WaitForChild("Remotes"))

local CombatController = {}

local localPlayer = Players.LocalPlayer
local currentStance = "OneHand"

local STANCE_KEYS = {
	[Enum.KeyCode.One]   = "OneHand",
	[Enum.KeyCode.Two]   = "TwoHand",
	[Enum.KeyCode.Three] = "DualWield",
	[Enum.KeyCode.Four]  = "SpellGrip",
}

local function mouseWorldPos(): Vector3?
	local mouse = localPlayer:GetMouse()
	return mouse and mouse.Hit and mouse.Hit.Position
end

local function nearestTargetUnderMouse(): (string?, string?, Vector3?)
	-- Simplistic: raycast forward from camera and return the object's name if
	-- it matches a known target convention (Name starts with "NPC_" or is a Player).
	local camera = workspace.CurrentCamera
	if not camera then return nil, nil, nil end
	local pos, dir
	do
		local mouse = localPlayer:GetMouse()
		local unit = mouse.UnitRay.Direction
		pos = camera.CFrame.Position
		dir = unit * 200
	end
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { localPlayer.Character or Instance.new("Model") }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(pos, dir, params)
	if not result then return nil, nil, nil end
	local inst = result.Instance
	local model = inst:FindFirstAncestorOfClass("Model")
	if not model then return nil, nil, result.Position end

	-- Player?
	local plr = Players:GetPlayerFromCharacter(model)
	if plr and plr ~= localPlayer then
		return "player", tostring(plr.UserId), result.Position
	end
	-- NPC convention: ObjectValue/StringValue "NpcId" on the model.
	local idTag = model:FindFirstChild("NpcId")
	if idTag and idTag:IsA("StringValue") then
		return "npc", idTag.Value, result.Position
	end
	return nil, nil, result.Position
end

function CombatController.attack()
	local kind, id, pos = nearestTargetUnderMouse()
	if not kind or not id or not pos then return end
	Remotes.event("Combat_Attack"):FireServer({
		targetKind = kind,
		targetId = id,
		targetPos = { x = pos.X, y = pos.Y, z = pos.Z },
	})
end

function CombatController.switchStance(stance: string)
	if currentStance == stance then return end
	currentStance = stance
	Remotes.event("Combat_SwitchStance"):FireServer(stance)
end

function CombatController.parry()
	Remotes.event("Combat_Parry"):FireServer({})
end

function CombatController.init(_profile: any)
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			CombatController.attack()
		elseif input.KeyCode == Enum.KeyCode.F then
			CombatController.parry()
		else
			local stance = STANCE_KEYS[input.KeyCode]
			if stance then CombatController.switchStance(stance) end
		end
	end)
end

function CombatController.currentStance(): string
	return currentStance
end

return CombatController
