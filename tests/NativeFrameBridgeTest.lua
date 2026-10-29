-- =========================================================
-- MugShot - NativeFrameBridgeTest  (tests/NativeFrameBridgeTest.lua)
-- =========================================================

local root = (arg and arg[0] and arg[0]:match("(.+)[/\\][^/\\]+$")) or "."
local addonRoot = root .. "/.."

local EsoMock = dofile(root .. "/EsoMock.lua")
EsoMock.Init()

dofile(addonRoot .. "/ESO/NativeFrameBridge.lua")

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

-- ── 1. Standard Hide & Restore Lifecycle ──────────────────
local bridge = MugShot.NativeFrameBridge.New()
check(bridge._foundNativeFrame == false, "Initial foundNativeFrame is false")
check(ZO_TargetUnitFramereticleover:IsHidden() == false, "Native frame initially visible")

bridge:Start()
check(bridge._foundNativeFrame == true, "Start() locates ZO_TargetUnitFramereticleover")

-- Activate replacement (target acquired)
bridge:SetReplacementActive(true)
check(ZO_TargetUnitFramereticleover:IsHidden() == true, "Native frame hidden by MugShot")
check(bridge._wasHiddenByUs == true, "wasHiddenByUs is true")

-- Test PreHook suppression: ESO native code trying to unhide the frame is blocked
ZO_TargetUnitFramereticleover:SetHidden(false)
check(ZO_TargetUnitFramereticleover:IsHidden() == true, "PreHook blocks native code from unhiding frame while replacement is active")

-- Deactivate replacement (target lost)
bridge:SetReplacementActive(false)
check(ZO_TargetUnitFramereticleover:IsHidden() == false, "Native frame restored by MugShot")
check(bridge._wasHiddenByUs == false, "wasHiddenByUs reset to false")

-- ── 2. Interoperability: External addon already hid the frame ─
ZO_TargetUnitFramereticleover:SetHidden(true) -- another addon hid it
bridge:SetReplacementActive(true)
check(bridge._wasHiddenByUs == false, "MugShot respects that another addon hid it")

bridge:SetReplacementActive(false)
check(ZO_TargetUnitFramereticleover:IsHidden() == true, "MugShot does not unhide frame hidden by other addon")

-- ── 3. Stop() cleanup ─────────────────────────────────────
ZO_TargetUnitFramereticleover:SetHidden(false)
bridge:SetReplacementActive(true)
check(ZO_TargetUnitFramereticleover:IsHidden() == true, "Frame hidden before Stop")

bridge:Stop()
check(ZO_TargetUnitFramereticleover:IsHidden() == false, "Stop() restores native frame")
check(bridge._foundNativeFrame == false, "Stop() clears found flag")
check(bridge._nativeFrame == nil, "Stop() clears native frame reference")

-- ── 4. Missing Native Frame Resiliency ────────────────────
ZO_TargetUnitFramereticleover = nil
local brokenBridge = MugShot.NativeFrameBridge.New()
brokenBridge:Start()
check(brokenBridge._foundNativeFrame == false, "Gracefully handles missing native frame")
brokenBridge:SetReplacementActive(true) -- Should not error
brokenBridge:SetReplacementActive(false)
brokenBridge:Stop()
check(true, "Resilient when native frame is absent")

print(string.format("[NativeFrameBridgeTest] %d passed, %d failed", pass, fail))
for _, e in ipairs(errors) do print("  " .. e) end
if fail > 0 then os.exit(1) end
