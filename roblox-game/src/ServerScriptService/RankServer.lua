-- RankServer.lua (ModuleScript)
-- Handles XP grants and rank advancement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankTiers   = require(ReplicatedStorage.Data.RankTiers)
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)

local RankServer = {}

local _playerManager

function RankServer.SetPlayerManager(pm)
	_playerManager = pm
end

local function GetRemote(name)
	return RemotesFolder:WaitForChild(name, 5)
end

-- Hook called on every rank-up. Add faction reward logic here post-prototype.
local function OnRankUp(player, newRankIndex)
	local tier = RankTiers[newRankIndex]
	print("[RankServer] " .. player.Name .. " ranked up to " .. (tier and tier.name or "?") .. " (rank " .. newRankIndex .. ")")
	-- TODO: unlock alloy/refinement eligibility check here
end

function RankServer.GrantXP(player, amount)
	if not _playerManager then return end
	local state = _playerManager.GetState(player)
	if not state then return end

	local newXP = state.XP + amount
	local newRank = state.RankIndex

	-- Check if the new XP crosses the next rank threshold
	while true do
		local nextTier = RankTiers[newRank + 1]
		if not nextTier then break end  -- already at max rank
		if newXP >= nextTier.xpRequired then
			newRank = newRank + 1
		else
			break
		end
	end

	local patch = { XP = newXP }
	if newRank ~= state.RankIndex then
		patch.RankIndex = newRank
		local tier = RankTiers[newRank]
		GetRemote("RankUp"):FireClient(player, {
			newRankIndex = newRank,
			newRankName  = tier and tier.name or "Unknown",
		})
		OnRankUp(player, newRank)
	end

	_playerManager.SetState(player, patch)
end

return RankServer
