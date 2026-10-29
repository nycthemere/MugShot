-- =========================================================
-- MugShot - ESO Mock Harness  (tests/EsoMock.lua)
-- Provides a full simulated ESO environment for testing
-- components that depend on UI, events, controls, and API.
-- =========================================================

local EsoMock = {}

function EsoMock.Init()
    -- ── 1. Constants ─────────────────────────────────────────
    unpack = unpack or table.unpack

    TOPLEFT      = 0
    TOPRIGHT     = 1
    BOTTOMLEFT   = 2
    BOTTOMRIGHT  = 3
    CENTER       = 4

    COMBAT_MECHANIC_FLAGS_HEALTH = 1

    UNIT_REACTION_HOSTILE     = 1
    UNIT_REACTION_FRIENDLY    = 2
    UNIT_REACTION_NEUTRAL     = 3
    UNIT_REACTION_PLAYER_ALLY = 4
    UNIT_REACTION_NPC_ALLY    = 5
    UNIT_REACTION_COMPANION   = nil  -- Does NOT exist in ESO engine
    UNIT_REACTION_DEFAULT     = 7

    COLLECTIBLE_CATEGORY_TYPE_COMPANION = 27
    COLLECTIBLE_CATEGORY_TYPE_ASSISTANT = 8

    -- ── Collectibles & Abilities Mock Data ─────────────────────
    EsoMock.language = "en"
    EsoMock.SetLanguage = function(lang)
        EsoMock.language = lang
    end

    EsoMock.collectibles = {
        [27] = { 9245, 9353, 9911, 9912, 11113, 11114, 12172, 12173 },
        [8]  = { 6376, 6378, 8994, 10184 },
    }
    EsoMock.collectibleData = {
        [9245]  = { name = "Bastian Hallix^M", icon = "/esoui/art/icons/comp_bastian.dds" },
        [9353]  = { name = "Mirri Elendis^F", icon = "/esoui/art/icons/comp_mirri.dds" },
        [9911]  = { name = "Ember^F", nameFr = "Braise^F", icon = "/esoui/art/icons/comp_ember.dds" },
        [9912]  = { name = "Isobel Veloise^F", icon = "/esoui/art/icons/comp_isobel.dds" },
        [11113] = { name = "Sharp-as-Night^M", nameFr = "Vif-comme-la-Nuit^M", icon = "/esoui/art/icons/companion_sharp.dds" },
        [11114] = { name = "Azandar al-Cybiades^M", icon = "/esoui/art/icons/companion_azander.dds" },
        [12172] = { name = "Tanlorin^N", icon = "/esoui/art/icons/u44_companion_tanlorin.dds" },
        [12173] = { name = "Zerith-var^M", icon = "/esoui/art/icons/u44_companion_zerith.dds" },
        [6376]  = { name = "Ezabi the Banker", nameFr = "Ezabi la banquière", icon = "/esoui/art/icons/assistant_ezabibanker.dds" },
        [6378]  = { name = "Fezez the Merchant", nameFr = "Fezez le marchand", icon = "/esoui/art/icons/assistant_fezezmerchant.dds" },
        [8994]  = { name = "Baron Jangleplume, the Banker", nameFr = "Baron Plumepinson, le banquier", icon = "/esoui/art/crowncrates/rewards/cc_assistant_baronjangleplumethebanker.dds" },
        [10184] = { name = "Giladil the Ragpicker", nameFr = "Giladil la chiffonnière", icon = "/esoui/art/icons/assistant_giladiltheragpicker.dds" },
    }
    EsoMock.abilities = {
        -- Sorcerer
        [23304]  = { name = "Summon Unstable Familiar", nameFr = "Invocation de familier instable", icon = "/esoui/art/icons/ability_sorcerer_unstable_fimiliar_summoned.dds" },
        [23319]  = { name = "Volatile Familiar", nameFr = "Familier explosif", icon = "/esoui/art/icons/ability_sorcerer_speedy_familiar_summoned.dds" },
        [23316]  = { name = "Clannfear", nameFr = "Faucheclan", icon = "/esoui/art/icons/ability_sorcerer_unstable_clannfear_summoned.dds" },
        [24613]  = { name = "Winged Twilight", nameFr = "Crépuscule ailé", icon = "/esoui/art/icons/ability_sorcerer_lightning_matriarch_summoned.dds" },
        [24636]  = { name = "Twilight Tormentor", nameFr = "Tourmenteur crépusculaire", icon = "/esoui/art/icons/ability_sorcerer_lightning_matriarch_summoned.dds" },
        [24639]  = { name = "Twilight Matriarch", nameFr = "Matriarche crépusculaire", icon = "/esoui/art/icons/ability_sorcerer_lightning_matriarch_summoned.dds" },
        [23492]  = { name = "Storm Atronach", nameFr = "Atronach de foudre", icon = "/esoui/art/icons/ability_sorcerer_storm_atronach.dds" },
        [23495]  = { name = "Greater Storm Atronach", nameFr = "Grand atronach de foudre", icon = "/esoui/art/icons/ability_sorcerer_greater_storm_atronach.dds" },
        [23498]  = { name = "Charged Atronach", nameFr = "Atronach chargé", icon = "/esoui/art/icons/ability_sorcerer_storm_atronach.dds" },
        -- Warden
        [85982]  = { name = "Feral Guardian", nameFr = "Gardien féroce", icon = "/esoui/art/icons/ability_warden_018.dds" },
        [85986]  = { name = "Eternal Guardian", nameFr = "Gardien éternel", icon = "/esoui/art/icons/ability_warden_018_a.dds" },
        [85990]  = { name = "Wild Guardian", nameFr = "Gardien sauvage", icon = "/esoui/art/icons/ability_warden_018_b.dds" },
        [86122]  = { name = "Betty Netch", nameFr = "Netch femelle", icon = "/esoui/art/icons/ability_warden_014.dds" },
        [86126]  = { name = "Bull Netch", nameFr = "Netch mâle", icon = "/esoui/art/icons/ability_warden_014_a.dds" },
        [86130]  = { name = "Blue Betty", nameFr = "Netch bleue", icon = "/esoui/art/icons/ability_warden_014_b.dds" },
        -- Necromancer
        [117638] = { name = "Blastbones", nameFr = "Squelette explosif", icon = "/esoui/art/icons/ability_necromancer_002.dds" },
        [117645] = { name = "Stalking Blastbones", nameFr = "Squelette traqueur", icon = "/esoui/art/icons/ability_necromancer_002_a.dds" },
        [117650] = { name = "Blighted Blastbones", nameFr = "Squelette infectieux", icon = "/esoui/art/icons/ability_necromancer_002_b.dds" },
        [117749] = { name = "Skeletal Mage", nameFr = "Mage squelette", icon = "/esoui/art/icons/ability_necromancer_003.dds" },
        [117756] = { name = "Skeletal Arcanist", nameFr = "Arcaniste squelette", icon = "/esoui/art/icons/ability_necromancer_003_a.dds" },
        [117760] = { name = "Skeletal Archer", nameFr = "Archer squelette", icon = "/esoui/art/icons/ability_necromancer_003_b.dds" },
        [117812] = { name = "Spirit Mender", nameFr = "Soigneur spirituel", icon = "/esoui/art/icons/ability_necromancer_005.dds" },
        [117817] = { name = "Spirit Guardian", nameFr = "Gardien spirituel", icon = "/esoui/art/icons/ability_necromancer_005_a.dds" },
        [117822] = { name = "Intensive Mender", nameFr = "Soigneur intensif", icon = "/esoui/art/icons/ability_necromancer_005_b.dds" },
        [115540] = { name = "Frozen Colossus", nameFr = "Colosse de chair", icon = "/esoui/art/icons/ability_necromancer_006.dds" },
        [118600] = { name = "Glacial Colossus", nameFr = "Colosse glacial", icon = "/esoui/art/icons/ability_necromancer_006_a.dds" },
        [118605] = { name = "Pestilent Colossus", nameFr = "Colosse pestilentiel", icon = "/esoui/art/icons/ability_necromancer_006_b.dds" },
        -- Nightblade
        [25375]  = { name = "Summon Shade", nameFr = "Invocation d'ombre", icon = "/esoui/art/icons/ability_nightblade_006.dds" },
        [25380]  = { name = "Shadow Image", nameFr = "Image d'ombre", icon = "/esoui/art/icons/ability_nightblade_006_b.dds" },
        [25385]  = { name = "Dark Shade", nameFr = "Ombre noire", icon = "/esoui/art/icons/ability_nightblade_006_a.dds" },
        -- Arcanist
        [183122] = { name = "The Unblinking Eye", nameFr = "L'Œil sans paupière", icon = "/esoui/art/icons/ability_arcanist_016.dds" },
        [185805] = { name = "The Languid Eye", nameFr = "L'Œil languissant", icon = "/esoui/art/icons/ability_arcanist_016_a.dds" },
        [185810] = { name = "Tide King's Gaze", nameFr = "Regard du Roi des marées", icon = "/esoui/art/icons/ability_arcanist_016_b.dds" },
    }

    ZO_COLLECTIBLE_DATA_MANAGER = {
        GetCollectibleDataById = function(self, colId)
            local d = EsoMock.collectibleData[colId]
            if d then
                return {
                    GetName = function()
                        if EsoMock.language == "fr" and d.nameFr then return d.nameFr end
                        return d.name
                    end,
                    GetIcon = function() return d.icon end,
                    IsUnlocked = function() return true end,
                }
            end
            return nil
        end,
    }

    GetTotalCollectiblesByCategoryType = function(catType)
        local list = EsoMock.collectibles[catType]
        return list and #list or 0
    end
    GetCollectibleIdFromType = function(catType, idx)
        local list = EsoMock.collectibles[catType]
        return list and list[idx] or 0
    end
    GetCollectibleName = function(colId)
        local d = EsoMock.collectibleData[colId]
        if not d then return "" end
        if EsoMock.language == "fr" and d.nameFr then return d.nameFr end
        return d.name or ""
    end
    GetCollectibleIcon = function(colId)
        local d = EsoMock.collectibleData[colId]
        return d and d.icon or ""
    end
    GetCollectibleInfo = function(colId)
        local d = EsoMock.collectibleData[colId]
        if d then
            local n = (EsoMock.language == "fr" and d.nameFr) or d.name
            return n, "", d.icon, "", true, false, false, 0, ""
        end
        return "", "", "", "", false, false, false, 0, ""
    end
    GetCompanionName = function(defId)
        local colMap = { [1] = 9245, [2] = 9353, [5] = 9911, [6] = 9912, [8] = 11113, [9] = 11114, [12] = 12172, [13] = 12173 }
        local cId = colMap[defId]
        if cId and EsoMock.collectibleData[cId] then
            local d = EsoMock.collectibleData[cId]
            return (EsoMock.language == "fr" and d.nameFr) or d.name
        end
        return ""
    end
    GetCompanionCollectibleId = function(defId)
        local colMap = { [1] = 9245, [2] = 9353, [5] = 9911, [6] = 9912, [8] = 11113, [9] = 11114, [12] = 12172, [13] = 12173 }
        return colMap[defId] or 0
    end
    GetAbilityName = function(abilityId)
        local a = EsoMock.abilities[abilityId]
        if not a then return "" end
        if EsoMock.language == "fr" and a.nameFr then return a.nameFr end
        return a.name or ""
    end
    GetAbilityIcon = function(abilityId)
        local a = EsoMock.abilities[abilityId]
        return a and a.icon or ""
    end

    TEXT_ALIGN_LEFT   = 0
    TEXT_ALIGN_CENTER = 1
    TEXT_ALIGN_RIGHT  = 2
    TEXT_ALIGN_TOP    = 0
    TEXT_ALIGN_BOTTOM = 2

    ATTRIBUTE_VISUAL_POWER_SHIELDING = 1
    STAT_MITIGATION                  = 1
    ATTRIBUTE_HEALTH                 = 1

    REGISTER_FILTER_UNIT_TAG   = 1
    REGISTER_FILTER_POWER_TYPE = 2

    EVENT_RETICLE_TARGET_CHANGED         = 100
    EVENT_POWER_UPDATE                   = 101
    EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED    = 102
    EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED  = 103
    EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED  = 104
    EVENT_EFFECT_CHANGED                 = 105
    EVENT_DISPOSITION_UPDATE             = 106
    EVENT_UNIT_COMBAT_STATE_CHANGED      = 107
    EVENT_ADD_ON_LOADED                  = 108
    EVENT_UNIT_DEATH_STATE_CHANGED       = 109
    EVENT_PLAYER_ACTIVATED               = 131102

    ORIENTATION_HORIZONTAL = 0
    MOUSE_BUTTON_INDEX_LEFT = 1

    CT_TOPLEVELCONTROL = 1
    CT_CONTROL         = 2
    CT_BACKDROP        = 3
    CT_TEXTURE         = 4
    CT_LABEL           = 5

    -- ── 2. Control Factory & Registry ────────────────────────
    EsoMock.controls = {}

    local function MakeControl(name, parent, controlType)
        local ctrl = {
            name        = name,
            parent      = parent,
            controlType = controlType,
            hidden      = false,
            width       = 0,
            height      = 0,
            anchors     = {},
            handlers    = {},
            text        = "",
            font        = "",
            texture     = "",
            textureCoords = nil,
            color       = { 1, 1, 1, 1 },
            centerColor = { 0, 0, 0, 1 },
            edgeColor   = { 0, 0, 0, 1 },
            mouseEnabled = false,
            movable     = false,
            clamped     = false,
            moving      = false,
            drawLayer   = 0,
        }

        function ctrl:SetHidden(h) self.hidden = not not h end
        function ctrl:IsHidden() return self.hidden end
        function ctrl:SetDimensions(w, h) self.width, self.height = w, h end
        function ctrl:GetDimensions() return self.width, self.height end

        function ctrl:ClearAnchors() self.anchors = {} end
        function ctrl:SetAnchor(point, relTo, relPoint, x, y)
            table.insert(self.anchors, {
                isValid       = true,
                point         = point,
                relativeTo    = relTo,
                relativePoint = relPoint,
                offsetX       = x or 0,
                offsetY       = y or 0,
            })
        end
        function ctrl:GetAnchor(idx)
            local a = self.anchors[(idx or 0) + 1]
            if a then
                return a.isValid, a.point, a.relativeTo, a.relativePoint, a.offsetX, a.offsetY
            end
            return false, 0, nil, 0, 0, 0
        end
        function ctrl:SetAnchorFill(target)
            self:ClearAnchors()
            local rel = target or self.parent
            self:SetAnchor(TOPLEFT, rel, TOPLEFT, 0, 0)
            self:SetAnchor(BOTTOMRIGHT, rel, BOTTOMRIGHT, 0, 0)
        end

        function ctrl:SetMovable(m) self.movable = m end
        function ctrl:SetMouseEnabled(e) self.mouseEnabled = e end
        function ctrl:SetClampedToScreen(c) self.clamped = c end
        function ctrl:StartMoving() self.moving = true end
        function ctrl:StopMovingOrResizing() self.moving = false end

        function ctrl:SetText(t) self.text = tostring(t or "") end
        function ctrl:GetText() return self.text end
        function ctrl:SetFont(f) self.font = f end
        function ctrl:SetHorizontalAlignment(a) self.hAlign = a end
        function ctrl:SetVerticalAlignment(a) self.vAlign = a end

        function ctrl:SetTexture(tex) self.texture = tex end
        function ctrl:GetTexture() return self.texture end
        function ctrl:SetTextureCoords(l, r, t, b) self.textureCoords = { l, r, t, b } end
        function ctrl:SetCenterTexture(t) self.centerTexture = t end
        function ctrl:SetEdgeTexture(t, l, r, b) self.edgeTexture = { t, l, r, b } end
        function ctrl:SetColor(r, g, b, a) self.color = { r, g, b, a or 1 } end
        function ctrl:SetCenterColor(r, g, b, a) self.centerColor = { r, g, b, a or 1 } end
        function ctrl:SetEdgeColor(r, g, b, a) self.edgeColor = { r, g, b, a or 1 } end
        function ctrl:SetDrawLayer(l) self.drawLayer = l end
        function ctrl:SetGradientColors(...) self.gradient = { ... } end

        function ctrl:SetHandler(event, handler) self.handlers[event] = handler end
        function ctrl:TriggerHandler(event, ...)
            if self.handlers[event] then
                return self.handlers[event](self, ...)
            end
        end

        if name then EsoMock.controls[name] = ctrl end
        return ctrl
    end

    GuiRoot = MakeControl("GuiRoot", nil, CT_CONTROL)
    GuiRoot:SetDimensions(1920, 1080)

    WINDOW_MANAGER = {
        CreateControl = function(self, name, parent, controlType)
            return MakeControl(name, parent, controlType)
        end,
        CreateTopLevelWindow = function(self, name)
            return MakeControl(name, GuiRoot, CT_TOPLEVELCONTROL)
        end,
    }
    CreateControl = function(name, parent, controlType)
        return MakeControl(name, parent, controlType)
    end
    CreateTopLevelWindow = function(name)
        return MakeControl(name, GuiRoot, CT_TOPLEVELCONTROL)
    end

    -- ── 3. Native Target Frame ────────────────────────────────
    ZO_TargetUnitFramereticleover = MakeControl("ZO_TargetUnitFramereticleover", GuiRoot, CT_CONTROL)
    ZO_TargetUnitFramereticleover:SetHidden(false)

    -- ── 4. Scene Management ───────────────────────────────────
    EsoMock.fragments = {}
    local function MakeFragment(control)
        local frag = {
            control = control,
            conditionalFn = nil,
            SetConditional = function(f, fn) f.conditionalFn = fn end,
            Refresh = function(f)
                if f.conditionalFn then
                    f.control:SetHidden(not f.conditionalFn())
                end
            end,
        }
        table.insert(EsoMock.fragments, frag)
        return frag
    end
    ZO_HUDFadeSceneFragment = {
        New = function(self, control) return MakeFragment(control) end,
    }
    ZO_SimpleSceneFragment = {
        New = function(self, control) return MakeFragment(control) end,
    }

    ZO_PreHook = function(object, methodName, hookFunction)
        if type(object) == "table" and type(methodName) == "string" and type(hookFunction) == "function" then
            local originalMethod = object[methodName]
            object[methodName] = function(self, ...)
                if hookFunction(self, ...) then
                    return true
                end
                if originalMethod then
                    return originalMethod(self, ...)
                end
            end
            return true
        end
        return false
    end

    local function MakeScene()
        return {
            fragments = {},
            AddFragment = function(s, f) table.insert(s.fragments, f) end,
        }
    end
    HUD_SCENE    = MakeScene()
    HUD_UI_SCENE = MakeScene()

    -- ── 5. Event Manager Mock ─────────────────────────────────
    EsoMock.events = {}
    EsoMock.updates = {}

    EVENT_MANAGER = {
        RegisterForEvent = function(self, namespace, eventCode, callback)
            EsoMock.events[namespace] = {
                eventCode = eventCode,
                callback  = callback,
                filters   = {},
            }
        end,
        UnregisterForEvent = function(self, namespace, eventCode)
            EsoMock.events[namespace] = nil
        end,
        AddFilterForEvent = function(self, namespace, eventCode, filterType, filterValue)
            if EsoMock.events[namespace] then
                EsoMock.events[namespace].filters[filterType] = filterValue
            end
        end,
        RegisterForUpdate = function(self, namespace, intervalMs, callback)
            EsoMock.updates[namespace] = { intervalMs = intervalMs, callback = callback }
        end,
        UnregisterForUpdate = function(self, namespace)
            EsoMock.updates[namespace] = nil
        end,
    }

    function EsoMock.TriggerEvent(eventCode, ...)
        local matched = {}
        for ns, reg in pairs(EsoMock.events) do
            if reg.eventCode == eventCode then
                table.insert(matched, reg.callback)
            end
        end
        for _, cb in ipairs(matched) do
            cb(eventCode, ...)
        end
    end

    function EsoMock.TriggerUpdate(namespace)
        if EsoMock.updates[namespace] then
            EsoMock.updates[namespace].callback()
        end
    end

    -- ── 6. Chat & UI Mode ─────────────────────────────────────
    SLASH_COMMANDS = {}
    CHAT_SYSTEM = {
        messages = {},
        AddMessage = function(self, msg) table.insert(self.messages, msg) end,
    }

    EsoMock.cameraUIMode = false
    SetGameCameraUIMode = function(enabled)
        EsoMock.cameraUIMode = enabled
    end

    -- ── 7. Unit Data Store ────────────────────────────────────
    EsoMock.currentTime = 1000.0
    GetGameTimeSeconds = function() return EsoMock.currentTime end

    EsoMock.units = {}

    function EsoMock.SetUnit(unitTag, data)
        EsoMock.units[unitTag] = data
    end

    function EsoMock.ClearUnits()
        EsoMock.units = {}
    end

    DoesUnitExist = function(unitTag)
        local u = EsoMock.units[unitTag]
        return u ~= nil and u.exists ~= false
    end

    IsUnitDead = function(unitTag)
        local u = EsoMock.units[unitTag]
        return (u and (u.isDead or (u.currentHealth and u.currentHealth <= 0))) or false
    end

    GetUnitName = function(unitTag)
        local u = EsoMock.units[unitTag]
        return (u and u.name) or ""
    end

    GetUnitDisplayName = function(unitTag)
        local u = EsoMock.units[unitTag]
        return (u and u.displayName) or ""
    end

    IsUnitPlayer = function(unitTag)
        local u = EsoMock.units[unitTag]
        return (u and u.isPlayer) or false
    end

    GetUnitReaction = function(unitTag)
        local u = EsoMock.units[unitTag]
        return (u and u.reaction) or UNIT_REACTION_DEFAULT
    end

    GetUnitReactionColor = function(unitTag)
        local u = EsoMock.units[unitTag]
        if u and u.reactionColor then
            return u.reactionColor[1], u.reactionColor[2], u.reactionColor[3]
        end
        return 0.85, 0.85, 0.85
    end

    GetUnitClassId = function(unitTag)
        local u = EsoMock.units[unitTag]
        return u and u.classId
    end

    GetUnitRaceId = function(unitTag)
        local u = EsoMock.units[unitTag]
        return u and u.raceId
    end

    GetUnitAlliance = function(unitTag)
        local u = EsoMock.units[unitTag]
        return u and u.allianceId
    end

    IsPlayerInRaid = function()
        return EsoMock.isPlayerInRaid or false
    end

    IsPlayerInRaidStagingArea = function()
        return EsoMock.isPlayerInRaidStagingArea or false
    end

    GetUnitPower = function(unitTag, powerType)
        local u = EsoMock.units[unitTag]
        if not u or u.currentHealth == nil then return nil end
        return u.currentHealth, u.maxHealth or u.currentHealth, u.effectiveMax or u.maxHealth
    end

    GetUnitAttributeVisualizerEffectInfo = function(unitTag, visual, stat, attr, power)
        local u = EsoMock.units[unitTag]
        if u and visual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
            return u.shield or 0
        end
        return 0
    end

    GetNumBuffs = function(unitTag)
        local u = EsoMock.units[unitTag]
        if u and u.buffs then return #u.buffs end
        return 0
    end

    GetUnitBuffInfo = function(unitTag, index)
        local u = EsoMock.units[unitTag]
        if u and u.buffs and u.buffs[index] then
            local b = u.buffs[index]
            return b.name or "", b.timeStarted or 0, b.timeEnding or 0, index,
                   b.stackCount or 0, b.iconFilename or "", b.buffType or 0,
                   b.effectType or 0, b.abilityType or 0, b.statusEffectType or 0,
                   b.abilityId or 0, b.canClickOff or false, b.castByPlayer or false
        end
    end

    AreUnitsEqual = function(tag1, tag2)
        return tag1 == tag2
    end

    GetCVar = function(cvar)
        if cvar == "language.2" then return "en" end
        return ""
    end

    -- ── 8. MugShot Global Stub ────────────────────────────────
    MugShot = MugShot or {}
    MugShot.logger = {
        Info    = function() end,
        Debug   = function() end,
        Warn    = function() end,
        Error   = function() end,
        Verbose = function() end,
    }

    MugShotSV = {}
end

return EsoMock
