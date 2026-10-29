-- =========================================================
-- MugShot - TargetFrameViewTest  (tests/TargetFrameViewTest.lua)
-- =========================================================

local root = (arg and arg[0] and arg[0]:match("(.+)[/\\][^/\\]+$")) or "."
local addonRoot = root .. "/.."

local EsoMock = dofile(root .. "/EsoMock.lua")
EsoMock.Init()

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
    displayName     = "Molag Bal",
    r               = 1.0,
    g               = 0.0,
    b               = 0.0,
    portraitTexture = "/esoui/art/icons/achievement_092.dds",
    portraitCoords  = { 0.1, 0.9, 0.2, 0.8 },
    raceIcon        = "/race.dds",
    allianceIcon    = "/alliance.dds",
    allianceColor   = { 0.5, 0.5, 0.5, 1 },
})

check(view.targetNameLabel:GetText() == "Molag Bal", "Target name text displayed")
check(view.healthBar.color[1] == 1.0 and view.healthBar.color[2] == 0.0, "Health bar color set to red")
check(view.portrait:GetTexture() == "/esoui/art/icons/achievement_092.dds", "Portrait texture set")
check(view.portrait.textureCoords[1] == 0.1, "Portrait UV coords unpacked")
check(view.portrait:IsHidden() == false, "Portrait is visible")
check(view.raceIcon:GetTexture() == "/race.dds", "Race badge texture set")
check(view.raceIcon:IsHidden() == false, "Race badge is visible")
check(view.allianceIcon:GetTexture() == "/alliance.dds", "Alliance badge texture set")
check(view.allianceIcon:IsHidden() == false, "Alliance badge is visible")
check(view.barContainer.width == MugShot.Style.BAR_BG_WIDTH, "Bar container standard width with portrait")
check(view.portraitBg:IsHidden() == false, "Portrait BG visible when portrait present")

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

print(string.format("[TargetFrameViewTest] %d passed, %d failed", pass, fail))
for _, e in ipairs(errors) do print("  " .. e) end
if fail > 0 then os.exit(1) end
