-- =========================================================
-- MugShot - EsoAdapterTest  (tests/EsoAdapterTest.lua)
-- =========================================================

local root = (arg and arg[0] and arg[0]:match("(.+)[/\\][^/\\]+$")) or "."
local addonRoot = root .. "/.."

local EsoMock = dofile(root .. "/EsoMock.lua")
EsoMock.Init()

dofile(addonRoot .. "/Constants.lua")
dofile(addonRoot .. "/Localisation.lua")
dofile(addonRoot .. "/UI/Style.lua")
dofile(addonRoot .. "/Data/Portraits.lua")
dofile(addonRoot .. "/ESO/EsoAdapter.lua")

local pass, fail = 0, 0
local errors = {}

local function check(cond, msg)
    if cond then
        pass = pass + 1
    else
        fail = fail + 1
        table.insert(errors, "FAIL: " .. (msg or "unnamed"))
    end
end

local adapter = MugShot.EsoAdapter.New()

-- ── 1. ReadIdentity for Hostile NPC ───────────────────────
EsoMock.SetUnit("reticleover", {
    exists      = true,
    name        = "Iron Atronach",
    displayName = "",
    isPlayer    = false,
    reaction    = UNIT_REACTION_HOSTILE,
})

local id1 = adapter:ReadIdentity("reticleover")
check(id1.name == "Iron Atronach", "NPC name is Iron Atronach")
check(id1.isPlayer == false, "NPC isPlayer is false")
check(id1.reaction == UNIT_REACTION_HOSTILE, "NPC reaction is HOSTILE")
check(id1.reactionR == 1.0 and id1.reactionG == 0.0, "Reaction color is hostile red")
check(id1.portraitTexture == "/esoui/art/icons/achievement_u29_dun2_flavorc.dds", "Boss portrait matched")

-- ── 2. ReadIdentity for Player Ally ───────────────────────
EsoMock.SetUnit("player", {
    exists      = true,
    name        = "PlayerChar",
    displayName = "@AccountName",
    isPlayer    = true,
    reaction    = UNIT_REACTION_PLAYER_ALLY,
    classId     = 1, -- Dragonknight
    raceId      = 1, -- Breton
    allianceId  = 1, -- Aldmeri Dominion
})

local id2 = adapter:ReadIdentity("player")
check(id2.name == "PlayerChar", "Player name read")
check(id2.displayName == "@AccountName", "Player displayName read")
check(id2.isPlayer == true, "Player isPlayer is true")
check(id2.raceIcon ~= nil, "Race icon badge populated")
check(id2.allianceIcon ~= nil, "Alliance badge populated")

-- ── 3. ReadVitals: Valid Health & Shield ──────────────────
EsoMock.SetUnit("reticleover", {
    exists        = true,
    currentHealth = 15000,
    maxHealth     = 30000,
    shield        = 5000,
})

local v1 = adapter:ReadVitals("reticleover")
check(v1.healthKnown == true, "Health known is true")
check(v1.currentHealth == 15000, "Current health is 15000")
check(v1.maxHealth == 30000, "Max health is 30000")
check(v1.shield == 5000, "Shield is 5000")
check(v1.isDead == false, "Living unit isDead is false")

-- Dead unit (health = 0)
EsoMock.SetUnit("reticleover", { exists = true, currentHealth = 0, maxHealth = 30000 })
local vDead = adapter:ReadVitals("reticleover")
check(vDead.isDead == true, "Unit at 0 health has isDead=true")

-- ── 4. ReadVitals: Health Unknown ─────────────────────────
EsoMock.SetUnit("reticleover", {
    exists        = true,
    currentHealth = nil,
})

local v2 = adapter:ReadVitals("reticleover")
check(v2.healthKnown == false, "Health known is false when nil")
check(v2.currentHealth == nil, "Current health is nil")
check(v2.shield == 0, "Shield is 0 when health unknown")

-- ── 5. ReadEffects: Extraction, Filtering, and Sorting ────────
EsoMock.currentTime = 1000.0
EsoMock.SetUnit("reticleover", {
    exists = true,
    buffs = {
        { name = "PassiveBuff", iconFilename = "/icon_passive.dds", timeEnding = 0, castByPlayer = false },
        { name = "OtherDebuff", iconFilename = "/icon_other.dds", timeEnding = 1005.0, castByPlayer = false },
        { name = "PlayerDotLong", iconFilename = "/icon_dot_long.dds", timeEnding = 1020.0, castByPlayer = true },
        { name = "PlayerDotShort", iconFilename = "/icon_dot_short.dds", timeEnding = 1008.0, castByPlayer = true },
    }
})

-- Default for target: filters by castByPlayer == true (natural clutter elimination)
local effs = adapter:ReadEffects("reticleover")
check(#effs == 2, "ReadEffects on target filters out non-player buffs by default (2 player effects)")
check(effs[1].name == "PlayerDotShort", "1st is player dot with shortest duration (timer=8)")
check(effs[1].timer == 8.0, "PlayerDotShort remaining timer is 8s")
check(effs[2].name == "PlayerDotLong", "2nd is player dot with longer duration (timer=20)")
check(effs[2].timer == 20.0, "PlayerDotLong remaining timer is 20s")

-- Explicit unfiltered query (onlyPlayerCast = false)
local allEffs = adapter:ReadEffects("reticleover", false)
check(#allEffs == 4, "ReadEffects with onlyPlayerCast=false returns all 4 valid effects")
check(allEffs[1].name == "PlayerDotShort", "Unfiltered: 1st is player dot shortest")
check(allEffs[2].name == "PlayerDotLong", "Unfiltered: 2nd is player dot longer")
check(allEffs[3].name == "OtherDebuff", "Unfiltered: 3rd is non-player timed effect")
check(allEffs[4].name == "PassiveBuff", "Unfiltered: 4th is non-player passive (timer 0)")

-- Player unitTag defaults to unfiltered
EsoMock.SetUnit("player", {
    exists = true,
    buffs = {
        { name = "FoodBuff", iconFilename = "/icon_food.dds", timeEnding = 0, castByPlayer = true },
        { name = "RaidHorn", iconFilename = "/icon_horn.dds", timeEnding = 1030.0, castByPlayer = false },
    }
})
local playerEffs = adapter:ReadEffects("player")
check(#playerEffs == 2, "ReadEffects on 'player' defaults to unfiltered (shows all player buffs)")

-- ── 6. Group Debuffs, Multi-Cast Merging & Solo-Mode Isolation ─
EsoMock.currentTime = 1000.0

-- Scenario A: Strict Solo Mode Isolation
EsoMock.isUnitGrouped = false
EsoMock.groupSize = 1
EsoMock.hasActiveCompanion = false

EsoMock.SetUnit("reticleover", {
    exists = true,
    buffs = {
        { name = "Major Vulnerability", iconFilename = "/vulnerable.dds", timeEnding = 1008.0, castByPlayer = true, stackCount = 0 },
        { name = "Major Vulnerability", iconFilename = "/vulnerable.dds", timeEnding = 1014.0, castByPlayer = false, stackCount = 0 },
        { name = "Off Balance",         iconFilename = "/offbalance.dds", timeEnding = 1015.0, castByPlayer = false, stackCount = 0 },
        { name = "PlayerDebuff",        iconFilename = "/player.dds",     timeEnding = 1010.0, castByPlayer = true, stackCount = 2 },
    }
})

local soloEffs = adapter:ReadEffects("reticleover", nil, true)
check(#soloEffs == 2, "Solo Mode: strictly isolates player-cast debuffs (2 effects)")
check(soloEffs[1].name == "Major Vulnerability", "Solo Mode: 1st is player Major Vulnerability")
check(soloEffs[1].sourceCount == 1, "Solo Mode: sourceCount is strictly 1 (no multi-source badge)")
check(soloEffs[1].timer == 8.0, "Solo Mode: keeps player timer (8s), ignores non-player cast")
check(soloEffs[2].name == "PlayerDebuff", "Solo Mode: 2nd is PlayerDebuff")

-- Scenario B: Group Mode — Unfiltered Debuffs & Multi-Cast Badge Merging
EsoMock.isUnitGrouped = true
EsoMock.groupSize = 4
EsoMock.hasActiveCompanion = false

local groupEffs = adapter:ReadEffects("reticleover", nil, true)
check(#groupEffs == 3, "Group Mode: displays unfiltered debuffs and merges duplicate casts (3 effects)")
-- Player cast (8s) + Ally cast (14s) of Major Vulnerability merge into 1 item with sourceCount = 2 and timer = 14s
local mv = nil
for _, e in ipairs(groupEffs) do
    if e.name == "Major Vulnerability" then mv = e end
end
check(mv ~= nil, "Group Mode: Major Vulnerability present")
check(mv.sourceCount == 2, "Group Mode: Multi-cast badge merged with sourceCount=2")
check(mv.timer == 14.0, "Group Mode: Merged effect retains highest remaining timer (14s)")
check(mv.castByPlayer == true, "Group Mode: Merged effect retains player-cast status")

local ob = nil
for _, e in ipairs(groupEffs) do
    if e.name == "Off Balance" then ob = e end
end
check(ob ~= nil, "Group Mode: Non-player group debuff (Off Balance) is displayed")
check(ob.sourceCount == 1, "Group Mode: Single-source ally debuff has sourceCount=1")
check(ob.castByPlayer == false, "Group Mode: Ally debuff retains castByPlayer=false")

-- Scenario C: Active Companion also enables Group Debuff tracking
EsoMock.isUnitGrouped = false
EsoMock.groupSize = 1
EsoMock.hasActiveCompanion = true
local companionEffs = adapter:ReadEffects("reticleover", nil, true)
check(#companionEffs == 3, "Companion Mode: Active companion enables group debuff tracking and merging")

-- Scenario D: trackGroupDebuffs = false disables non-player debuffs even in group
EsoMock.isUnitGrouped = true
EsoMock.groupSize = 4
local disabledGroupEffs = adapter:ReadEffects("reticleover", nil, false)
check(#disabledGroupEffs == 2, "trackGroupDebuffs=false: filters out non-player debuffs in group")

-- Scenario E: Multi-Source 3-way Merge & Stack Count Retention
EsoMock.SetUnit("reticleover", {
    exists = true,
    buffs = {
        { name = "Crusher", iconFilename = "/crusher.dds", timeEnding = 1005.0, castByPlayer = true,  stackCount = 1 },
        { name = "Crusher", iconFilename = "/crusher.dds", timeEnding = 1009.0, castByPlayer = false, stackCount = 3 },
        { name = "Crusher", iconFilename = "/crusher.dds", timeEnding = 1003.0, castByPlayer = false, stackCount = 2 },
    }
})
local tripleEffs = adapter:ReadEffects("reticleover", nil, true)
check(#tripleEffs == 1, "Triple cast merges into exactly 1 effect card")
check(tripleEffs[1].sourceCount == 3, "sourceCount is 3 for triple merge")
check(tripleEffs[1].timer == 9.0, "Triple merge retains highest timer (9s)")
check(tripleEffs[1].stackCount == 3, "Triple merge retains highest stackCount (3)")
check(tripleEffs[1].castByPlayer == true, "Triple merge retains player cast status")
check(tripleEffs[1].playerTimer == 5.0, "Triple merge tracks playerTimer = 5s")
check(tripleEffs[1].teamTimer == 9.0, "Triple merge tracks teamTimer = 9s")
check(tripleEffs[1].winnerFromPlayer == false, "Triple merge winnerFromPlayer is false because teamTimer (9s) > playerTimer (5s)")

-- Scenario E2: Player cast timer > Team cast timer
EsoMock.SetUnit("reticleover", {
    exists = true,
    buffs = {
        { name = "Crusher", iconFilename = "/crusher.dds", timeEnding = 1015.0, castByPlayer = true,  stackCount = 1 },
        { name = "Crusher", iconFilename = "/crusher.dds", timeEnding = 1009.0, castByPlayer = false, stackCount = 3 },
    }
})
local pWinEffs = adapter:ReadEffects("reticleover", nil, true)
check(pWinEffs[1].playerTimer == 15.0, "Player timer is 15s")
check(pWinEffs[1].teamTimer == 9.0, "Team timer is 9s")
check(pWinEffs[1].timer == 15.0, "Winning timer is 15s")
check(pWinEffs[1].winnerFromPlayer == true, "winnerFromPlayer is true when playerTimer (15s) > teamTimer (9s)")

-- Scenario F: Zero buffs & Reusable Buffer
EsoMock.SetUnit("reticleover", { exists = true, buffs = {} })
local customBuffer = {}
local zeroEffs = adapter:ReadEffects("reticleover", nil, true, customBuffer)
check(#zeroEffs == 0, "Zero buffs returns empty array")
check(zeroEffs == customBuffer, "ReadEffects reuses custom outBuffer")

-- ── 7. IsInTrial: IsPlayerInRaid / IsPlayerInRaidStagingArea ─
EsoMock.isPlayerInRaid = false
EsoMock.isPlayerInRaidStagingArea = false
check(adapter:IsInTrial() == false, "IsInTrial is false outside raid")

EsoMock.isPlayerInRaid = true
check(adapter:IsInTrial() == true, "IsInTrial is true when IsPlayerInRaid() is true")

EsoMock.isPlayerInRaid = false
EsoMock.isPlayerInRaidStagingArea = true
check(adapter:IsInTrial() == true, "IsInTrial is true when IsPlayerInRaidStagingArea() is true")

print(string.format("[EsoAdapterTest] %d passed, %d failed", pass, fail))
for _, e in ipairs(errors) do print("  " .. e) end
if fail > 0 then os.exit(1) end
