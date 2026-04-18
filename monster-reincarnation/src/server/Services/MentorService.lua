--!strict
-- Mentor system: experienced players can sponsor novices for bonus XP / unlocks.
-- Cap pairings, reward both sides modestly, block exploit XP farms.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes: any = require(Shared:WaitForChild("Remotes"))

local Services = require(script.Parent)

local MentorService = {}

local MIN_MENTOR_LEVEL = 10
local MAX_MENTEES_PER_MENTOR = 3
local MENTOR_COOLDOWN_SEC = 60 * 60 * 24   -- 1 per mentor per mentee per day

local pairings: { [number]: { mentorUserId: number, startedAt: number } } = {}  -- keyed by mentee
local mentees:  { [number]: { [number]: boolean } } = {}                        -- mentor -> set of menteeUserIds
local lastSponsor: { [string]: number } = {}

local function pairKey(mentor: number, mentee: number): string
	return mentor .. ":" .. mentee
end

function MentorService.request(menteePlayer: Player, mentorUserId: number)
	-- A mentee invites; the mentor accepts via accept().
	local DataService = Services.get("DataService")
	local menteeProfile = DataService.getProfile(menteePlayer.UserId)
	local mentorProfile = DataService.getProfile(mentorUserId)
	if not menteeProfile or not mentorProfile then return end
	if mentorProfile.level < MIN_MENTOR_LEVEL then return end
	if pairings[menteePlayer.UserId] then return end       -- already has a mentor

	local cooldownKey = pairKey(mentorUserId, menteePlayer.UserId)
	if (lastSponsor[cooldownKey] or 0) + MENTOR_COOLDOWN_SEC > os.time() then return end

	local m = mentees[mentorUserId] or {}
	local n = 0
	for _ in pairs(m) do n += 1 end
	if n >= MAX_MENTEES_PER_MENTOR then return end

	-- Forward request to the mentor's client as an offer.
	local Players = game:GetService("Players")
	local mentorPlr = Players:GetPlayerByUserId(mentorUserId)
	if mentorPlr then
		Remotes.event("Mentor_Request"):FireClient(mentorPlr, {
			menteeUserId = menteePlayer.UserId,
			menteeName = menteePlayer.Name,
		})
	end
end

function MentorService.accept(mentorPlayer: Player, rawData: any)
	local menteeUserId = tonumber(rawData and rawData.menteeUserId)
	if not menteeUserId then return end
	local Players = game:GetService("Players")
	local mentee = Players:GetPlayerByUserId(menteeUserId)
	if not mentee then return end

	local DataService = Services.get("DataService")
	pairings[menteeUserId] = { mentorUserId = mentorPlayer.UserId, startedAt = os.time() }
	mentees[mentorPlayer.UserId] = mentees[mentorPlayer.UserId] or {}
	mentees[mentorPlayer.UserId][menteeUserId] = true
	lastSponsor[pairKey(mentorPlayer.UserId, menteeUserId)] = os.time()

	-- Grant mentee a 25% XP bonus for 30 minutes; flag both with titles.
	DataService.mutate(menteeUserId, function(p)
		p.buffs = p.buffs or {}
		table.insert(p.buffs, { key = "mentor_xp", value = 0.25, expiresAt = os.time() + 60 * 30 })
	end)
	DataService.mutate(mentorPlayer.UserId, function(p)
		p.titles = p.titles or {}
		if not table.find(p.titles, "Mentor") then table.insert(p.titles, "Mentor") end
	end)

	Remotes.event("UI_SendNotification"):FireClient(mentorPlayer, { kind = "success", text = "Mentorship accepted." })
	Remotes.event("UI_SendNotification"):FireClient(mentee,        { kind = "success", text = "You have a mentor for 30 minutes." })
end

-- Called by CombatService when a mentee lands a kill; splits a small XP reward.
function MentorService.onMenteeXP(menteeUserId: number, xp: number)
	local p = pairings[menteeUserId]
	if not p then return end
	local Players = game:GetService("Players")
	local mentor = Players:GetPlayerByUserId(p.mentorUserId)
	if not mentor then return end
	local DataService = Services.get("DataService")
	DataService.mutate(p.mentorUserId, function(mp)
		mp.xp = (mp.xp or 0) + math.floor(xp * 0.10)   -- 10% share
	end)
end

function MentorService.start()
	Remotes.event("Mentor_Request").OnServerEvent:Connect(function(plr, data)
		MentorService.request(plr, tonumber(data and data.mentorUserId) or 0)
	end)
	Remotes.event("Mentor_Accept").OnServerEvent:Connect(function(plr, data)
		MentorService.accept(plr, data)
	end)
end

return MentorService
