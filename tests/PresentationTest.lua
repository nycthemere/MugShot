-- =========================================================
-- MugShot - PresentationTest  (tests/PresentationTest.lua)
-- Standalone tests for Core/Presentation.lua.
-- =========================================================

MugShot = MugShot or {}
MugShot.logger = MugShot.logger or {
    Info=function()end, Debug=function()end,
    Warn=function()end, Error=function()end, Verbose=function()end,
}
TOPLEFT = 0
UNIT_REACTION_HOSTILE    = 1
UNIT_REACTION_PLAYER_ALLY = 4

local root = (arg and arg[0] and arg[0]:match("(.+)[/\\][^/\\]+$")) or "."
local EsoMock = dofile(root .. "/EsoMock.lua")
EsoMock.Init()
dofile(root .. "/../Constants.lua")
dofile(root .. "/../Localisation.lua")
dofile(root .. "/../UI/Style.lua")
dofile(root .. "/../Core/TargetState.lua")
dofile(root .. "/../Core/Presentation.lua")

local TS   = MugShot.TargetState
local P    = MugShot.Presentation
local fakeSettings = {}
local pass, fail = 0, 0
local errors = {}

local function check(cond, msg)
    if cond then pass = pass + 1
    else fail = fail + 1; table.insert(errors, "FAIL: " .. (msg or "")) end
end
local function eq(a, b, msg)  check(a == b, (msg or "") .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

-- ── BuildVitals ──────────────────────────────────────────
-- healthKnown = false
local s1 = TS.New()
local v1 = P.BuildVitals(s1, fakeSettings)
eq(v1.healthKnown,   false, "BuildVitals: healthKnown=false")
eq(v1.healthText,    nil,   "BuildVitals: healthText=nil when unknown")
eq(v1.healthPercent, nil,   "BuildVitals: healthPercent=nil when unknown")

-- Standard data with shield
local s2 = TS.New()
s2.vitals = { healthKnown=true, currentHealth=3000, maxHealth=6000, shield=1000 }
local v2 = P.BuildVitals(s2, fakeSettings)
eq(v2.healthKnown,   true,   "BuildVitals: healthKnown=true")
eq(v2.healthPercent, 0.5,    "BuildVitals: healthPercent=0.5 for 3000/6000")
eq(v2.percentText,   "50%",  "BuildVitals: percentText=50%")
eq(v2.shield,        1000,   "BuildVitals: shield=1000")
check(v2.shieldPercent > 0.16 and v2.shieldPercent < 0.17, "BuildVitals: shieldPercent ~16.6%")
check(string.find(v2.healthText, "%[1k%]") ~= nil, "BuildVitals: healthText contains [1k] shield")

-- Full health, no shield
local s3 = TS.New()
s3.vitals = { healthKnown=true, currentHealth=5000, maxHealth=5000, shield=0 }
local v3 = P.BuildVitals(s3, fakeSettings)
eq(v3.healthPercent, 1.0,     "BuildVitals: full health = 1.0")
eq(v3.percentText,   "100%",  "BuildVitals: full health 100%")
eq(v3.healthText,    "5k/5k", "BuildVitals: full health text")

-- 0/0 edge case (divide by zero guard)
local s4 = TS.New()
s4.vitals = { healthKnown=true, currentHealth=0, maxHealth=0, shield=0 }
local v4 = P.BuildVitals(s4, fakeSettings)
eq(v4.healthPercent, 0, "BuildVitals: 0/0 → 0 percent, no crash")

-- ── BuildIdentity ─────────────────────────────────────────
-- Player with display name
local s5 = TS.New()
s5.identity = { name="RealName", displayName="@Handle", isPlayer=true,
                reaction=UNIT_REACTION_PLAYER_ALLY, reactionR=0.2, reactionG=0.9, reactionB=0.2,
                portraitTexture="/path/to/class.dds", raceIcon="/path/to/race.dds" }
local id5 = P.BuildIdentity(s5, fakeSettings)
eq(id5.displayName, "@Handle", "BuildIdentity: player uses displayName")
eq(id5.r, 0.2, "BuildIdentity: r matches reactionR")
eq(id5.portraitTexture, "/path/to/class.dds", "BuildIdentity: portrait passed")
eq(id5.raceIcon, "/path/to/race.dds", "BuildIdentity: raceIcon passed")

-- NPC with name only
local s6 = TS.New()
s6.identity = { name="Goblin", displayName="", isPlayer=false,
                reaction=UNIT_REACTION_HOSTILE, reactionR=1.0, reactionG=0.0, reactionB=0.0 }
local id6 = P.BuildIdentity(s6, fakeSettings)
eq(id6.displayName, "Goblin", "BuildIdentity: NPC uses name")
eq(id6.r, 1.0, "BuildIdentity: hostile red r=1.0")

-- No name at all → Unknown
local s7 = TS.New()
s7.identity = { name=nil, displayName=nil, isPlayer=false }
local id7 = P.BuildIdentity(s7, fakeSettings)
eq(id7.displayName, "Unknown", "BuildIdentity: nil name → Unknown")
eq(id7.r, 0.8, "BuildIdentity: default r=0.8 when no reaction colour")

-- ── BuildEffects ──────────────────────────────────────────
local s8 = TS.New()
s8.effects = {
    { name = "Debuff1", icon = "/icon1.dds", timer = 4.2, stackCount = 3 },
    { name = "Buff2",   icon = "/icon2.dds", timer = 0,   stackCount = 0 },
    { name = "BuffMin", icon = "/icon3.dds", timer = 75,  stackCount = 0 },
    { name = "BuffHour",icon = "/icon4.dds", timer = 3600,stackCount = 0 },
    { name = "Buff2h",  icon = "/icon5.dds", timer = 7500,stackCount = 0 },
}
local eff8 = P.BuildEffects(s8, fakeSettings)
eq(#eff8, 5, "BuildEffects: returns 5 items")
eq(eff8[1].timerText, "5", "BuildEffects: 4.2 rounded up to 5")
eq(eff8[1].stackText, "3", "BuildEffects: stackCount=3")
eq(eff8[2].timerText, "", "BuildEffects: 0 timer returns empty string")
eq(eff8[2].stackText, "", "BuildEffects: 0 stack returns empty string")
eq(eff8[3].timerText, "1m", "BuildEffects: 75s formatted as 1m")
eq(eff8[4].timerText, "1h", "BuildEffects: 3600s formatted as 1h")
eq(eff8[5].timerText, "2h", "BuildEffects: 7500s formatted as 2h")

-- Test no artificial cap on effects (> 10 effects supported)
local sMany = TS.New()
sMany.effects = {}
for i = 1, 15 do
    table.insert(sMany.effects, { name = "Buff" .. i, icon = "/icon" .. i .. ".dds", timer = i * 10 })
end
local effMany = P.BuildEffects(sMany, fakeSettings)
eq(#effMany, 15, "BuildEffects: supports 15 effects without 10-cap limitation")

-- Test that BuildEffects does not artificially cap effects (handled cleanly via castByPlayer filtering)
local sRaid = TS.New()
sRaid.effects = {}
for i = 1, 40 do
    table.insert(sRaid.effects, { name = "Debuff" .. i, icon = "/icon" .. i .. ".dds", timer = i })
end
local effRaid = P.BuildEffects(sRaid, fakeSettings)
eq(#effRaid, 40, "BuildEffects: presents all target effects without artificial truncation")

-- Test Zero-GC Reusable Buffer
local testBuffer = {}
local sBuf = TS.New()
sBuf.effects = {
    { name = "DoT1", icon = "/icon1.dds", timer = 12.4, stackCount = 3 },
    { name = "DoT2", icon = "/icon2.dds", timer = 5.1,  stackCount = 0 },
}
local res1 = P.BuildEffects(sBuf, fakeSettings, testBuffer)
eq(res1, testBuffer, "BuildEffects reuses provided outBuffer instance (zero table allocation)")
eq(#res1, 2, "Buffer populated with 2 effects")
eq(res1[1].timerText, "13", "12.4s formatted to Flyweight '13'")
eq(res1[1].stackText, "3", "stackCount 3 formatted to Flyweight '3'")
eq(res1[2].timerText, "6", "5.1s formatted to Flyweight '6'")

local firstItemRef = res1[1]

-- Tick 2: Update timers in place
sBuf.effects[1].timer = 11.2
local res2 = P.BuildEffects(sBuf, fakeSettings, testBuffer)
eq(res2, testBuffer, "Tick 2 returns same buffer instance")
eq(res2[1], firstItemRef, "Item sub-table reference preserved in-place (zero GC churn)")
eq(res2[1].timerText, "12", "11.2s updated in-place to '12'")

-- ── Multi-Source Badge & Border Presentation ───────────────
local sMulti = TS.New()
sMulti.effects = {
    { name = "Major Vulnerability", icon = "/icon_mv.dds", timer = 14, sourceCount = 2, stackCount = 0, castByPlayer = true },
    { name = "Minor Breach",        icon = "/icon_mb.dds", timer = 20, sourceCount = 3, stackCount = 0, castByPlayer = false },
    { name = "Solo Player Dot",     icon = "/icon_dot.dds", timer = 8, sourceCount = 1, stackCount = 0, castByPlayer = true },
}
local effMulti = P.BuildEffects(sMulti, fakeSettings)
eq(#effMulti, 3, "Multi-source effects built")
eq(effMulti[1].sourceText, "x2", "sourceCount 2 formatted to 'x2'")
eq(effMulti[1].isPlayerCast, true, "Player cast preserved on merged effect")
check(effMulti[1].borderR > 0.15 and effMulti[1].borderB > 0.9, "Multi-source effect has cyan border (borderB > 0.9)")
eq(effMulti[2].sourceText, "x3", "sourceCount 3 formatted to 'x3'")
eq(effMulti[2].isPlayerCast, false, "Ally effect has isPlayerCast=false")
check(effMulti[2].borderR > 0.15 and effMulti[2].borderB > 0.9, "Ally multi-source has cyan border")
eq(effMulti[3].sourceText, "", "Single source effect has empty sourceText")
eq(effMulti[3].borderB, 0.0, "Single source player effect has standard black border (borderB=0)")

-- ── Unknown / Empty Identity presentation ─────────────────
local sUnknown = TS.New()
sUnknown.identity = { name = "", displayName = "" }
local idUnknown = P.BuildIdentity(sUnknown, fakeSettings)
check(idUnknown.displayName == "Unknown" or idUnknown.displayName == "Inconnu", "Empty name resolves to localized UNKNOWN")
check(idUnknown.r > 0.5 and idUnknown.g > 0.5, "Default reaction colour is neutral grey")

print(string.format("[PresentationTest] %d passed, %d failed", pass, fail))
for _, e in ipairs(errors) do print("  " .. e) end
if fail > 0 then os.exit(1) end
