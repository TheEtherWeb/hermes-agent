--!strict
-- Dungeon UI toggled with [N]. Tower entry, lair room placement buttons.

local UIUtil = require(script.Parent:WaitForChild("UIUtil"))
local Remotes: any = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local DungeonData: any = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("DungeonData"))

local DungeonUI = {}

function DungeonUI.init(_profile: any)
	local gui = UIUtil.screenGui("MR_Dungeon")
	local panel = UIUtil.frame(gui, {
		Size = UDim2.new(0, 440, 0, 360),
		Position = UDim2.new(0.5, -220, 0.5, -180),
		Visible = false,
		BackgroundColor3 = Color3.fromRGB(18, 14, 20),
	})
	UIUtil.label(panel, "Dungeon / Lair  [N]", { Position = UDim2.new(0, 12, 0, 8), TextSize = 16 })

	-- Tower floor selector.
	UIUtil.label(panel, "Tower", { Position = UDim2.new(0, 12, 0, 40), TextSize = 14 })
	local floorBox = Instance.new("TextBox")
	floorBox.PlaceholderText = "Floor"
	floorBox.Size = UDim2.new(0, 60, 0, 26)
	floorBox.Position = UDim2.new(0, 12, 0, 64)
	floorBox.Parent = panel
	UIUtil.button(panel, "Enter", function()
		Remotes.event("Dungeon_EnterTower"):FireServer(tonumber(floorBox.Text) or 1)
	end, { Position = UDim2.new(0, 80, 0, 64), Size = UDim2.new(0, 80, 0, 26) })

	-- Lair room placement list.
	UIUtil.label(panel, "Lair Rooms", { Position = UDim2.new(0, 12, 0, 100), TextSize = 14 })
	local roomList = Instance.new("ScrollingFrame")
	roomList.BackgroundTransparency = 1
	roomList.Size = UDim2.new(1, -16, 0, 220)
	roomList.Position = UDim2.new(0, 8, 0, 124)
	roomList.ScrollBarThickness = 6
	roomList.Parent = panel

	local y = 0
	for roomId, room in pairs(DungeonData.ROOMS) do
		local row = UIUtil.frame(roomList, {
			Size = UDim2.new(1, -12, 0, 30),
			Position = UDim2.new(0, 4, 0, y),
			BackgroundColor3 = Color3.fromRGB(30, 25, 35),
		})
		UIUtil.label(row, room.display, { Position = UDim2.new(0, 8, 0, 6), Size = UDim2.new(1, -100, 0, 20) })
		UIUtil.button(row, "Place", function()
			Remotes.event("Lair_PlaceRoom"):FireServer({ roomId = roomId, x = 0, y = 0 })
		end, { Position = UDim2.new(1, -84, 0, 2), Size = UDim2.new(0, 78, 0, 26) })
		y += 34
	end
	roomList.CanvasSize = UDim2.new(0, 0, 0, y)

	UIUtil.toggleOnKey(gui, panel, Enum.KeyCode.N)
end

return DungeonUI
