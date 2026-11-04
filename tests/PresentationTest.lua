-- =========================================================
-- MugShot - PresentationTest  (tests/PresentationTest.lua)
-- =========================================================

local root = (arg and arg[0] and arg[0]:match("(.+)[/\\][^/\\]+$")) or "."
local addonRoot = root .. "/.."

local EsoMock = dofile(root .. "/EsoMock.lua")
EsoMock.Init()

dofile(addonRoot .. "/Constants.lua")
dofile(addonRoot .. "/Localisation.lua")
dofile(addonRoot .. "/Core/TargetState.lua")
dofile(addonRoot .. "/Core/Presentation.lua")

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

local function eq(a, b, msg)
    if a == b then
        pass = pass + 1
    else
        fail = fail + 1
        table.insert(errors, string.format("FAIL: %s (got %s, want %s)", msg or "", tostring(a), tostring(b)))
    end
end

local P  = MugShot.Presentation
local TS = MugShot.TargetState

local fakeSettings = { useHodorIcons = true }

-- ── BuildVitals ───────────────────────────────────────────
-- Unknown health
local s1 = TS.New()
s1.vitals = { healthKnown = false }
local v1 = P.BuildVitals(s1, fakeSettings)
eq(v1.healthKnown, false, "BuildVitals: unknown health -> healthKnown=false")
eq(v1.percentText, "",    "BuildVitals: unknown health -> percentText empty")

-- Known health + shield
local s2 = TS.New()
s2.vitals = { healthKnown=true, currentHealth=3000, maxHealth=6000, shield=1000 }
local v2 = P.BuildVitals(s2, fakeSettings)
eq(v2.healthKnown,   true,   "BuildVitals: healthKnown=true")
eq(v2.healthPercent, 0.5,    "BuildVitals: 3000/6000 = 0.5")
eq(v2.percentText,   "50%",  "BuildVitals: percentText=50%")
eq(v2.shield,        1000,   "BuildVitals: shield=1000")
check(v2.shieldPercent > 0.16 and v2.shieldPercent < 0.17, "BuildVitals: shieldPercent ~16.6%")
check(string.find(v2.healthText:upper(), "%[1K%]") ~= nil, "BuildVitals: healthText contains [1K] shield")

-- Full health, no shield
local s3 = TS.New()
s3.vitals = { healthKnown=true, currentHealth=5000, maxHealth=5000, shield=0 }
local v3 = P.BuildVitals(s3, fakeSettings)
eq(v3.healthPercent, 1.0,     "BuildVitals: full health = 1.0")
eq(v3.percentText,   "100%",  "BuildVitals: full health 100%")
eq(v3.healthText:upper(), "5K/5K", "BuildVitals: full health text")

-- 0/0 edge case (divide by zero guard)
local s4 = TS.New()
s4.vitals = { healthKnown=true, currentHealth=0, maxHealth=0, shield=0 }
local v4 = P.BuildVitals(s4, fakeSettings)
eq(v4.healthPercent, 0, "BuildVitals: 0/0 -> 0 percent, no crash")

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
eq(id6.g, 0.0, "BuildIdentity: hostile red g=0.0")

-- Missing name fallback
local s7 = TS.New()
s7.identity = { isPlayer=false }
local id7 = P.BuildIdentity(s7, fakeSettings)
check(id7.displayName ~= nil and id7.displayName ~= "", "BuildIdentity: missing name -> fallback")

-- Hodor icons disabled in settings
local s8 = TS.New()
s8.identity = { name="Test", isPlayer=true, portraitTexture="/hodor/icon.dds", classIcon="/class/icon.dds" }
local id8 = P.BuildIdentity(s8, { useHodorIcons = false })
eq(id8.portraitTexture, "/class/icon.dds", "BuildIdentity: useHodorIcons=false -> classIcon fallback")

-- Dummy campaign icon fallback
local s9 = TS.New()
s9.identity = { name="Test", isPlayer=true, portraitTexture="/esoui/art/icons/campaignbrowser_guestcampaign.dds", classIcon="/class/icon.dds" }
local id9 = P.BuildIdentity(s9, fakeSettings)
eq(id9.portraitTexture, "/class/icon.dds", "BuildIdentity: dummy campaign icon -> classIcon fallback")

-- Custom names via LibCustomNames (/mugshot hodor enabled)
local sCustom = TS.New()
sCustom.identity = { name="CharName", displayName="@HodorFriend", isPlayer=true }

-- 1. LibCustomNames active and returns custom colored name
_G.LibCustomNames = {
    Get = function(handle, colored)
        if handle == "@HodorFriend" then
            return "|cFF00FFPrincess Hodor|r"
        end
    end
}
local idCustom1 = P.BuildIdentity(sCustom, { useHodorIcons = true })
eq(idCustom1.displayName, "|cFF00FFPrincess Hodor|r", "BuildIdentity: LibCustomNames custom name resolved when useHodorIcons=true")

-- 2. Custom name disabled when useHodorIcons = false (strictly uses character name)
local idCustom2 = P.BuildIdentity(sCustom, { useHodorIcons = false })
eq(idCustom2.displayName, "CharName", "BuildIdentity: custom name ignored when useHodorIcons=false (strictly uses character name)")

-- 3. HodorReflexes util hook fallback when LibCustomNames is nil
_G.LibCustomNames = nil
_G.HodorReflexes = {
    util = {
        GetUserName = function(handle, pretty)
            if handle == "@HodorFriend" then
                return "|c00FFFFTankGod|r"
            end
        end
    }
}
local idCustom3 = P.BuildIdentity(sCustom, { useHodorIcons = true })
eq(idCustom3.displayName, "|c00FFFFTankGod|r", "BuildIdentity: HodorReflexes.util.GetUserName resolved custom name")

-- 4. Thorough Account Name vs Character Name toggle validation
local sNyx = TS.New()
sNyx.identity = { name = "nycthemere", displayName = "@nycthemere", isPlayer = true }

_G.LibCustomNames = {
    Get = function(handle, colored)
        if handle == "@nycthemere" or handle == "nycthemere" then
            return "|c783f04nyc|r|c8fce00thé|r|c6a329fmère|r"
        end
    end
}

-- Case A: Hodor ON + Custom name available -> custom colored nickname
local idNyx1 = P.BuildIdentity(sNyx, { useHodorIcons = true })
eq(idNyx1.displayName, "|c783f04nyc|r|c8fce00thé|r|c6a329fmère|r", "Hodor ON: uses colored custom name from LibCustomNames")

-- Case B: Hodor ON + Case variation in account name (@Nycthemere) -> matches case-insensitively
local sNyxCase = TS.New()
sNyxCase.identity = { name = "nycthemere", displayName = "@Nycthemere", isPlayer = true }
local idNyxCase = P.BuildIdentity(sNyxCase, { useHodorIcons = true })
eq(idNyxCase.displayName, "|c783f04nyc|r|c8fce00thé|r|c6a329fmère|r", "Hodor ON: case-insensitive match for @Nycthemere")

-- Case C: Hodor ON + No custom nickname -> displays Account Name (@Handle)
_G.LibCustomNames = nil
local idNyx2 = P.BuildIdentity(sNyx, { useHodorIcons = true })
eq(idNyx2.displayName, "@nycthemere", "Hodor ON: displays Account Name when no custom nickname exists")

-- Case D: Hodor OFF -> strictly displays Character Name (nom de perso)
local idNyx3 = P.BuildIdentity(sNyx, { useHodorIcons = false })
eq(idNyx3.displayName, "nycthemere", "Hodor OFF: strictly displays Character Name (nom de perso)")

-- 5. Clean up globals
_G.LibCustomNames = nil
_G.HodorReflexes = nil

-- ── BuildEffects ──────────────────────────────────────────
local s10 = TS.New()
s10.effects = {
    { icon="/icon1.dds", timer=10.4, stackCount=3, castByPlayer=true },
    { icon="/icon2.dds", timer=0,    stackCount=1, castByPlayer=false },
    { icon="/icon3.dds", timer=75.0, stackCount=0, castByPlayer=true },  -- > 60s -> 1m
    { icon="/icon4.dds", timer=3700, stackCount=0, castByPlayer=true },  -- > 3600s -> 1h
}
local effs = P.BuildEffects(s10, fakeSettings)
eq(#effs, 4, "BuildEffects: all 4 effects preserved (no arbitrary cap)")
eq(effs[1].icon,      "/icon1.dds", "Effect 1: icon correct")
eq(effs[1].timerText, "11",         "Effect 1: 10.4s rounds up to 11")
eq(effs[1].stackText, "3",          "Effect 1: stackCount 3 displayed")
eq(effs[2].timerText, "",           "Effect 2: 0s timer displays empty string")
eq(effs[2].stackText, "",           "Effect 2: stackCount 1 displays empty string")
eq(effs[3].timerText, "1m",         "Effect 3: 75s displays 1m")
eq(effs[4].timerText, "1h",         "Effect 4: 3700s displays 1h")

-- Empty effects
local s11 = TS.New()
s11.effects = {}
local effs2 = P.BuildEffects(s11, fakeSettings)
eq(#effs2, 0, "BuildEffects: empty list -> 0 items")

-- Nil state guard
local effs3 = P.BuildEffects(nil, fakeSettings)
eq(#effs3, 0, "BuildEffects: nil state -> 0 items, no error")

-- ── Reusable output buffer (0 allocation test) ────────────
local outBuf = {}
local effs4 = P.BuildEffects(s10, fakeSettings, outBuf)
check(effs4 == outBuf, "BuildEffects: returned same table as outBuffer")
eq(#effs4, 4, "BuildEffects: buffer populated with 4 effects")

-- Second run with fewer effects: trims excess
local s12 = TS.New()
s12.effects = { { icon="/icon1.dds", timer=5, stackCount=1 } }
P.BuildEffects(s12, fakeSettings, outBuf)
eq(#outBuf, 1, "BuildEffects: trimmed excess buffer entries from 4 to 1")

-- Multi-source group debuff badge
local s13 = TS.New()
s13.effects = {
    { icon="/icon1.dds", timer=10, stackCount=1, sourceCount=3, castByPlayer=false },
}
local effs5 = P.BuildEffects(s13, fakeSettings)
eq(effs5[1].sourceText, "x3", "BuildEffects: sourceCount 3 displays 'x3'")

-- Excluded names (Privileged Debuffs deduplication)
local s14 = TS.New()
s14.effects = {
    { name="Crusher",     tag="CRUSH",   icon="/icon1.dds", timer=5, stackCount=1 },
    { name="Major Breach", tag="BREACH", icon="/icon2.dds", timer=15, stackCount=1 },
    { name="Minor Breach", tag="BREACH", icon="/icon3.dds", timer=18, stackCount=1 },
    { name="Unrelated Debuff", tag="",   icon="/icon4.dds", timer=12, stackCount=1 },
}
local excluded = { ["Crusher"] = true, ["Major Breach"] = true, ["Minor Breach"] = true }
local effs6 = P.BuildEffects(s14, fakeSettings, nil, excluded)
eq(#effs6, 1, "BuildEffects: excluded 3 privileged debuffs, leaving 1 unrelated debuff")
eq(effs6[1].name, "Unrelated Debuff", "BuildEffects: remaining debuff is Unrelated Debuff")

-- Test portraitColor forwarding and Hodor fallback color
local s15 = TS.New()
s15.identity = {
    isPlayer = true,
    name = "TestPlayer",
    portraitTexture = "/custom.dds",
    portraitColor = { 1.0, 1.0, 1.0, 1.0 },
    classIcon = "/class.dds",
    classColor = { 0.45, 0.55, 1.0, 1.0 },
}
local idPres15 = P.BuildIdentity(s15, { useHodorIcons = true })
eq(idPres15.portraitColor[1], 1.0, "BuildIdentity: custom icon has unaltered portraitColor (1.0)")

local idPres15Class = P.BuildIdentity(s15, { useHodorIcons = false })
eq(idPres15Class.portraitTexture, "/class.dds", "BuildIdentity: useHodorIcons=false falls back to classIcon")
eq(idPres15Class.portraitColor[1], 0.45, "BuildIdentity: classIcon uses classColor red component (0.45)")
eq(idPres15Class.portraitColor[2], 0.55, "BuildIdentity: classIcon uses classColor green component (0.55)")

print(string.format("[PresentationTest] %d passed, %d failed", pass, fail))
if fail > 0 then
    for _, e in ipairs(errors) do print("  " .. e) end
end
