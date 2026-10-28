-- =========================================================
-- MugShot - LocalisationTest  (tests/LocalisationTest.lua)
-- =========================================================

local root = (arg and arg[0] and arg[0]:match("(.+)[/\\][^/\\]+$")) or "."
local addonRoot = root .. "/.."

local EsoMock = dofile(root .. "/EsoMock.lua")
EsoMock.Init()

dofile(addonRoot .. "/Constants.lua")
dofile(addonRoot .. "/Localisation.lua")

local pass, fail = 0, 0
local errors = {}

local function check(cond, msg)
    if cond then pass = pass + 1
    else fail = fail + 1; table.insert(errors, "FAIL: " .. (msg or "")) end
end
local function eq(a, b, msg) check(a == b, (msg or "") .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

-- 1. Table structure
check(MugShot.strings ~= nil, "strings table exists")
check(MugShot.strings.en ~= nil, "en strings exist")
check(MugShot.strings.fr ~= nil, "fr strings exist")

-- 2. Verify all keys in EN exist in FR
local enKeys = 0
for k, _ in pairs(MugShot.strings.en) do
    enKeys = enKeys + 1
    check(MugShot.strings.fr[k] ~= nil, "Key '" .. k .. "' exists in fr dictionary")
end
check(enKeys >= 15, "At least 15 localized keys")

-- 3. GetText behavior
MugShot.L = MugShot.strings.en
eq(MugShot.GetText("UNKNOWN"), "Unknown", "GetText EN for UNKNOWN")

MugShot.L = MugShot.strings.fr
eq(MugShot.GetText("UNKNOWN"), "Inconnu", "GetText FR for UNKNOWN")
eq(MugShot.GetText("DRAG_ME_TITLE"), "[MugShot] Déplacez-moi !", "GetText FR drag me title")
check(string.find(MugShot.GetText("FRAME_LOCKED"), "verrouillé") ~= nil, "FR frame locked string")
check(string.find(MugShot.GetText("FRAME_UNLOCKED"), "déverrouillé") ~= nil, "FR frame unlocked string")

-- 4. GetText formatting with parameters
local formatted = MugShot.GetText("STATUS_ENABLED_LOCKED", "true", "false")
check(string.find(formatted, "true") ~= nil, "Formatted string contains param 1")
check(string.find(formatted, "false") ~= nil, "Formatted string contains param 2")

-- 5. Missing key fallback
eq(MugShot.GetText("NON_EXISTENT_KEY"), "NON_EXISTENT_KEY", "Missing key returns key itself")

print(string.format("[LocalisationTest] %d passed, %d failed", pass, fail))
for _, e in ipairs(errors) do print("  " .. e) end
if fail > 0 then os.exit(1) end
