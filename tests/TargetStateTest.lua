-- =========================================================
-- MugShot - TargetStateTest  (tests/TargetStateTest.lua)
-- Standalone tests for Core/TargetState.lua.
-- Can be run via the main test runner (tests/run.lua) or
-- individually with:  lua tests/TargetStateTest.lua
-- =========================================================

-- Stub globals required by the module
MugShot = MugShot or {}
MugShot.logger = MugShot.logger or {
    Info    = function() end,
    Debug   = function() end,
    Warn    = function() end,
    Error   = function() end,
    Verbose = function() end,
}
TOPLEFT = 0

-- Load the module under test
local root = (arg and arg[0] and arg[0]:match("(.+)[/\\][^/\\]+$")) or "."
dofile(root .. "/../Core/TargetState.lua")

local TS = MugShot.TargetState
local pass, fail = 0, 0
local errors = {}

local function check(cond, msg)
    if cond then
        pass = pass + 1
    else
        fail = fail + 1
        table.insert(errors, "FAIL: " .. (msg or "unnamed check"))
    end
end

-- Initial state
local s = TS.New()
check(s.generation == 0,           "initial generation == 0")
check(s.exists == false,           "initial exists == false")
check(s.unitTag == "reticleover",  "initial unitTag == 'reticleover'")
check(s.identity.name == nil,      "initial identity.name == nil")
check(s.vitals.healthKnown == false, "initial vitals.healthKnown == false")
check(type(s.effects) == "table",  "effects is a table")

-- Populate some data
s.exists = true
s.identity.name = "Molag Bal"
s.vitals.healthKnown = true
s.vitals.currentHealth = 99999
s.vitals.maxHealth     = 99999

-- Reset
s:ResetForTargetChange()
check(s.generation == 1,           "generation == 1 after first reset")
check(s.exists == false,           "exists == false after reset")
check(s.identity.name == nil,      "identity.name == nil after reset")
check(s.vitals.healthKnown == false, "vitals.healthKnown == false after reset")
check(s.vitals.currentHealth == nil, "vitals.currentHealth == nil after reset")

-- Second reset
s:ResetForTargetChange()
check(s.generation == 2,           "generation == 2 after second reset")

-- Multiple New() instances are independent
local s2 = TS.New()
s:ResetForTargetChange()   -- s.generation = 3
check(s2.generation == 0,  "independent instance unaffected by other reset")

-- Print summary
print(string.format("[TargetStateTest] %d passed, %d failed", pass, fail))
for _, e in ipairs(errors) do print("  " .. e) end
if fail > 0 then os.exit(1) end
