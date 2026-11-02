-- =========================================================
-- MugShot - Live Dynamic UI Preview & 3D Arena Simulator
-- (tests/preview/main.lua)
-- Concise orchestrator managing:
--   - Arena3D: 3D projection, first-person movement, reticle raycast
--   - Entities: 3D target definitions, catalog, and native ESO events
--   - EsoUiRenderer: Decoupled, agnostic Love2D renderer for ESO controls
--   - EsoMock: Headless ESO runtime & event manager
-- =========================================================

local Arena3D       = require("Arena3D")
local Entities      = require("Entities")
local EsoUiRenderer = require("EsoUiRenderer")
local LayoutSolver  = require("LayoutSolver")

-- ── Paths & Modules ───────────────────────────────────────
local previewDir = (love and love.filesystem and love.filesystem.getSource()) or "."
local addonRoot  = previewDir .. "/../.."
package.path     = package.path .. ";" .. addonRoot .. "/?.lua;" .. addonRoot .. "/tests/?.lua"

-- ── Watched Addon Source Files for Hot-Reload ─────────────
local WATCHED_FILES = {
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

-- ── Runtime Components & State ────────────────────────────
local arena            = nil
local uiRenderer       = nil
local targets          = {}
local currentTarget    = nil
local isInGroup        = true  -- Group mode active by default to showcase group debuffs & multi-source cyan merges

local EsoMock          = nil
local frameRoot        = nil
local globalAnimTime   = 0
local hotReloadTimer   = 0
local hudNotification  = nil
local hudNotificationTimer = 0
local fileFingerprints = {}
local watchTimer       = 0

-- Frame dragging state (Move Mode)
local isDragging       = false
local dragOffsetX      = 0
local dragOffsetY      = 0

-- Mouse look state
local isRightMouseDown = false
local mouseLookActive  = true
local showHelpOverlay  = false

-- Font definitions
local fonts = {}

local function StripEsoMarkup(str)
    if not str then return "" end
    return (str:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""))
end

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

-- ── Addon Reload Engine ───────────────────────────────────
local function ReloadAddon(isHotReload)
    EsoMock = dofile(addonRoot .. "/tests/EsoMock.lua")
    EsoMock.Init()
    _G.EsoMock = EsoMock

    -- Set up player character for Move Mode preview
    EsoMock.SetUnit("player", {
        exists        = true,
        name          = "",
        displayName   = "",
        isPlayer      = true,
        reaction      = 2, -- UNIT_REACTION_FRIENDLY
        classId       = 1, -- Dragonknight
        raceId        = 1, -- Breton
        allianceId    = 1, -- Aldmeri Dominion
        currentHealth = 24500,
        maxHealth     = 24500,
        shield        = 0,
        buffs         = {
            { name = "Major Brutality",  iconFilename = "/esoui/art/icons/ability_warrior_001.dds", duration = 15, timeStarted = 1000, timeEnding = 1015, stackCount = 3, effectType = 1, castByPlayer = true },
            { name = "Major Expedition", iconFilename = "/esoui/art/icons/ability_rogue_012.dds",   duration = 7,  timeStarted = 1000, timeEnding = 1007, stackCount = 0, effectType = 1, castByPlayer = true },
            { name = "Minor Force",      iconFilename = "/esoui/art/icons/ability_mage_002.dds",    duration = 0,  timeStarted = 1000, timeEnding = 0,    stackCount = 0, effectType = 1, castByPlayer = true },
        }
    })

    -- Load addon modules in manifest order
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
        local isTrial = MugShot.settings:Get().onlyHostileInTrials
        EsoMock.isPlayerInRaid = isTrial
        if MugShot._controller then
            MugShot._controller:OnZoneChanged()
        end
    end

    frameRoot = EsoMock.controls["MugShot_TargetFrame"]

    -- Sync group state and target state via standard ESO events
    Entities.ToggleGroup(isInGroup, EsoMock)
    Entities.SyncToMock(currentTarget, EsoMock)

    if isHotReload then
        hotReloadTimer = 2.0
    end
end

-- ── Love2D Callbacks ──────────────────────────────────────

function love.load()
    fonts = {
        fontSmall = love.graphics.newFont(11),
        fontMain  = love.graphics.newFont(13),
        fontTitle = love.graphics.newFont(16),
        fontTiny  = love.graphics.newFont(9),
        fontTimer = love.graphics.newFont(13),
        fontBadge = love.graphics.newFont(11),
    }

    arena      = Arena3D.New()
    uiRenderer = EsoUiRenderer.New(fonts)
    targets    = Entities.CreateDefaultTargets()

    currentTarget = targets[1]
    arena:SnapCameraTo(currentTarget)

    -- Enable authentic first-person mouse camera look by default
    love.mouse.setRelativeMode(true)
    mouseLookActive = true

    for _, relPath in ipairs(WATCHED_FILES) do
        fileFingerprints[relPath] = ComputeFileHash(relPath)
    end

    ReloadAddon(false)
end

function love.update(dt)
    if os.getenv("MUGSHOT_TEST_EXIT") then
        love.event.quit()
        return
    end
    globalAnimTime = globalAnimTime + dt

    -- 1. Advance ESO clock & execute registered EVENT_MANAGER timers
    if EsoMock then
        local now = (EsoMock.currentTime or 1000.0) + dt
        EsoMock.currentTime = now

        for _, entry in pairs(EsoMock.updates or {}) do
            if entry and entry.callback then
                entry.callback()
            end
        end
    end

    -- 2. First-Person Movement & Camera Update
    arena:Update(dt)

    -- 3. Crosshair Raycast Targeting (when not in Move Mode)
    local inMove = MugShot._controller and MugShot._controller:IsInMoveMode()
    if not inMove then
        local sw, sh = love.graphics.getDimensions()
        local hit = arena:FindTargetUnderReticle(targets, sw, sh)
        if hit ~= currentTarget then
            currentTarget = hit
            Entities.SyncToMock(currentTarget, EsoMock)
        end
    end

    -- 4. File Watcher for Live Hot-Reloading
    watchTimer = watchTimer + dt
    if watchTimer >= 0.30 then
        watchTimer = 0
        if CheckForCodeChanges() then
            ReloadAddon(true)
        end
    end

    if hotReloadTimer > 0 then
        hotReloadTimer = math.max(0, hotReloadTimer - dt)
    end
    if hudNotificationTimer > 0 then
        hudNotificationTimer = math.max(0, hudNotificationTimer - dt)
        if hudNotificationTimer <= 0 then
            hudNotification = nil
        end
    end

    -- 5. Frame Dragging in Move Mode
    if isDragging and frameRoot then
        local mx, my = love.mouse.getPosition()
        local newX = math.floor(mx - dragOffsetX + 0.5)
        local newY = math.floor(my - dragOffsetY + 0.5)
        frameRoot:ClearAnchors()
        frameRoot:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, newX, newY)
    end
end

function love.draw()
    local sw, sh = love.graphics.getDimensions()

    -- 1. Draw 3D Arena (Geometry, Pillars, Braziers, Target Cards & Overhead Nameplates)
    arena:Draw(targets, currentTarget, globalAnimTime, sw, sh, fonts)

    -- 2. Draw Targeting Reticle
    arena:DrawReticle(sw, sh, currentTarget ~= nil)

    -- 3. Draw MugShot UI Frame (Decoupled Agnostic ESO Renderer)
    uiRenderer:Draw(EsoMock.controls, sw, sh)

    -- 4. Sleek Minimalist Top HUD Bar (Height 36px)
    love.graphics.setColor(0.04, 0.05, 0.08, 0.90)
    love.graphics.rectangle("fill", 0, 0, sw, 36)
    love.graphics.setColor(0.18, 0.22, 0.28, 0.8)
    love.graphics.line(0, 36, sw, 36)

    -- Left: Brand & Status Badges
    love.graphics.setFont(fonts.fontTitle)
    love.graphics.setColor(1.0, 0.82, 0.25, 1.0)
    love.graphics.print("MugShot", 14, 8)

    local inMove = MugShot._controller and MugShot._controller:IsInMoveMode()
    local isTrial = MugShot.settings and MugShot.settings:Get().onlyHostileInTrials

    local badgeX = 110
    local function DrawPill(text, r, g, b, active)
        local f = fonts.fontSmall
        love.graphics.setFont(f)
        local tw = f:getWidth(text)
        local pw = tw + 14
        local ph = 20
        local py = 8

        if active then
            love.graphics.setColor(r * 0.25, g * 0.25, b * 0.25, 0.95)
            love.graphics.rectangle("fill", badgeX, py, pw, ph, 4, 4)
            love.graphics.setColor(r, g, b, 1.0)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", badgeX, py, pw, ph, 4, 4)
            love.graphics.setColor(r, g, b, 1.0)
        else
            love.graphics.setColor(0.10, 0.12, 0.16, 0.85)
            love.graphics.rectangle("fill", badgeX, py, pw, ph, 4, 4)
            love.graphics.setColor(0.24, 0.28, 0.35, 0.6)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", badgeX, py, pw, ph, 4, 4)
            love.graphics.setColor(0.60, 0.65, 0.72, 0.85)
        end
        love.graphics.printf(text, badgeX, py + 3, pw, "center")
        badgeX = badgeX + pw + 8
    end

    DrawPill(isInGroup and "GROUPE (4j)" or "SOLO", 0.18, 0.78, 0.96, isInGroup)
    DrawPill(isTrial and "RAID ACTIF" or "RAID OFF", 1.0, 0.65, 0.20, isTrial)
    DrawPill(inMove and "DÉPLACEMENT" or "VERROUILLÉ", inMove and 0.20 or 0.25, inMove and 0.80 or 0.85, inMove and 1.0 or 0.45, true)

    -- Center: Animated Toast Notification
    if hotReloadTimer > 0 then
        local msg = "[Code rechargé instantanément]"
        local tw = fonts.fontMain:getWidth(msg) + 24
        local tx = math.floor((sw - tw) / 2)
        love.graphics.setColor(0.05, 0.15, 0.08, 0.95)
        love.graphics.rectangle("fill", tx, 6, tw, 24, 4, 4)
        love.graphics.setColor(0.25, 0.90, 0.40, 1.0)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", tx, 6, tw, 24, 4, 4)
        love.graphics.setFont(fonts.fontMain)
        love.graphics.printf(msg, tx, 9, tw, "center")
    elseif hudNotification then
        local msg = StripEsoMarkup(hudNotification)
        local tw = fonts.fontMain:getWidth(msg) + 24
        local tx = math.floor((sw - tw) / 2)
        love.graphics.setColor(0.05, 0.09, 0.14, 0.95)
        love.graphics.rectangle("fill", tx, 6, tw, 24, 4, 4)
        love.graphics.setColor(1.0, 0.82, 0.30, 0.95)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", tx, 6, tw, 24, 4, 4)
        love.graphics.setFont(fonts.fontMain)
        love.graphics.printf(msg, tx, 9, tw, "center")
    end

    -- Right: Controls / FPS
    love.graphics.setFont(fonts.fontSmall)
    local mouseStatus = mouseLookActive and "Souris : Caméra 3D [Tab]" or "Souris : Curseur Libre [Tab]"
    local fpsText = string.format("%s   |   [F1] Aide   |   %d FPS", mouseStatus, love.timer.getFPS())
    love.graphics.setColor(0.65, 0.72, 0.80, 0.90)
    love.graphics.printf(fpsText, 0, 11, sw - 14, "right")

    -- 5. Bottom Docked Command Palette (Clean Floating Bar)
    local dockY = sh - 36
    love.graphics.setColor(0.04, 0.05, 0.08, 0.88)
    love.graphics.rectangle("fill", 10, dockY, sw - 20, 28, 6, 6)
    love.graphics.setColor(0.18, 0.22, 0.28, 0.7)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", 10, dockY, sw - 20, 28, 6, 6)

    love.graphics.setFont(fonts.fontSmall)
    love.graphics.setColor(0.85, 0.88, 0.92, 0.95)
    local dockHelp = "[ZQSD/WASD] Marcher   |   [1-5] Cibles   |   [Flèches G/D] PV   |   [H] Soin   |   [K] Bouclier   |   [J] Mort   |   [+] / [-] Effets   |   [T] 14 Buffs   |   [G] Solo/Groupe   |   [M] Déplacer   |   [R] Reset   |   [F1] Guide"
    love.graphics.printf(dockHelp, 12, dockY + 7, sw - 24, "center")

    -- 6. Optional Fullscreen Help Modal Overlay ([F1])
    if showHelpOverlay then
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", 0, 0, sw, sh)

        local modalW, modalH = 680, 440
        local modalX = math.floor((sw - modalW) / 2)
        local modalY = math.floor((sh - modalH) / 2)

        love.graphics.setColor(0.06, 0.08, 0.12, 0.98)
        love.graphics.rectangle("fill", modalX, modalY, modalW, modalH, 8, 8)
        love.graphics.setColor(0.25, 0.35, 0.48, 0.9)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", modalX, modalY, modalW, modalH, 8, 8)

        -- Title
        love.graphics.setFont(fonts.fontTitle)
        love.graphics.setColor(1.0, 0.85, 0.25, 1.0)
        love.graphics.printf("Guide des Contrôles - Simulateur MugShot", modalX, modalY + 16, modalW, "center")

        -- Sections
        local lines = {
            { cat = "DÉPLACEMENT & VUE", desc = "[WASD / ZQSD] : Déplacement dans l'arène\n[Souris] : Regard 1ère personne (ou clic droit)\n[Tab] : Basculer entre caméra 3D et curseur libre" },
            { cat = "SÉLECTION DES CIBLES", desc = "[1] Boss Oaxiltso  |  [2] Elysia (Joueuse)  |  [3] Bastian (Compagnon)\n[4] Familier  |  [5] Squelette d'entraînement\n(Ou visez directement un mannequin au réticule central)" },
            { cat = "COMBAT & SANTÉ", desc = "[Flèches Gauche / Droite] : Retirer / Ajouter 5% de PV en direct\n[H] : Soigner la cible à 100% PV\n[K] ou [Espace] : Activer / Désactiver le bouclier (20% PV max)\n[J] ou [Suppr] : Simuler la mort / résurrection de la cible" },
            { cat = "EFFETS, BUFFS & DÉBUFFS", desc = "[+] ou [B] : Ajouter un effet (catalogue ESO)\n[-] ou [N] : Retirer le dernier effet\n[T] : Stress-test 14 buffs et débuffs simultanés\n[G] : Basculer Solo / Groupe (fusions multi-source x2/x3 avec bordure cyan)" },
            { cat = "INTERFACE & SYSTÈME", desc = "[M] : Déverrouiller le cadre (/mugshot move) et le glisser à la souris\n[R] : Réinitialiser la position par défaut et déverrouiller (/mugshot reset)\n[X] : Basculer le filtre Raid Épreuve (hostiles uniquement)\n[F5] : Recharger le code addon en direct (Hot-Reload)\n[Échap] : Quitter le simulateur" },
        }

        local curY = modalY + 54
        for _, sec in ipairs(lines) do
            love.graphics.setFont(fonts.fontMain)
            love.graphics.setColor(0.35, 0.80, 1.0, 1.0)
            love.graphics.print(sec.cat, modalX + 24, curY)
            curY = curY + 18

            love.graphics.setFont(fonts.fontSmall)
            love.graphics.setColor(0.82, 0.86, 0.90, 0.95)
            love.graphics.printf(sec.desc, modalX + 28, curY, modalW - 56, "left")
            curY = curY + 46
        end

        love.graphics.setFont(fonts.fontSmall)
        love.graphics.setColor(0.55, 0.60, 0.68, 0.9)
        love.graphics.printf("Appuyez sur [F1] ou [Échap] pour fermer ce guide", modalX, modalY + modalH - 26, modalW, "center")
    end
end

function love.keypressed(key, scancode)
    local k = string.lower(key or "")
    local sc = string.lower(scancode or "")

    -- Toggle help modal
    if k == "f1" or sc == "f1" then
        showHelpOverlay = not showHelpOverlay
        return
    end

    if showHelpOverlay and (k == "escape" or sc == "escape") then
        showHelpOverlay = false
        return
    end

    -- Target selection [1-5]
    if k == "1" or sc == "1" or k == "&" or k == "kp1" or sc == "kp1" then
        currentTarget = targets[1]
        arena:SnapCameraTo(currentTarget)
        Entities.SyncToMock(currentTarget, EsoMock)
        hudNotification = "[Cible : " .. currentTarget.name .. "]"
        hudNotificationTimer = 2.0
    elseif k == "2" or sc == "2" or k == "é" or k == "kp2" or sc == "kp2" then
        currentTarget = targets[2]
        arena:SnapCameraTo(currentTarget)
        Entities.SyncToMock(currentTarget, EsoMock)
        hudNotification = "[Cible : " .. currentTarget.name .. "]"
        hudNotificationTimer = 2.0
    elseif k == "3" or sc == "3" or k == '"' or k == "kp3" or sc == "kp3" then
        currentTarget = targets[3]
        arena:SnapCameraTo(currentTarget)
        Entities.SyncToMock(currentTarget, EsoMock)
        hudNotification = "[Cible : " .. currentTarget.name .. "]"
        hudNotificationTimer = 2.0
    elseif k == "4" or sc == "4" or k == "'" or k == "kp4" or sc == "kp4" then
        currentTarget = targets[4]
        arena:SnapCameraTo(currentTarget)
        Entities.SyncToMock(currentTarget, EsoMock)
        hudNotification = "[Cible : " .. currentTarget.name .. "]"
        hudNotificationTimer = 2.0
    elseif k == "5" or sc == "5" or k == "(" or k == "kp5" or sc == "kp5" then
        currentTarget = targets[5]
        arena:SnapCameraTo(currentTarget)
        Entities.SyncToMock(currentTarget, EsoMock)
        hudNotification = "[Cible : " .. currentTarget.name .. "]"
        hudNotificationTimer = 2.0

    -- Vitals mutations (Pure ESO events)
    elseif k == "left" or sc == "left" or k == "down" or sc == "down" then
        if not currentTarget then
            currentTarget = targets[1]
            arena:SnapCameraTo(currentTarget)
            Entities.SyncToMock(currentTarget, EsoMock)
        end
        Entities.UpdateHealth(currentTarget, -0.05, EsoMock)
    elseif k == "right" or sc == "right" or k == "up" or sc == "up" then
        if not currentTarget then
            currentTarget = targets[1]
            arena:SnapCameraTo(currentTarget)
            Entities.SyncToMock(currentTarget, EsoMock)
        end
        Entities.UpdateHealth(currentTarget, 0.05, EsoMock)
    elseif k == "h" or sc == "h" then
        if not currentTarget then
            currentTarget = targets[1]
            arena:SnapCameraTo(currentTarget)
            Entities.SyncToMock(currentTarget, EsoMock)
        end
        Entities.HealFull(currentTarget, EsoMock)
        hudNotification = "[Soin complet appliqué]"
        hudNotificationTimer = 2.0
    elseif k == "k" or sc == "k" or k == "space" or sc == "space" then
        if not currentTarget then
            currentTarget = targets[1]
            arena:SnapCameraTo(currentTarget)
            Entities.SyncToMock(currentTarget, EsoMock)
        end
        local active = Entities.ToggleShield(currentTarget, EsoMock)
        hudNotification = "[Bouclier : " .. (active and "ACTIF (20%)" or "DÉSACTIVÉ") .. "]"
        hudNotificationTimer = 2.0
    elseif k == "j" or sc == "j" or k == "delete" or sc == "delete" then
        if not currentTarget then
            currentTarget = targets[1]
            arena:SnapCameraTo(currentTarget)
            Entities.SyncToMock(currentTarget, EsoMock)
        end
        local dead = Entities.ToggleDeath(currentTarget, EsoMock)
        hudNotification = "[Statut : " .. (dead and "MORT" or "VIVANT") .. "]"
        hudNotificationTimer = 2.0

    -- Buff mutations (Comprehensive key detection: +, =, kp+, add, b, -, kp-, minus, subtract, n)
    elseif k == "+" or sc == "+" or k == "=" or sc == "=" or k == "kp+" or sc == "kp+" or sc == "equals" or k == "add" or k == "b" or sc == "b" then
        local inMove = MugShot._controller and MugShot._controller:IsInMoveMode()
        if inMove then
            local name, count = Entities.AddBuffToPlayer(EsoMock)
            hudNotification = string.format("[+ Buff Joueur : %s (%d actifs)]", name or "", count)
        else
            if not currentTarget then
                currentTarget = targets[1]
                arena:SnapCameraTo(currentTarget)
                Entities.SyncToMock(currentTarget, EsoMock)
            end
            local name, count = Entities.AddBuff(currentTarget, EsoMock)
            hudNotification = string.format("[+ Effet ajouté : %s (%d actifs)]", name or "", count)
        end
        hudNotificationTimer = 2.5

    elseif k == "-" or sc == "-" or k == "kp-" or sc == "kp-" or sc == "minus" or k == "subtract" or k == "n" or sc == "n" then
        local inMove = MugShot._controller and MugShot._controller:IsInMoveMode()
        if inMove then
            local name, count = Entities.RemoveBuffFromPlayer(EsoMock)
            hudNotification = name and string.format("[- Buff Joueur retiré : %s (%d restants)]", name, count) or "[Aucun buff joueur à retirer]"
        else
            if not currentTarget then
                currentTarget = targets[1]
                arena:SnapCameraTo(currentTarget)
                Entities.SyncToMock(currentTarget, EsoMock)
            end
            local name, count = Entities.RemoveBuff(currentTarget, EsoMock)
            hudNotification = name and string.format("[- Effet retiré : %s (%d restants)]", name, count) or "[Aucun effet à retirer sur la cible]"
        end
        hudNotificationTimer = 2.5

    elseif k == "t" or sc == "t" then
        if not currentTarget then
            currentTarget = targets[1]
            arena:SnapCameraTo(currentTarget)
            Entities.SyncToMock(currentTarget, EsoMock)
        end
        local count = Entities.ToggleStressTest(currentTarget, EsoMock)
        hudNotification = "[Stress Test : " .. count .. " buffs appliqués]"
        hudNotificationTimer = 2.0

    -- Solo / Group mode toggle
    elseif k == "g" or sc == "g" then
        isInGroup = not isInGroup
        Entities.ToggleGroup(isInGroup, EsoMock)
        hudNotification = "[Mode : " .. (isInGroup and "GROUPE (4j, débuffs partagés & multi-cast cyan)" or "SOLO (isolation stricte joueur)") .. "]"
        hudNotificationTimer = 3.0

    -- Toggle Mouse Look / Free Cursor
    elseif k == "tab" or sc == "tab" then
        mouseLookActive = not mouseLookActive
        love.mouse.setRelativeMode(mouseLookActive)
        hudNotification = mouseLookActive and "[Souris : Caméra première personne]" or "[Souris : Curseur libre]"
        hudNotificationTimer = 2.0

    -- Slash commands simulation
    elseif k == "m" or sc == "m" then
        if SLASH_COMMANDS and SLASH_COMMANDS["/mugshot"] then
            SLASH_COMMANDS["/mugshot"]("move")
        end
        isDragging = false
        local inMove = MugShot._controller and MugShot._controller:IsInMoveMode()
        if inMove then
            mouseLookActive = false
            love.mouse.setRelativeMode(false)
        else
            mouseLookActive = true
            love.mouse.setRelativeMode(true)
        end
        local lastMsg = (CHAT_SYSTEM and CHAT_SYSTEM.messages and CHAT_SYSTEM.messages[#CHAT_SYSTEM.messages])
        hudNotification = lastMsg or (inMove and MugShot.GetText("FRAME_UNLOCKED") or MugShot.GetText("FRAME_LOCKED"))
        hudNotificationTimer = 3.0

    elseif k == "x" or sc == "x" then
        if SLASH_COMMANDS and SLASH_COMMANDS["/mugshot"] then
            SLASH_COMMANDS["/mugshot"]("trial")
            local isTrial = MugShot.settings and MugShot.settings:Get().onlyHostileInTrials
            EsoMock.isPlayerInRaid = isTrial
            if MugShot._controller then
                MugShot._controller:OnZoneChanged()
            end
            local lastMsg = (CHAT_SYSTEM and CHAT_SYSTEM.messages and CHAT_SYSTEM.messages[#CHAT_SYSTEM.messages])
            hudNotification = lastMsg or (isTrial and MugShot.GetText("TRIAL_FILTER_ENABLED") or MugShot.GetText("TRIAL_FILTER_DISABLED"))
            hudNotificationTimer = 2.5
        end

    -- /mugshot reset [R] (Authentic ESO reset)
    elseif k == "r" or sc == "r" then
        if SLASH_COMMANDS and SLASH_COMMANDS["/mugshot"] then
            SLASH_COMMANDS["/mugshot"]("reset")
        end
        isDragging = false
        mouseLookActive = false
        love.mouse.setRelativeMode(false)

        local lastMsg = (CHAT_SYSTEM and CHAT_SYSTEM.messages and CHAT_SYSTEM.messages[#CHAT_SYSTEM.messages])
        hudNotification = lastMsg or MugShot.GetText("POSITION_RESET")
        hudNotificationTimer = 3.0

    -- Engine controls
    elseif k == "f5" or sc == "f5" then
        ReloadAddon(true)
    elseif k == "escape" or sc == "escape" then
        love.event.quit()
    end
end

function love.mousepressed(x, y, button)
    local inMove = MugShot._controller and MugShot._controller:IsInMoveMode()

    if button == 1 and frameRoot and inMove then
        local sw, sh = love.graphics.getDimensions()
        local box = LayoutSolver.Resolve(frameRoot, {}, sw, sh)
        if box then
            local fw = box.w or 381
            local fh = (box.h or 79) + 70

            if x >= box.x and x <= box.x + fw and y >= box.y and y <= box.y + fh then
                isDragging = true
                dragOffsetX = x - box.x
                dragOffsetY = y - box.y
                return
            end
        end
    end

    if button == 1 and not inMove and not mouseLookActive then
        -- Left click re-captures mouse into first-person camera mode
        mouseLookActive = true
        love.mouse.setRelativeMode(true)
    elseif button == 2 then
        isRightMouseDown = true
    end
end

function love.mousereleased(x, y, button)
    if button == 2 then
        isRightMouseDown = false
    elseif button == 1 and isDragging then
        isDragging = false
        if MugShot.settings and MugShot._controller and MugShot._controller:IsInMoveMode() and frameRoot then
            local isValid, point, _relTo, relPoint, offsetX, offsetY = frameRoot:GetAnchor(0)
            if isValid then
                MugShot.settings:Set("position", {
                    point         = point,
                    relativePoint = relPoint,
                    offsetX       = math.floor(offsetX + 0.5),
                    offsetY       = math.floor(offsetY + 0.5),
                })
            end
        end
    end
end

function love.mousemoved(x, y, dx, dy)
    if (mouseLookActive or isRightMouseDown) and arena then
        arena:RotateCamera(dx, dy)
    end
end
