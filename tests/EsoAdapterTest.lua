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

-- ── 6. IsInTrial: IsPlayerInRaid / IsPlayerInRaidStagingArea ─
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
