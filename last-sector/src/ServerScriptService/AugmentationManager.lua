-- AugmentationManager.lua
-- Handles augmentation equip/unequip/purchase on the server.
-- Validates faction unlocks, class restrictions, and cost; then
-- triggers stat recalculation via PlayerManager.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules            = ReplicatedStorage:WaitForChild("Modules")
local AugmentationData   = require(Modules:WaitForChild("AugmentationData"))
local FactionData        = require(Modules:WaitForChild("FactionData"))
local NetworkEvents      = require(Modules:WaitForChild("NetworkEvents"))
local PlayerDataModule   = require(Modules:WaitForChild("PlayerData"))
local GameData           = require(Modules:WaitForChild("GameData"))

local AugmentationManager = {}
AugmentationManager.__index = AugmentationManager

local _remotes       = nil
local _playerManager = nil

-- ── Init ─────────────────────────────────────────────────────────────────────
function AugmentationManager:Init(remoteFolder, playerManager)
    _remotes       = remoteFolder
    _playerManager = playerManager

    -- Equip / Unequip
    _remotes:WaitForChild(NetworkEvents.C2S.RequestEquipAug).OnServerEvent:Connect(function(player, slot, augId)
        self:HandleEquipAug(player, slot, augId)
    end)
    _remotes:WaitForChild(NetworkEvents.C2S.RequestUnequipAug).OnServerEvent:Connect(function(player, slot)
        self:HandleUnequipAug(player, slot)
    end)

    -- Purchase
    _remotes:WaitForChild(NetworkEvents.C2S.RequestPurchaseAug).OnServerEvent:Connect(function(player, augId)
        self:HandlePurchaseAug(player, augId)
    end)

    -- Weapon equip / purchase
    _remotes:WaitForChild(NetworkEvents.C2S.RequestEquipWeapon).OnServerEvent:Connect(function(player, lane, weaponId)
        self:HandleEquipWeapon(player, lane, weaponId)
    end)
    _remotes:WaitForChild(NetworkEvents.C2S.RequestPurchaseWeapon).OnServerEvent:Connect(function(player, weaponId)
        self:HandlePurchaseWeapon(player, weaponId)
    end)

    -- RemoteFunction: GetAugCatalog
    _remotes:WaitForChild(NetworkEvents.RF.GetAugCatalog).OnServerInvoke = function(player, slot)
        return self:GetCatalogForPlayer(player, slot)
    end
end

-- ── Equip Aug ─────────────────────────────────────────────────────────────────
function AugmentationManager:HandleEquipAug(player, slot, augId)
    -- Validate slot name
    if not GameData.AugSlots[slot:upper()] and not AugmentationData.Arms then
        -- Try to match slot directly
    end

    local data = _playerManager:GetData(player)
    if not data then return end

    -- Check ownership and class restriction
    local canEquip, reason = PlayerDataModule.CanEquipAug(data, augId, AugmentationData)
    if not canEquip then
        self:SendError(player, reason)
        return
    end

    local aug = AugmentationData.GetById(augId)
    if not aug then return end

    -- Validate slot matches aug slot
    if aug.Slot ~= slot then
        self:SendError(player, "Augmentation does not fit this slot")
        return
    end

    -- Equip (replaces whatever was there)
    local previous = data.Augmentations[slot]
    data.Augmentations[slot] = augId
    data.Stats.AugChanges = (data.Stats.AugChanges or 0) + 1

    -- Recalculate all stats
    _playerManager:RecalculateStats(player)

    -- Notify client
    _remotes:WaitForChild(NetworkEvents.S2C.AugEquipped):FireClient(player, slot, augId, previous)

    print("[AugmentationManager]", player.Name, "equipped", augId, "in slot", slot)
end

-- ── Unequip Aug ───────────────────────────────────────────────────────────────
function AugmentationManager:HandleUnequipAug(player, slot)
    local data = _playerManager:GetData(player)
    if not data then return end

    local previous = data.Augmentations[slot]
    if not previous then return end

    data.Augmentations[slot] = nil
    data.Stats.AugChanges = (data.Stats.AugChanges or 0) + 1

    _playerManager:RecalculateStats(player)
    _remotes:WaitForChild(NetworkEvents.S2C.AugUnequipped):FireClient(player, slot, previous)
end

-- ── Purchase Aug ──────────────────────────────────────────────────────────────
function AugmentationManager:HandlePurchaseAug(player, augId)
    local data = _playerManager:GetData(player)
    if not data then return end

    local aug = AugmentationData.GetById(augId)
    if not aug then
        self:SendError(player, "Unknown augmentation")
        return
    end

    -- Check if already owned
    for _, ownedId in ipairs(data.UnlockedAugs) do
        if ownedId == augId then
            self:SendError(player, "Augmentation already owned")
            return
        end
    end

    -- Get tier costs
    local tierDef = AugmentationData.Tiers[aug.Tier]
    if not tierDef then return end

    local credits = tierDef.creditCost
    local scrap   = tierDef.scrapCost

    -- Apply Axiom discount if brand-loyal
    if aug.Flags.corpBranded then
        local axiomRep = data.FactionRep["Axiom"] or 0
        if axiomRep >= 100 then
            credits = math.floor(credits * 0.90)
        end
    end

    -- Check faction unlock for restricted augs
    if aug.Flags.cultLocked then
        local cultRep = data.FactionRep["MachineCult"] or 0
        if cultRep < 300 then
            self:SendError(player, "Requires MachineCult Standing 300+")
            return
        end
    end
    if aug.Flags.androidArchitecture and data.Class ~= "Android" then
        self:SendError(player, "Requires Android chassis")
        return
    end

    -- Check affordability
    if not PlayerDataModule.CanAfford(data, credits, scrap) then
        self:SendError(player, "Insufficient credits or scrap")
        return
    end

    -- Deduct cost
    PlayerDataModule.Spend(data, credits, scrap)

    -- Add to inventory
    table.insert(data.UnlockedAugs, augId)

    -- Notify client
    _remotes:WaitForChild(NetworkEvents.S2C.AugUnlocked):FireClient(player, augId)
    _remotes:WaitForChild(NetworkEvents.S2C.PlayerDataUpdated):FireClient(player,
        { Credits = data.Credits, Scrap = data.Scrap, UnlockedAugs = data.UnlockedAugs }
    )

    print("[AugmentationManager]", player.Name, "purchased", augId)
end

-- ── Equip Weapon ──────────────────────────────────────────────────────────────
function AugmentationManager:HandleEquipWeapon(player, lane, weaponId)
    local data = _playerManager:GetData(player)
    if not data then return end

    -- Must own the weapon
    local owned = false
    for _, id in ipairs(data.UnlockedWeapons) do
        if id == weaponId then owned = true; break end
    end
    if not owned then
        self:SendError(player, "Weapon not owned")
        return
    end

    -- Validate lane
    if lane ~= "Primary" and lane ~= "Secondary" then return end

    data.Weapons[lane] = weaponId
    _remotes:WaitForChild(NetworkEvents.S2C.PlayerDataUpdated):FireClient(player,
        { Weapons = data.Weapons }
    )
end

-- ── Purchase Weapon ───────────────────────────────────────────────────────────
function AugmentationManager:HandlePurchaseWeapon(player, weaponId)
    local data = _playerManager:GetData(player)
    if not data then return end

    local WeaponDataMod = require(Modules:WaitForChild("WeaponData"))
    local wDef = WeaponDataMod.GetById(weaponId)
    if not wDef then
        self:SendError(player, "Unknown weapon")
        return
    end

    -- Check already owned
    for _, id in ipairs(data.UnlockedWeapons) do
        if id == weaponId then
            self:SendError(player, "Weapon already owned")
            return
        end
    end

    -- Weapon cost: base on tier-equivalent (using damage as proxy)
    -- In full implementation this would be in WeaponData
    local damage = wDef.Stats.Damage or 20
    local credits = math.floor(damage * 40)

    if not PlayerDataModule.CanAfford(data, credits, 0) then
        self:SendError(player, "Insufficient credits")
        return
    end
    PlayerDataModule.Spend(data, credits, 0)

    table.insert(data.UnlockedWeapons, weaponId)
    _remotes:WaitForChild(NetworkEvents.S2C.PlayerDataUpdated):FireClient(player,
        { Credits = data.Credits, UnlockedWeapons = data.UnlockedWeapons }
    )
end

-- ── Catalog for Player ────────────────────────────────────────────────────────
-- Returns aug list filtered by what the player can see (not necessarily buy).
function AugmentationManager:GetCatalogForPlayer(player, slot)
    local data = _playerManager:GetData(player)
    if not data then return {} end

    local allAugs = slot and AugmentationData.GetBySlot(slot) or (function()
        local combined = {}
        for _, list in pairs({ AugmentationData.Arms, AugmentationData.Legs,
                               AugmentationData.Spine, AugmentationData.Head,
                               AugmentationData.Internals }) do
            for _, a in ipairs(list) do table.insert(combined, a) end
        end
        return combined
    end)()

    local result = {}
    for _, aug in ipairs(allAugs) do
        -- Filter android-only if not android
        if aug.Flags.androidArchitecture and data.Class ~= "Android" then
            -- still show but mark as restricted
        end

        local owned = false
        for _, id in ipairs(data.UnlockedAugs) do
            if id == aug.Id then owned = true; break end
        end

        local equipped = false
        for _, id in pairs(data.Augmentations) do
            if id == aug.Id then equipped = true; break end
        end

        table.insert(result, {
            Id          = aug.Id,
            DisplayName = aug.DisplayName,
            Description = aug.Description,
            Slot        = aug.Slot,
            Origin      = aug.Origin,
            Tier        = aug.Tier,
            ILBase      = aug.ILBase,
            Stats       = aug.Stats,
            Flags       = aug.Flags,
            Owned       = owned,
            Equipped    = equipped,
            -- Cost info
            CreditCost  = AugmentationData.Tiers[aug.Tier] and AugmentationData.Tiers[aug.Tier].creditCost or 0,
            ScrapCost   = AugmentationData.Tiers[aug.Tier] and AugmentationData.Tiers[aug.Tier].scrapCost  or 0,
        })
    end
    return result
end

-- ── Utility ───────────────────────────────────────────────────────────────────
function AugmentationManager:SendError(player, message)
    _remotes:WaitForChild(NetworkEvents.S2C.HUDNotification):FireClient(player, message, 4, "error")
end

return AugmentationManager
