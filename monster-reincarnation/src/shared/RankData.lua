--!strict
-- Guild rank ladder. Guild_Score thresholds and the permissions at each rank.

local RankData = {}

RankData.RANKS = {
	{ rank = 0, title = "Recruit",     score = 0,     perms = { chat = true } },
	{ rank = 1, title = "Footman",     score = 100,   perms = { chat = true, base = true } },
	{ rank = 2, title = "Officer",     score = 500,   perms = { chat = true, base = true, invite = true, promoteTo = 1 } },
	{ rank = 3, title = "Lieutenant",  score = 1000,  perms = { chat = true, base = true, invite = true, promoteTo = 2, modifyBase = true } },
	{ rank = 4, title = "Guild Leader", score = 2500, perms = { chat = true, base = true, invite = true, promoteTo = 3, modifyBase = true, kickRemote = true, disband = true } },
}

function RankData.rankForScore(score: number): number
	local best = 0
	for _, r in ipairs(RankData.RANKS) do
		if score >= r.score then best = r.rank end
	end
	return best
end

function RankData.canPerform(rank: number, action: string): boolean
	for _, r in ipairs(RankData.RANKS) do
		if r.rank == rank then
			return r.perms[action] == true
		end
	end
	return false
end

function RankData.canPromoteTo(rank: number, targetRank: number): boolean
	for _, r in ipairs(RankData.RANKS) do
		if r.rank == rank then
			return (r.perms.promoteTo or -1) >= targetRank
		end
	end
	return false
end

return RankData
