--!strict
-- Demon contract prompt. When a demon offers a contract to this player, a
-- modal appears showing offer/demand/penalty with Accept/Reject.

local UIUtil = require(script.Parent:WaitForChild("UIUtil"))
local Remotes: any = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))

local ContractUI = {}

local function describeOffer(o: any): string
	if not o then return "?" end
	if o.kind == "statBuff" then return ("+%d %s"):format(o.amount or 0, tostring(o.stat or "")) end
	if o.kind == "heal"     then return ("Heal %d"):format(o.amount or 0) end
	if o.kind == "spellGrant" then return ("Spell %s"):format(tostring(o.spellId or "?")) end
	if o.kind == "weaponInfusion" then return ("Infuse %s"):format(tostring(o.affinity or "?")) end
	return tostring(o.kind)
end

local function describeDemand(d: any): string
	if not d then return "?" end
	if d.kind == "sacrificeItem" then return ("Sacrifice %d x %s"):format(d.qty or 1, tostring(d.templateId or "?")) end
	if d.kind == "goldTribute"   then return ("Pay %dg"):format(d.amount or 0) end
	if d.kind == "killNpc"       then return ("Kill %d x %s"):format(d.count or 1, tostring(d.npcKind or "?")) end
	if d.kind == "loyalty"       then return ("Loyalty for %ds"):format(d.durationSec or 0) end
	return tostring(d.kind)
end

function ContractUI.init(_profile: any)
	local gui = UIUtil.screenGui("MR_Contract")
	Remotes.event("Contract_Offer").OnClientEvent:Connect(function(contract)
		if not contract then return end
		local panel = UIUtil.frame(gui, {
			Size = UDim2.new(0, 420, 0, 260),
			Position = UDim2.new(0.5, -210, 0.5, -130),
			BackgroundColor3 = Color3.fromRGB(24, 10, 18),
		})
		UIUtil.label(panel, "A demon is offering you a contract.", {
			Position = UDim2.new(0, 12, 0, 12), TextSize = 16, TextColor3 = Color3.fromRGB(220, 100, 120),
		})
		UIUtil.label(panel, "OFFER: "   .. describeOffer(contract.offer),   { Position = UDim2.new(0, 12, 0, 48) })
		UIUtil.label(panel, "DEMAND: "  .. describeDemand(contract.demand), { Position = UDim2.new(0, 12, 0, 72) })
		UIUtil.label(panel, "PENALTY: " .. tostring(contract.penaltyKind or "none"), { Position = UDim2.new(0, 12, 0, 96) })
		UIUtil.label(panel, "EXPIRES: " .. tostring(contract.expiresAt), { Position = UDim2.new(0, 12, 0, 120) })

		UIUtil.button(panel, "Accept", function()
			Remotes.event("Contract_Accept"):FireServer(contract.id)
			panel:Destroy()
		end, { Position = UDim2.new(0, 40, 1, -48), Size = UDim2.new(0, 140, 0, 32),
			BackgroundColor3 = Color3.fromRGB(60, 100, 70) })
		UIUtil.button(panel, "Reject", function()
			Remotes.event("Contract_Reject"):FireServer(contract.id)
			panel:Destroy()
		end, { Position = UDim2.new(0, 200, 1, -48), Size = UDim2.new(0, 140, 0, 32),
			BackgroundColor3 = Color3.fromRGB(110, 60, 70) })
	end)
end

return ContractUI
