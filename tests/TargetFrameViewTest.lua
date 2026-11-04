-- =========================================================
-- MugShot - TargetFrameViewTest  (tests/TargetFrameViewTest.lua)
-- =========================================================

local root = (arg and arg[0] and arg[0]:match("(.+)[/\\][^/\\]+$")) or "."
local addonRoot = root .. "/.."

local EsoMock = dofile(root .. "/EsoMock.lua")
EsoMock.Init()

dofile(addonRoot .. "/Constants.lua")
dofile(addonRoot .. "/UI/Style.lua")
dofile(addonRoot .. "/UI/TargetFrameView.lua")

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

-- ── 1. Construction and Control Hierarchy ─────────────────
local view = MugShot.TargetFrameView.New()

check(view.frame ~= nil, "Root frame created")
check(view.frame:IsHidden() == true, "Frame initially hidden")
check(view.healthBar ~= nil, "HealthBar created")
check(view.shieldBar ~= nil, "ShieldBar created")
check(view.shieldBar:IsHidden() == true, "ShieldBar initially hidden")
check(view.portrait ~= nil, "Portrait texture created")
check(view.raceIcon ~= nil, "RaceIcon created")
check(view.allianceIcon ~= nil, "AllianceIcon created")
check(#view.effectSlots == MugShot.Style.MAX_EFFECTS, "MAX_EFFECTS slots pre-allocated")
check(view.fragment ~= nil, "HUD Fade Scene Fragment attached")

-- ── 2. SetIdentity Presentation ───────────────────────────
view:SetIdentity({
    displayName     = "@ArkayHealer",
    isPlayer        = true,
    r               = 0.0,
    g               = 1.0,
    b               = 0.0,
    portraitTexture = "/esoui/art/icons/achievement_092.dds",
    portraitCoords  = { 0.1, 0.9, 0.2, 0.8 },
    raceIcon        = "/race.dds",
    allianceIcon    = "/alliance.dds",
    allianceColor   = { 0.5, 0.5, 0.5, 1 },
})

check(view.targetNameLabel:GetText() == "@ArkayHealer", "Target name text displayed")
check(view.healthBar.color[1] == 0.0 and view.healthBar.color[2] == 1.0, "Health bar color set to green")
check(view.portrait:GetTexture() == "/esoui/art/icons/achievement_092.dds", "Portrait texture set")
check(view.portrait.textureCoords[1] == 0.1, "Portrait UV coords unpacked")
check(view.portrait:IsHidden() == false, "Portrait is visible")
check(view.portrait.color[1] == 1.0 and view.portrait.color[2] == 1.0 and view.portrait.color[3] == 1.0 and view.portrait.color[4] == 1.0, "Portrait vertex color strictly set to white (1,1,1,1) for full-color rendering")
check(view.raceIcon:GetTexture() == "/race.dds", "Race badge texture set")
check(view.raceIcon:IsHidden() == false, "Race badge is visible for players")
check(view.allianceIcon:GetTexture() == "/alliance.dds", "Alliance badge texture set")
check(view.allianceIcon:IsHidden() == false, "Alliance badge is visible for players")
check(view.barContainer.width == MugShot.Style.BAR_BG_WIDTH, "Bar container standard width with portrait")
check(view.portraitBg:IsHidden() == false, "Portrait BG visible when portrait present")

-- Non-player targets MUST NEVER show race or alliance badges!
view:SetIdentity({
    displayName     = "Molag Bal",
    isPlayer        = false,
    r               = 1.0,
    g               = 0.0,
    b               = 0.0,
    portraitTexture = "/esoui/art/icons/achievement_092.dds",
    raceIcon        = "/race.dds",
    allianceIcon    = "/alliance.dds",
})
check(view.raceIcon:IsHidden() == true, "Race badge strictly hidden on non-player enemies")
check(view.allianceIcon:IsHidden() == true, "Alliance badge strictly hidden on non-player enemies")

-- Fallback for no icon => stretch the bar across the entire frame
view:SetIdentity({
    displayName     = "Critter Without Icon",
    r               = 0.8,
    g               = 0.8,
    b               = 0.8,
    portraitTexture = nil,
})
check(view.portraitBg:IsHidden() == true, "Portrait BG hidden when no portrait")
check(view.portrait:IsHidden() == true, "Portrait hidden when no portrait")
check(view.barContainer.width == MugShot.Style.FRAME_WIDTH, "Bar container stretched to full FRAME_WIDTH (381px)")

-- ── 3. SetVitals Presentation ─────────────────────────────
view:SetVitals({
    healthKnown   = true,
    percentText   = "65%",
    healthText    = "13k/20k [2k]",
    healthPercent = 0.65,
    shieldPercent = 0.10,
    shield        = 2000,
})

check(view.percentageLabel:GetText() == "65%", "Percentage label updated")
check(view.healthLabel:GetText() == "13k/20k [2k]", "Health text label updated")
check(view.shieldBar:IsHidden() == false, "Shield bar shown when shield > 0")

-- When health is unknown
view:SetVitals({ healthKnown = false })
check(view.percentageLabel:GetText() == "", "Percentage label cleared on unknown health")
check(view.shieldBar:IsHidden() == true, "Shield bar hidden on unknown health")

-- ── 4. SetEffects Presentation ────────────────────────────
view:SetEffects({
    { icon = "/icon1.dds", timerText = "12", stackText = "3" },
    { icon = "/icon2.dds", timerText = "",   stackText = "" },
})

check(view.effectSlots[1].bg:IsHidden() == false, "Slot 1 visible")
check(view.effectSlots[1].icon:GetTexture() == "/icon1.dds", "Slot 1 icon set")
check(view.effectSlots[1].timerLabel:GetText() == "12", "Slot 1 timer text set")
check(view.effectSlots[1].stackLabel:GetText() == "3", "Slot 1 stack count set")

-- Dirty Flag Caches
check(view.effectSlots[1]._lastTimerText == "12", "Slot 1 cached _lastTimerText (Dirty Flag)")
check(view.effectSlots[1]._lastStackText == "3", "Slot 1 cached _lastStackText (Dirty Flag)")
check(view.effectSlots[1]._lastIcon == "/icon1.dds", "Slot 1 cached _lastIcon (Dirty Flag)")
check(view.effectSlots[1]._lastHidden == false, "Slot 1 cached _lastHidden (Dirty Flag)")

check(view.effectSlots[2].bg:IsHidden() == false, "Slot 2 visible")
check(view.effectSlots[2].icon:GetTexture() == "/icon2.dds", "Slot 2 icon set")

check(view.effectSlots[3].bg:IsHidden() == true, "Slot 3 hidden (no buff)")

-- Multi-row wrapping test with 15 buffs (> 10 max cap removed)
local manyEffects = {}
for i = 1, 15 do
    table.insert(manyEffects, { icon = "/buff" .. i .. ".dds", timerText = tostring(i), stackText = "" })
end
view:SetEffects(manyEffects)
check(#view.effectSlots >= 15, "Effect slots dynamically expanded beyond 10")
check(view.effectSlots[15].bg:IsHidden() == false, "Slot 15 visible in 2nd row")
check(view.effectSlots[15].icon:GetTexture() == "/buff15.dds", "Slot 15 icon applied")
check(view.effectSlots[15].timerLabel:GetText() == "15", "Slot 15 timer text applied")
check(view.effectContainer.height > MugShot.Style.EFFECT_SLOT_SIZE, "Effect container expanded vertically for 2nd row")

-- ── 5. SetVisible & Scene Fragment ────────────────────────
view:SetVisible(true)
check(view.frame:IsHidden() == false, "SetVisible(true) unhides frame via fragment")

view:SetVisible(false)
check(view.frame:IsHidden() == true, "SetVisible(false) hides frame via fragment")

-- ── 6. SetMoveMode (Cyan border toggle) ───────────────────
view:SetMoveMode(true)
check(view.barBg.edgeColor[1] == 0.2 and view.barBg.edgeColor[2] == 0.8, "Cyan border activated in MoveMode")

view:SetMoveMode(false)
check(view.barBg.edgeColor[1] == 0.0 and view.barBg.edgeColor[2] == 0.0, "Black border restored on MoveMode off")

-- ── 7. ApplyLayout ────────────────────────────────────────
view:ApplyLayout({
    position = { point = TOPLEFT, relativePoint = TOPLEFT, offsetX = 450, offsetY = 600 }
})
local _, _, _, _, offX, offY = view.frame:GetAnchor(0)
check(offX == 450 and offY == 600, "ApplyLayout correctly positioned the frame")

-- ── 8. Reset ──────────────────────────────────────────────
view:Reset()
check(view.targetNameLabel:GetText() == "", "Reset clears target name")
check(view.percentageLabel:GetText() == "", "Reset clears percentage")
check(view.portrait:IsHidden() == true, "Reset hides portrait")
check(view.effectSlots[1].bg:IsHidden() == true, "Reset hides all effect slots")

-- ── 9. Quadrants: Left/Right Swapping on Line 1 & 2 ───────
local Q = MugShot.Constants.QUADRANTS
local V = MugShot.Constants.VALUES

view:ApplyQuadrantLayout({
    [Q.TOP_LEFT]     = V.NAME,
    [Q.TOP_RIGHT]    = V.NONE,
    [Q.BOTTOM_LEFT]  = V.PERCENT,
    [Q.BOTTOM_RIGHT] = V.HEALTH,
})
check(view._currentQuadrants[Q.TOP_LEFT] == V.NAME, "T9: Initial topLeft is NAME")
check(view._currentQuadrants[Q.TOP_RIGHT] == V.NONE, "T9: Initial topRight is NONE")

-- Swap Left and Right on Line 1
view:_OnQuadrantClicked(Q.TOP_LEFT)
check(view._selectedQuadrant == Q.TOP_LEFT, "T9: Selected topLeft quadrant")
view:_OnQuadrantClicked(Q.TOP_RIGHT)
check(view._selectedQuadrant == nil, "T9: Selection cleared after swap")
check(view._currentQuadrants[Q.TOP_LEFT] == V.NONE, "T9: topLeft is now NONE")
check(view._currentQuadrants[Q.TOP_RIGHT] == V.NAME, "T9: topRight is now NAME (Swapped Left/Right)")

-- Swap Left and Right on Line 2
view:_OnQuadrantClicked(Q.BOTTOM_LEFT)
view:_OnQuadrantClicked(Q.BOTTOM_RIGHT)
check(view._currentQuadrants[Q.BOTTOM_LEFT] == V.HEALTH, "T9: bottomLeft is now HEALTH")
check(view._currentQuadrants[Q.BOTTOM_RIGHT] == V.PERCENT, "T9: bottomRight is now PERCENT (Swapped Left/Right)")

-- ── 10. Privileged Debuffs on Line 3 (Paired & Single) ─────
view:SetPrivilegedDebuffs({
    { tag = "CRUSH",  name = "Crusher", isPair = false, timerText = "4s", isActive = true, fromPlayer = true },
    { tag = "BREACH", name = "Breach",  isPair = true,  majorActive = true, minorActive = true, majorTimerText = "18s", minorTimerText = "22s", majorFromPlayer = true, minorFromPlayer = false },
    { tag = "LN-BRK", name = "Line Breaker", isPair = false, timerText = "0s", isActive = false, isGhost = true },
})

check(view.privilegedContainer:IsHidden() == false, "T10: Privileged container shown when debuffs exist")
check(view.privilegedSlots[1].header:GetText() == "CRUSH", "T10: Slot 1 header is CRUSH")
check(view.privilegedSlots[1].singleTimer:GetText() == "4", "T10: Slot 1 single timer is 4")
check(view.privilegedSlots[1].singleTimer.color[1] == 1.0, "T10: Slot 1 single timer is White (fromPlayer = true)")
check(view.privilegedSlots[2].header:GetText() == "BREACH", "T10: Slot 2 header is BREACH")
check(view.privilegedSlots[2].majorBadge:GetText() == "M", "T10: Slot 2 major badge is M")
check(view.privilegedSlots[2].majorTimer:GetText() == "18", "T10: Slot 2 major timer is 18")
check(view.privilegedSlots[2].majorTimer.color[1] == 1.0, "T10: Slot 2 major timer is White (majorFromPlayer = true)")
check(view.privilegedSlots[2].minorBadge:GetText() == "m", "T10: Slot 2 minor badge is m")
check(view.privilegedSlots[2].minorTimer:GetText() == "22", "T10: Slot 2 minor timer is 22")
check(view.privilegedSlots[2].minorTimer.color[1] == MugShot.Style.TEXT_COLOR_CYAN.r, "T10: Slot 2 minor timer is Cyan (minorFromPlayer = false, team cast)")
check(view.privilegedSlots[3].header:GetText() == "LN-BRK", "T10: Slot 3 header is LN-BRK (Ghost)")

-- Test team debuff for single layout (fromPlayer = false -> Cyan)
view:SetPrivilegedDebuffs({
    { tag = "CRUSH", name = "Crusher", isPair = false, timerText = "12s", isActive = true, fromPlayer = false },
})
check(view.privilegedSlots[1].singleTimer.color[1] == MugShot.Style.TEXT_COLOR_CYAN.r, "T10: Slot 1 single timer is Cyan when fromPlayer = false")

-- ── 11. Empty Debuffs on Non-Hostile targets (Neutral / Ally) ───
view:SetPrivilegedDebuffs({})
check(view.privilegedContainer:IsHidden() == true, "T11: Privileged container hidden when debuffs empty")
check(view.barContainer.height == MugShot.Style.BAR_BG_HEIGHT, "T11: Bar container preserves normal 94px height")
check(view.portraitBg.height == MugShot.Style.PORTRAIT_BG_SIZE, "T11: Portrait preserves normal 94px height")

-- ── 12. Move Mode Target Toggle Button ────────────────────
view:SetMoveMode(true, "enemy")
check(view.moveTargetBtn:IsHidden() == false, "T12: Move target button visible in move mode")
check(view.moveTargetBtn:GetText():find("ENNEMI") ~= nil, "T12: Move target button displays ENNEMI for enemy mode")

view:SetMoveMode(true, "player")
check(view.moveTargetBtn:GetText():find("JOUEUR") ~= nil, "T12: Move target button displays JOUEUR for player mode")

view:SetMoveMode(false)
check(view.moveTargetBtn:IsHidden() == true, "T12: Move target button hidden when move mode ends")

-- ── 13. Line Swapping (Lines 1, 2, 3 interchangeable) ──────
view:SetMoveMode(true, "enemy")
view:ApplyQuadrantLayout({
    [Q.LINE1_LEFT]   = V.NAME,
    [Q.LINE1_RIGHT]  = V.NONE,
    [Q.LINE2_LEFT]   = V.PERCENT,
    [Q.LINE2_RIGHT]  = V.HEALTH,
    [Q.LINE3_LEFT]   = V.PRIVILEGED,
    [Q.LINE3_RIGHT]  = V.NONE,
})

-- Swap Line 1 and Line 2
view:SwapLines(1, 2)
check(view._currentQuadrants[Q.LINE1_LEFT] == V.PERCENT, "T13: Line 1 Left is now PERCENT")
check(view._currentQuadrants[Q.LINE1_RIGHT] == V.HEALTH, "T13: Line 1 Right is now HEALTH")
check(view._currentQuadrants[Q.LINE2_LEFT] == V.NAME, "T13: Line 2 Left is now NAME")

-- Swap Line 2 and Line 3
view:SwapLines(2, 3)
check(view._currentQuadrants[Q.LINE2_LEFT] == V.PRIVILEGED, "T13: Line 2 Left is now PRIVILEGED (Line 3 debuffs moved to Line 2)")
check(view._currentQuadrants[Q.LINE3_LEFT] == V.NAME, "T13: Line 3 Left is now NAME")

-- ── 14. Full-Bleed 60px Edge-to-Edge Privileged Debuff Slots ─
for i = 1, 5 do
    check(view.privilegedSlots[i].bg.width == 60, "T14: Slot " .. i .. " width is exactly 60px")
    check(view.privilegedSlots[i].bg.anchors[1].offsetX == (i - 1) * 60, "T14: Slot " .. i .. " x position is exactly " .. ((i - 1) * 60))
end

-- ── 15. Line Swapping Handles ([L1], [L2], [L3]) ───────────
check(view.lineHandles[1] ~= nil, "T15: Line handle 1 exists")
check(view.lineHandles[2] ~= nil, "T15: Line handle 2 exists")
check(view.lineHandles[3] ~= nil, "T15: Line handle 3 exists")
check(view.lineHandles[1]:IsHidden() == false, "T15: Line handle 1 visible in move mode")
view:SetMoveMode(false)
check(view.lineHandles[1]:IsHidden() == true, "T15: Line handle 1 hidden when move mode off")

-- ── 16. Portrait Class Tint and Color Reset ─────────────────
view:SetIdentity({
    portraitTexture = "/esoui/art/icons/class/gamepad/gp_class_sorcerer.dds",
    portraitColor   = { 0.45, 0.55, 1.0, 1.0 },
})
check(view.portrait.color and view.portrait.color[1] == 0.45 and view.portrait.color[2] == 0.55 and view.portrait.color[3] == 1.0, "T16: Portrait is tinted with class color (0.45, 0.55, 1.0)")

view:Reset()
check(view.portrait.color and view.portrait.color[1] == 1.0 and view.portrait.color[2] == 1.0 and view.portrait.color[3] == 1.0, "T16: Portrait color resets to neutral 1.0")

print(string.format("[TargetFrameViewTest] %d passed, %d failed", pass, fail))
if fail > 0 then
    for _, e in ipairs(errors) do print("  " .. e) end
end
if fail > 0 then os.exit(1) end
