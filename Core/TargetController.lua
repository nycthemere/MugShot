-- =========================================================
-- MugShot - TargetController  (Core/TargetController.lua)
-- Orchestrates the full data → display pipeline:
--
--   ESO events
--     └→ TargetController
--          ├→ EsoAdapter      (read raw identity, vitals, shield, effects)
--          ├→ TargetState     (store raw data)
--          ├→ TargetPolicy    (should we display?)
--          ├→ Presentation    (transform to display tables)
--          ├→ TargetFrameView (render)
--          └→ NativeFrameBridge (hide/show native frame)
-- =========================================================

local TargetController = {}
TargetController.__index = TargetController

-- ── Constructor ───────────────────────────────────────────
function TargetController.New(deps)
    local self = setmetatable({}, TargetController)
    self._state         = deps.state
    self._adapter       = deps.adapter
    self._eventBindings = deps.eventBindings
    self._nativeBridge  = deps.nativeBridge
    self._view          = deps.view
    self._settings      = deps.settings
    self._inMoveMode    = false
    self._inDebugMode   = false
    return self
end

-- ── Start ─────────────────────────────────────────────────
function TargetController:Start()
    self._nativeBridge:Start()
    self._eventBindings:Start(self)
    self:RefreshTarget()
    MugShot.logger:Info("TargetController: started")
end

-- ── Stop ──────────────────────────────────────────────────
function TargetController:Stop()
    self._eventBindings:Stop()
    self._view:SetVisible(false)
    self._nativeBridge:Stop()
    MugShot.logger:Info("TargetController: stopped")
end

-- ── ApplySettings ─────────────────────────────────────────
function TargetController:ApplySettings(settings)
    self._view:ApplyLayout(settings)
end

-- ── SetMoveMode ───────────────────────────────────────────
function TargetController:SetMoveMode(active)
    self._inMoveMode = active
    local state = self._state

    if active then
        if self._view.SetMoveMode then
            self._view:SetMoveMode(true)
        end

        state:ResetForTargetChange()
        state.exists  = true
        state.unitTag = "player"

        local playerTag = "player"
        local settings  = self._settings:Get()

        -- Read live player data via adapter
        local id      = (self._adapter.ReadIdentity and self._adapter:ReadIdentity(playerTag)) or {}
        local vitals  = (self._adapter.ReadVitals and self._adapter:ReadVitals(playerTag)) or {}
        local effects = (self._adapter.ReadEffects and self._adapter:ReadEffects(playerTag)) or {}

        -- Prefer character name for player preview
        local playerName = (id.name and id.name ~= "" and id.name)
            or (id.displayName and id.displayName ~= "" and id.displayName)
            or (GetUnitName and GetUnitName(playerTag))
            or (MugShot.GetText and MugShot.GetText("DRAG_ME_TITLE"))
            or "[MugShot] Déplacez-moi !"
        id.displayName = playerName

        state.identity = id
        state.vitals   = vitals
        state.effects  = effects

        local idPres     = MugShot.Presentation.BuildIdentity(state, settings)
        local vitalsPres = MugShot.Presentation.BuildVitals(state, settings)
        local effPres    = MugShot.Presentation.BuildEffects(state, settings)

        -- Fallback portrait if missing or dummy/question mark
        if not idPres.portraitTexture or idPres.portraitTexture == ""
           or (type(idPres.portraitTexture) == "string" and (idPres.portraitTexture:find("campaignbrowser_guestcampaign", 1, true) or idPres.portraitTexture:find("icon_missing", 1, true))) then
            idPres.portraitTexture = (id and id.classIcon and id.classIcon ~= "" and id.classIcon) or "/esoui/art/icons/class/gamepad/gp_class_dragonknight.dds"
        end

        -- Fallback vitals if player health could not be read
        if not vitalsPres.healthKnown or not vitalsPres.healthText or vitalsPres.healthText == "" then
            vitalsPres = {
                healthKnown   = true,
                percentText   = "100%",
                healthText    = "100k/100k",
                healthPercent = 1.0,
                shieldPercent = 0.0,
                shield        = 0,
            }
        end

        -- If player has no active buffs, display preview sample icons so row position is visible
        if #effPres == 0 then
            effPres = {
                { icon = "/esoui/art/icons/ability_warrior_001.dds", timerText = "15", stackText = "3" },
                { icon = "/esoui/art/icons/ability_rogue_012.dds",   timerText = "7",  stackText = "" },
                { icon = "/esoui/art/icons/ability_mage_002.dds",    timerText = "",   stackText = "" },
            }
        end

        self._view:SetIdentity(idPres)
        self._view:SetVitals(vitalsPres)
        self._view:SetEffects(effPres)
        self._view:SetVisible(true)

        -- Start live countdown timers for any active buffs with remaining duration
        local hasTimers = false
        for _, eff in ipairs(effects) do
            if eff.timer and eff.timer > 0 then
                hasTimers = true
                break
            end
        end
        if hasTimers and self._eventBindings.StartEffectTimer then
            self._eventBindings:StartEffectTimer()
        elseif self._eventBindings.StopEffectTimer then
            self._eventBindings:StopEffectTimer()
        end
    else
        if self._view.SetMoveMode then
            self._view:SetMoveMode(false)
        end
        state.unitTag = "reticleover"
        self:RefreshTarget()
    end
end

-- ── IsInMoveMode ──────────────────────────────────────────
function TargetController:IsInMoveMode()
    return self._inMoveMode == true
end

-- ── SetDebugMode ──────────────────────────────────────────
-- Shows realistic dummy target matching targetframe.png
function TargetController:SetDebugMode(active)
    self._inDebugMode = active
    if active then
        self._view:SetIdentity({
            displayName     = "Target Skeleton, Humanoid",
            r               = 0.84,
            g               = 0.00,
            b               = 0.00,
            portraitTexture = "/esoui/art/icons/event_witchfest_sacking_skelet.dds",
            raceIcon        = nil,
            allianceIcon    = nil,
        })
        self._view:SetVitals({
            healthKnown   = true,
            percentText   = "70%",
            healthText    = "2.1m/3m",
            healthPercent = 0.70,
            shieldPercent = 0.0,
            shield        = 0,
        })
        self._view:SetEffects({
            { icon = "/esoui/art/icons/ability_debuff_stumble.dds", timerText = "2", stackText = "" },
            { icon = "/esoui/art/icons/ability_debuff_vulnerable.dds", timerText = "3", stackText = "2" },
            { icon = "/esoui/art/icons/ability_debuff_offbalance.dds", timerText = "15", stackText = "" },
        })
        self._view:SetVisible(true)
    else
        self:RefreshTarget()
    end
end

-- ── RefreshTarget ─────────────────────────────────────────
function TargetController:RefreshTarget()
    if self._inMoveMode or self._inDebugMode then
        return
    end

    local state    = self._state
    local settings = self._settings:Get()

    state:ResetForTargetChange()

    local unitTag = state.unitTag   -- "reticleover"

    if not DoesUnitExist(unitTag) then
        if self._eventBindings.StopEffectTimer then
            self._eventBindings:StopEffectTimer()
        end
        self._view:SetVisible(false)
        self._view:Reset()
        self._nativeBridge:SetReplacementActive(false)
        MugShot.logger:Debug("RefreshTarget: no target")
        return
    end

    state.exists = true

    local id      = self._adapter:ReadIdentity(unitTag)
    local vitals  = self._adapter:ReadVitals(unitTag)
    local effects = self._adapter:ReadEffects(unitTag)

    state.identity = id
    state.vitals   = vitals
    state.effects  = effects

    if not MugShot.TargetPolicy.ShouldDisplay(state, settings) then
        if self._eventBindings.StopEffectTimer then
            self._eventBindings:StopEffectTimer()
        end
        self._view:SetVisible(false)
        self._view:Reset()
        self._nativeBridge:SetReplacementActive(false)
        return
    end

    local idPres     = MugShot.Presentation.BuildIdentity(state, settings)
    local vitalsPres = MugShot.Presentation.BuildVitals(state, settings)
    local effPres    = MugShot.Presentation.BuildEffects(state, settings)

    self._view:SetIdentity(idPres)
    self._view:SetVitals(vitalsPres)
    self._view:SetEffects(effPres)
    self._view:SetVisible(true)
    self._nativeBridge:SetReplacementActive(true)

    -- Check if any effects have timers needing update
    local hasTimers = false
    for _, eff in ipairs(effects) do
        if eff.timer and eff.timer > 0 then
            hasTimers = true
            break
        end
    end
    if hasTimers and self._eventBindings.StartEffectTimer then
        self._eventBindings:StartEffectTimer()
    elseif self._eventBindings.StopEffectTimer then
        self._eventBindings:StopEffectTimer()
    end

    MugShot.logger:Debug("RefreshTarget: target=%s exists=true", state.identity.name or "?")
end

-- ── RefreshVitals ─────────────────────────────────────────
function TargetController:RefreshVitals(cur, max, _effectiveMax)
    if self._inDebugMode then
        return
    end

    local state = self._state
    if not state.exists then return end

    state.vitals.healthKnown   = true
    state.vitals.currentHealth = cur
    state.vitals.maxHealth     = max

    -- Re-check shield along with health
    local vitals = self._adapter:ReadVitals(state.unitTag)
    state.vitals.shield = vitals.shield

    -- Dynamically update identity/reaction if changed (e.g. neutral -> hostile upon hit)
    if not self._inMoveMode then
        self:RefreshIdentity()
    end

    local settings = self._settings:Get()
    local vitalsPres = MugShot.Presentation.BuildVitals(state, settings)
    self._view:SetVitals(vitalsPres)
end

-- ── RefreshIdentity ───────────────────────────────────────
function TargetController:RefreshIdentity(force)
    if self._inMoveMode then
        self:RefreshMoveModeIdentity()
        return
    end
    if self._inDebugMode then return end
    local state = self._state
    if not state.exists then return end

    local id = self._adapter:ReadIdentity(state.unitTag)
    if not id then return end

    if force or not state.identity or id.reaction ~= state.identity.reaction or id.name ~= state.identity.name then
        state.identity = id
        local settings = self._settings:Get()
        local idPres = MugShot.Presentation.BuildIdentity(state, settings)
        self._view:SetIdentity(idPres)
    end
end

-- ── RefreshMoveModeIdentity ───────────────────────────────
function TargetController:RefreshMoveModeIdentity()
    if not self._inMoveMode then return end
    local state = self._state
    local settings = self._settings:Get()

    local id = (self._adapter.ReadIdentity and self._adapter:ReadIdentity("player")) or {}
    local playerName = (id.name and id.name ~= "" and id.name)
        or (id.displayName and id.displayName ~= "" and id.displayName)
        or (GetUnitName and GetUnitName("player"))
        or (MugShot.GetText and MugShot.GetText("DRAG_ME_TITLE"))
        or "[MugShot] Déplacez-moi !"
    id.displayName = playerName

    state.identity = id
    local idPres = MugShot.Presentation.BuildIdentity(state, settings)

    if not idPres.portraitTexture or idPres.portraitTexture == "" then
        idPres.portraitTexture = "/esoui/art/icons/class/gamepad/gp_class_dragonknight.dds"
    end

    self._view:SetIdentity(idPres)
end

-- ── RefreshShield ─────────────────────────────────────────
function TargetController:RefreshShield()
    if self._inDebugMode then return end
    local state = self._state
    if not state.exists then return end

    local vitals = self._adapter:ReadVitals(state.unitTag)
    state.vitals.shield = vitals.shield

    local settings   = self._settings:Get()
    local vitalsPres = MugShot.Presentation.BuildVitals(state, settings)
    self._view:SetVitals(vitalsPres)
end

-- ── RefreshEffects ────────────────────────────────────────
function TargetController:RefreshEffects()
    if self._inDebugMode then return end
    local state = self._state
    if not state.exists then return end

    local effects = self._adapter:ReadEffects(state.unitTag)
    state.effects = effects

    local settings = self._settings:Get()
    local effPres  = MugShot.Presentation.BuildEffects(state, settings)

    -- In move mode, if 0 buffs, preserve sample icons
    if self._inMoveMode and #effPres == 0 then
        effPres = {
            { icon = "/esoui/art/icons/ability_warrior_001.dds", timerText = "15", stackText = "3" },
            { icon = "/esoui/art/icons/ability_rogue_012.dds",   timerText = "7",  stackText = "" },
            { icon = "/esoui/art/icons/ability_mage_002.dds",    timerText = "",   stackText = "" },
        }
    end

    self._view:SetEffects(effPres)

    local hasTimers = false
    for _, eff in ipairs(effects) do
        if eff.timer and eff.timer > 0 then
            hasTimers = true
            break
        end
    end
    if hasTimers and self._eventBindings.StartEffectTimer then
        self._eventBindings:StartEffectTimer()
    elseif not self._inMoveMode and self._eventBindings.StopEffectTimer then
        self._eventBindings:StopEffectTimer()
    end
end

-- ── UpdateEffectTimers ────────────────────────────────────
-- Called every 250ms by the update timer to decrement timers
function TargetController:UpdateEffectTimers()
    if self._inDebugMode then return end
    local state = self._state
    if not state.exists or #state.effects == 0 then return end

    local now = (GetGameTimeSeconds and GetGameTimeSeconds()) or 0
    local anyActive = false

    for _, eff in ipairs(state.effects) do
        if eff.timeEnding and eff.timeEnding > 0 then
            local rem = eff.timeEnding - now
            if rem > 0 then
                eff.timer = rem
                anyActive = true
            else
                eff.timer = 0
            end
        end
    end

    local settings = self._settings:Get()
    local effPres  = MugShot.Presentation.BuildEffects(state, settings)

    if self._inMoveMode and #effPres == 0 then
        effPres = {
            { icon = "/esoui/art/icons/ability_warrior_001.dds", timerText = "15", stackText = "3" },
            { icon = "/esoui/art/icons/ability_rogue_012.dds",   timerText = "7",  stackText = "" },
            { icon = "/esoui/art/icons/ability_mage_002.dds",    timerText = "",   stackText = "" },
        }
    end

    self._view:SetEffects(effPres)

    if not anyActive and not self._inMoveMode and self._eventBindings.StopEffectTimer then
        self._eventBindings:StopEffectTimer()
    end
end

MugShot.TargetController = TargetController
MugShot.logger:Info("=== TargetController loaded ===")
