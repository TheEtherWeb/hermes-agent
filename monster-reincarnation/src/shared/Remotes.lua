--!strict
-- Central registry of RemoteEvents / RemoteFunctions. Server creates them,
-- client fetches via WaitForChild. Naming convention prevents accidental reuse.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local EVENT_NAMES = {
	"Combat_Attack",
	"Combat_SwitchStance",
	"Combat_Parry",
	"Combat_Block",
	"Combat_HitFeedback",
	"Crafting_Forge",
	"Weapon_Equip",
	"Weapon_Inspect",
	"Evolution_Choose",
	"Dynasty_Rebirth",
	"Guild_Create",
	"Guild_Invite",
	"Guild_AcceptInvite",
	"Guild_Kick",
	"Guild_Promote",
	"Guild_SetBase",
	"Guild_SummonBase",
	"Dungeon_EnterTower",
	"Lair_PlaceRoom",
	"Lair_RemoveRoom",
	"Follower_AssignRole",
	"Follower_Recruit",
	"Contract_Offer",
	"Contract_Accept",
	"Contract_Reject",
	"Contract_Breach",
	"Faction_Join",
	"Faction_Leave",
	"Market_List",
	"Market_Buy",
	"Market_Cancel",
	"Mentor_Request",
	"Mentor_Accept",
	"UI_SendNotification",
	"Profile_Replicate",
}

local FUNCTION_NAMES = {
	"Profile_Get",
	"Market_Browse",
	"Guild_GetInfo",
	"Weapon_GetChronicle",
	"EvolutionTree_Get",
}

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(EVENT_NAMES) do
		local ev = folder:FindFirstChild(name)
		if not ev then
			ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = folder
		end
	end
	for _, name in ipairs(FUNCTION_NAMES) do
		local rf = folder:FindFirstChild(name)
		if not rf then
			rf = Instance.new("RemoteFunction")
			rf.Name = name
			rf.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
