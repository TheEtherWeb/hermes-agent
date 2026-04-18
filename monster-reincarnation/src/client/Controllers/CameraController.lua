--!strict
-- Over-the-shoulder third-person camera tuning. Kept minimal; Roblox default
-- plus tighter offset + zoom limits.

local Players = game:GetService("Players")

local CameraController = {}

function CameraController.init()
	local localPlayer = Players.LocalPlayer
	localPlayer.CameraMode = Enum.CameraMode.Classic
	localPlayer.CameraMinZoomDistance = 6
	localPlayer.CameraMaxZoomDistance = 16

	local function applyToChar(char: Model)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.CameraOffset = Vector3.new(1.5, 0, 0)
			hum.AutoRotate = true
		end
	end

	if localPlayer.Character then applyToChar(localPlayer.Character) end
	localPlayer.CharacterAdded:Connect(applyToChar)
end

return CameraController
