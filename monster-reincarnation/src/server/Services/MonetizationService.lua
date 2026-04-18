--!strict
-- Cosmetic-only purchases. All items here are visual or slot-of-convenience;
-- none grants in-game power. Uses MarketplaceService developer products and
-- game passes; resolves to a grant function that never touches combat stats.

local MarketplaceService = game:GetService("MarketplaceService")
local Players            = game:GetService("Players")

local MonetizationService = {}

-- productId -> grant function.
local PRODUCT_GRANTS: { [number]: (Player) -> () } = {}
-- passId -> grant function.
local PASS_GRANTS:   { [number]: (Player) -> () } = {}

-- Example catalog. Replace IDs with real Roblox products before shipping.
MonetizationService.CATALOG = {
	cosmetics = {
		{ productId = 0, key = "BannerHouseRed", display = "House Banner (Red)" },
		{ productId = 0, key = "DragonPetSkin",  display = "Dragon Pet Skin" },
		{ productId = 0, key = "DungeonTheme_Crypt", display = "Dungeon Theme: Crypt" },
	},
	convenience = {
		{ productId = 0, key = "ExtraCharacterSlot", display = "Extra Character Slot" },
		{ productId = 0, key = "ExtraGuildSlot",     display = "Extra Guild Slot" },
	},
	-- A VIP pass that grants a very small XP boost (kept under 5%). Strictly
	-- tuned to avoid pay-to-win perception.
	passes = {
		{ passId = 0, key = "SupporterPass", xpBoost = 0.05, cosmeticFrame = true },
	},
}

function MonetizationService.registerProductGrant(productId: number, fn: (Player) -> ())
	PRODUCT_GRANTS[productId] = fn
end

function MonetizationService.registerPassGrant(passId: number, fn: (Player) -> ())
	PASS_GRANTS[passId] = fn
end

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local fn = PRODUCT_GRANTS[info.ProductId]
		if not fn then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local ok, err = pcall(fn, player)
		if ok then return Enum.ProductPurchaseDecision.PurchaseGranted end
		warn("[Monetization] grant failed: " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	Players.PlayerAdded:Connect(function(plr)
		for passId, grant in pairs(PASS_GRANTS) do
			if passId and passId > 0 then
				task.spawn(function()
					local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, plr.UserId, passId)
					if ok and owns then pcall(grant, plr) end
				end)
			end
		end
	end)
end

return MonetizationService
