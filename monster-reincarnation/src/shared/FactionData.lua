--!strict
-- NPC factions, their territories, and how actions affect reputation.

local FactionData = {}

FactionData.FACTIONS = {
	Humanity = {
		display   = "Kingdoms of Men",
		joinable  = false,
		initial   = -10,
		territory = { "RuinedVillage", "BorderKeep", "Capital" },
		enemies   = { "DemonCourt", "BeastTribes" },
		actions   = {
			killedHumanNPC       = -3,
			savedHumanCaravan    =  8,
			raidedHumanOutpost   = -20,
		},
	},
	MageGuild = {
		display   = "Mage Guild",
		joinable  = true,
		requires  = { level = 15, intellect = 20 },
		initial   = 0,
		territory = { "ArcaneAcademy" },
		perks     = { bankAccess = true, discount = 0.10 },
		actions   = {
			returnedArcaneTome   = 15,
			killedMage           = -25,
			soldRareAlchemy      = 5,
		},
	},
	DemonCourt = {
		display   = "Demon Court",
		joinable  = true,
		requires  = { race = "DemonSpark" },
		initial   = 0,
		territory = { "InfernalRift" },
		perks     = { pactDiscount = 0.25 },
		actions   = {
			fulfilledContract    = 10,
			breachedContract     = -20,
			killedDemon          = -30,
		},
	},
	BeastTribes = {
		display   = "Beast Tribes",
		joinable  = true,
		requires  = { race = "BeastkinPup" },
		initial   = 5,
		territory = { "WhisperForest", "WolfFang Peaks" },
		perks     = { huntBonus = 0.15 },
		actions   = {
			huntedAlphaTogether  = 12,
			killedTribeMember    = -30,
		},
	},
	CentralAuthority = {
		display   = "Central Authority",
		joinable  = true,
		requires  = { level = 10 },
		initial   = 0,
		territory = { "Capital" },
		perks     = { exileImmunity = true, bounties = true },
		actions   = {
			turnedInExile        = 10,
			aidedExile           = -15,
		},
	},
}

function FactionData.get(id: string)
	return FactionData.FACTIONS[id]
end

function FactionData.allJoinable(): { string }
	local out = {}
	for id, f in pairs(FactionData.FACTIONS) do
		if f.joinable then table.insert(out, id) end
	end
	return out
end

return FactionData
