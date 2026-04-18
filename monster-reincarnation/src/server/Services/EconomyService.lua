--!strict
-- Marketplace: list, browse, buy, cancel. Listing fee + sale tax. Persisted
-- in a dedicated DataStore so listings survive server restarts.

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants: any = require(Shared:WaitForChild("Constants"))
local Remotes:   any = require(Shared:WaitForChild("Remotes"))
local Util:      any = require(Shared:WaitForChild("Util"))

local Services = require(script.Parent)

local EconomyService = {}

local marketStore = DataStoreService:GetDataStore(Constants.DataStore.MARKET_STORE)
local MARKET_KEY  = "global_v1"

local listings: { any } = {}
local loaded = false

local function loadListings()
	if loaded then return end
	local ok, data = pcall(function() return marketStore:GetAsync(MARKET_KEY) end)
	if ok and typeof(data) == "table" then
		listings = data
	end
	loaded = true
end

local function persistListings()
	pcall(function()
		marketStore:UpdateAsync(MARKET_KEY, function() return listings end)
	end)
end

local function countListingsBySeller(userId: number): number
	local n = 0
	for _, l in ipairs(listings) do
		if l.sellerUserId == userId then n += 1 end
	end
	return n
end

local function findItemById(profile: any, id: string): (number?, any)
	for i, item in ipairs(profile.inventory) do
		if item.id == id then return i, item end
	end
	return nil, nil
end

function EconomyService.list(player: Player, rawReq: any)
	loadListings()
	local req = Util.sanitize(rawReq) or {}
	local DataService = Services.get("DataService")
	local profile = DataService.getProfile(player.UserId)
	if not profile then return end

	if countListingsBySeller(player.UserId) >= Constants.Economy.MAX_LISTINGS_PER_PLAYER then
		Remotes.event("UI_SendNotification"):FireClient(player, { kind = "error", text = "Listing cap reached." })
		return
	end

	local itemId = tostring(req.itemId)
	local price  = math.max(1, math.floor(tonumber(req.price) or 0))
	local i, item = findItemById(profile, itemId)
	if not i or not item then return end
	if item.kind == "token" then return end       -- untradable

	local fee = math.ceil(price * Constants.Economy.AUCTION_LISTING_FEE_PCT)
	if profile.gold < fee then
		Remotes.event("UI_SendNotification"):FireClient(player, { kind = "error", text = "Can't afford listing fee." })
		return
	end

	DataService.mutate(player.UserId, function(p)
		p.gold -= fee
		table.remove(p.inventory, i)
	end)

	local listing = {
		id = Util.uuid(),
		sellerUserId = player.UserId,
		item = Util.deepCopy(item),
		price = price,
		listedAt = os.time(),
		expiresAt = os.time() + Constants.Economy.MAX_LISTING_DURATION_SEC,
	}
	table.insert(listings, listing)
	persistListings()

	Remotes.event("UI_SendNotification"):FireClient(player, {
		kind = "success", text = ("Listed for %dg (fee %dg)"):format(price, fee),
	})
end

function EconomyService.cancel(player: Player, rawListingId: any)
	loadListings()
	local id = tostring(rawListingId)
	for i, l in ipairs(listings) do
		if l.id == id and l.sellerUserId == player.UserId then
			local DataService = Services.get("DataService")
			DataService.mutate(player.UserId, function(p)
				table.insert(p.inventory, Util.deepCopy(l.item))
			end)
			table.remove(listings, i)
			persistListings()
			return
		end
	end
end

function EconomyService.buy(player: Player, rawListingId: any)
	loadListings()
	local id = tostring(rawListingId)
	for i, l in ipairs(listings) do
		if l.id == id then
			if l.sellerUserId == player.UserId then return end   -- no self-buy

			local DataService = Services.get("DataService")
			local buyerProfile = DataService.getProfile(player.UserId)
			if not buyerProfile or buyerProfile.gold < l.price then
				Remotes.event("UI_SendNotification"):FireClient(player, { kind = "error", text = "Not enough gold." })
				return
			end

			local tax = math.ceil(l.price * Constants.Economy.AUCTION_SALE_TAX_PCT)
			local payout = l.price - tax

			DataService.mutate(player.UserId, function(p)
				p.gold -= l.price
				table.insert(p.inventory, Util.deepCopy(l.item))
			end)

			-- Seller may be offline; credit via profile mutate if loaded, else queue.
			local sellerProfile = DataService.getProfile(l.sellerUserId)
			if sellerProfile then
				DataService.mutate(l.sellerUserId, function(p) p.gold += payout end)
			else
				-- Queue escrow for next login.
				local escrowKey = "escrow_" .. tostring(l.sellerUserId)
				pcall(function()
					DataStoreService:GetDataStore("MarketEscrowV1"):UpdateAsync(escrowKey, function(old)
						old = old or { gold = 0 }
						old.gold += payout
						return old
					end)
				end)
			end

			-- Weapon chronicle: transfer entry.
			if l.item.kind == "weapon" then
				local Chronicle = Services.optional("WeaponChronicle")
				if Chronicle then
					Chronicle.onTransfer(l.item.id, l.sellerUserId, player.UserId)
				end
			end

			table.remove(listings, i)
			persistListings()

			Remotes.event("UI_SendNotification"):FireClient(player, {
				kind = "success", text = ("Bought for %dg (tax %dg)"):format(l.price, tax),
			})
			return
		end
	end
end

function EconomyService.browse(_plr: Player, rawFilter: any): { any }
	loadListings()
	local filter = Util.sanitize(rawFilter) or {}
	local out = {}
	for _, l in ipairs(listings) do
		if os.time() < l.expiresAt then
			if not filter.kind or l.item.kind == filter.kind then
				table.insert(out, l)
			end
		end
	end
	return out
end

-- Credits queued escrow gold on login.
local function claimEscrowFor(userId: number)
	local escrowKey = "escrow_" .. tostring(userId)
	pcall(function()
		DataStoreService:GetDataStore("MarketEscrowV1"):UpdateAsync(escrowKey, function(old)
			if not old or (old.gold or 0) <= 0 then return old end
			local DataService = Services.get("DataService")
			DataService.mutate(userId, function(p) p.gold += old.gold end)
			return { gold = 0 }
		end)
	end)
end

function EconomyService.start()
	loadListings()

	-- Sweep expired listings, return items to seller-escrow.
	task.spawn(function()
		while true do
			task.wait(300)
			local now = os.time()
			local anyRemoved = false
			for i = #listings, 1, -1 do
				if now > listings[i].expiresAt then
					-- Return item to seller via DataStore escrow
					local l = listings[i]
					local escrowKey = "escrow_items_" .. tostring(l.sellerUserId)
					pcall(function()
						DataStoreService:GetDataStore("MarketEscrowV1"):UpdateAsync(escrowKey, function(old)
							old = old or { items = {} }
							table.insert(old.items, l.item)
							return old
						end)
					end)
					table.remove(listings, i)
					anyRemoved = true
				end
			end
			if anyRemoved then persistListings() end
		end
	end)

	Remotes.event("Market_List").OnServerEvent:Connect(function(plr, req) EconomyService.list(plr, req) end)
	Remotes.event("Market_Buy").OnServerEvent:Connect(function(plr, id) EconomyService.buy(plr, id) end)
	Remotes.event("Market_Cancel").OnServerEvent:Connect(function(plr, id) EconomyService.cancel(plr, id) end)
	Remotes.func("Market_Browse").OnServerInvoke = function(plr, filter)
		return EconomyService.browse(plr, filter)
	end

	Players.PlayerAdded:Connect(function(plr)
		task.wait(3)   -- ensure DataService profile is loaded first
		claimEscrowFor(plr.UserId)
	end)
end

return EconomyService
