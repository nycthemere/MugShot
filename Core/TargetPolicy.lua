-- =========================================================
-- MugShot - TargetPolicy  (Core/TargetPolicy.lua)
-- Determines whether the custom frame should be displayed
-- for the current TargetState: show whenever a target exists,
-- regardless of reaction type.
-- =========================================================

local TargetPolicy = {}

-- ── ShouldDisplay ─────────────────────────────────────────
-- @param  state     MugShot.TargetState instance
-- @param  settings  table returned by MugShot.Settings:Get()
-- @return bool      true → show the frame, false → hide it
function TargetPolicy.ShouldDisplay(state, _settings)
    if not state or state.exists ~= true then
        return false
    end
    -- Hide frame if target is dead
    if state.vitals and state.vitals.isDead == true then
        return false
    end
    return true
end

MugShot.TargetPolicy = TargetPolicy
MugShot.logger:Info("=== TargetPolicy loaded ===")
