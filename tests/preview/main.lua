-- =========================================================
-- MugShot - Live Dynamic UI Preview (Love2D)
-- (tests/preview/main.lua)
-- Fully connected to the real MugShot addon engine.
-- Any change in the addon source code immediately hot-reloads
-- and updates the preview in real-time!
-- =========================================================

local LayoutSolver = require("LayoutSolver")

-- ── Project Paths ─────────────────────────────────────────
local previewDir = (love and love.filesystem and love.filesystem.getSource()) or "."
local addonRoot  = previewDir .. "/../.."
package.path     = package.path .. ";" .. addonRoot .. "/?.lua;" .. addonRoot .. "/tests/?.lua"

-- ── Watched Addon Source Files for Hot-Reload ─────────────
local WATCHED_FILES = {
    "Namespace.lua",
    "Defaults.lua",
    "Constants.lua",
    "Localisation.lua",
    "Data/Portraits.lua",
    "Core/TargetState.lua",
    "Core/TargetPolicy.lua",
    "Core/Presentation.lua",
    "ESO/EsoAdapter.lua",
    "UI/Style.lua",
    "UI/TargetFrameView.lua",
    "ESO/NativeFrameBridge.lua",
    "ESO/EventBindings.lua",
    "Core/TargetController.lua",
    "Settings.lua",
    "Main.lua",
}

-- ── Catalog of Sample Buffs for Dynamic Testing ───────────
local BUFF_CATALOG = {
    { name = "Major Vulnerability", iconFilename = "/esoui/art/icons/ability_debuff_vulnerable.dds", duration = 8, stackCount = 2, effectType = 2 },
    { name = "Off Balance",         iconFilename = "/esoui/art/icons/ability_debuff_offbalance.dds", duration = 15, stackCount = 0, effectType = 2 },
    { name = "Stumble",             iconFilename = "/esoui/art/icons/ability_debuff_stumble.dds",    duration = 5, stackCount = 3, effectType = 2 },
    { name = "Major Breach",        iconFilename = "/esoui/art/icons/ability_debuff_minor_breach.dds", duration = 30, stackCount = 0, effectType = 2 },
    { name = "Major Sorcery",       iconFilename = "/esoui/art/icons/ability_buff_major_sorcery.dds", duration = 24, stackCount = 0, effectType = 1 },
    { name = "Major Resolve",       iconFilename = "/esoui/art/icons/ability_buff_major_resolve.dds", duration = 180, stackCount = 0, effectType = 1 }, -- 3m duration
    { name = "Berserk",             iconFilename = "/esoui/art/icons/ability_warrior_001.dds",       duration = 10, stackCount = 5, effectType = 1 },
    { name = "Major Expedition",    iconFilename = "/esoui/art/icons/ability_rogue_012.dds",         duration = 7, stackCount = 0, effectType = 1 },
    { name = "Minor Force",         iconFilename = "/esoui/art/icons/ability_mage_002.dds",          duration = 0, stackCount = 0, effectType = 1 }, -- Permanent
    { name = "Minor Lifesteal",     iconFilename = "/esoui/art/icons/ability_healer_018.dds",        duration = 20, stackCount = 0, effectType = 2 },
    { name = "Minor Maim",          iconFilename = "/esoui/art/icons/ability_debuff_minor_maim.dds", duration = 12, stackCount = 0, effectType = 2 },
    { name = "Long Blessing",       iconFilename = "/esoui/art/icons/ability_buff_minor_resolve.dds", duration = 3600, stackCount = 0, effectType = 1 }, -- 1h duration
}

-- ── Runtime State ─────────────────────────────────────────
local EsoMock = nil
local frameRoot = nil
local currentScenario = 1
local shieldActive = true
local isDead = false
local liveHealthFraction = nil
local hotReloadBannerTimer = 0
local hudNotification = nil
local hudNotificationTimer = 0
local fileFingerprints = {}
local watchTimer = 0
local nextCatalogIdx = 1

-- Drag position
local isDragging = false
local dragOffsetX = 0
local dragOffsetY = 0
local framePosX = 420
local framePosY = 220

-- Fonts
local fontMain  = nil
local fontSmall = nil
local fontTitle = nil

-- ── Raw ESO Scenarios ─────────────────────────────────────
local SCENARIOS = {
    {
        id = 1,
        title = "Trial Boss: Oaxiltso",
        name = "Oaxiltso",
        reaction = 1, -- UNIT_REACTION_HOSTILE
        currentHealth = 2100000,
        maxHealth = 3000000,
        baseShield = 250000,
        buffs = {
            { name = "Major Vulnerability", iconFilename = "/esoui/art/icons/ability_debuff_vulnerable.dds", duration = 8, stackCount = 2, effectType = 2 },
            { name = "Off Balance",         iconFilename = "/esoui/art/icons/ability_debuff_offbalance.dds", duration = 15, stackCount = 0, effectType = 2 },
            { name = "Stumble",             iconFilename = "/esoui/art/icons/ability_debuff_stumble.dds",    duration = 5, stackCount = 0, effectType = 2 },
        }
    },
    {
        id = 2,
        title = "Companion: Bastian Hallix",
        name = "Bastian Hallix",
        reaction = 5, -- UNIT_REACTION_NPC_ALLY
        currentHealth = 32400,
        maxHealth = 32400,
        baseShield = 0,
        raceId = 1,
        allianceId = 1,
        buffs = {
            { name = "Major Sorcery", iconFilename = "/esoui/art/icons/ability_buff_major_sorcery.dds", duration = 24, stackCount = 0, effectType = 1 },
            { name = "Major Resolve", iconFilename = "/esoui/art/icons/ability_buff_major_resolve.dds", duration = 180, stackCount = 0, effectType = 1 },
        }
    },
    {
        id = 3,
        title = "Sorcerer Pet: Summon Unstable Familiar",
        name = "Summon Unstable Familiar",
        reaction = 4, -- UNIT_REACTION_PLAYER_ALLY
        currentHealth = 18200,
        maxHealth = 21400,
        baseShield = 0,
        buffs = {
            { name = "Unstable Familiar", iconFilename = "/esoui/art/icons/ability_sorcerer_unstable_fimiliar_summoned.dds", duration = 12, stackCount = 0, effectType = 1 },
        }
    },
    {
        id = 4,
        title = "Player Preview (/mugshotmove)",
        moveMode = true,
    },
    {
        id = 5,
        title = "No-Icon Fallback: Target Skeleton, Robust",
        name = "Target Skeleton, Robust",
        reaction = 3, -- UNIT_REACTION_NEUTRAL
        currentHealth = 3000000,
        maxHealth = 6000000,
        baseShield = 0,
        buffs = {
            { name = "Minor Breach", iconFilename = "/esoui/art/icons/ability_debuff_minor_breach.dds", duration = 10, stackCount = 0, effectType = 2 },
        }
    },
}

-- ── File Hash Check for Live Hot-Reload ───────────────────
local function ComputeFileHash(relPath)
    local f = io.open(addonRoot .. "/" .. relPath, "rb")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    local hash = 5381 + #content
    for i = 1, #content, 9 do
        hash = (hash * 33 + content:byte(i)) % 2147483647
    end
    return hash
end

local function CheckForCodeChanges()
    local changed = false
    for _, relPath in ipairs(WATCHED_FILES) do
        local h = ComputeFileHash(relPath)
        if h and fileFingerprints[relPath] ~= nil and fileFingerprints[relPath] ~= h then
            changed = true
        end
        fileFingerprints[relPath] = h
    end
    return changed
end

-- ── Scenario Applier ──────────────────────────────────────
local function ApplyScenario(idx)
    currentScenario = idx
    local sc = SCENARIOS[idx]
    if not sc or not MugShot._controller then return end

    isDead = false

    if sc.moveMode then
        if not MugShot._controller:IsInMoveMode() then
            SLASH_COMMANDS["/mugshotmove"]()
        end
        return
    else
        if MugShot._controller:IsInMoveMode() then
            SLASH_COMMANDS["/mugshotmove"]()
        end
    end

    local curHp = sc.currentHealth
    if liveHealthFraction ~= nil then
        curHp = math.floor(sc.maxHealth * liveHealthFraction)
    end

    local curShield = 0
    if shieldActive then
        curShield = (sc.baseShield and sc.baseShield > 0) and sc.baseShield or math.floor(sc.maxHealth * 0.20)
    end

    local now = (EsoMock and EsoMock.currentTime) or 1000.0
    local unitBuffs = {}
    for _, b in ipairs(sc.buffs or {}) do
        table.insert(unitBuffs, {
            name          = b.name,
            iconFilename  = b.iconFilename,
            duration      = b.duration or 10,
            timeStarted   = now,
            timeEnding    = (b.duration and b.duration > 0) and (now + b.duration) or 0,
            stackCount    = b.stackCount or 0,
            effectType    = b.effectType or 2,
        })
    end

    EsoMock.SetUnit("reticleover", {
        exists        = true,
        name          = sc.name,
        reaction      = sc.reaction,
        currentHealth = curHp,
        maxHealth     = sc.maxHealth,
        shield        = curShield,
        raceId        = sc.raceId,
        allianceId    = sc.allianceId,
        isDead        = false,
        buffs         = unitBuffs,
    })

    EsoMock.TriggerEvent(EVENT_RETICLE_TARGET_CHANGED)
end

-- ── ReloadAddon (Hot-Reload from Source Code) ──────────────
local function ReloadAddon(isHotReload)
    EsoMock = dofile(addonRoot .. "/tests/EsoMock.lua")
    EsoMock.Init()
    _G.EsoMock = EsoMock

    -- Set up realistic player character for Move Mode preview
    EsoMock.SetUnit("player", {
        exists        = true,
        name          = "", -- Empty so TargetController falls back to MugShot.GetText("DRAG_ME_TITLE") -> "[MugShot] Déplacez-moi !"
        displayName   = "",
        isPlayer      = true,
        reaction      = 2, -- UNIT_REACTION_FRIENDLY
        classId       = 1, -- Dragonknight (resolves class icon)
        raceId        = 1, -- Breton
        allianceId    = 1, -- Aldmeri Dominion
        currentHealth = 24500,
        maxHealth     = 24500,
        shield        = 0,
        buffs         = {
            { name = "Major Brutality",  iconFilename = "/esoui/art/icons/ability_warrior_001.dds", duration = 15, timeStarted = 1000, timeEnding = 1015, stackCount = 3, effectType = 1 },
            { name = "Major Expedition", iconFilename = "/esoui/art/icons/ability_rogue_012.dds",   duration = 7,  timeStarted = 1000, timeEnding = 1007, stackCount = 0, effectType = 1 },
            { name = "Minor Force",      iconFilename = "/esoui/art/icons/ability_mage_002.dds",    duration = 0,  timeStarted = 1000, timeEnding = 0,    stackCount = 0, effectType = 1 },
        }
    })

    for _, relPath in ipairs(WATCHED_FILES) do
        dofile(addonRoot .. "/" .. relPath)
    end

    if MugShot.Portraits and MugShot.Portraits.PopulateDynamicRegistry then
        MugShot.Portraits.PopulateDynamicRegistry()
    end

    EsoMock.TriggerEvent(EVENT_ADD_ON_LOADED, MugShot.Constants.ADDON_NAME)

    -- In standard gameplay, frame starts locked
    if MugShot.settings then
        MugShot.settings:Set("locked", true)
    end

    frameRoot = EsoMock.controls["MugShot_TargetFrame"]
    if frameRoot then
        frameRoot:ClearAnchors()
        frameRoot:SetAnchor(0, GuiRoot, 0, framePosX, framePosY)
    end

    ApplyScenario(currentScenario)

    if isHotReload then
        hotReloadBannerTimer = 2.0
    end
end

-- ── Dynamic Buff Add / Remove ─────────────────────────────
local function AddBuff()
    local inMove = MugShot._controller and MugShot._controller:IsInMoveMode()
    local unitTag = inMove and "player" or "reticleover"
    local u = EsoMock.units[unitTag]
    if not u then return end

    u.buffs = u.buffs or {}
    local sample = BUFF_CATALOG[nextCatalogIdx]
    nextCatalogIdx = (nextCatalogIdx % #BUFF_CATALOG) + 1

    local now = EsoMock.currentTime or 1000.0
    table.insert(u.buffs, {
        name         = sample.name,
        iconFilename = sample.iconFilename,
        duration     = sample.duration,
        timeStarted  = now,
        timeEnding   = (sample.duration > 0) and (now + sample.duration) or 0,
        stackCount   = sample.stackCount or 0,
        effectType   = sample.effectType or 2,
    })

    if MugShot._controller then
        MugShot._controller:RefreshEffects(nil, unitTag)
    end
end

local function RemoveBuff()
    local inMove = MugShot._controller and MugShot._controller:IsInMoveMode()
    local unitTag = inMove and "player" or "reticleover"
    local u = EsoMock.units[unitTag]
    if not u or not u.buffs or #u.buffs == 0 then return end

    table.remove(u.buffs)
    if MugShot._controller then
        MugShot._controller:RefreshEffects(nil, unitTag)
    end
end

local function ToggleStressTestBuffs()
    local inMove = MugShot._controller and MugShot._controller:IsInMoveMode()
    local unitTag = inMove and "player" or "reticleover"
    local u = EsoMock.units[unitTag]
    if not u then return end

    u.buffs = u.buffs or {}
    if #u.buffs >= 14 then
        ApplyScenario(currentScenario)
    else
        local now = EsoMock.currentTime or 1000.0
        u.buffs = {}
        for i = 1, 14 do
            local sample = BUFF_CATALOG[((i - 1) % #BUFF_CATALOG) + 1]
            table.insert(u.buffs, {
                name         = sample.name,
                iconFilename = sample.iconFilename,
                duration     = sample.duration,
                timeStarted  = now,
                timeEnding   = (sample.duration > 0) and (now + sample.duration) or 0,
                stackCount   = (i % 3 == 0) and (i % 5 + 1) or 0,
                effectType   = sample.effectType or 2,
            })
        end
        if MugShot._controller then
            MugShot._controller:RefreshEffects(nil, unitTag)
        end
    end
end

-- ── Love2D Callbacks ──────────────────────────────────────

function love.load()
    fontSmall = love.graphics.newFont(11)
    fontMain  = love.graphics.newFont(13)
    fontTitle = love.graphics.newFont(16)

    for _, relPath in ipairs(WATCHED_FILES) do
        fileFingerprints[relPath] = ComputeFileHash(relPath)
    end

    ReloadAddon(false)
end

function love.update(dt)
    -- 1. Advance ESO clock & execute registered update loops
    if EsoMock and not isDead then
        local now = (EsoMock.currentTime or 1000.0) + dt
        EsoMock.currentTime = now

        -- Automatically loop expired timers so they restart seamlessly
        local function LoopBuffs(unitTag)
            local u = EsoMock.units[unitTag]
            local restarted = false
            if u and u.buffs then
                for _, b in ipairs(u.buffs) do
                    if b.timeEnding and b.timeEnding > 0 and now >= b.timeEnding then
                        local dur = b.duration or 10
                        if dur <= 0 then dur = 10 end
                        b.timeStarted = now
                        b.timeEnding = now + dur
                        restarted = true
                    end
                end
            end
            return restarted
        end

        local loopTarget = LoopBuffs("reticleover")
        local loopPlayer = LoopBuffs("player")

        if (loopTarget or loopPlayer) and MugShot._controller then
            MugShot._controller:RefreshEffects(nil, loopPlayer and "player" or "reticleover")
        end

        -- Trigger all active EVENT_MANAGER updates (including MugShot_TimerUpdate!)
        for _, entry in pairs(EsoMock.updates or {}) do
            if entry and entry.callback then
                entry.callback()
            end
        end
    end

    -- 2. File Watcher: auto-reload on code save
    watchTimer = watchTimer + dt
    if watchTimer >= 0.30 then
        watchTimer = 0
        if CheckForCodeChanges() then
            ReloadAddon(true)
        end
    end

    if hotReloadBannerTimer > 0 then
        hotReloadBannerTimer = math.max(0, hotReloadBannerTimer - dt)
    end
    if hudNotificationTimer > 0 then
        hudNotificationTimer = math.max(0, hudNotificationTimer - dt)
        if hudNotificationTimer <= 0 then hudNotification = nil end
    end

    -- 3. Dragging (only allowed in Move Mode)
    if isDragging and frameRoot then
        local mx, my = love.mouse.getPosition()
        framePosX = mx - dragOffsetX
        framePosY = my - dragOffsetY
        frameRoot:ClearAnchors()
        frameRoot:SetAnchor(0, GuiRoot, 0, framePosX, framePosY)
    end
end

function love.draw()
    -- Dark background + reticle
    love.graphics.clear(0.07, 0.08, 0.09)

    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0.12, 0.14, 0.16, 0.5)
    love.graphics.line(sw / 2 - 20, sh / 2, sw / 2 + 20, sh / 2)
    love.graphics.line(sw / 2, sh / 2 - 20, sw / 2, sh / 2 + 20)
    love.graphics.circle("line", sw / 2, sh / 2, 8)

    -- Hierarchical control visibility check
    local function IsEffectivelyVisible(ctrl)
        local cur = ctrl
        while cur do
            if cur.hidden then return false end
            cur = cur.parent
        end
        return true
    end

    -- Resolve and render ALL MugShot frame controls via LayoutSolver
    local boxes = {}
    local drawList = {}

    for _, ctrl in pairs(EsoMock.controls) do
        if IsEffectivelyVisible(ctrl) and ctrl.name ~= "GuiRoot" then
            local box = LayoutSolver.Resolve(ctrl, boxes, sw, sh)
            if box and box.w > 0 and box.h > 0 then
                table.insert(drawList, { ctrl = ctrl, box = box, layer = ctrl.drawLayer or 0 })
            end
        end
    end

    table.sort(drawList, function(a, b) return a.layer < b.layer end)

    for _, item in ipairs(drawList) do
        local ctrl = item.ctrl
        local b = item.box

        if ctrl.controlType == CT_BACKDROP then
            local cc = ctrl.centerColor or { 0.08, 0.08, 0.08, 1.0 }
            love.graphics.setColor(cc[1], cc[2], cc[3], cc[4] or 1.0)
            love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)

            local ec = ctrl.edgeColor or { 0.0, 0.0, 0.0, 1.0 }
            love.graphics.setColor(ec[1], ec[2], ec[3], ec[4] or 1.0)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", b.x, b.y, b.w, b.h)

        elseif ctrl.controlType == CT_TEXTURE then
            local isPortrait = (ctrl.name == "MugShot_Portrait")
            local isEffectIcon = ctrl.name and ctrl.name:find("EffectIcon")
            local isBadge = (ctrl.name == "MugShot_RaceIcon" or ctrl.name == "MugShot_AllianceIcon")

            if isPortrait then
                love.graphics.setColor(0.12, 0.14, 0.18, 1.0)
                love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
                love.graphics.setColor(0.35, 0.40, 0.48, 1.0)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", b.x + 1, b.y + 1, b.w - 2, b.h - 2)

                local shortName = (ctrl.texture or ""):match("([^/]+)%.dds$") or "Portrait"
                love.graphics.setColor(1.0, 0.85, 0.30, 0.9)
                love.graphics.setFont(fontSmall)
                love.graphics.printf(shortName:sub(1, 12), b.x + 2, b.y + b.h / 2 - 6, b.w - 4, "center")

            elseif isEffectIcon then
                love.graphics.setColor(0.12, 0.14, 0.17, 1.0)
                love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
                love.graphics.setColor(0.28, 0.32, 0.38, 1.0)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", b.x, b.y, b.w, b.h)

            elseif isBadge then
                local tc = ctrl.color or { 1.0, 1.0, 1.0, 1.0 }
                love.graphics.setColor(0.08, 0.10, 0.12, 0.95)
                love.graphics.circle("fill", b.x + b.w / 2, b.y + b.h / 2, b.w / 2)
                love.graphics.setColor(tc[1], tc[2], tc[3], tc[4] or 1.0)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", b.x + b.w / 2, b.y + b.h / 2, b.w / 2)

                local badgeLetter = ctrl.name:find("Race") and "R" or "A"
                love.graphics.setFont(fontSmall)
                love.graphics.printf(badgeLetter, b.x, b.y + b.h / 2 - 6, b.w, "center")

            else
                local tc = ctrl.color or { 1.0, 1.0, 1.0, 1.0 }
                love.graphics.setColor(tc[1], tc[2], tc[3], tc[4] or 1.0)
                love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
            end

        elseif ctrl.controlType == CT_LABEL then
            local text = ctrl:GetText()
            if text and text ~= "" then
                local col = ctrl.color or { 1.0, 1.0, 1.0, 1.0 }
                local align = "left"
                if ctrl.hAlign == 2 then align = "right"
                elseif ctrl.hAlign == 1 then align = "center" end

                local f = fontMain
                if ctrl.name == "MugShot_TargetNameLabel" or ctrl.name == "MugShot_PercentageLabel" then
                    f = fontTitle
                elseif ctrl.name and ctrl.name:find("EffectStack") then
                    f = fontSmall
                end
                love.graphics.setFont(f)

                love.graphics.setColor(0.0, 0.0, 0.0, 0.85)
                love.graphics.printf(text, b.x + 1, b.y + 1, b.w, align)

                love.graphics.setColor(col[1], col[2], col[3], col[4] or 1.0)
                love.graphics.printf(text, b.x, b.y, b.w, align)
            end
        end
    end

    -- 3. Top HUD Banner (cleanly located above game canvas, zero synthetic frame overlays)
    local inMove = MugShot._controller and MugShot._controller:IsInMoveMode()

    love.graphics.setColor(0.04, 0.05, 0.06, 0.90)
    love.graphics.rectangle("fill", 0, 0, sw, 88)
    love.graphics.setColor(0.18, 0.22, 0.26, 1.0)
    love.graphics.line(0, 88, sw, 88)

    love.graphics.setFont(fontTitle)
    love.graphics.setColor(1.0, 0.85, 0.20, 1.0)
    love.graphics.print("MugShot Live Preview", 16, 8)

    if hotReloadBannerTimer > 0 then
        love.graphics.setColor(0.2, 1.0, 0.4, 0.95)
        love.graphics.setFont(fontMain)
        love.graphics.print("[HOT-RELOAD ACTIVÉ : Code source rechargé en direct !]", 230, 10)
    elseif hudNotification then
        love.graphics.setColor(1.0, 0.8, 0.3, 0.95)
        love.graphics.setFont(fontMain)
        love.graphics.print(hudNotification, 230, 10)
    end

    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.75, 0.80, 0.85, 1.0)
    local activeTag = inMove and "player" or "reticleover"
    local curBuffs = (EsoMock and EsoMock.units[activeTag] and EsoMock.units[activeTag].buffs) or {}
    local numRows = math.max(1, math.ceil(math.max(1, #curBuffs) / 10))

    local scDesc = string.format("Scénario: [%d] %s", currentScenario, SCENARIOS[currentScenario].title)
    if isDead then
        scDesc = scDesc .. "   [CIBLE MORTE / CADRE MASQUÉ]"
    elseif inMove then
        scDesc = scDesc .. "   [MODE DÉPLACEMENT DÉVERROUILLÉ - Bordures cyan]"
    else
        scDesc = scDesc .. "   [VERROUILLÉ]"
    end
    scDesc = scDesc .. string.format("   |   Effets: %d (%d ligne%s)", #curBuffs, numRows, numRows > 1 and "s" or "")
    if shieldActive then
        scDesc = scDesc .. "   [Bouclier: ON]"
    else
        scDesc = scDesc .. "   [Bouclier: OFF]"
    end
    love.graphics.print(scDesc, 16, 36)

    love.graphics.setColor(0.9, 0.9, 0.9, 0.9)
    local help = "[1-5] Scénarios  |  [Flèches G/D] PV live  |  [S] Bouclier  |  [M] Mode Move (/mugshotmove)  |  [D] Mort  |  [+] / [-] Effets  |  [T] Test 14 Effets  |  [R] Reset  |  [F5] Reload"
    love.graphics.print(help, 16, 60)
end

-- ── Live Health Modifier ──────────────────────────────────
local function UpdateLiveHealth(delta)
    local inMove = MugShot._controller and MugShot._controller:IsInMoveMode()
    local unitTag = inMove and "player" or "reticleover"
    local u = EsoMock and EsoMock.units[unitTag]
    if not u then return end

    if liveHealthFraction == nil then
        liveHealthFraction = u.currentHealth / u.maxHealth
    end

    liveHealthFraction = math.min(1.0, math.max(0.0, liveHealthFraction + delta))
    u.currentHealth = math.floor(u.maxHealth * liveHealthFraction)

    -- Update vitals via controller & event
    MugShot._controller:RefreshVitals(u.currentHealth, u.maxHealth, u.maxHealth, nil, unitTag)
    EsoMock.TriggerEvent(EVENT_POWER_UPDATE, unitTag, 1, COMBAT_MECHANIC_FLAGS_HEALTH,
        u.currentHealth, u.maxHealth, u.maxHealth)
end

function love.keypressed(key, scancode)
    local k = string.lower(key or "")
    local sc = string.lower(scancode or "")

    if k == "1" or sc == "1" or k == "kp1" or sc == "kp1" or k == "&" then
        liveHealthFraction = nil
        ApplyScenario(1)
    elseif k == "2" or sc == "2" or k == "kp2" or sc == "kp2" or k == "é" then
        liveHealthFraction = nil
        ApplyScenario(2)
    elseif k == "3" or sc == "3" or k == "kp3" or sc == "kp3" or k == '"' then
        liveHealthFraction = nil
        ApplyScenario(3)
    elseif k == "4" or sc == "4" or k == "kp4" or sc == "kp4" or k == "'" then
        ApplyScenario(4)
    elseif k == "5" or sc == "5" or k == "kp5" or sc == "kp5" or k == "(" then
        liveHealthFraction = nil
        ApplyScenario(5)
    elseif k == "left" or sc == "left" or k == "down" or sc == "down" then
        UpdateLiveHealth(-0.05)
    elseif k == "right" or sc == "right" or k == "up" or sc == "up" then
        UpdateLiveHealth(0.05)
    elseif k == "s" or sc == "s" then
        shieldActive = not shieldActive
        local inMove = MugShot._controller and MugShot._controller:IsInMoveMode()
        local unitTag = inMove and "player" or "reticleover"
        local u = EsoMock.units[unitTag]
        if u then
            u.shield = shieldActive and math.floor(u.maxHealth * 0.20) or 0
            if shieldActive then
                EsoMock.TriggerEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, unitTag, ATTRIBUTE_VISUAL_POWER_SHIELDING, 1, 1, 1, u.shield, u.currentHealth, u.maxHealth)
            else
                EsoMock.TriggerEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, unitTag, ATTRIBUTE_VISUAL_POWER_SHIELDING, 1, 1, 1, 0, u.currentHealth, u.maxHealth)
            end
            MugShot._controller:RefreshShield(nil, unitTag)
        end
    elseif k == "m" or sc == "m" then
        if SLASH_COMMANDS and SLASH_COMMANDS["/mugshotmove"] then
            SLASH_COMMANDS["/mugshotmove"]()
        end
    elseif k == "d" or sc == "d" then
        isDead = not isDead
        EsoMock.TriggerEvent(EVENT_UNIT_DEATH_STATE_CHANGED, "reticleover", isDead)
    elseif k == "r" or sc == "r" then
        -- Execute real /mugshotreset command (resets position and unlocks frame in move mode)
        if SLASH_COMMANDS and SLASH_COMMANDS["/mugshotreset"] then
            SLASH_COMMANDS["/mugshotreset"]()
        end
        local pos = (MugShot.settings and MugShot.settings:Get().position) or { offsetX = 100, offsetY = 200 }
        framePosX = pos.offsetX or 100
        framePosY = pos.offsetY or 200
        if frameRoot then
            frameRoot:ClearAnchors()
            frameRoot:SetAnchor(0, GuiRoot, 0, framePosX, framePosY)
        end
        hudNotification = "[/mugshotreset : Position réinitialisée à (100, 200) et mode déplacement actif]"
        hudNotificationTimer = 2.5
    elseif k == "+" or sc == "+" or k == "=" or sc == "=" or k == "b" or sc == "b" or k == "kp+" then
        AddBuff()
    elseif k == "-" or sc == "-" or k == "kp-" then
        RemoveBuff()
    elseif k == "t" or sc == "t" then
        ToggleStressTestBuffs()
    elseif k == "f5" or sc == "f5" then
        ReloadAddon(true)
    elseif k == "escape" or sc == "escape" then
        love.event.quit()
    end
end

function love.mousepressed(x, y, button)
    if button == 1 and frameRoot then
        local inMove = MugShot._controller and MugShot._controller:IsInMoveMode()
        local Style = MugShot.Style
        local fw = (Style and Style.FRAME_WIDTH) or 381
        local fh = ((Style and Style.FRAME_HEIGHT) or 79) + 60

        if x >= framePosX and x <= framePosX + fw and y >= framePosY and y <= framePosY + fh then
            if inMove then
                isDragging = true
                dragOffsetX = x - framePosX
                dragOffsetY = y - framePosY
            else
                hudNotification = "[Cadre verrouillé : tapez /mugshotmove ou appuyez sur [M] pour déverrouiller]"
                hudNotificationTimer = 2.0
            end
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        isDragging = false
        if MugShot.settings and MugShot._controller and MugShot._controller:IsInMoveMode() then
            MugShot.settings:Set("position", {
                point         = 0,
                relativePoint = 0,
                offsetX       = framePosX,
                offsetY       = framePosY,
            })
        end
    end
end
