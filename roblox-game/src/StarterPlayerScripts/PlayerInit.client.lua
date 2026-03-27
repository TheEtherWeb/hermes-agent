-- PlayerInit.client.lua
-- Client bootstrap. Runs once when the local player joins.
-- Responsibilities:
--   1. Wait for all RemoteEvent/Function instances to be ready
--   2. Cache references into a shared table for other LocalScripts
--   3. Maintain a local mirror of PlayerState via StateChanged
--   4. Invoke UIManager once initial state is received

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer   = Players.LocalPlayer
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 15)

-- ── Remote cache (accessible to sibling LocalScripts via _G.Remotes) ─────────
-- Using _G is fine for a prototype; swap for a BindableEvent/ModuleScript system in production.

_G.Remotes = {}

local REMOTE_NAMES = {
	"RequestLightAttack",
	"RequestHeavyAttack",
	"RequestBlock",
	"RequestWeaponSummon",
	"RequestWeaponDismiss",
	"StateChanged",
	"CombatHitConfirmed",
	"GuardBroken",
	"WeaponBroken",
	"PlayerCollapsed",
	"RankUp",
	"BossDefeated",
	"PromptCharacterSetup",
	"BossSpawned",
	"BossHealthUpdate",
	"SubmitCharacterSetup",
	"GetPlayerState",
}

for _, name in ipairs(REMOTE_NAMES) do
	local remote = RemotesFolder:WaitForChild(name, 10)
	if remote then
		_G.Remotes[name] = remote
	else
		warn("[PlayerInit] Remote not found: " .. name)
	end
end

print("[PlayerInit] All remotes cached.")

-- ── Local state mirror ────────────────────────────────────────────────────────

_G.LocalPlayerState = {}

local function ApplyPatch(patch)
	for k, v in pairs(patch) do
		_G.LocalPlayerState[k] = v
	end
end

-- Listen to incremental state patches from the server
_G.Remotes.StateChanged.OnClientEvent:Connect(function(patch)
	ApplyPatch(patch)
	-- Notify UI systems
	if _G.OnStateChanged then
		_G.OnStateChanged(_G.LocalPlayerState, patch)
	end
end)

-- ── Character setup flow ──────────────────────────────────────────────────────

-- Show character creation UI when prompted
_G.Remotes.PromptCharacterSetup.OnClientEvent:Connect(function()
	-- UIManager will mount the setup panel; for now emit a signal it can pick up
	if _G.OnShowCharacterSetup then
		_G.OnShowCharacterSetup()
	else
		-- Fallback: auto-submit defaults so the prototype can still run
		task.delay(0.5, function()
			local result = _G.Remotes.SubmitCharacterSetup:InvokeServer({
				race        = "Gem",
				family      = "Diamond",
				trait       = "Faceted",
				weaponStyle = "Sword_Projection",
			})
			if not result or not result.success then
				warn("[PlayerInit] Character setup failed: " .. tostring(result and result.error or "no response"))
			end
		end)
	end
end)

print("[PlayerInit] Bootstrap complete. Waiting for server state...")
