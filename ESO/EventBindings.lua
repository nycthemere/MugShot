-- =========================================================
-- MugShot - EventBindings  (ESO/EventBindings.lua)
-- Registers and unregisters all ESO event handlers.
-- Each registration uses a unique namespace string so that
-- multiple binds/unbinds don't collide with each other or
-- with other addons.
-- =========================================================

local EventBindings = {}
EventBindings.__index = EventBindings

-- Namespace prefixes used with EVENT_MANAGER
local NS_TARGET  = "MugShot_Target"
local NS_VITALS  = "MugShot_Vitals"
local NS_SHIELD  = "MugShot_Shield"
local NS_EFFECTS = "MugShot_Effects"
local NS_UPDATE  = "MugShot_TimerUpdate"

-- ── Constructor ───────────────────────────────────────────
function EventBindings.New()
    local self = setmetatable({}, EventBindings)
    self._timerActive = false
    return self
end

-- ── Start ─────────────────────────────────────────────────
-- Register all event handlers.
-- @param  controller  TargetController instance
function EventBindings:Start(controller)
    self._controller = controller

    -- ── 1. Target Change ──────────────────────────────────
    EVENT_MANAGER:RegisterForEvent(NS_TARGET, EVENT_RETICLE_TARGET_CHANGED, function(_eventCode)
        controller:RefreshTarget()
    end)

    -- ── 2. Health Power Updates ───────────────────────────
    EVENT_MANAGER:RegisterForEvent(NS_VITALS, EVENT_POWER_UPDATE,
        function(_eventCode, unitTag, _powerIndex, powerType,
                 powerValue, powerMax, powerEffectiveMax)
            if powerType == COMBAT_MECHANIC_FLAGS_HEALTH then
                controller:RefreshVitals(powerValue, powerMax, powerEffectiveMax)
            end
        end)
    EVENT_MANAGER:AddFilterForEvent(NS_VITALS, EVENT_POWER_UPDATE,
        REGISTER_FILTER_UNIT_TAG, "reticleover")

    -- Live WYSIWYG player health in Move Mode
    EVENT_MANAGER:RegisterForEvent(NS_VITALS .. "_Player", EVENT_POWER_UPDATE,
        function(_eventCode, unitTag, _powerIndex, powerType,
                 powerValue, powerMax, powerEffectiveMax)
            if powerType == COMBAT_MECHANIC_FLAGS_HEALTH and controller.IsInMoveMode and controller:IsInMoveMode() then
                controller:RefreshVitals(powerValue, powerMax, powerEffectiveMax)
            end
        end)
    EVENT_MANAGER:AddFilterForEvent(NS_VITALS .. "_Player", EVENT_POWER_UPDATE,
        REGISTER_FILTER_UNIT_TAG, "player")

    -- ── 3. Shield Visual Updates ──────────────────────────
    local function OnShieldEvent(_eventCode, unitTag, unitAttributeVisual)
        if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING or not unitAttributeVisual then
            controller:RefreshShield()
        end
    end

    local function OnPlayerShieldEvent(_eventCode, unitTag, unitAttributeVisual)
        if controller.IsInMoveMode and controller:IsInMoveMode() then
            OnShieldEvent(_eventCode, unitTag, unitAttributeVisual)
        end
    end

    if EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED then
        EVENT_MANAGER:RegisterForEvent(NS_SHIELD .. "_Add", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, OnShieldEvent)
        EVENT_MANAGER:AddFilterForEvent(NS_SHIELD .. "_Add", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED,
            REGISTER_FILTER_UNIT_TAG, "reticleover")

        EVENT_MANAGER:RegisterForEvent(NS_SHIELD .. "_Player_Add", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, OnPlayerShieldEvent)
        EVENT_MANAGER:AddFilterForEvent(NS_SHIELD .. "_Player_Add", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED,
            REGISTER_FILTER_UNIT_TAG, "player")
    end
    if EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED then
        EVENT_MANAGER:RegisterForEvent(NS_SHIELD .. "_Upd", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, OnShieldEvent)
        EVENT_MANAGER:AddFilterForEvent(NS_SHIELD .. "_Upd", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED,
            REGISTER_FILTER_UNIT_TAG, "reticleover")

        EVENT_MANAGER:RegisterForEvent(NS_SHIELD .. "_Player_Upd", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, OnPlayerShieldEvent)
        EVENT_MANAGER:AddFilterForEvent(NS_SHIELD .. "_Player_Upd", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED,
            REGISTER_FILTER_UNIT_TAG, "player")
    end
    if EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED then
        EVENT_MANAGER:RegisterForEvent(NS_SHIELD .. "_Rem", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, OnShieldEvent)
        EVENT_MANAGER:AddFilterForEvent(NS_SHIELD .. "_Rem", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED,
            REGISTER_FILTER_UNIT_TAG, "reticleover")

        EVENT_MANAGER:RegisterForEvent(NS_SHIELD .. "_Player_Rem", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, OnPlayerShieldEvent)
        EVENT_MANAGER:AddFilterForEvent(NS_SHIELD .. "_Player_Rem", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED,
            REGISTER_FILTER_UNIT_TAG, "player")
    end

    -- ── 4. Buffs & Debuffs ────────────────────────────────
    if EVENT_EFFECT_CHANGED then
        EVENT_MANAGER:RegisterForEvent(NS_EFFECTS, EVENT_EFFECT_CHANGED, function(_eventCode, _changeType, _effectSlot, _effectName, unitTag)
            controller:RefreshEffects()
        end)
        EVENT_MANAGER:AddFilterForEvent(NS_EFFECTS, EVENT_EFFECT_CHANGED,
            REGISTER_FILTER_UNIT_TAG, "reticleover")

        -- Live WYSIWYG player buffs in Move Mode
        EVENT_MANAGER:RegisterForEvent(NS_EFFECTS .. "_Player", EVENT_EFFECT_CHANGED, function(_eventCode, _changeType, _effectSlot, _effectName, unitTag)
            if controller.IsInMoveMode and controller:IsInMoveMode() then
                controller:RefreshEffects()
            end
        end)
        EVENT_MANAGER:AddFilterForEvent(NS_EFFECTS .. "_Player", EVENT_EFFECT_CHANGED,
            REGISTER_FILTER_UNIT_TAG, "player")
    end

    -- ── 5. Disposition & Reaction Updates ─────────────────
    if EVENT_DISPOSITION_UPDATE then
        EVENT_MANAGER:RegisterForEvent(NS_TARGET .. "_Disp", EVENT_DISPOSITION_UPDATE, function(_eventCode, unitTag)
            if not unitTag or unitTag == "" or unitTag == "reticleover" or (AreUnitsEqual and DoesUnitExist and DoesUnitExist("reticleover") and DoesUnitExist(unitTag) and AreUnitsEqual(unitTag, "reticleover")) then
                controller:RefreshIdentity()
            end
        end)
    end
    if EVENT_UNIT_COMBAT_STATE_CHANGED then
        EVENT_MANAGER:RegisterForEvent(NS_TARGET .. "_Combat", EVENT_UNIT_COMBAT_STATE_CHANGED, function(_eventCode, unitTag, _inCombat)
            if unitTag == "reticleover" or (AreUnitsEqual and DoesUnitExist and DoesUnitExist("reticleover") and unitTag and DoesUnitExist(unitTag) and AreUnitsEqual(unitTag, "reticleover")) then
                controller:RefreshIdentity()
            end
        end)
    end

    MugShot.logger:Info("EventBindings: started")
end

-- ── Timer Control for Buff Countdowns ─────────────────────
function EventBindings:StartEffectTimer()
    if self._timerActive then return end
    self._timerActive = true
    if EVENT_MANAGER and EVENT_MANAGER.RegisterForUpdate and self._controller then
        EVENT_MANAGER:RegisterForUpdate(NS_UPDATE, 250, function()
            if self._controller then
                self._controller:UpdateEffectTimers()
            end
        end)
    end
end

function EventBindings:StopEffectTimer()
    if not self._timerActive then return end
    self._timerActive = false
    if EVENT_MANAGER and EVENT_MANAGER.UnregisterForUpdate then
        EVENT_MANAGER:UnregisterForUpdate(NS_UPDATE)
    end
end

-- ── Stop ──────────────────────────────────────────────────
-- Unregister all event handlers registered by Start().
function EventBindings:Stop()
    self:StopEffectTimer()
    EVENT_MANAGER:UnregisterForEvent(NS_TARGET, EVENT_RETICLE_TARGET_CHANGED)
    EVENT_MANAGER:UnregisterForEvent(NS_VITALS, EVENT_POWER_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(NS_VITALS .. "_Player", EVENT_POWER_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(NS_SHIELD .. "_Add", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED)
    EVENT_MANAGER:UnregisterForEvent(NS_SHIELD .. "_Player_Add", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED)
    EVENT_MANAGER:UnregisterForEvent(NS_SHIELD .. "_Upd", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED)
    EVENT_MANAGER:UnregisterForEvent(NS_SHIELD .. "_Player_Upd", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED)
    EVENT_MANAGER:UnregisterForEvent(NS_SHIELD .. "_Rem", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED)
    EVENT_MANAGER:UnregisterForEvent(NS_SHIELD .. "_Player_Rem", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED)
    EVENT_MANAGER:UnregisterForEvent(NS_EFFECTS, EVENT_EFFECT_CHANGED)
    EVENT_MANAGER:UnregisterForEvent(NS_EFFECTS .. "_Player", EVENT_EFFECT_CHANGED)
    if EVENT_DISPOSITION_UPDATE then
        EVENT_MANAGER:UnregisterForEvent(NS_TARGET .. "_Disp", EVENT_DISPOSITION_UPDATE)
    end
    if EVENT_UNIT_COMBAT_STATE_CHANGED then
        EVENT_MANAGER:UnregisterForEvent(NS_TARGET .. "_Combat", EVENT_UNIT_COMBAT_STATE_CHANGED)
    end
    self._controller = nil
    MugShot.logger:Info("EventBindings: stopped")
end

MugShot.EventBindings = EventBindings
MugShot.logger:Info("=== EventBindings loaded ===")
