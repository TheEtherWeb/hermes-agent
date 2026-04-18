--!strict
-- Guild UI toggled with [G]. Create, view info, invite by userId, summon base.

local UIUtil = require(script.Parent:WaitForChild("UIUtil"))
local Remotes: any = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))

local GuildUI = {}

local infoLabel: TextLabel
local cached: any

local function refresh()
	if not cached then return end
	if cached.guildId then
		local g = Remotes.func("Guild_GetInfo"):InvokeServer(cached.guildId)
		if g then
			local n = 0
			for _ in pairs(g.members or {}) do n += 1 end
			infoLabel.Text = ("%s [%s]  Score %d  Members %d"):format(g.name, g.tag, g.score or 0, n)
		else
			infoLabel.Text = "Guild: unknown"
		end
	else
		infoLabel.Text = "You are not in a guild."
	end
end

function GuildUI.init(profile: any)
	cached = profile
	local gui = UIUtil.screenGui("MR_Guild")
	local panel = UIUtil.frame(gui, {
		Size = UDim2.new(0, 400, 0, 280),
		Position = UDim2.new(0.5, -200, 0.5, -140),
		Visible = false,
		BackgroundColor3 = Color3.fromRGB(18, 14, 20),
	})
	UIUtil.label(panel, "Guild  [G]", { Position = UDim2.new(0, 12, 0, 8), TextSize = 16 })
	infoLabel = UIUtil.label(panel, "...", { Position = UDim2.new(0, 12, 0, 36), Size = UDim2.new(1, -20, 0, 20) })

	local nameBox = Instance.new("TextBox")
	nameBox.PlaceholderText = "Guild name"
	nameBox.Size = UDim2.new(0, 220, 0, 26)
	nameBox.Position = UDim2.new(0, 12, 0, 72)
	nameBox.Parent = panel
	local tagBox = Instance.new("TextBox")
	tagBox.PlaceholderText = "TAG"
	tagBox.Size = UDim2.new(0, 60, 0, 26)
	tagBox.Position = UDim2.new(0, 240, 0, 72)
	tagBox.Parent = panel

	UIUtil.button(panel, "Create", function()
		Remotes.event("Guild_Create"):FireServer({ name = nameBox.Text, tag = tagBox.Text })
		task.delay(0.5, refresh)
	end, { Position = UDim2.new(0, 308, 0, 72), Size = UDim2.new(0, 80, 0, 26) })

	local invBox = Instance.new("TextBox")
	invBox.PlaceholderText = "Invite by UserId"
	invBox.Size = UDim2.new(0, 220, 0, 26)
	invBox.Position = UDim2.new(0, 12, 0, 110)
	invBox.Parent = panel
	UIUtil.button(panel, "Invite", function()
		local uid = tonumber(invBox.Text)
		if uid then Remotes.event("Guild_Invite"):FireServer({ targetUserId = uid }) end
	end, { Position = UDim2.new(0, 240, 0, 110), Size = UDim2.new(0, 80, 0, 26) })

	UIUtil.button(panel, "Summon Base", function()
		Remotes.event("Guild_SummonBase"):FireServer()
	end, { Position = UDim2.new(0, 12, 0, 148), Size = UDim2.new(0, 140, 0, 26) })

	UIUtil.toggleOnKey(gui, panel, Enum.KeyCode.G)

	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then refresh() end
	end)

	-- Handle incoming invite: show accept prompt.
	Remotes.event("Guild_Invite").OnClientEvent:Connect(function(data)
		if not data or not data.guildId then return end
		local promptGui = UIUtil.screenGui("MR_GuildInvite")
		local promptPanel = UIUtil.frame(promptGui, {
			Size = UDim2.new(0, 360, 0, 120),
			Position = UDim2.new(0.5, -180, 0.2, 0),
			BackgroundColor3 = Color3.fromRGB(20, 30, 40),
		})
		UIUtil.label(promptPanel, (data.fromName or "Someone") .. " invited you to a guild.", {
			Position = UDim2.new(0, 12, 0, 12), TextSize = 15,
		})
		UIUtil.button(promptPanel, "Accept", function()
			Remotes.event("Guild_AcceptInvite"):FireServer({ guildId = data.guildId })
			promptPanel:Destroy()
		end, { Position = UDim2.new(0, 40, 1, -44), Size = UDim2.new(0, 120, 0, 30) })
		UIUtil.button(promptPanel, "Decline", function()
			promptPanel:Destroy()
		end, { Position = UDim2.new(0, 200, 1, -44), Size = UDim2.new(0, 120, 0, 30) })
	end)
end

function GuildUI.onProfile(profile: any)
	cached = profile
	if infoLabel then refresh() end
end

return GuildUI
