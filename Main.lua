-- =========================================================
-- MugShot - Main  (Main.lua)
-- Bootstrap entry point.
-- Assembles all modules on EVENT_ADD_ON_LOADED and registers
-- slash commands for runtime control.
-- =========================================================

local C = MugShot.Constants

-- ── Bootstrap ─────────────────────────────────────────────
-- All assembly happens inside this callback so that ESO has
-- fully initialised SavedVariables and UI controls before
-- we touch them.
local function OnAddonLoaded(_eventCode, addonName)
    if addonName ~= C.ADDON_NAME then return end

    -- Unregister immediately — we only need this once
    EVENT_MANAGER:UnregisterForEvent(C.ADDON_NAME .. "_Load", EVENT_ADD_ON_LOADED)

    MugShot.logger:Info("=== MugShot %s by %s — initialising ===",
        C.ADDON_VERSION, C.AUTHOR)

    -- ── 1. Settings ──────────────────────────────────────
    local settings = MugShot.Settings.New()
    settings:Load()
    MugShot.settings = settings   -- stash for drag-save in TargetFrameView

    -- ── 2. Core objects ───────────────────────────────────
    local state         = MugShot.TargetState.New()
    local adapter       = MugShot.EsoAdapter.New()
    local eventBindings = MugShot.EventBindings.New()
    local nativeBridge  = MugShot.NativeFrameBridge.New()
    local view          = MugShot.TargetFrameView.New()

    -- Apply saved position immediately
    view:ApplyLayout(settings:Get())

    -- ── 3. Controller ─────────────────────────────────────
    local controller = MugShot.TargetController.New({
        state         = state,
        adapter       = adapter,
        eventBindings = eventBindings,
        nativeBridge  = nativeBridge,
        view          = view,
        settings      = settings,
    })

    -- Stash references for slash commands
    MugShot._controller   = controller
    MugShot._view         = view
    MugShot._nativeBridge = nativeBridge

    -- ── 4. Start (if enabled) ─────────────────────────────
    if settings:Get().enabled then
        controller:Start()
    else
        MugShot.logger:Info(MugShot.GetText("DISABLED_HELP"))
    end

    -- ── 5. Slash commands ─────────────────────────────────

    -- /mugshot — toggle enable/disable
    SLASH_COMMANDS["/mugshot"] = function()
        local s = settings:Get()
        local nowEnabled = not s.enabled
        settings:Set("enabled", nowEnabled)

        if nowEnabled then
            controller:Start()
            CHAT_SYSTEM:AddMessage(MugShot.GetText("ENABLED"))
        else
            controller:Stop()
            CHAT_SYSTEM:AddMessage(MugShot.GetText("DISABLED"))
        end
    end

    -- /mugshotmove — toggle frame repositioning mode
    SLASH_COMMANDS["/mugshotmove"] = function()
        local s = settings:Get()
        local nowLocked = not s.locked
        settings:Set("locked", nowLocked)
        controller:SetMoveMode(not nowLocked)

        if nowLocked then
            pcall(function() SetGameCameraUIMode(false) end)
            CHAT_SYSTEM:AddMessage(MugShot.GetText("FRAME_LOCKED"))
        else
            pcall(function() SetGameCameraUIMode(true) end)
            CHAT_SYSTEM:AddMessage(MugShot.GetText("FRAME_UNLOCKED"))
        end
    end

    -- /mugshotdebug — force-show the frame with dummy data so you can
    -- verify position and rendering without needing an actual target.
    -- Toggle: a second call hides it again.
    local _debugShown = false
    SLASH_COMMANDS["/mugshotdebug"] = function()
        _debugShown = not _debugShown
        controller:SetDebugMode(_debugShown)
        if _debugShown then
            local pos = settings:Get().position
            CHAT_SYSTEM:AddMessage(MugShot.GetText(
                "DEBUG_SHOWN",
                tostring(pos and pos.offsetX), tostring(pos and pos.offsetY)))
        else
            CHAT_SYSTEM:AddMessage(MugShot.GetText("DEBUG_HIDDEN"))
        end
    end

    -- /mugshotreset — reset position to default and activate move mode
    SLASH_COMMANDS["/mugshotreset"] = function()
        local defaultPos = {
            point         = TOPLEFT,
            relativePoint = TOPLEFT,
            offsetX       = 100,
            offsetY       = 200,
        }
        settings:Set("position", defaultPos)
        settings:Set("locked", false)
        view:ApplyLayout(settings:Get())
        controller:SetMoveMode(true)
        pcall(function() SetGameCameraUIMode(true) end)
        CHAT_SYSTEM:AddMessage(MugShot.GetText("POSITION_RESET"))
    end

    -- /mugshotstatus — print full diagnostic report in chat
    SLASH_COMMANDS["/mugshotstatus"] = function()
        local s = settings:Get()
        local pos = s.position or {}
        local f = view.frame
        local hasTarget = DoesUnitExist("reticleover")
        local targetName = hasTarget and (GetUnitName("reticleover") or "?") or MugShot.GetText("STATUS_TARGET_NONE")
        local bridgeOk = nativeBridge and nativeBridge._foundNativeFrame

        CHAT_SYSTEM:AddMessage(MugShot.GetText("STATUS_HEADER"))
        CHAT_SYSTEM:AddMessage(MugShot.GetText("STATUS_ENABLED_LOCKED", tostring(s.enabled), tostring(s.locked)))
        CHAT_SYSTEM:AddMessage(MugShot.GetText("STATUS_FRAME_POS",
            tostring(f and f:IsHidden()),
            tostring(pos.offsetX), tostring(pos.offsetY)))
        CHAT_SYSTEM:AddMessage(MugShot.GetText("STATUS_TARGET", tostring(hasTarget), targetName))
        CHAT_SYSTEM:AddMessage(MugShot.GetText("STATUS_NATIVE_HOOKED", tostring(bridgeOk)))
    end

    MugShot.logger:Info("=== MugShot initialisation complete ===")
end

-- Register the load listener (filtered to our addon name for efficiency)
EVENT_MANAGER:RegisterForEvent(
    MugShot.Constants.ADDON_NAME .. "_Load",
    EVENT_ADD_ON_LOADED,
    OnAddonLoaded)
