-- =========================================================
-- MugShot - SettingsTest  (tests/SettingsTest.lua)
-- =========================================================

local root = (arg and arg[0] and arg[0]:match("(.+)[/\\][^/\\]+$")) or "."
local addonRoot = root .. "/.."

local EsoMock = dofile(root .. "/EsoMock.lua")
EsoMock.Init()

dofile(addonRoot .. "/Defaults.lua")
dofile(addonRoot .. "/Settings.lua")

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

-- ── 1. Initial Load (First Run / Empty SavedVariables) ────
MugShotSV = {}
local settings = MugShot.Settings.New()
check(settings:Get() == nil, "settings:Get() is nil before Load()")

settings:Load()
local data = settings:Get()
check(data ~= nil, "settings:Get() returns table after Load()")
check(data.schemaVersion == MugShot.Defaults.schemaVersion, "Default schemaVersion set")
check(data.enabled == true, "Default enabled is true")
check(data.locked == false, "Default locked is false")
check(data.useHodorIcons == true, "Default useHodorIcons is true")
check(data.position ~= nil, "Default position exists")
check(data.position.offsetX == 100, "Default offsetX is 100")
check(data.position.offsetY == 200, "Default offsetY is 200")

-- ── 2. Preserves User Values & Merges New Defaults ────────
MugShotSV = {
    schemaVersion = 1,
    enabled       = false, -- user customized
    locked        = true,  -- user customized
    position      = {
        point   = TOPLEFT,
        offsetX = 350,     -- user customized
        -- offsetY missing
    }
}

local settings2 = MugShot.Settings.New()
settings2:Load()
local data2 = settings2:Get()
check(data2.enabled == false, "Preserved user enabled=false")
check(data2.locked == true, "Preserved user locked=true")
check(data2.position.offsetX == 350, "Preserved user offsetX=350")
check(data2.position.offsetY == 200, "Merged missing offsetY default (200)")
check(data2.useHodorIcons == true, "Merged missing useHodorIcons default (true)")

-- ── 3. Schema Version Migration ───────────────────────────
MugShotSV = {
    schemaVersion = 0, -- Old schema
    legacyKey     = "oldValue",
    position      = { offsetX = 9999 }
}

local settingsMigrate = MugShot.Settings.New()
settingsMigrate:Load()
local dataMigrate = settingsMigrate:Get()
check(dataMigrate.schemaVersion == 1, "Migrated to schemaVersion 1")
check(dataMigrate.legacyKey == nil, "Old schema stale keys cleaned up")
check(dataMigrate.position.offsetX == 100, "Reset to clean defaults on schema upgrade")

-- ── 4. Set() and Save() ───────────────────────────────────
settings2:Set("locked", false)
check(data2.locked == false, "Set('locked', false) updates live data")
check(MugShotSV.locked == false, "Set updates global MugShotSV directly")

-- Guard against Set() before Load()
local uninitializedSettings = MugShot.Settings.New()
uninitializedSettings:Set("enabled", false) -- should not crash
check(uninitializedSettings:Get() == nil, "Uninitialized settings remained nil")

settings2:Save() -- verify Save() is callable without error
check(true, "Save() executed cleanly")

print(string.format("[SettingsTest] %d passed, %d failed", pass, fail))
for _, e in ipairs(errors) do print("  " .. e) end
if fail > 0 then os.exit(1) end
