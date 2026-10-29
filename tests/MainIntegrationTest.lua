-- =========================================================
-- MugShot - MainIntegrationTest  (tests/MainIntegrationTest.lua)
-- Lifecycle startup, slash command registration, and dispatcher.
-- =========================================================

local root = (arg and arg[0] and arg[0]:match("(.+)[/\\][^/\\]+$")) or "."
local addonRoot = root .. "/.."

local EsoMock = dofile(root .. "/EsoMock.lua")
EsoMock.Init()

local pass, fail = 0, 0
local errors = {}

local function check(cond, msg)
    if cond then pass = pass + 1
    else fail = fail + 1; table.insert(errors, "FAIL: " .. (msg or "")) end
end

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

-- Trigger ADD_ON_LOADED
EsoMock.TriggerEvent(EVENT_ADD_ON_LOADED, MugShot.Constants.ADDON_NAME)

-- ── 1. Startup & Components ───────────────────────────────
check(EsoMock.events["MugShot_Load"] == nil, "Unregistered load event after initialisation")
check(MugShot._controller ~= nil, "TargetController initialized")
check(MugShot._view ~= nil, "TargetFrameView initialized")
check(MugShot._nativeBridge ~= nil, "NativeFrameBridge initialized")
check(MugShot.settings:Get().enabled == true, "Addon started enabled by default")

-- ── 2. Two-word Slash Commands & No Single-Word Leftovers ─
check(type(SLASH_COMMANDS["/mugshot"]) == "function", "/mugshot registered")
check(SLASH_COMMANDS["/mugshotmove"] == nil, "Old /mugshotmove is NOT registered")
check(SLASH_COMMANDS["/mugshotreset"] == nil, "Old /mugshotreset is NOT registered")
check(SLASH_COMMANDS["/mugshothodor"] == nil, "Old /mugshothodor is NOT registered")

-- ── 3. Test /mugshot toggle ───────────────────────────────
CHAT_SYSTEM.messages = {}
SLASH_COMMANDS["/mugshot"]("toggle")
check(MugShot.settings:Get().enabled == false, "/mugshot toggle toggled enabled to false")
check(#CHAT_SYSTEM.messages > 0, "Chat message printed on disable")

SLASH_COMMANDS["/mugshot"]("toggle on")
check(MugShot.settings:Get().enabled == true, "/mugshot toggle on enabled addon")

SLASH_COMMANDS["/mugshot"]("toggle off")
check(MugShot.settings:Get().enabled == false, "/mugshot toggle off disabled addon")

SLASH_COMMANDS["/mugshot"]("toggle")
check(MugShot.settings:Get().enabled == true, "/mugshot toggle restored enabled")

-- ── 4. Test /mugshot move ─────────────────────────────────
SLASH_COMMANDS["/mugshot"]("move")
check(MugShot.settings:Get().locked == true, "/mugshot move toggled locked to true")
check(EsoMock.cameraUIMode == false, "Camera UI mode disabled when locked")

SLASH_COMMANDS["/mugshot"]("move")
check(MugShot.settings:Get().locked == false, "/mugshot move toggled locked to false")
check(EsoMock.cameraUIMode == true, "Camera UI mode enabled when unlocked")
check(MugShot._controller:IsInMoveMode() == true, "Controller entered MoveMode")

-- ── 5. Test /mugshot reset ────────────────────────────────
MugShot.settings:Set("position", { point = TOPLEFT, relativePoint = TOPLEFT, offsetX = 999, offsetY = 888 })
SLASH_COMMANDS["/mugshot"]("reset")
local curPos = MugShot.settings:Get().position
check(curPos.offsetX == 100 and curPos.offsetY == 200, "/mugshot reset restored (100, 200)")
check(MugShot.settings:Get().locked == false, "/mugshot reset unlocked the frame")
check(EsoMock.cameraUIMode == true, "/mugshot reset activated camera UI mode")

-- ── 6. Test /mugshot trial [on|off] ───────────────────────
check(MugShot.settings:Get().onlyHostileInTrials == false, "onlyHostileInTrials false by default")
SLASH_COMMANDS["/mugshot"]("trial")
check(MugShot.settings:Get().onlyHostileInTrials == true, "/mugshot trial toggled to true")

SLASH_COMMANDS["/mugshot"]("trial off")
check(MugShot.settings:Get().onlyHostileInTrials == false, "/mugshot trial off set to false")

SLASH_COMMANDS["/mugshot"]("trial on")
check(MugShot.settings:Get().onlyHostileInTrials == true, "/mugshot trial on set to true")

SLASH_COMMANDS["/mugshot"]("trial")
check(MugShot.settings:Get().onlyHostileInTrials == false, "/mugshot trial toggled back to false")

-- ── 7. Test /mugshot hodor ────────────────────────────────
MugShot.settings:Set("useHodorIcons", true)
SLASH_COMMANDS["/mugshot"]("hodor")
check(MugShot.settings:Get().useHodorIcons == false, "/mugshot hodor toggled to false")

SLASH_COMMANDS["/mugshot"]("hodor")
check(MugShot.settings:Get().useHodorIcons == true, "/mugshot hodor toggled back to true")

-- ── 8. Test /mugshot help & unknown ───────────────────────
CHAT_SYSTEM.messages = {}
SLASH_COMMANDS["/mugshot"]("help")
check(#CHAT_SYSTEM.messages >= 6, "/mugshot help printed command list")

CHAT_SYSTEM.messages = {}
SLASH_COMMANDS["/mugshot"]("foobar")
check(#CHAT_SYSTEM.messages == 1, "/mugshot foobar printed unknown subcommand error")

-- ── 9. Test LibSlashCommander Integration ─────────────────
local registeredSubs = {}
LibSlashCommander = {
    Register = function(_self, _alias, _cb, _desc)
        return {
            RegisterSubCommand = function(_cmdSelf)
                return {
                    AddAlias = function(_sSelf, a) table.insert(registeredSubs, a) end,
                    SetCallback = function() end,
                    SetDescription = function() end,
                }
            end,
        }
    end,
}
-- Re-load Main.lua to register load listener with LibSlashCommander active
dofile(addonRoot .. "/Main.lua")
EsoMock.TriggerEvent(EVENT_ADD_ON_LOADED, MugShot.Constants.ADDON_NAME)
check(#registeredSubs == 6, "LibSlashCommander registered all 6 subcommands")
check(registeredSubs[1] == "toggle" and registeredSubs[2] == "move", "Subcommands order verified")

print(string.format("[MainIntegrationTest] %d passed, %d failed", pass, fail))
for _, e in ipairs(errors) do print("  " .. e) end
if fail > 0 then os.exit(1) end
