-- =========================================================
-- MugShot - TargetPolicyTest  (tests/TargetPolicyTest.lua)
-- Standalone tests for Core/TargetPolicy.lua.
-- =========================================================

MugShot = MugShot or {}
MugShot.logger = MugShot.logger or {
    Info=function()end, Debug=function()end,
    Warn=function()end, Error=function()end, Verbose=function()end,
}
TOPLEFT = 0
UNIT_REACTION_HOSTILE     = 1
UNIT_REACTION_FRIENDLY    = 2
UNIT_REACTION_NEUTRAL     = 3
UNIT_REACTION_PLAYER_ALLY = 4

local root = (arg and arg[0] and arg[0]:match("(.+)[/\\][^/\\]+$")) or "."
dofile(root .. "/../Core/TargetState.lua")
dofile(root .. "/../Core/TargetPolicy.lua")

local TS   = MugShot.TargetState
local TP   = MugShot.TargetPolicy
local fakeSettings = {}
local pass, fail = 0, 0
local errors = {}

local function check(cond, msg)
    if cond then pass = pass + 1
    else fail = fail + 1; table.insert(errors, "FAIL: " .. (msg or "")) end
end

-- No target
local s = TS.New()
check(TP.ShouldDisplay(s, fakeSettings) == false,
    "ShouldDisplay(exists=false) == false")

-- Target present
s.exists = true
check(TP.ShouldDisplay(s, fakeSettings) == true,
    "ShouldDisplay(exists=true) == true")

-- After reset
s:ResetForTargetChange()
check(TP.ShouldDisplay(s, fakeSettings) == false,
    "ShouldDisplay after reset == false")

-- Settings table content is irrelevant to standard display gate
s.exists = true
local richSettings = { enabled = false, locked = true }
check(TP.ShouldDisplay(s, richSettings) == true,
    "ShouldDisplay depends only on exists flag without trial filter")

-- Target is dead
s.exists = true
s.vitals.isDead = true
check(TP.ShouldDisplay(s, fakeSettings) == false,
    "ShouldDisplay(isDead=true) == false (dead target is cleared)")

s.vitals.isDead = false
check(TP.ShouldDisplay(s, fakeSettings) == true,
    "ShouldDisplay(isDead=false) == true (living target displayed)")

-- ── Trial Filter (onlyHostileInTrials) Tests ────────────────
local trialSettings = { onlyHostileInTrials = true }

-- In Trial: Hostile target -> DISPLAYED
s.identity.reaction = UNIT_REACTION_HOSTILE
check(TP.ShouldDisplay(s, trialSettings, true) == true,
    "Trial filter: Hostile enemy is displayed in Trial")

-- In Trial: Friendly target -> HIDDEN
s.identity.reaction = UNIT_REACTION_FRIENDLY
check(TP.ShouldDisplay(s, trialSettings, true) == false,
    "Trial filter: Friendly target is hidden in Trial")

-- In Trial: Player ally target -> HIDDEN
s.identity.reaction = UNIT_REACTION_PLAYER_ALLY
check(TP.ShouldDisplay(s, trialSettings, true) == false,
    "Trial filter: Player ally is hidden in Trial")

-- Outside Trial: Friendly target -> DISPLAYED
check(TP.ShouldDisplay(s, trialSettings, false) == true,
    "Trial filter: Friendly target is displayed outside Trial")

-- In Trial but filter disabled -> DISPLAYED
local noFilterSettings = { onlyHostileInTrials = false }
check(TP.ShouldDisplay(s, noFilterSettings, true) == true,
    "Trial filter disabled: Friendly target is displayed in Trial")

-- ── Strategy Pattern Extensibility Tests ───────────────────
check(#TP.Strategies == 2, "Strategy Pattern: 2 built-in strategies registered")

-- Register custom test strategy (e.g. Ignore test dummies)
local blockDummies = true
TP.RegisterStrategy(function(state, _settings, _isInTrial)
    if blockDummies and state.identity and state.identity.name == "Target Dummy" then
        return false
    end
    return true
end)

s.identity.name = "Target Dummy"
check(TP.ShouldDisplay(s, fakeSettings, false) == false,
    "Strategy Pattern: Custom strategy successfully blocks Target Dummy")

s.identity.name = "Boss Monster"
check(TP.ShouldDisplay(s, fakeSettings, false) == true,
    "Strategy Pattern: Custom strategy allows Boss Monster")

-- Restore clean strategy state
table.remove(TP.Strategies)

print(string.format("[TargetPolicyTest] %d passed, %d failed", pass, fail))
for _, e in ipairs(errors) do print("  " .. e) end
if fail > 0 then os.exit(1) end
