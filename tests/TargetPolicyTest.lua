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

-- Settings table content is irrelevant to display gate
s.exists = true
local richSettings = { enabled = false, locked = true }
check(TP.ShouldDisplay(s, richSettings) == true,
    "ShouldDisplay depends only on exists flag")

-- Target is dead
s.exists = true
s.vitals.isDead = true
check(TP.ShouldDisplay(s, fakeSettings) == false,
    "ShouldDisplay(isDead=true) == false (dead target is cleared)")

s.vitals.isDead = false
check(TP.ShouldDisplay(s, fakeSettings) == true,
    "ShouldDisplay(isDead=false) == true (living target displayed)")

print(string.format("[TargetPolicyTest] %d passed, %d failed", pass, fail))
for _, e in ipairs(errors) do print("  " .. e) end
if fail > 0 then os.exit(1) end
