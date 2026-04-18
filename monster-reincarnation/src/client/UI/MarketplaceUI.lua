--!strict
-- Marketplace panel toggled with [M]. Browse listings, list own items, buy.

local UIUtil = require(script.Parent:WaitForChild("UIUtil"))
local Remotes: any = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))

local MarketplaceUI = {}

local listFrame: ScrollingFrame

local function refresh()
	if not listFrame then return end
	for _, c in ipairs(listFrame:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	local listings = Remotes.func("Market_Browse"):InvokeServer({})
	local y = 0
	for _, l in ipairs(listings or {}) do
		local row = UIUtil.frame(listFrame, {
			Size = UDim2.new(1, -12, 0, 40),
			Position = UDim2.new(0, 4, 0, y),
			BackgroundColor3 = Color3.fromRGB(30, 25, 35),
		})
		local itemLabel = l.item.templateId
		if l.item.kind == "weapon" and l.item.data and l.item.data.weapon then
			itemLabel = l.item.data.weapon.name or "Weapon"
			if l.item.data.weapon.quality then itemLabel = itemLabel .. " (" .. l.item.data.weapon.quality .. ")" end
		end
		UIUtil.label(row, itemLabel .. "  x" .. tostring(l.item.qty or 1), {
			Position = UDim2.new(0, 8, 0, 4), Size = UDim2.new(1, -160, 0, 18),
		})
		UIUtil.label(row, "Price: " .. tostring(l.price) .. "g", {
			Position = UDim2.new(0, 8, 0, 22), Size = UDim2.new(1, -160, 0, 16),
			TextColor3 = Color3.fromRGB(220, 200, 120),
		})
		UIUtil.button(row, "Buy", function()
			Remotes.event("Market_Buy"):FireServer(l.id)
			task.delay(0.3, refresh)
		end, { Position = UDim2.new(1, -84, 0, 7), Size = UDim2.new(0, 78, 0, 26) })
		y += 44
	end
	listFrame.CanvasSize = UDim2.new(0, 0, 0, y)
end

function MarketplaceUI.init(_profile: any)
	local gui = UIUtil.screenGui("MR_Market")
	local panel = UIUtil.frame(gui, {
		Size = UDim2.new(0, 500, 0, 420),
		Position = UDim2.new(0.5, -250, 0.5, -210),
		Visible = false,
		BackgroundColor3 = Color3.fromRGB(18, 14, 20),
	})
	UIUtil.label(panel, "Marketplace  [M]", { Position = UDim2.new(0, 12, 0, 8), TextSize = 16 })
	listFrame = Instance.new("ScrollingFrame")
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel = 0
	listFrame.Size = UDim2.new(1, -16, 1, -80)
	listFrame.Position = UDim2.new(0, 8, 0, 36)
	listFrame.ScrollBarThickness = 6
	listFrame.Parent = panel

	local idBox = Instance.new("TextBox")
	idBox.PlaceholderText = "Item UUID"
	idBox.Size = UDim2.new(0, 200, 0, 26)
	idBox.Position = UDim2.new(0, 12, 1, -36)
	idBox.Parent = panel
	local priceBox = Instance.new("TextBox")
	priceBox.PlaceholderText = "Price (g)"
	priceBox.Size = UDim2.new(0, 80, 0, 26)
	priceBox.Position = UDim2.new(0, 220, 1, -36)
	priceBox.Parent = panel
	UIUtil.button(panel, "List", function()
		local price = tonumber(priceBox.Text) or 0
		Remotes.event("Market_List"):FireServer({ itemId = idBox.Text, price = price })
		task.delay(0.5, refresh)
	end, { Position = UDim2.new(0, 310, 1, -36), Size = UDim2.new(0, 72, 0, 26) })

	UIUtil.toggleOnKey(gui, panel, Enum.KeyCode.M)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then refresh() end
	end)
end

return MarketplaceUI
