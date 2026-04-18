--!strict
-- Authoritative combat: damage, posture, stance switching, mastery progression.
-- Client sends intent (attack, switchStance, parry). Server validates + resolves.

local Players = game:GetService("Players")

local Shared    = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants: any = require(Shared:WaitForChild("Constants"))
local Remotes:   any = require(Shared:WaitForChild("Remotes"))
local Util:      any = require(Shared:WaitForChild("Util"))

local Services = require(script.Parent)

local CombatService = {}

-- Per-character transient combat state. Reset on respawn.
local state: {
	[number]: {
		stance: string,
		stamina: number,
		posture: number,
		lastAttackAt: number,
		hitsInStance: { [string]: number },
		stunUntil: number,
	}
} = {}

local function stateFor(userId: number)
	if not state[userId] then
		state[userId] = {
			stance = "OneHand",
			stamina = Constants.Combat.BASE_STAMINA,
			posture = Constants.Combat.POSTURE_MAX,
			lastAttackAt = 0,
			hitsInStance = { TwoHand = 0, OneHand = 0, DualWield = 0, SpellGrip = 0 },
			stunUntil = 0,
		}
	end
	return state[userId]
end

local function getStanceCfg(stance: string)
	return Constants.Combat.Stances[stance] or Constants.Combat.Stances.OneHand
end

-- Resolve a single attack from player -> targetUserId or targetNpcId.
-- `rawIntent` is the client-sent table; we validate it thoroughly.
function CombatService.handleAttack(player: Player, rawIntent: any)
	local intent = Util.sanitize(rawIntent) or {}
	local AntiExploit = Services.get("AntiExploit")

	if not AntiExploit.checkRate(player.UserId, "attack", Constants.AntiExploit.MAX_ATTACKS_PER_SEC, 1) then
		return
	end

	local s = stateFor(player.UserId)
	if os.clock() < s.stunUntil then return end   -- stunned; ignore

	local stance = s.stance
	local cfg = getStanceCfg(stance)
	local staminaCost = 12 * cfg.stamina
	if s.stamina < staminaCost then return end

	local DataService = Services.get("DataService")
	local profile = DataService.getProfile(player.UserId)
	if not profile then return end

	local targetKind = intent.targetKind   -- "player" | "npc"
	local targetId   = intent.targetId
	local targetPos  = intent.targetPos and Vector3.new(intent.targetPos.x or 0, intent.targetPos.y or 0, intent.targetPos.z or 0)
	if typeof(targetPos) ~= "Vector3" then return end

	-- Distance sanity based on stance reach.
	local reach = (stance == "TwoHand") and 10 or (stance == "DualWield") and 6 or (stance == "SpellGrip") and 40 or 8
	if not AntiExploit.checkHitDistance(player, targetPos, reach) then return end

	-- Compute damage.
	local strScale  = 1 + profile.stats.Strength * 0.02
	local dexScale  = 1 + profile.stats.Dexterity * 0.01
	local baseDmg   = 10 * strScale * dexScale * cfg.dmg
	local postureDmg = 15 * cfg.posture

	-- Weapon contribution
	if profile.equippedWeaponId then
		for _, item in ipairs(profile.inventory) do
			if item.id == profile.equippedWeaponId and item.data and item.data.weapon then
				local w = item.data.weapon
				baseDmg += (w.baseStats.damage or 0)
				-- Persona scaling: +2% dmg per level.
				baseDmg *= 1 + (w.persona.level or 0) * 0.02
			end
		end
	end

	baseDmg = AntiExploit.checkDamage(baseDmg)

	-- Stance mastery XP (soft cap 1000).
	s.hitsInStance[stance] = (s.hitsInStance[stance] or 0) + 1
	if s.hitsInStance[stance] % Constants.Combat.HITS_PER_MASTERY_RANK == 0 then
		DataService.mutate(player.UserId, function(p)
			p.stanceMastery[stance] = math.min(1000, (p.stanceMastery[stance] or 0) + 1)
		end)
	end

	s.stamina = math.max(0, s.stamina - staminaCost)
	s.lastAttackAt = os.clock()

	-- Dispatch to target resolver (NPC or Player).
	local damageDealt = baseDmg
	if targetKind == "player" then
		local victim = Players:GetPlayerByUserId(targetId)
		if victim then
			CombatService.applyDamageToPlayer(victim, damageDealt, postureDmg, player)
		end
	elseif targetKind == "npc" then
		local NpcService = Services.optional("NpcService")
		if NpcService then
			local killed = NpcService.applyDamage(targetId, damageDealt, postureDmg, player)
			if killed then
				local WeaponPersona = Services.get("WeaponPersona")
				WeaponPersona.onKill(player, targetId)
				local Chronicle = Services.optional("WeaponChronicle")
				if Chronicle and profile.equippedWeaponId then
					Chronicle.append(profile.equippedWeaponId, {
						ts = os.time(), kind = "kill",
						text = "slew " .. tostring(targetId),
						playerUserId = player.UserId,
						generation = profile.generation,
					})
				end
			end
		end
	end

	-- Feedback to nearby clients (cheap broadcast).
	Remotes.event("Combat_HitFeedback"):FireAllClients({
		attacker = player.UserId, dmg = damageDealt, stance = stance, pos = targetPos,
	})
end

function CombatService.applyDamageToPlayer(victim: Player, damage: number, postureDmg: number, attacker: Player)
	local DataService = Services.get("DataService")
	local profile = DataService.getProfile(victim.UserId)
	if not profile then return end
	local char = victim.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Corruption-based damage reduction from family traits, etc.
	local trait = profile.familyTrait
	if trait and trait.key == "fire_charm" then
		damage *= 0.95
	end

	humanoid.Health = math.max(0, humanoid.Health - damage)
	local vs = stateFor(victim.UserId)
	vs.posture = math.max(0, vs.posture - postureDmg)
	if vs.posture <= 0 then
		vs.posture = Constants.Combat.POSTURE_MAX
		vs.stunUntil = os.clock() + Constants.Combat.POSTURE_BROKEN_STUN_SEC
	end

	if humanoid.Health <= 0 then
		local Analytics = Services.optional("Analytics")
		if Analytics then Analytics.track("pvp_kill", { killer = attacker.UserId, victim = victim.UserId }) end
	end
end

function CombatService.handleSwitchStance(player: Player, rawStance: any)
	local stance = tostring(rawStance)
	if not Constants.Combat.Stances[stance] then return end

	-- Weapons may restrict stance options (daggers always 1H, etc.).
	local DataService = Services.get("DataService")
	local profile = DataService.getProfile(player.UserId)
	if profile and profile.equippedWeaponId then
		for _, item in ipairs(profile.inventory) do
			if item.id == profile.equippedWeaponId and item.data and item.data.weapon then
				local w = item.data.weapon
				-- Example rule: "light" blades can only be One-Hand or Dual-Wield.
				for _, tag in ipairs(w.baseTags or {}) do
					if tag == "light" and stance == "TwoHand" then return end
					if tag == "heavy" and stance == "DualWield" then return end
				end
			end
		end
	end

	stateFor(player.UserId).stance = stance
end

function CombatService.handleParry(player: Player, _raw: any)
	local s = stateFor(player.UserId)
	local cfg = getStanceCfg(s.stance)
	if not cfg.parry then return end
	-- Parry is a short (0.3s) window; actual resolution handled by attacker
	-- check of victim state. We just stamp the state here.
	(s :: any).parryUntil = os.clock() + 0.3
end

-- Regen ticker -------------------------------------------------------------
function CombatService.start()
	task.spawn(function()
		while true do
			task.wait(1)
			for uid, s in pairs(state) do
				s.stamina = math.min(Constants.Combat.BASE_STAMINA, s.stamina + Constants.Combat.STAMINA_REGEN_PER_SEC)
				s.posture = math.min(Constants.Combat.POSTURE_MAX, s.posture + Constants.Combat.POSTURE_REGEN_PER_SEC)
			end
		end
	end)

	Remotes.event("Combat_Attack").OnServerEvent:Connect(function(plr, intent)
		CombatService.handleAttack(plr, intent)
	end)
	Remotes.event("Combat_SwitchStance").OnServerEvent:Connect(function(plr, stance)
		CombatService.handleSwitchStance(plr, stance)
	end)
	Remotes.event("Combat_Parry").OnServerEvent:Connect(function(plr, raw)
		CombatService.handleParry(plr, raw)
	end)

	Players.PlayerRemoving:Connect(function(plr) state[plr.UserId] = nil end)
end

return CombatService
