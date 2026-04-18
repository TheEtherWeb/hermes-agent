--!strict
-- Minimal NPC registry so CombatService has targets to hit. Real game would
-- plug in rig models + behaviour trees; this module tracks HP/posture only.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Util: any = require(Shared:WaitForChild("Util"))
local Remotes: any = require(Shared:WaitForChild("Remotes"))

local Services = require(script.Parent)

local NpcService = {}

local npcs: { [string]: any } = {}

function NpcService.spawn(kind: string, zoneId: string, pos: Vector3?): string
	local id = kind .. "_" .. Util.uuid()
	local DungeonService = Services.get("Dungeon")
	-- Fallback scaling based on zone + an arbitrary player level.
	local scale = DungeonService.scaleForZone(zoneId, 10)
	npcs[id] = {
		id = id,
		kind = kind,
		zoneId = zoneId,
		hp = scale.hp, maxHp = scale.hp,
		dmg = scale.dmg,
		xp = scale.xp,
		pos = pos or Vector3.new(0, 0, 0),
	}
	return id
end

function NpcService.applyDamage(targetId: string, damage: number, postureDmg: number, attacker: Player): boolean
	local npc = npcs[targetId]
	if not npc then return false end
	npc.hp -= damage
	if npc.hp <= 0 then
		npcs[targetId] = nil
		local DataService = Services.get("DataService")
		DataService.mutate(attacker.UserId, function(p)
			p.xp = (p.xp or 0) + (npc.xp or 10)
			-- Corpses-eaten tracker fires when player eats; for now just count kills.
			p.hidden.CorpsesEaten = (p.hidden.CorpsesEaten or 0) + 1
		end)
		local Mentor = Services.optional("Mentor")
		if Mentor then Mentor.onMenteeXP(attacker.UserId, npc.xp or 10) end
		Remotes.event("UI_SendNotification"):FireClient(attacker, { kind = "info", text = "Killed " .. npc.kind })
		return true
	end
	return false
end

function NpcService.get(id: string) return npcs[id] end

function NpcService.start() end

return NpcService
