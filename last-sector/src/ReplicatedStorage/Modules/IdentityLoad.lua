-- IdentityLoad.lua
-- The Identity Load system tracks how far a player has drifted from their
-- original biological self through augmentation. Shared module used by both
-- server (for authoritative calculations) and client (for display effects).
--
-- Identity Load is not a morality meter. It is a systems-strain meter.
-- The more machine you become, the more the world reads you differently.

local GameData = require(script.Parent.GameData)

local IdentityLoad = {}

-- ─── Core Calculation ─────────────────────────────────────────────────────────

-- Calculate the total IL for a given aug loadout.
-- augLoadout = { Arms = augId|nil, Legs = augId|nil, Spine = augId|nil,
--                Head = augId|nil, Internals = augId|nil }
function IdentityLoad.Calculate(augLoadout, classId, AugmentationData)
    local GameDataRef = GameData
    local total = 0
    local classStats = GameDataRef.ClassBaseStats[classId]
    if not classStats then return 0 end

    local ilRate = classStats.IdentityLoadRate
    local originMults = GameDataRef.AugOriginILMult

    for slot, augId in pairs(augLoadout) do
        if augId then
            local aug = AugmentationData.GetById(augId)
            if aug then
                local baseIL = aug.ILBase
                local originMult = originMults[aug.Origin] or 1.0
                local tierMult = 1.0 + (aug.Tier - 1) * 0.15
                total = total + math.floor(baseIL * originMult * tierMult * ilRate)
            end
        end
    end

    return math.max(0, total)
end

-- ─── Threshold Lookup ─────────────────────────────────────────────────────────

function IdentityLoad.GetThreshold(il)
    for _, thresh in ipairs(GameData.IdentityLoadThresholds) do
        if il >= thresh.min and il <= thresh.max then
            return thresh
        end
    end
    return GameData.IdentityLoadThresholds[#GameData.IdentityLoadThresholds]
end

function IdentityLoad.GetLabel(il)
    return IdentityLoad.GetThreshold(il).label
end

function IdentityLoad.GetColorHex(il)
    return IdentityLoad.GetThreshold(il).colorHex
end

-- ─── Dialogue Glitch Probability ─────────────────────────────────────────────
-- Returns 0.0 to 1.0 probability that dialogue is glitched at this IL level.
-- Androids start glitching earlier; humans resist longer.
function IdentityLoad.GlitchProbability(il, classId)
    local base = 0
    local thresholds = {
        Human   = { start = 200, full = 500 },
        Cyborg  = { start = 150, full = 400 },
        Android = { start = 80,  full = 300 },
    }
    local t = thresholds[classId] or thresholds.Cyborg
    if il < t.start then
        return 0
    elseif il >= t.full then
        return 0.85  -- never 100%, some signal always remains
    else
        return (il - t.start) / (t.full - t.start) * 0.85
    end
end

-- ─── Machine Interface Probability ───────────────────────────────────────────
-- At high IL, machines may recognize the player as kin rather than threat.
function IdentityLoad.MachineAffinityScore(il, classId)
    local base = {
        Human   = 0.0,
        Cyborg  = 0.10,
        Android = 0.30,
    }
    local b = base[classId] or 0.0
    local scaledIL = math.min(il, 600)
    return math.min(1.0, b + (scaledIL / 600) * 0.70)
end

-- ─── Social Blend Modifier ────────────────────────────────────────────────────
-- High IL reduces the player's ability to pass as a normal civilian.
function IdentityLoad.SocialBlendModifier(il, classId)
    local classStats = GameData.ClassBaseStats[classId]
    if not classStats then return 0 end

    local base = classStats.SocialBlend
    -- IL above 200 starts eroding social blend
    local penalty = 0
    if il > 200 then
        penalty = math.min(base * 0.80, (il - 200) * 0.12)
    end
    return math.max(0, base - penalty)
end

-- ─── NPC Reaction Lookup ──────────────────────────────────────────────────────
-- Returns what kind of reaction a given NPC type will have based on IL.
function IdentityLoad.GetNPCReaction(il, npcType)
    -- npcType: "civilian" | "security" | "machine" | "cult"
    local matrix = GameData.NPCReactionMatrix
    for _, row in ipairs(matrix) do
        if il >= row[1] and il <= row[2] then
            local reactions = {
                civilian = row[3],
                security = row[4],
                machine  = row[5],
                cult     = row[6],
            }
            return reactions[npcType] or "neutral"
        end
    end
    return "neutral"
end

-- ─── Memory Flashback Trigger ─────────────────────────────────────────────────
-- Returns true if a random IL-based memory event should fire this frame.
-- Should be called at a throttled rate (e.g., once per 30 seconds of play).
function IdentityLoad.ShouldTriggerFlashback(il, classId)
    local prob = {
        Human   = { threshold = 250, rate = 0.05 },
        Cyborg  = { threshold = 180, rate = 0.10 },
        Android = { threshold = 100, rate = 0.18 },
    }
    local p = prob[classId] or prob.Cyborg
    if il < p.threshold then return false end
    local scaledProb = p.rate * ((il - p.threshold) / 200)
    return math.random() < math.min(0.60, scaledProb)
end

-- ─── Overdrive IL Cost ────────────────────────────────────────────────────────
-- Some overdrives consume or generate IL. Returns the delta for a given overdrive.
function IdentityLoad.OverdriveILDelta(overdriveId)
    local deltas = {
        BreakState = 0,          -- Human overdrive: desperate, no IL cost
        Overclock  = 5,          -- Cyborg overdrive: minor IL spike from stress
        GhostSync  = -30,        -- Android overdrive: consumes IL (stabilizing)
    }
    return deltas[overdriveId] or 0
end

-- ─── Identity Load Cap Check ──────────────────────────────────────────────────
function IdentityLoad.IsAtCap(il, classId)
    local classStats = GameData.ClassBaseStats[classId]
    if not classStats then return false end
    return il >= classStats.IdentityLoadMax
end

-- ─── Stat Penalties at High IL ───────────────────────────────────────────────
-- Returns a table of stat modifiers from IL strain.
function IdentityLoad.GetStrainPenalties(il, classId)
    local penalties = {}
    -- Below 150: no penalties
    if il < 150 then return penalties end

    -- 150-299: minor strain
    if il < 300 then
        penalties.SocialBlend = -math.floor((il - 150) * 0.2)
        return penalties
    end

    -- 300-449: moderate strain
    if il < 450 then
        penalties.SocialBlend     = -30
        penalties.EnergyRegen     = -math.floor((il - 300) * 0.03)
        return penalties
    end

    -- 450-599: heavy strain
    if il < 600 then
        penalties.SocialBlend     = -50
        penalties.EnergyRegen     = -5
        penalties.RegenRate       = -1
        penalties.DialougeGlitch  = true
        return penalties
    end

    -- 600+: deep fracture
    penalties.SocialBlend     = -70
    penalties.EnergyRegen     = -8
    penalties.RegenRate       = -2
    penalties.DialogueGlitch  = true
    penalties.MachineAffinity = 0.60   -- machines actively curious/friendly
    return penalties
end

-- ─── Ending Check ────────────────────────────────────────────────────────────
-- Different endings are gated partly by IL level at key story moments.
-- This returns a table of possible endings the player qualifies for.
function IdentityLoad.GetAvailableEndings(il, classId, factionReps)
    local endings = {}

    -- Human ending: stay intact
    if classId == "Human" and il < 100 then
        table.insert(endings, "HumanLegacy")
    end

    -- Synthetic integration ending
    if il >= 400 and factionReps then
        local overseersRep = factionReps["Overseers"] or 0
        if overseersRep >= 300 then
            table.insert(endings, "NetworkIntegration")
        end
    end

    -- Cult ascendance ending
    if il >= 350 then
        local cultRep = factionReps and factionReps["MachineCult"] or 0
        if cultRep >= 600 then
            table.insert(endings, "Ascendance")
        end
    end

    -- Fragmented self ending: very high IL, no faction integration
    if il >= 500 then
        local hasIntegration = false
        if factionReps then
            for _, rep in pairs(factionReps) do
                if rep >= 600 then hasIntegration = true break end
            end
        end
        if not hasIntegration then
            table.insert(endings, "LostSignal")
        end
    end

    -- Liberation ending: moderate IL, android sympathy
    if factionReps then
        local libRep = factionReps["Liberation"] or 0
        if libRep >= 600 and il >= 100 then
            table.insert(endings, "NewFlesh")
        end
    end

    -- Purist ending: very low IL, covenant aligned
    if il <= 80 then
        local puristRep = factionReps and factionReps["Purists"] or 0
        if puristRep >= 400 then
            table.insert(endings, "Restoration")
        end
    end

    -- Default: survive and contract again
    table.insert(endings, "AnotherContract")

    return endings
end

return IdentityLoad
