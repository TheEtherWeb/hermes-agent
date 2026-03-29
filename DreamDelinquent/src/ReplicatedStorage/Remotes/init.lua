-- Dream Delinquent: Remotes Init
-- Pre-creates all Remote instances so client and server can find them immediately.
-- This script runs as a ModuleScript that can be required from either side.
-- GameManager (server) will also create these if missing, but this guarantees early availability.

-- In Roblox, place this as a Script/ModuleScript inside ReplicatedStorage/Remotes
-- OR let GameManager.server.lua create them all via getRemote().

-- This file documents the full remote API:

--[[
REMOTE EVENTS (one-way broadcasts)
───────────────────────────────────────────────────────────────
StateUpdate         Server → Client   Full serialized PlayerData
StrongerStranger    Server → Client   { axis, gain, milestone }
RumorHeard          Server → Client   { id, title, body }
RumorResult         Server → Client   { rumorId, survived, isTrue, consequence, nextRumorId }
PhaseChange         Server → Client   { phase, day, isNight, lighting }
CombatResult        Server → Client   { won, wins }
CombatUpdate        Server → Client   { attackerHp, defenderHp, ... }
ClubResult          Server → Client   { clubId, statGains, strongerResult, flavourText }
ClassResult         Server → Client   { tier, score, statGains, credits, newGPA }
DialogueLine        Server → Client   { speaker, text }
PortraitState       Server → Client   "Neutral" | "Focused" | etc.
MilestoneText       Server → Client   { text, axis, gain, newCondition }
ParkourResult       Client → Server   { moveType }
StartMinigame       Server → Client   { subjectId, gameType, roundTime, totalRounds }
ShowDiploma         Server → Client   diplomaData table

REMOTE FUNCTIONS (two-way)
───────────────────────────────────────────────────────────────
GetPlayerState      Client → Server   () → serialized PlayerData
JoinClub            Client → Server   (clubId) → (ok, msg)
SubmitMinigame      Client → Server   (subjectId, score) → result
PursueRumor         Client → Server   (rumorId) → outcome
ExamResult          Client → Server   (examScore) → result
CombatAction        Client → Server   (action) → hitResult
StartCombat         Client → Server   (targetUserId?, npcId?) → (combatId, err)
FleeCombat          Client → Server   () → (success, msg)
SetBackground       Client → Server   (backgroundId) → ()
]]

return {}
