-- =========================================================
-- MugShot - Unified Test Runner  (tests/run.lua)
-- Executes all modular test suites, validates output,
-- and reports aggregate statistics.
-- Usage:  lua tests/run.lua
-- =========================================================

local root = (arg and arg[0] and arg[0]:match("(.+)[/\\][^/\\]+$")) or "."

local suites = {
    { name = "TargetState",        file = root .. "/TargetStateTest.lua" },
    { name = "TargetPolicy",       file = root .. "/TargetPolicyTest.lua" },
    { name = "Presentation",       file = root .. "/PresentationTest.lua" },
    { name = "Portraits",          file = root .. "/PortraitsTest.lua" },
    { name = "Localisation",       file = root .. "/LocalisationTest.lua" },
    { name = "TargetController",   file = root .. "/TargetControllerTest.lua" },
    { name = "EsoAdapter",         file = root .. "/EsoAdapterTest.lua" },
    { name = "NativeFrameBridge",  file = root .. "/NativeFrameBridgeTest.lua" },
    { name = "EventBindings",      file = root .. "/EventBindingsTest.lua" },
    { name = "Settings",           file = root .. "/SettingsTest.lua" },
    { name = "TargetFrameView",    file = root .. "/TargetFrameViewTest.lua" },
    { name = "MainIntegration",    file = root .. "/MainIntegrationTest.lua" },
}

print("══════════════════════════════════════════════════════════")
print("               MugShot — Test Suite Runner                ")
print("══════════════════════════════════════════════════════════")

local totalPass = 0
local totalFail = 0
local suiteErrors = {}

for _, suite in ipairs(suites) do
    local cmd = string.format('lua "%s"', suite.file)
    local pipe = io.popen(cmd)
    local output = pipe:read("*a")
    local success = pipe:close()

    local p, f = output:match("(%d+) passed, (%d+) failed")
    p = tonumber(p) or 0
    f = tonumber(f) or 0

    if not success or f > 0 then
        totalFail = totalFail + math.max(1, f)
        totalPass = totalPass + p
        table.insert(suiteErrors, string.format("[%s] Execution error or failures:\n%s", suite.name, output))
        print(string.format("  ✖  %-20s  (FAILED: %d failed, %d passed)", suite.name, f, p))
    else
        totalPass = totalPass + p
        print(string.format("  ✓  %-20s  (%d passed)", suite.name, p))
    end
end

print("══════════════════════════════════════════════════════════")
print(string.format("  Overall Results: %d passed, %d failed across %d suites", totalPass, totalFail, #suites))
print("══════════════════════════════════════════════════════════")

if totalFail > 0 then
    print("\nDetailed Errors:")
    for _, err in ipairs(suiteErrors) do
        print(err)
    end
    os.exit(1)
else
    print("  All test suites passed successfully! ✓\n")
    os.exit(0)
end
