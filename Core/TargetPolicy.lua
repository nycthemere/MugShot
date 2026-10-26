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
    return state.exists == true
end

MugShot.TargetPolicy = TargetPolicy
MugShot.logger:Info("=== TargetPolicy loaded ===")
