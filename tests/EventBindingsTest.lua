-- =========================================================
-- MugShot - EventBindingsTest  (tests/EventBindingsTest.lua)
-- =========================================================

local root = (arg and arg[0] and arg[0]:match("(.+)[/\\][^/\\]+$")) or "."
local addonRoot = root .. "/.."

local EsoMock = dofile(root .. "/EsoMock.lua")
EsoMock.Init()

dofile(addonRoot .. "/ESO/EventBindings.lua")

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

local eb = MugShot.EventBindings.New()

-- Mock Controller to capture events
local mockCtrl = {
    refreshedTarget = false,
    vitalsCalled = false,
    vitalsValue = nil,
    shieldRefreshed = false,
    effectsRefreshed = false,
    identityRefreshed = false,
    timersUpdated = false,
    targetDeathCalled = false,
    inMoveMode = false,
    gen = 42,

    RefreshTarget = function(self) self.refreshedTarget = true end,
    RefreshVitals = function(self, val, max, eff)
        self.vitalsCalled = true
        self.vitalsValue = val
    end,
    RefreshShield = function(self) self.shieldRefreshed = true end,
    RefreshEffects = function(self) self.effectsRefreshed = true end,
    RefreshIdentity = function(self) self.identityRefreshed = true end,
    OnTargetDeath = function(self) self.targetDeathCalled = true end,
    UpdateEffectTimers = function(self, gen) self.timersUpdated = true end,
    IsInMoveMode = function(self) return self.inMoveMode end,
    GetGeneration = function(self) return self.gen end,
}

-- ── 1. Start Event Bindings ───────────────────────────────
eb:Start(mockCtrl)

check(EsoMock.events["MugShot_Target"] ~= nil, "Target event registered")
check(EsoMock.events["MugShot_Vitals"] ~= nil, "Vitals event registered")
check(EsoMock.events["MugShot_Vitals"].filters[REGISTER_FILTER_UNIT_TAG] == "reticleover", "Vitals filtered to reticleover")
check(EsoMock.events["MugShot_Shield_Add"] ~= nil, "Shield Add event registered")
check(EsoMock.events["MugShot_Effects"] ~= nil, "Effects event registered")

-- ── 2. Event Dispatching to Controller ────────────────────
EsoMock.TriggerEvent(EVENT_RETICLE_TARGET_CHANGED)
check(mockCtrl.refreshedTarget == true, "Triggering TARGET_CHANGED invokes RefreshTarget")

EsoMock.TriggerEvent(EVENT_POWER_UPDATE, "reticleover", 1, COMBAT_MECHANIC_FLAGS_HEALTH, 1234, 5000, 5000)
check(mockCtrl.vitalsCalled == true, "Triggering POWER_UPDATE invokes RefreshVitals")
check(mockCtrl.vitalsValue == 1234, "Correct health value delivered to RefreshVitals")

EsoMock.TriggerEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, "reticleover", ATTRIBUTE_VISUAL_POWER_SHIELDING)
check(mockCtrl.shieldRefreshed == true, "Triggering ATTRIBUTE_VISUAL invokes RefreshShield")

EsoMock.TriggerEvent(EVENT_EFFECT_CHANGED, 1, 1, "Buff", "reticleover")
check(mockCtrl.effectsRefreshed == true, "Triggering EFFECT_CHANGED invokes RefreshEffects")

EsoMock.TriggerEvent(EVENT_UNIT_DEATH_STATE_CHANGED, "reticleover", true)
check(mockCtrl.targetDeathCalled == true, "Triggering UNIT_DEATH_STATE_CHANGED invokes OnTargetDeath")

-- ── 2b. Move Mode ignores reticleover & accepts player ───────
mockCtrl.refreshedTarget = false
mockCtrl.vitalsCalled = false
mockCtrl.vitalsValue = nil
mockCtrl.shieldRefreshed = false
mockCtrl.effectsRefreshed = false
mockCtrl.targetDeathCalled = false
mockCtrl.inMoveMode = true

-- Reticle target change ignored
EsoMock.TriggerEvent(EVENT_RETICLE_TARGET_CHANGED)
check(mockCtrl.refreshedTarget == false, "MoveMode: TARGET_CHANGED ignored")

-- Insect/reticleover health power update ignored!
EsoMock.TriggerEvent(EVENT_POWER_UPDATE, "reticleover", 1, COMBAT_MECHANIC_FLAGS_HEALTH, 1, 1, 1)
check(mockCtrl.vitalsCalled == false, "MoveMode: reticleover POWER_UPDATE ignored (insect bug prevented)")

-- Player health update IS accepted
EsoMock.TriggerEvent(EVENT_POWER_UPDATE, "player", 1, COMBAT_MECHANIC_FLAGS_HEALTH, 24000, 30000, 30000)
check(mockCtrl.vitalsCalled == true, "MoveMode: player POWER_UPDATE accepted")
check(mockCtrl.vitalsValue == 24000, "MoveMode: player health value delivered")

-- Reticleover death ignored
EsoMock.TriggerEvent(EVENT_UNIT_DEATH_STATE_CHANGED, "reticleover", true)
check(mockCtrl.targetDeathCalled == false, "MoveMode: reticleover death ignored")

mockCtrl.inMoveMode = false

-- ── 3. Timer Control ──────────────────────────────────────
eb:StartEffectTimer()
check(eb._timerActive == true, "StartEffectTimer activates timer")
check(EsoMock.updates["MugShot_TimerUpdate"] ~= nil, "Update registration exists in EVENT_MANAGER")

EsoMock.TriggerUpdate("MugShot_TimerUpdate")
check(mockCtrl.timersUpdated == true, "Timer tick calls UpdateEffectTimers")

eb:StopEffectTimer()
check(eb._timerActive == false, "StopEffectTimer deactivates timer")
check(EsoMock.updates["MugShot_TimerUpdate"] == nil, "Update unregistered from EVENT_MANAGER")

-- ── 4. Stop Event Bindings ────────────────────────────────
eb:Stop()
check(EsoMock.events["MugShot_Target"] == nil, "Stop() unregisters target event")
check(EsoMock.events["MugShot_Vitals"] == nil, "Stop() unregisters vitals event")
check(EsoMock.events["MugShot_Effects"] == nil, "Stop() unregisters effects event")
check(eb._controller == nil, "Stop() clears controller reference")

print(string.format("[EventBindingsTest] %d passed, %d failed", pass, fail))
for _, e in ipairs(errors) do print("  " .. e) end
if fail > 0 then os.exit(1) end
