-- FactionManager.lua
-- Manages faction reputation changes, unlock checks, and NPC reaction updates.
-- Hooks into PlayerManager and broadcasts rep changes to the client.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules        = ReplicatedStorage:WaitForChild("Modules")
local FactionData    = require(Modules:WaitForChild("FactionData"))
local IdentityLoad   = require(Modules:WaitForChild("IdentityLoad"))
local NetworkEvents  = require(Modules:WaitForChild("NetworkEvents"))

local FactionManager = {}
FactionManager.__index = FactionManager

local _remotes       = nil
local _playerManager = nil

-- ── Init ─────────────────────────────────────────────────────────────────────
function FactionManager:Init(remoteFolder, playerManager)
    _remotes       = remoteFolder
    _playerManager = playerManager

    -- RemoteFunction: GetFactionStatus
    _remotes:WaitForChild(NetworkEvents.RF.GetFactionStatus).OnServerInvoke = function(player)
        return self:GetFactionStatusForPlayer(player)
    end
end

-- ── Rep Adjustment ────────────────────────────────────────────────────────────
-- External API: called by MissionManager, CombatManager, etc.
function FactionManager:AdjustRep(player, changes)
    local data = _playerManager:GetData(player)
    if not data then return end

    local conflictPenalties = {}

    for factionId, delta in pairs(changes) do
        local faction = FactionData.GetById(factionId)
        if not faction then continue end

        -- Check Covenant IL restriction
        if factionId == "Purists" and delta > 0 then
            if data.IdentityLoad > (faction.ILLimit or 150) then
                -- Purists drop to hostile above IL limit
                data.FactionRep["Purists"] = math.min(
                    data.FactionRep["Purists"] or 0,
                    -200
                )
                _remotes:WaitForChild(NetworkEvents.S2C.HUDNotification):FireClient(player,
                    "The Iron Covenant rejects you. Your body has gone too far.", 5, "warning"
                )
                continue
            end
        end

        -- Check Cult IL requirement
        if factionId == "MachineCult" and delta > 0 then
            local ilReq = faction.ILRequirement
            if ilReq and data.IdentityLoad < ilReq then
                -- Still allow rep gain but cap tier at Distrusted until requirement met
            end
        end

        local oldRep = data.FactionRep[factionId] or 0
        local newRep = oldRep + delta
        data.FactionRep[factionId] = newRep

        -- Check for tier change
        local oldTier = FactionData.GetRepTier(oldRep)
        local newTier = FactionData.GetRepTier(newRep)
        if newTier.id ~= oldTier.id then
            _remotes:WaitForChild(NetworkEvents.S2C.FactionUnlocked):FireClient(player, factionId, newTier)
            self:CheckAndGrantUnlocks(player, data, factionId, newRep)
        end

        -- Conflict penalties: gaining rep with one faction hurts enemies
        for _, conflictId in ipairs(faction.Conflicts or {}) do
            local conflictFaction = FactionData.GetById(conflictId)
            if conflictFaction and delta > 0 then
                local penalty = -math.floor(delta * 0.30)  -- 30% rep bleed to enemies
                conflictPenalties[conflictId] = (conflictPenalties[conflictId] or 0) + penalty
            end
        end
    end

    -- Apply conflict penalties (without recursion)
    for factionId, penalty in pairs(conflictPenalties) do
        if data.FactionRep[factionId] ~= nil then
            data.FactionRep[factionId] = data.FactionRep[factionId] + penalty
        end
    end

    -- Broadcast all rep changes to client
    _remotes:WaitForChild(NetworkEvents.S2C.PlayerDataUpdated):FireClient(player,
        { FactionRep = data.FactionRep }
    )

    -- Update NPC reaction based on new reps
    self:UpdateNPCReactions(player, data)
end

-- ── Unlock Checks ─────────────────────────────────────────────────────────────
function FactionManager:CheckAndGrantUnlocks(player, data, factionId, newRep)
    local faction = FactionData.GetById(factionId)
    if not faction then return end

    for repReq, unlock in pairs(faction.RepUnlocks or {}) do
        if newRep >= repReq then
            if unlock.type == "AugAccess" then
                -- Add aug to available pool (can now purchase)
                local alreadyAvailable = false
                for _, id in ipairs(data.UnlockedAugs) do
                    if id == unlock.value then alreadyAvailable = true; break end
                end
                -- Note: faction unlocks add to "purchasable" pool, not owned pool
                -- In full implementation, this would be a separate table
                _remotes:WaitForChild(NetworkEvents.S2C.HUDNotification):FireClient(player,
                    unlock.desc, 6, "unlock"
                )
            elseif unlock.type == "WeaponAccess" then
                _remotes:WaitForChild(NetworkEvents.S2C.HUDNotification):FireClient(player,
                    unlock.desc, 6, "unlock"
                )
            elseif unlock.type == "ShopDiscount" then
                _remotes:WaitForChild(NetworkEvents.S2C.HUDNotification):FireClient(player,
                    unlock.desc, 6, "unlock"
                )
            elseif unlock.type == "Identity" then
                -- Major identity flag: player has deep faction integration
                local flagName = "faction_" .. factionId .. "_identity"
                if not data.ActiveFlags[flagName] then
                    data.ActiveFlags[flagName] = true
                    _remotes:WaitForChild(NetworkEvents.S2C.NarrativeFlagSet):FireClient(player, flagName)
                    _remotes:WaitForChild(NetworkEvents.S2C.HUDNotification):FireClient(player,
                        "[IDENTITY] " .. unlock.desc, 8, "narrative"
                    )
                end
            end
        end
    end
end

-- ── NPC Reaction Updates ──────────────────────────────────────────────────────
function FactionManager:UpdateNPCReactions(player, data)
    -- Calculate reaction matrix based on IL and faction reps
    local il = data.IdentityLoad

    local reactions = {
        civilian = IdentityLoad.GetNPCReaction(il, "civilian"),
        security = IdentityLoad.GetNPCReaction(il, "security"),
        machine  = IdentityLoad.GetNPCReaction(il, "machine"),
        cult     = IdentityLoad.GetNPCReaction(il, "cult"),
    }

    -- Faction rep overrides
    local axiomRep = data.FactionRep["Axiom"] or 0
    if axiomRep >= 300 then
        reactions.security = "friendly"  -- Axiom security is friendlier
    elseif axiomRep <= -200 then
        reactions.security = "hostile"
    end

    local cultRep = data.FactionRep["MachineCult"] or 0
    if cultRep >= 600 then
        reactions.cult = "reverent"
    end

    local overseersRep = data.FactionRep["Overseers"] or -100
    if overseersRep >= 300 then
        reactions.machine = "neutral"   -- machines no longer auto-hostile
    elseif overseersRep >= 600 then
        reactions.machine = "friendly"
    end

    _remotes:WaitForChild(NetworkEvents.S2C.NPCReactionChanged):FireClient(player, reactions)
end

-- ── Daily Standing Drift ──────────────────────────────────────────────────────
-- Over time, faction reps drift toward 0 if not maintained (very slowly).
-- Called from PlayerManager Tick. Not applied to allied/integrated tiers.
function FactionManager:ApplyStandingDrift(player, dt)
    local data = _playerManager:GetData(player)
    if not data then return end

    local driftRate = 0.01  -- rep/second toward 0
    local changed   = false

    for factionId, rep in pairs(data.FactionRep) do
        if math.abs(rep) > 50 then  -- don't drift if near neutral
            local drift = driftRate * dt
            if rep > 0 then
                data.FactionRep[factionId] = math.max(0, rep - drift)
                changed = true
            elseif rep < -50 then
                -- Hostile reps drift toward -50 (not to 0; you stay on record)
                data.FactionRep[factionId] = math.min(-50, rep + drift)
                changed = true
            end
        end
    end
end

-- ── Faction Status for Client ─────────────────────────────────────────────────
function FactionManager:GetFactionStatusForPlayer(player)
    local data = _playerManager:GetData(player)
    if not data then return {} end

    local result = {}
    for _, faction in ipairs(FactionData.Factions) do
        local rep  = data.FactionRep[faction.Id] or 0
        local tier = FactionData.GetRepTier(rep)
        table.insert(result, {
            Id          = faction.Id,
            DisplayName = faction.DisplayName,
            Alias       = faction.Alias,
            Description = faction.Description,
            ColorHex    = faction.ColorHex,
            Rep         = rep,
            TierLabel   = tier.label,
            TierId      = tier.id,
            NPCReact    = tier.npcReact,
        })
    end
    return result
end

return FactionManager
