-- =========================================================
-- MugShot - MainIntegrationTest  (tests/MainIntegrationTest.lua)
-- =========================================================

local root = (arg and arg[0] and arg[0]:match("(.+)[/\\][^/\\]+$")) or "."
local addonRoot = root .. "/.."

local EsoMock = dofile(root .. "/EsoMock.lua")
EsoMock.Init()

-- Load all addon modules in manifest order
dofile(addonRoot .. "/Namespace.lua")
dofile(addonRoot .. "/Defaults.lua")
dofile(addonRoot .. "/Constants.lua")
dofile(addonRoot .. "/Localisation.lua")
dofile(addonRoot .. "/Data/Portraits.lua")
dofile(addonRoot .. "/Core/TargetState.lua")
dofile(addonRoot .. "/Core/TargetPolicy.lua")
dofile(addonRoot .. "/Core/Presentation.lua")
dofile(addonRoot .. "/ESO/EsoAdapter.lua")
dofile(addonRoot .. "/UI/Style.lua")
dofile(addonRoot .. "/UI/TargetFrameView.lua")
dofile(addonRoot .. "/ESO/NativeFrameBridge.lua")
dofile(addonRoot .. "/ESO/EventBindings.lua")
dofile(addonRoot .. "/Core/TargetController.lua")
dofile(addonRoot .. "/Settings.lua")
dofile(addonRoot .. "/Main.lua")

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

-- ── 1. Bootstrap on EVENT_ADD_ON_LOADED ───────────────────
check(EsoMock.events["MugShot_Load"] ~= nil, "Load event listener registered")

-- Trigger load for another addon (should ignore)
EsoMock.TriggerEvent(EVENT_ADD_ON_LOADED, "AnotherAddon")
check(EsoMock.events["MugShot_Load"] ~= nil, "Ignored other addon load event")

-- Trigger load for MugShot
EsoMock.TriggerEvent(EVENT_ADD_ON_LOADED, MugShot.Constants.ADDON_NAME)
check(EsoMock.events["MugShot_Load"] == nil, "Unregistered load event after initialisation")
check(MugShot._controller ~= nil, "TargetController initialized")
check(MugShot._view ~= nil, "TargetFrameView initialized")
check(MugShot._nativeBridge ~= nil, "NativeFrameBridge initialized")
check(MugShot.settings:Get().enabled == true, "Addon started enabled by default")

-- ── 2. Slash Commands Registered ──────────────────────────
check(type(SLASH_COMMANDS["/mugshot"]) == "function", "/mugshot registered")
check(type(SLASH_COMMANDS["/mugshotmove"]) == "function", "/mugshotmove registered")
check(type(SLASH_COMMANDS["/mugshotreset"]) == "function", "/mugshotreset registered")
check(type(SLASH_COMMANDS["/mugshothodor"]) == "function", "/mugshothodor registered")

-- ── 3. Test /mugshot (Toggle Enable/Disable) ──────────────
CHAT_SYSTEM.messages = {}
SLASH_COMMANDS["/mugshot"]()
check(MugShot.settings:Get().enabled == false, "/mugshot toggled enabled to false")
check(#CHAT_SYSTEM.messages > 0, "Chat message printed on disable")

SLASH_COMMANDS["/mugshot"]()
check(MugShot.settings:Get().enabled == true, "/mugshot toggled enabled back to true")

-- ── 4. Test /mugshotmove (Toggle Move Mode) ───────────────
SLASH_COMMANDS["/mugshotmove"]()
check(MugShot.settings:Get().locked == true, "/mugshotmove toggled locked to true")
check(EsoMock.cameraUIMode == false, "Camera UI mode disabled when locked")

SLASH_COMMANDS["/mugshotmove"]()
check(MugShot.settings:Get().locked == false, "/mugshotmove toggled locked to false")
check(EsoMock.cameraUIMode == true, "Camera UI mode enabled when unlocked")
check(MugShot._controller:IsInMoveMode() == true, "Controller entered MoveMode")

-- ── 5. Test /mugshotreset (Reset Position) ────────────────
MugShot.settings:Set("position", { point = TOPLEFT, relativePoint = TOPLEFT, offsetX = 999, offsetY = 888 })
SLASH_COMMANDS["/mugshotreset"]()
local curPos = MugShot.settings:Get().position
check(curPos.offsetX == 100 and curPos.offsetY == 200, "/mugshotreset restored (100, 200)")
check(MugShot.settings:Get().locked == false, "/mugshotreset unlocked the frame")
check(EsoMock.cameraUIMode == true, "/mugshotreset activated camera UI mode")

-- ── 6. Test /mugshothodor (Toggle Custom Portraits) ───────
MugShot.settings:Set("useHodorIcons", true)
SLASH_COMMANDS["/mugshothodor"]()
check(MugShot.settings:Get().useHodorIcons == false, "/mugshothodor toggled to false")

SLASH_COMMANDS["/mugshothodor"]()
check(MugShot.settings:Get().useHodorIcons == true, "/mugshothodor toggled back to true")

print(string.format("[MainIntegrationTest] %d passed, %d failed", pass, fail))
for _, e in ipairs(errors) do print("  " .. e) end
if fail > 0 then os.exit(1) end
