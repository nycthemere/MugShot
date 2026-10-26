-- =========================================================
-- MugShot - TargetFrameView  (UI/TargetFrameView.lua)
-- Creates and manages the custom target frame UI.
-- Faithfully modeled on TargetFrame / targetframe.png.
-- =========================================================

local TargetFrameView = {}
TargetFrameView.__index = TargetFrameView

local Style = MugShot.Style

-- ── Constructor ───────────────────────────────────────────
function TargetFrameView.New()
    local self = setmetatable({}, TargetFrameView)
    self:_Build()
    return self
end

-- ── _Build ────────────────────────────────────────────────
function TargetFrameView:_Build()
    local wm = WINDOW_MANAGER

    -- ── Root Frame ────────────────────────────────────────
    local frame = (wm and wm.CreateTopLevelWindow and wm:CreateTopLevelWindow("MugShot_TargetFrame"))
               or (CreateTopLevelWindow and CreateTopLevelWindow("MugShot_TargetFrame"))
               or CreateControl("MugShot_TargetFrame", GuiRoot, CT_TOPLEVELCONTROL or CT_CONTROL)

    frame:SetDimensions(Style.FRAME_WIDTH, Style.FRAME_HEIGHT + Style.EFFECT_SLOT_SIZE + 6)
    frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 100, 200)
    frame:SetMovable(true)
    frame:SetMouseEnabled(true)
    frame:SetClampedToScreen(true)
    frame:SetHidden(true)

    -- ── Main Bar Container (Health & Shield) ──────────────
    local barContainer = CreateControl("MugShot_BarContainer", frame, CT_CONTROL)
    barContainer:SetDimensions(Style.BAR_WIDTH, Style.BAR_HEIGHT)
    barContainer:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    barContainer:SetMouseEnabled(true)

    -- Bar background (dark unfilled portion + border)
    local barBg = wm:CreateControlFromVirtual("MugShot_BarBG", barContainer, "ZO_DefaultBackdrop")
    if not barBg then
        barBg = CreateControl("MugShot_BarBG", barContainer, CT_BACKDROP)
        if barBg.SetCenterTexture then
            barBg:SetCenterTexture("/esoui/art/chatwindow/chat_bg_center.dds")
        end
        if barBg.SetEdgeTexture then
            barBg:SetEdgeTexture("/esoui/art/chatwindow/chat_bg_edge.dds", 256, 128, 16)
        end
    end
    barBg:ClearAnchors()
    barBg:SetAnchorFill(barContainer)
    barBg:SetCenterColor(0.08, 0.08, 0.08, 0.92)
    barBg:SetEdgeColor(0.0, 0.0, 0.0, 1.0)
    barBg:SetMouseEnabled(true)

    -- Health bar (full-bleed inside barContainer)
    local healthBar = CreateControl("MugShot_HealthBar", barContainer, CT_STATUSBAR)
    healthBar:SetAnchor(TOPLEFT, barContainer, TOPLEFT, 2, 2)
    healthBar:SetAnchor(BOTTOMRIGHT, barContainer, BOTTOMRIGHT, -2, -2)
    healthBar:SetMinMax(0, 1)
    healthBar:SetValue(1)
    if healthBar.SetTexture then
        healthBar:SetTexture(Style.BAR_TEXTURE)
    end
    if healthBar.SetOrientation and ORIENTATION_HORIZONTAL then
        healthBar:SetOrientation(ORIENTATION_HORIZONTAL)
    end
    healthBar:SetColor(0.84, 0.0, 0.0, 1.0)
    healthBar:SetMouseEnabled(true)

    -- Damage shield overlay bar (superposed over health bar)
    local shieldBar = CreateControl("MugShot_ShieldBar", barContainer, CT_STATUSBAR)
    shieldBar:SetAnchor(TOPLEFT, barContainer, TOPLEFT, 2, 2)
    shieldBar:SetAnchor(BOTTOMRIGHT, barContainer, BOTTOMRIGHT, -2, -2)
    shieldBar:SetMinMax(0, 1)
    shieldBar:SetValue(0)
    if shieldBar.SetTexture then
        shieldBar:SetTexture(Style.BAR_TEXTURE)
    end
    if shieldBar.SetOrientation and ORIENTATION_HORIZONTAL then
        shieldBar:SetOrientation(ORIENTATION_HORIZONTAL)
    end
    local sc = Style.SHIELD_COLOR
    shieldBar:SetColor(sc.r, sc.g, sc.b, sc.a)
    shieldBar:SetHidden(true)
    shieldBar:SetMouseEnabled(true)

    -- Percentage label: TOP-LEFT of bar (e.g. "70%", "100%")
    local percentageLabel = CreateControl("MugShot_PercentageLabel", barContainer, CT_LABEL)
    percentageLabel:SetAnchor(TOPLEFT, barContainer, TOPLEFT, 8, 4)
    percentageLabel:SetFont(Style.FONT_PERCENTAGE)
    percentageLabel:SetColor(1, 1, 1, 1)
    percentageLabel:SetText("")
    percentageLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    percentageLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)

    -- Health text label: BOTTOM-LEFT of bar (e.g. "2.1M/3M", "24.3K/24.3K [3.6K]")
    local healthLabel = CreateControl("MugShot_HealthLabel", barContainer, CT_LABEL)
    healthLabel:SetAnchor(BOTTOMLEFT, barContainer, BOTTOMLEFT, 8, -4)
    healthLabel:SetFont(Style.FONT_HEALTH)
    healthLabel:SetColor(1, 1, 1, 1)
    healthLabel:SetText("")
    healthLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    healthLabel:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)

    -- Target name label: TOP-RIGHT of bar (e.g. "Target Skeleton, Humanoid", "@cpcharles")
    local targetNameLabel = CreateControl("MugShot_TargetNameLabel", barContainer, CT_LABEL)
    targetNameLabel:SetAnchor(TOPRIGHT, barContainer, TOPRIGHT, -8, 4)
    targetNameLabel:SetAnchor(TOPLEFT, barContainer, TOPLEFT, 70, 4)
    targetNameLabel:SetFont(Style.FONT_NAME)
    targetNameLabel:SetColor(1, 1, 1, 1)
    targetNameLabel:SetText("")
    targetNameLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    targetNameLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)

    -- ── Portrait Box (MugShot!) on the right ──────────────
    local portraitBg = wm:CreateControlFromVirtual("MugShot_PortraitBG", frame, "ZO_DefaultBackdrop")
    if not portraitBg then
        portraitBg = CreateControl("MugShot_PortraitBG", frame, CT_BACKDROP)
        if portraitBg.SetCenterTexture then
            portraitBg:SetCenterTexture("/esoui/art/chatwindow/chat_bg_center.dds")
        end
    end
    -- ZO_DefaultBackdrop inherits AnchorFill (2 anchors); clear them first before repositioning!
    portraitBg:ClearAnchors()
    portraitBg:SetDimensions(Style.PORTRAIT_BG_SIZE, Style.PORTRAIT_BG_SIZE)
    portraitBg:SetAnchor(LEFT, barContainer, RIGHT, 2, 0)
    portraitBg:SetCenterColor(0.04, 0.04, 0.04, 1.0)
    portraitBg:SetEdgeColor(0.0, 0.0, 0.0, 1.0)
    portraitBg:SetMouseEnabled(true)

    local portrait = CreateControl("MugShot_Portrait", portraitBg, CT_TEXTURE)
    portrait:SetDimensions(Style.PORTRAIT_SIZE, Style.PORTRAIT_SIZE)
    portrait:SetAnchor(CENTER, portraitBg, CENTER, 0, 0)
    portrait:SetHidden(true)

    -- Race badge on top-right of portrait
    local raceIcon = CreateControl("MugShot_RaceIcon", portraitBg, CT_TEXTURE)
    raceIcon:SetDimensions(30, 30)
    raceIcon:SetAnchor(TOPRIGHT, portraitBg, TOPRIGHT, 6, -6)
    raceIcon:SetHidden(true)

    -- Alliance / Class badge on bottom-right of portrait
    local allianceIcon = CreateControl("MugShot_AllianceIcon", portraitBg, CT_TEXTURE)
    allianceIcon:SetDimensions(30, 30)
    allianceIcon:SetAnchor(BOTTOMRIGHT, portraitBg, BOTTOMRIGHT, 6, 6)
    allianceIcon:SetHidden(true)

    -- ── Buffs / Debuffs Container ─────────────────────────
    local effectContainer = CreateControl("MugShot_EffectContainer", frame, CT_CONTROL)
    effectContainer:SetDimensions(Style.BAR_WIDTH, Style.EFFECT_SLOT_SIZE)
    effectContainer:SetAnchor(TOPLEFT, barContainer, BOTTOMLEFT, 0, 4)
    effectContainer:SetMouseEnabled(true)

    -- Pre-create reusable pool of effect slots
    local effectSlots = {}
    for i = 1, Style.MAX_EFFECTS do
        local slotBg = CreateControl("MugShot_EffectSlot_" .. i, effectContainer, CT_BACKDROP)
        slotBg:SetDimensions(Style.EFFECT_SLOT_SIZE, Style.EFFECT_SLOT_SIZE)
        slotBg:SetAnchor(TOPLEFT, effectContainer, TOPLEFT, (i - 1) * (Style.EFFECT_SLOT_SIZE + Style.EFFECT_GAP), 0)
        if slotBg.SetCenterTexture then
            slotBg:SetCenterTexture("/esoui/art/chatwindow/chat_bg_center.dds")
        end
        if slotBg.SetEdgeTexture then
            slotBg:SetEdgeTexture("/esoui/art/chatwindow/chat_bg_edge.dds", 256, 128, 4)
        end
        slotBg:SetCenterColor(0.05, 0.05, 0.05, 0.85)
        slotBg:SetEdgeColor(0.0, 0.0, 0.0, 1.0)
        slotBg:SetHidden(true)

        local slotIcon = CreateControl("MugShot_EffectIcon_" .. i, slotBg, CT_TEXTURE)
        slotIcon:SetDimensions(Style.EFFECT_ICON_SIZE, Style.EFFECT_ICON_SIZE)
        slotIcon:SetAnchor(CENTER, slotBg, CENTER, 0, 0)

        local timerLabel = CreateControl("MugShot_EffectTimer_" .. i, slotIcon, CT_LABEL)
        timerLabel:SetAnchor(CENTER, slotIcon, CENTER, 0, 0)
        timerLabel:SetFont(Style.FONT_TIMER)
        timerLabel:SetColor(1, 1, 1, 1)
        timerLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        timerLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

        local stackLabel = CreateControl("MugShot_EffectStack_" .. i, slotIcon, CT_LABEL)
        stackLabel:SetAnchor(TOPRIGHT, slotIcon, TOPRIGHT, 2, -2)
        stackLabel:SetFont(Style.FONT_STACK)
        stackLabel:SetColor(1, 1, 1, 1)
        stackLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        stackLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)

        effectSlots[i] = {
            bg         = slotBg,
            icon       = slotIcon,
            timerLabel = timerLabel,
            stackLabel = stackLabel,
        }
    end

    -- ── Drag Handlers ─────────────────────────────────────
    local function OnDragStart(ctrl, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and not MugShot.settings:Get().locked then
            frame:StartMoving()
        end
    end

    local function OnDragStop(ctrl, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            frame:StopMovingOrResizing()
            local isValid, point, relativeTo, relativePoint, offsetX, offsetY = frame:GetAnchor(0)
            if isValid then
                MugShot.settings:Set("position", {
                    point         = point,
                    relativePoint = relativePoint,
                    offsetX       = math.floor(offsetX + 0.5),
                    offsetY       = math.floor(offsetY + 0.5),
                })
            end
        end
    end

    local dragTargets = { frame, barContainer, barBg, healthBar, shieldBar, portraitBg, effectContainer }
    for _, ctrl in ipairs(dragTargets) do
        ctrl:SetHandler("OnMouseDown", OnDragStart)
        ctrl:SetHandler("OnMouseUp", OnDragStop)
    end

    -- ── Scene Manager Integration ─────────────────────────
    self._shouldBeVisible = false
    if ZO_HUDFadeSceneFragment and HUD_SCENE and HUD_UI_SCENE then
        local fragment = ZO_HUDFadeSceneFragment:New(frame)
        fragment:SetConditional(function()
            return self._shouldBeVisible == true
        end)
        HUD_SCENE:AddFragment(fragment)
        HUD_UI_SCENE:AddFragment(fragment)
        self.fragment = fragment
    end

    -- Store references
    self.frame           = frame
    self.barContainer    = barContainer
    self.barBg           = barBg
    self.healthBar       = healthBar
    self.shieldBar       = shieldBar
    self.percentageLabel = percentageLabel
    self.healthLabel     = healthLabel
    self.targetNameLabel = targetNameLabel
    self.portraitBg      = portraitBg
    self.portrait        = portrait
    self.raceIcon        = raceIcon
    self.allianceIcon    = allianceIcon
    self.effectSlots     = effectSlots
end

-- ── SetIdentity ───────────────────────────────────────────
-- @param  pres  table from Presentation.BuildIdentity()
function TargetFrameView:SetIdentity(pres)
    self.targetNameLabel:SetText(pres.displayName or "")

    -- Reaction color on health bar & darker shade for background
    local r = pres.r or 0.8
    local g = pres.g or 0.8
    local b = pres.b or 0.8
    self.healthBar:SetColor(r, g, b, 1.0)
    self.barBg:SetCenterColor(r * 0.22, g * 0.22, b * 0.22, 0.92)

    -- Portrait display
    if pres.portraitTexture and pres.portraitTexture ~= "" then
        self.portrait:SetTexture(pres.portraitTexture)
        self.portrait:SetHidden(false)
        self.portraitBg:SetHidden(false)
    else
        self.portrait:SetHidden(true)
        self.portraitBg:SetHidden(false) -- Keep box for visual consistency
    end

    -- Race badge
    if pres.raceIcon and pres.raceIcon ~= "" then
        self.raceIcon:SetTexture(pres.raceIcon)
        self.raceIcon:SetHidden(false)
    else
        self.raceIcon:SetHidden(true)
    end

    -- Alliance badge
    if pres.allianceIcon and pres.allianceIcon ~= "" then
        self.allianceIcon:SetTexture(pres.allianceIcon)
        if pres.allianceColor then
            self.allianceIcon:SetColor(unpack(pres.allianceColor))
        else
            self.allianceIcon:SetColor(1, 1, 1, 1)
        end
        self.allianceIcon:SetHidden(false)
    else
        self.allianceIcon:SetHidden(true)
    end
end

-- ── SetVitals ─────────────────────────────────────────────
-- @param  pres  table from Presentation.BuildVitals()
function TargetFrameView:SetVitals(pres)
    if pres.healthKnown then
        local pct = pres.healthPercent or 0
        self.healthBar:SetValue(pct)
        self.percentageLabel:SetText(pres.percentText or "")
        self.healthLabel:SetText(pres.healthText or "")

        -- Shield overlay
        local shieldPct = pres.shieldPercent or 0
        if shieldPct > 0 then
            self.shieldBar:SetValue(shieldPct)
            self.shieldBar:SetHidden(false)
        else
            self.shieldBar:SetValue(0)
            self.shieldBar:SetHidden(true)
        end
    else
        self.healthBar:SetValue(0)
        self.shieldBar:SetValue(0)
        self.shieldBar:SetHidden(true)
        self.percentageLabel:SetText("")
        self.healthLabel:SetText("")
    end
end

-- ── SetEffects ────────────────────────────────────────────
-- @param  items  table array from Presentation.BuildEffects()
function TargetFrameView:SetEffects(items)
    items = items or {}
    for i = 1, Style.MAX_EFFECTS do
        local slot = self.effectSlots[i]
        local data = items[i]
        if data then
            slot.icon:SetTexture(data.icon or "")
            slot.timerLabel:SetText(data.timerText or "")
            slot.stackLabel:SetText(data.stackText or "")
            slot.bg:SetHidden(false)
        else
            slot.bg:SetHidden(true)
        end
    end
end

-- ── SetVisible ────────────────────────────────────────────
-- @param  visible  bool
function TargetFrameView:SetVisible(visible)
    self._shouldBeVisible = visible
    if self.fragment then
        self.fragment:Refresh()
    else
        self.frame:SetHidden(not visible)
    end
end

-- ── SetMoveMode ───────────────────────────────────────────
-- Toggles visual feedback (glowing cyan border) for repositioning.
-- @param  enabled  bool
function TargetFrameView:SetMoveMode(enabled)
    if enabled then
        self.barBg:SetEdgeColor(0.2, 0.8, 1.0, 1.0)
        self.portraitBg:SetEdgeColor(0.2, 0.8, 1.0, 1.0)
    else
        self.barBg:SetEdgeColor(0.0, 0.0, 0.0, 1.0)
        self.portraitBg:SetEdgeColor(0.0, 0.0, 0.0, 1.0)
    end
end

-- ── ApplyLayout ───────────────────────────────────────────
-- Applies saved position from settings.
-- @param  settings  table from Settings:Get()
function TargetFrameView:ApplyLayout(settings)
    local pos = settings.position
    if not pos then return end

    self.frame:ClearAnchors()
    self.frame:SetAnchor(
        pos.point         or TOPLEFT,
        GuiRoot,
        pos.relativePoint or TOPLEFT,
        pos.offsetX       or 100,
        pos.offsetY       or 200
    )
end

-- ── Reset ─────────────────────────────────────────────────
-- Clears all displayed data without hiding the frame.
function TargetFrameView:Reset()
    self.percentageLabel:SetText("")
    self.healthLabel:SetText("")
    self.targetNameLabel:SetText("")
    self.healthBar:SetValue(0)
    self.shieldBar:SetValue(0)
    self.shieldBar:SetHidden(true)
    self.portrait:SetHidden(true)
    self.raceIcon:SetHidden(true)
    self.allianceIcon:SetHidden(true)
    self:SetEffects({})
end

MugShot.TargetFrameView = TargetFrameView
MugShot.logger:Info("=== TargetFrameView loaded ===")
