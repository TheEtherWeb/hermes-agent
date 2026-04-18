--!strict
-- Lightweight UI primitive helpers to keep other UI modules terse.

local UIUtil = {}

function UIUtil.screenGui(name: string): ScreenGui
	local player = game:GetService("Players").LocalPlayer
	local pg = player:WaitForChild("PlayerGui")
	local existing = pg:FindFirstChild(name)
	if existing and existing:IsA("ScreenGui") then return existing end
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = pg
	return gui
end

function UIUtil.frame(parent: Instance, props: { [string]: any }?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.fromRGB(20, 18, 22)
	f.BackgroundTransparency = 0.15
	f.Parent = parent
	if props then
		for k, v in pairs(props) do (f :: any)[k] = v end
	end
	return f
end

function UIUtil.label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.TextColor3 = Color3.fromRGB(235, 230, 220)
	t.Font = Enum.Font.Gotham
	t.TextSize = 14
	t.Text = text
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Size = UDim2.new(1, -8, 0, 18)
	t.Parent = parent
	if props then for k, v in pairs(props) do (t :: any)[k] = v end end
	return t
end

function UIUtil.button(parent: Instance, text: string, cb: () -> (), props: { [string]: any }?): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Color3.fromRGB(60, 45, 70)
	b.BorderSizePixel = 0
	b.TextColor3 = Color3.fromRGB(235, 230, 220)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.Text = text
	b.AutoButtonColor = true
	b.Size = UDim2.new(0, 120, 0, 26)
	b.Parent = parent
	b.MouseButton1Click:Connect(cb)
	if props then for k, v in pairs(props) do (b :: any)[k] = v end end
	return b
end

function UIUtil.toggleOnKey(gui: ScreenGui, frame: Frame, key: Enum.KeyCode)
	game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == key then
			frame.Visible = not frame.Visible
		end
	end)
end

function UIUtil.listLayout(parent: Instance, pad: number?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, pad or 4)
	l.Parent = parent
	return l
end

return UIUtil
