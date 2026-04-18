--!strict
-- Evolution panel toggled with [V]. Lists available nodes and their unlock
-- status. Clicking an unlocked node requests evolution from server.

local UIUtil = require(script.Parent:WaitForChild("UIUtil"))
local Remotes: any = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))

local EvolutionUI = {}

local listFrame: ScrollingFrame

local function refresh()
	if not listFrame then return end
	for _, c in ipairs(listFrame:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	local tree = Remotes.func("EvolutionTree_Get"):InvokeServer()
	local y = 0
	for _, node in ipairs(tree or {}) do
		local row = UIUtil.frame(listFrame, {
			Size = UDim2.new(1, -12, 0, 44),
			Position = UDim2.new(0, 4, 0, y),
			BackgroundColor3 = node.unlocked and Color3.fromRGB(40, 70, 55) or Color3.fromRGB(35, 25, 35),
		})
		UIUtil.label(row, node.display .. " (" .. (node.branch or "?") .. ")", {
			Position = UDim2.new(0, 8, 0, 4), Size = UDim2.new(1, -120, 0, 20), TextSize = 14,
		})
		UIUtil.label(row, node.unlocked and "Available" or "Locked", {
			Position = UDim2.new(0, 8, 0, 22), Size = UDim2.new(1, -120, 0, 18),
			TextColor3 = node.unlocked and Color3.fromRGB(140, 230, 160) or Color3.fromRGB(200, 130, 130),
		})
		if node.unlocked then
			UIUtil.button(row, "Evolve", function()
				Remotes.event("Evolution_Choose"):FireServer(node.id)
				task.delay(0.5, refresh)
			end, { Position = UDim2.new(1, -84, 0, 9), Size = UDim2.new(0, 78, 0, 26) })
		end
		y += 48
	end
	listFrame.CanvasSize = UDim2.new(0, 0, 0, y)
end

function EvolutionUI.init(_profile: any)
	local gui = UIUtil.screenGui("MR_Evolution")
	local panel = UIUtil.frame(gui, {
		Size = UDim2.new(0, 440, 0, 400),
		Position = UDim2.new(0.5, -220, 0.5, -200),
		Visible = false,
		BackgroundColor3 = Color3.fromRGB(18, 14, 20),
	})
	UIUtil.label(panel, "Evolution  [V]", { Position = UDim2.new(0, 12, 0, 8), TextSize = 16 })
	listFrame = Instance.new("ScrollingFrame")
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel = 0
	listFrame.Size = UDim2.new(1, -16, 1, -48)
	listFrame.Position = UDim2.new(0, 8, 0, 36)
	listFrame.ScrollBarThickness = 6
	listFrame.Parent = panel

	UIUtil.toggleOnKey(gui, panel, Enum.KeyCode.V)

	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then refresh() end
	end)
end

function EvolutionUI.onProfile(_profile: any)
	if listFrame and listFrame.Parent and (listFrame.Parent :: Frame).Visible then
		refresh()
	end
end

return EvolutionUI
