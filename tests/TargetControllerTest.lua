-- =========================================================
-- MugShot - TargetControllerTest  (tests/TargetControllerTest.lua)
-- Standalone tests for Core/TargetController.lua.
-- All ESO globals are replaced with fakes.
-- =========================================================

MugShot = MugShot or {}
MugShot.logger = MugShot.logger or {
    Info=function()end, Debug=function()end,
    Warn=function()end, Error=function()end, Verbose=function()end,
}
TOPLEFT = 0
COMBAT_MECHANIC_FLAGS_HEALTH = 1
UNIT_REACTION_HOSTILE    = 1
UNIT_REACTION_PLAYER_ALLY = 4

local root = (arg and arg[0] and arg[0]:match("(.+)[/\\][^/\\]+$")) or "."
local EsoMock = dofile(root .. "/EsoMock.lua")
EsoMock.Init()
dofile(root .. "/../Constants.lua")
dofile(root .. "/../Localisation.lua")
dofile(root .. "/../Core/TargetState.lua")
dofile(root .. "/../Core/TargetPolicy.lua")
dofile(root .. "/../Core/Presentation.lua")
dofile(root .. "/../Core/TargetController.lua")

local TS   = MugShot.TargetState
local TC   = MugShot.TargetController
local pass, fail = 0, 0
local errors = {}

local function check(cond, msg)
    if cond then pass = pass + 1
    else fail = fail + 1; table.insert(errors, "FAIL: " .. (msg or "")) end
end

-- ── Fake helpers ──────────────────────────────────────────
local function makeView()
    return {
        _visible=nil, _reset=false, _identity=nil, _vitals=nil, _effects=nil, _privileged=nil,
        SetVisible  = function(self,v) self._visible = v end,
        SetIdentity = function(self,p) self._identity = p end,
        SetVitals   = function(self,p) self._vitals = p end,
        SetEffects  = function(self,p) self._effects = p end,
        SetPrivilegedDebuffs = function(self,d) self._privileged = d end,
        SetMoveMode = function(self,m) self._moveMode = m end,
        Reset       = function(self)   self._reset = true end,
        ApplyLayout = function(self,_) end,
    }
end

local function makeNative()
    return {
        _active=nil,
        Start                = function(self) end,
        Stop                 = function(self) end,
        SetReplacementActive = function(self,a) self._active = a end,
    }
end

local function makeBindings()
    return {
        _started=false,
        Start = function(self,_) self._started=true end,
        Stop  = function(self)   self._started=false end,
        StartEffectTimer = function(self) end,
        StopEffectTimer  = function(self) end,
        StartMoveModeEvents = function(self) end,
        StopMoveModeEvents  = function(self) end,
    }
end

local function makeSettings(overrides)
    local d = { enabled=true, locked=false, layout="compact",
                position={point=0,relativePoint=0,offsetX=100,offsetY=200} }
    if overrides then for k,v in pairs(overrides) do d[k]=v end end
    return {
        _data = d,
        Get   = function(self) return self._data end,
        Set   = function(self,k,v) self._data[k]=v end,
    }
end

local function makeAdapter(identityData, vitalsData)
    return {
        ReadIdentity = function(self,_)
            return identityData or {
                name="TestMob",displayName="",isPlayer=false,
                reaction=UNIT_REACTION_HOSTILE,reactionR=1,reactionG=0,reactionB=0
            }
        end,
        ReadVitals = function(self,_)
            return vitalsData or { healthKnown=true, currentHealth=500, maxHealth=1000 }
        end,
        ReadEffects = function(self,_)
            return {}
        end,
        IsInTrial = function(self) return false end,
    }
end

-- ── Test 1: RefreshTarget with no target ─────────────────
do
    DoesUnitExist = function() return false end
    local view    = makeView()
    local native  = makeNative()
    local state   = TS.New()
    local ctrl    = TC.New({
        state=state, adapter=makeAdapter(), eventBindings=makeBindings(),
        nativeBridge=native, view=view, settings=makeSettings(),
    })
    ctrl:RefreshTarget()
    check(view._visible == false, "T1: view hidden when no target")
    check(view._reset   == true,  "T1: view.Reset() called when no target")
    check(native._active == true, "T1: nativeBridge remains active (suppressed) when no target to prevent native frame flicker")
    check(state.exists == false,  "T1: state.exists false after no-target refresh")
end

-- ── Test 2: RefreshTarget with a target ──────────────────
do
    DoesUnitExist = function() return true end
    local view   = makeView()
    local native = makeNative()
    local state  = TS.New()
    local ctrl   = TC.New({
        state=state, adapter=makeAdapter(), eventBindings=makeBindings(),
        nativeBridge=native, view=view, settings=makeSettings(),
    })
    ctrl:RefreshTarget()
    check(view._visible == true,   "T2: view shown when target exists")
    check(native._active == true,  "T2: nativeBridge activated when target exists")
    check(view._identity ~= nil,   "T2: SetIdentity called")
    check(view._vitals   ~= nil,   "T2: SetVitals called")
    check(state.exists == true,    "T2: state.exists = true after refresh")
end

-- ── Test 3: generation fence — stale vitals ignored ──────
do
    -- Simulates: target appears, then disappears before RefreshVitals fires
    DoesUnitExist = function() return false end
    local view   = makeView()
    local native = makeNative()
    local state  = TS.New()
    local ctrl   = TC.New({
        state=state, adapter=makeAdapter(), eventBindings=makeBindings(),
        nativeBridge=native, view=view, settings=makeSettings(),
    })

    -- Manually set state to no-target
    state:ResetForTargetChange()
    state.exists = false

    -- Stale vitals callback arrives
    view._vitals = "STALE_MARKER"  -- pre-set to detect overwrite
    ctrl:RefreshVitals(9999, 9999, 9999)

    -- view._vitals must NOT have been updated (state.exists is false)
    check(view._vitals == "STALE_MARKER",
        "T3: stale RefreshVitals ignored when state.exists=false")

    -- ── Generation fence test across target change (Target A -> Target B) ──
    DoesUnitExist = function() return true end
    ctrl:RefreshTarget() -- Target A arrives (generation 2)
    local genA = ctrl:GetGeneration()
    ctrl:RefreshVitals(5000, 10000, 10000, genA)
    check(view._vitals.healthPercent == 0.5, "T3: Target A vitals accepted with valid gen")

    ctrl:RefreshTarget() -- Target B arrives (generation 3)
    local genB = ctrl:GetGeneration()
    check(genB > genA, "T3: Target B incremented generation")
    ctrl:RefreshVitals(8000, 10000, 10000, genB)
    check(view._vitals.healthPercent == 0.8, "T3: Target B vitals applied (0.8)")

    -- Delayed callback for Target A arrives with genA
    ctrl:RefreshVitals(1000, 10000, 10000, genA)
    check(view._vitals.healthPercent == 0.8, "T3: Stale callback with genA discarded by generation fence")
end

-- ── Test 4: RefreshVitals updates view when target exists ─
do
    DoesUnitExist = function() return true end
    local view   = makeView()
    local native = makeNative()
    local state  = TS.New()
    state.exists = true  -- simulate a live target
    local ctrl   = TC.New({
        state=state, adapter=makeAdapter(), eventBindings=makeBindings(),
        nativeBridge=native, view=view, settings=makeSettings(),
    })
    ctrl:RefreshVitals(750, 1000, 1000)
    check(view._vitals ~= nil,               "T4: SetVitals called by RefreshVitals")
    check(view._vitals.healthKnown == true,  "T4: healthKnown=true")
    check(view._vitals.healthPercent == 0.75, "T4: healthPercent=0.75 for 750/1000")

    -- Target dies (cur == 0): frame cleared immediately
    ctrl:RefreshVitals(0, 1000, 1000)
    check(view._visible == false, "T4: Target dies (cur=0) hides view")
    check(view._reset == true,    "T4: Target dies (cur=0) resets view")

    -- OnTargetDeath() event clears frame
    view._visible = true
    view._reset = false
    ctrl:OnTargetDeath()
    check(view._visible == false, "T4: OnTargetDeath() hides view")
    check(view._reset == true,    "T4: OnTargetDeath() resets view")
end

-- ── Test 5: Stop hides view ───────────────────────────────
do
    DoesUnitExist = function() return true end
    local view   = makeView()
    local native = makeNative()
    local state  = TS.New()
    local bind   = makeBindings()
    local ctrl   = TC.New({
        state=state, adapter=makeAdapter(), eventBindings=bind,
        nativeBridge=native, view=view, settings=makeSettings(),
    })
    ctrl:Stop()
    check(view._visible == false, "T5: Stop() hides the view")
    check(bind._started == false, "T5: Stop() unregisters event bindings")
    check(native._active == false, "T5: Stop() restores native frame (active=false)")
end

-- ── Test 6: SetMoveMode preserves visibility on no-target & immune to reticleover ──
do
    DoesUnitExist = function() return false end
    local view   = makeView()
    local native = makeNative()
    local state  = TS.New()
    local ctrl   = TC.New({
        state=state, adapter=makeAdapter(), eventBindings=makeBindings(),
        nativeBridge=native, view=view, settings=makeSettings(),
    })
    ctrl:SetMoveMode(true)
    check(view._visible == true, "T6: SetMoveMode(true) displays frame")
    ctrl:RefreshTarget() -- reticle event occurs
    check(view._visible == true, "T6: RefreshTarget does not hide frame during MoveMode")

    -- Verify Move Mode immunity to reticleover / insect vitals
    local initialHealth = state.vitals.currentHealth
    ctrl:RefreshVitals(1, 1, 1, nil, "reticleover")
    check(state.vitals.currentHealth == initialHealth, "T6: RefreshVitals from reticleover ignored in MoveMode")

    -- Verify player vitals update IS accepted in Move Mode
    ctrl:RefreshVitals(18000, 24000, 24000, nil, "player")
    check(state.vitals.currentHealth == 18000, "T6: RefreshVitals from player accepted in MoveMode")
    check(view._vitals.healthPercent == 18000/24000, "T6: View vitals updated with player health in MoveMode")

    -- Verify reticle death does not kill or reset frame in Move Mode
    ctrl:OnTargetDeath("reticleover")
    check(view._visible == true, "T6: OnTargetDeath(reticleover) does not hide frame in MoveMode")
    check(state.vitals.isDead == false, "T6: isDead remains false in MoveMode")

    ctrl:SetMoveMode(false)
    check(view._visible == false, "T6: SetMoveMode(false) restores target refresh (hides when no target)")
end

-- ── Test 7: SetDebugMode preserves visibility on no-target ─
do
    DoesUnitExist = function() return false end
    local view   = makeView()
    local native = makeNative()
    local state  = TS.New()
    local ctrl   = TC.New({
        state=state, adapter=makeAdapter(), eventBindings=makeBindings(),
        nativeBridge=native, view=view, settings=makeSettings(),
    })
    ctrl:SetDebugMode(true)
    check(view._visible == true, "T7: SetDebugMode(true) displays frame")
    ctrl:RefreshTarget()
    check(view._visible == true, "T7: RefreshTarget does not hide frame during DebugMode")
    ctrl:SetDebugMode(false)
    check(view._visible == false, "T7: SetDebugMode(false) restores target refresh")
end

-- ── Test 8: Dynamic reaction update (neutral -> enemy on hit or aggro) ─
do
    UNIT_REACTION_NEUTRAL = 2
    DoesUnitExist = function() return true end
    local currentReaction = UNIT_REACTION_NEUTRAL
    local currentR, currentG, currentB = 1.0, 0.85, 0.0

    local dynamicAdapter = {
        ReadIdentity = function(self, _)
            return {
                name = "Mudcrab",
                displayName = "",
                isPlayer = false,
                reaction = currentReaction,
                reactionR = currentR,
                reactionG = currentG,
                reactionB = currentB,
            }
        end,
        ReadVitals = function(self, _)
            return { healthKnown = true, currentHealth = 1000, maxHealth = 1000, shield = 0 }
        end,
        ReadEffects = function(self, _)
            return {}
        end,
    }

    local view   = makeView()
    local native = makeNative()
    local state  = TS.New()
    local ctrl   = TC.New({
        state = state, adapter = dynamicAdapter, eventBindings = makeBindings(),
        nativeBridge = native, view = view, settings = makeSettings(),
    })

    -- 1. Initial target is neutral (yellow: g=0.85)
    ctrl:RefreshTarget()
    check(view._identity.r == 1.0 and view._identity.g == 0.85, "T8: Initial target is neutral yellow")

    -- 2. Target turns hostile (e.g. attacked or proximity aggro: red: g=0.0)
    currentReaction = UNIT_REACTION_HOSTILE
    currentR, currentG, currentB = 1.0, 0.0, 0.0

    -- Power update arrives from damage
    ctrl:RefreshVitals(900, 1000, 1000)
    check(view._identity.g == 0.0, "T8: RefreshVitals immediately updates identity to hostile red")
    check(state.identity.reaction == UNIT_REACTION_HOSTILE, "T8: state.identity.reaction updated to hostile")

    -- 3. Target turns back to neutral, tested via direct RefreshIdentity()
    currentReaction = UNIT_REACTION_NEUTRAL
    currentR, currentG, currentB = 1.0, 0.85, 0.0
    ctrl:RefreshIdentity()
    check(view._identity.g == 0.85, "T8: RefreshIdentity immediately updates identity to neutral yellow")
end

-- ── Test 9: SetMoveMode reads and displays player data ──
do
    local requestedTag = nil
    local customAdapter = {
        ReadIdentity = function(self, tag)
            requestedTag = tag
            return {
                name = "MyHero",
                displayName = "@SubAccount",
                isPlayer = true,
                reaction = UNIT_REACTION_PLAYER_ALLY,
                reactionR = 0, reactionG = 1, reactionB = 0,
                portraitTexture = "/esoui/art/icons/class/gamepad/gp_class_sorcerer.dds",
                raceIcon = "/esoui/art/charactercreate/gamepad/charactercreate_bretonicon_down.dds",
                allianceIcon = "/esoui/art/stats/alliancebadge_aldmeri.dds",
            }
        end,
        ReadVitals = function(self, tag)
            return { healthKnown = true, currentHealth = 25000, maxHealth = 25000, shield = 5000 }
        end,
        ReadEffects = function(self, tag)
            return { { icon = "/esoui/art/icons/ability_sorcerer_001.dds", timer = 10 } }
        end,
    }
    local view   = makeView()
    local native = makeNative()
    local state  = TS.New()
    local ctrl   = TC.New({
        state=state, adapter=customAdapter, eventBindings=makeBindings(),
        nativeBridge=native, view=view, settings=makeSettings(),
    })
    ctrl:SetMoveMode(true)
    check(requestedTag == "player", "T9: SetMoveMode requests 'player' unitTag")
    check(view._identity.displayName == "@SubAccount", "T9: SetMoveMode displays account name when Hodor is ON")
    check(view._identity.portraitTexture == "/esoui/art/icons/class/gamepad/gp_class_sorcerer.dds", "T9: SetMoveMode displays player class portrait")
    check(view._vitals.healthPercent == 1.0, "T9: SetMoveMode displays player vitals")
    check(#view._effects == 1, "T9: SetMoveMode displays player effects")

    -- When Hodor is OFF, SetMoveMode displays character name
    local offSettings = { Get = function() return { useHodorIcons = false, trackGroupDebuffs = false } end, Save = function() end }
    local ctrlOff = TC.New({
        state=TS.New(), adapter=customAdapter, eventBindings=makeBindings(),
        nativeBridge=native, view=view, settings=offSettings,
    })
    ctrlOff:SetMoveMode(true)
    check(view._identity.displayName == "MyHero", "T9: SetMoveMode displays character name when Hodor is OFF")
end

-- ── Test 10: Trial filter suppresses native frame for non-hostiles ─
do
    DoesUnitExist = function(tag) return tag == "reticleover" end
    local customAdapter = {
        ReadIdentity = function() return { name = "Bastian", reaction = UNIT_REACTION_FRIENDLY } end,
        ReadVitals   = function() return { healthKnown = true, currentHealth = 30000, maxHealth = 30000 } end,
        ReadEffects  = function() return {} end,
        IsInTrial    = function() return true end,
    }
    local view   = makeView()
    local native = makeNative()
    local state  = TS.New()
    local settings = makeSettings({ onlyHostileInTrials = true })
    local ctrl   = TC.New({
        state=state, adapter=customAdapter, eventBindings=makeBindings(),
        nativeBridge=native, view=view, settings=settings,
    })
    ctrl:Start() -- initializes and calls RefreshTarget
    check(view._visible == false, "T10: Friendly unit in trial hides MugShot")
    check(native._active == true, "T10: Native target frame remains suppressed (active=true)")
end

-- ── Test 11: Combat grace period (350ms target retention) ─
do
    local targetExists = true
    DoesUnitExist = function(tag) return targetExists and tag == "reticleover" end
    EsoMock.isUnitInCombat["player"] = true

    local view   = makeView()
    local native = makeNative()
    local state  = TS.New()
    local ctrl   = TC.New({
        state=state, adapter=makeAdapter(), eventBindings=makeBindings(),
        nativeBridge=native, view=view, settings=makeSettings(),
    })
    ctrl:RefreshTarget()
    check(view._visible == true, "T11: Target acquired in combat, view visible")

    -- Target dodges / camera moves rapidly -> target temporarily nil
    targetExists = false
    ctrl:RefreshTarget()
    check(view._visible == true, "T11: View REMAINS visible during active combat grace period")
    check(ctrl._clearTargetTimerId ~= nil, "T11: Retention timer created")

    -- Grace period expires: zo_callLater fires
    local timerFn = EsoMock.timers[ctrl._clearTargetTimerId]
    check(type(timerFn) == "function", "T11: Timer callback registered in EsoMock")
    timerFn()
    check(view._visible == false, "T11: View hidden after grace period expires without target")

    -- Cleanup combat state
    EsoMock.isUnitInCombat["player"] = false
end

-- ── Test 12: Combat grace period cancelled when target re-acquired ─
do
    local targetExists = true
    DoesUnitExist = function(tag) return targetExists and tag == "reticleover" end
    EsoMock.isUnitInCombat["player"] = true

    local view   = makeView()
    local native = makeNative()
    local state  = TS.New()
    local ctrl   = TC.New({
        state=state, adapter=makeAdapter(), eventBindings=makeBindings(),
        nativeBridge=native, view=view, settings=makeSettings(),
    })
    ctrl:RefreshTarget()

    -- Target temporarily lost
    targetExists = false
    ctrl:RefreshTarget()
    local pendingTimerId = ctrl._clearTargetTimerId
    check(pendingTimerId ~= nil, "T12: Grace period timer active")

    -- Target re-acquired before timer expiration
    targetExists = true
    ctrl:RefreshTarget()
    check(ctrl._clearTargetTimerId == nil, "T12: Grace period timer cancelled upon target re-acquisition")
    check(EsoMock.timers[pendingTimerId] == nil, "T12: Timer unregistered from callLater")
    check(view._visible == true, "T12: View stays visible continuously")

    EsoMock.isUnitInCombat["player"] = false
end

-- ── Test 13: Local player targeting guard (3rd person camera) ─
do
    DoesUnitExist = function(tag) return true end
    AreUnitsEqual = function(t1, t2) return t1 == "reticleover" and t2 == "player" end -- reticleover is player

    local view   = makeView()
    local native = makeNative()
    local state  = TS.New()
    local ctrl   = TC.New({
        state=state, adapter=makeAdapter(), eventBindings=makeBindings(),
        nativeBridge=native, view=view, settings=makeSettings(),
    })
    ctrl:RefreshTarget()
    check(view._visible == false, "T13: Reticle pointing at local player is ignored and frame is hidden")
    check(state.exists == false, "T13: state.exists remains false for local player")

    -- Restore AreUnitsEqual
    AreUnitsEqual = function(t1, t2) return t1 == t2 end
end

-- ── Test 14: RefreshShield updates view shield vitals ──────
do
    DoesUnitExist = function(tag) return true end
    local currentShield = 0
    local adapter = {
        ReadIdentity = function() return { name = "Boss", reaction = UNIT_REACTION_HOSTILE } end,
        ReadVitals   = function() return { healthKnown = true, currentHealth = 20000, maxHealth = 20000, shield = currentShield } end,
        ReadEffects  = function() return {} end,
        IsInTrial    = function() return false end,
    }
    local view   = makeView()
    local native = makeNative()
    local state  = TS.New()
    local ctrl   = TC.New({
        state=state, adapter=adapter, eventBindings=makeBindings(),
        nativeBridge=native, view=view, settings=makeSettings(),
    })
    ctrl:RefreshTarget()
    check(view._vitals.shield == 0, "T14: Initial shield is 0")

    currentShield = 5000
    ctrl:RefreshShield()
    check(view._vitals.shield == 5000, "T14: RefreshShield updates view shield to 5000")
    check(view._vitals.shieldPercent > 0.24, "T14: Shield percent calculated accurately (~25%)")
end

-- ── Test 15: Target Dummy Neutral vs Hostile Reaction Switch ───────────
do
    DoesUnitExist = function() return true end
    AreUnitsEqual = function() return false end
    local dummyReaction = UNIT_REACTION_NEUTRAL
    local adapter = {
        ReadIdentity = function() return { name = "Target Iron Atronach, Trial", reaction = dummyReaction, attackable = true } end,
        ReadVitals   = function() return { healthKnown = true, currentHealth = 21000000, maxHealth = 21000000, shield = 0 } end,
        ReadEffects  = function()
            return {
                { name = "Crusher", tag = "CRUSH", timer = 4, icon = "/crusher.dds" },
                { name = "Major Breach", tag = "BREACH", timer = 18, icon = "/breach.dds" },
                { name = "Minor Breach", tag = "BREACH", timer = 22, icon = "/breach.dds" },
                { name = "Stumble", tag = "", timer = 2, icon = "/stumble.dds" },
            }
        end,
        IsInTrial    = function() return false end,
    }
    local view   = makeView()
    local native = makeNative()
    local state  = TS.New()
    local ctrl   = TC.New({
        state=state, adapter=adapter, eventBindings=makeBindings(),
        nativeBridge=native, view=view, settings=makeSettings(),
    })

    -- 1. Unattacked dummy is neutral: NO privileged debuffs!
    ctrl:RefreshTarget()
    check(view._privileged ~= nil and #view._privileged == 0, "T15: Neutral Target Dummy strictly has NO privileged debuffs on Line 3")

    -- 2. Dummy aggroed / attacked (reaction becomes UNIT_REACTION_HOSTILE): Dynamic Switch to Enemy layout!
    dummyReaction = UNIT_REACTION_HOSTILE
    ctrl:RefreshIdentity(true)
    ctrl:_UpdateEffectsView()
    check(view._privileged ~= nil and #view._privileged > 0, "T15: Hostile Target Dummy has privileged debuffs on Line 3")
    check(#view._effects == 1, "T15: Privileged debuffs excluded from bottom icon row (only Stumble remains)")
    check(view._effects[1].name == "Stumble", "T15: Remaining effect is non-privileged Stumble")
end

-- ── Test 16: Peaceful Neutral NPC (Neutral reaction + attackable = false) ─
do
    DoesUnitExist = function() return true end
    AreUnitsEqual = function() return false end
    local adapter = {
        ReadIdentity = function() return { name = "Pacifist Merchant", reaction = UNIT_REACTION_NEUTRAL, attackable = false } end,
        ReadVitals   = function() return { healthKnown = true, currentHealth = 5000, maxHealth = 5000, shield = 0 } end,
        ReadEffects  = function()
            return {
                { name = "Major Breach", tag = "BREACH", timer = 15, icon = "/breach.dds" },
            }
        end,
        IsInTrial    = function() return false end,
    }
    local view   = makeView()
    local native = makeNative()
    local state  = TS.New()
    local ctrl   = TC.New({
        state=state, adapter=adapter, eventBindings=makeBindings(),
        nativeBridge=native, view=view, settings=makeSettings(),
    })
    ctrl:RefreshTarget()
    check(view._privileged ~= nil and #view._privileged == 0, "T16: Peaceful Neutral has empty privileged debuffs row")
    check(#view._effects == 1, "T16: Effects on peaceful neutral are not excluded")
end

-- ── Test 17: Move Mode Enemy vs Player Toggle ─
do
    local view   = makeView()
    local native = makeNative()
    local state  = TS.New()
    local ctrl   = TC.New({
        state=state, adapter=makeAdapter(), eventBindings=makeBindings(),
        nativeBridge=native, view=view, settings=makeSettings(),
    })
    ctrl:SetMoveMode(true, "enemy")
    check(ctrl:GetMoveModeTarget() == "enemy", "T17: SetMoveMode(true, 'enemy') activates enemy target")
    check(view._privileged ~= nil and #view._privileged > 0, "T17: Enemy move mode populates privileged debuffs")
    check(view._identity.portraitTexture == "/esoui/art/icons/achievement_u29_dun2_flavorc.dds", "T17: Mock enemy has flaming Iron Atronach portrait")

    local nextTarget = ctrl:ToggleMoveModeTarget()
    check(nextTarget == "player", "T17: ToggleMoveModeTarget switched to player")
    check(ctrl:GetMoveModeTarget() == "player", "T17: Controller target is player")
    check(view._privileged ~= nil and #view._privileged == 0, "T17: Player move mode has empty privileged debuffs")

    local thirdTarget = ctrl:ToggleMoveModeTarget()
    check(thirdTarget == "enemy", "T17: ToggleMoveModeTarget switched back to enemy")
    check(view._privileged ~= nil and #view._privileged > 0, "T17: Enemy debuffs restored")
end

-- ── Test 18: SwapPrivilegedDebuffs ─
do
    local view   = makeView()
    local native = makeNative()
    local state  = TS.New()
    local settings = makeSettings()
    local ctrl   = TC.New({
        state=state, adapter=makeAdapter(), eventBindings=makeBindings(),
        nativeBridge=native, view=view, settings=settings,
    })
    ctrl:SetMoveMode(true, "enemy")
    local d1 = view._privileged[1].name
    local d2 = view._privileged[2].name
    ctrl:SwapPrivilegedDebuffs(1, 2)
    check(view._privileged[1].name == d2, "T18: Slot 1 now holds former slot 2 debuff")
    check(view._privileged[2].name == d1, "T18: Slot 2 now holds former slot 1 debuff")
    check(settings:Get().customDebuffs ~= nil, "T18: Swapped debuffs saved in settings")
end

-- ── Test 19: French Debuff Keywords Detection & Deduplication ─────────
do
    DoesUnitExist = function() return true end
    AreUnitsEqual = function() return false end
    local adapter = {
        ReadIdentity = function() return { name = "Boss Français", reaction = UNIT_REACTION_HOSTILE, attackable = true } end,
        ReadVitals   = function() return { healthKnown = true, currentHealth = 5000000, maxHealth = 5000000, shield = 0 } end,
        ReadEffects  = function()
            return {
                { name = "Écrasement", timer = 4, icon = "/crush.dds" },
                { name = "Brèche majeure", timer = 18, icon = "/breach.dds" },
                { name = "Friabilité mineure", timer = 10, icon = "/brittle.dds" },
                { name = "Autre effet", timer = 30, icon = "/autre.dds" },
            }
        end,
        IsInTrial    = function() return false end,
    }
    local view   = makeView()
    local native = makeNative()
    local state  = TS.New()
    local ctrl   = TC.New({
        state=state, adapter=adapter, eventBindings=makeBindings(),
        nativeBridge=native, view=view, settings=makeSettings(),
    })
    ctrl:RefreshTarget()
    check(#view._effects == 1, "T19: French debuffs (Écrasement, Brèche, Friabilité) deducted from bottom row, leaving 1 non-privileged effect")
    check(view._effects[1].name == "Autre effet", "T19: Remaining effect is 'Autre effet'")
    check(view._privileged ~= nil and #view._privileged > 0, "T19: Privileged debuffs table populated on Line 3")
end

-- ── Test 20: Enemy Move Mode Buff Isolation & Valid Fake Ability Icons ──
do
    local playerBuffs = {
        { name = "Major Sorcery", timer = 25, icon = "/sorcery.dds", castByPlayer = true },
        { name = "Major Prophecy", timer = 20, icon = "/prophecy.dds", castByPlayer = true },
    }
    local adapter = {
        ReadIdentity = function(self, tag)
            if tag == "player" then
                return { name = "MyHero", displayName = "@MyAccount", isPlayer = true }
            end
            return { name = "Mock Enemy", reaction = UNIT_REACTION_HOSTILE }
        end,
        ReadVitals = function(self, tag)
            return { healthKnown = true, currentHealth = 25000, maxHealth = 25000, shield = 0 }
        end,
        ReadEffects = function(self, tag)
            if tag == "player" then
                return playerBuffs
            end
            return {}
        end,
        IsInTrial = function(self) return false end,
    }
    local view = makeView()
    local native = makeNative()
    local state = TS.New()
    local ctrl = TC.New({
        state = state, adapter = adapter, eventBindings = makeBindings(),
        nativeBridge = native, view = view, settings = makeSettings(),
    })

    -- 1. Enter Move Mode in enemy target
    ctrl:SetMoveMode(true, "enemy")
    check(ctrl:GetMoveModeTarget() == "enemy", "T20: In move mode enemy")
    check(view._effects ~= nil and #view._effects > 0, "T20: Enemy mock has sample effects displayed")

    -- Check every mock ability has a valid icon
    local allHaveIcons = true
    for idx, eff in ipairs(view._effects) do
        if not eff.icon or eff.icon == "" then
            allHaveIcons = false
        end
    end
    check(allHaveIcons == true, "T20: All fake abilities on mock enemy have valid icons (none empty)")

    -- 2. Simulate player receiving a buff update (EVENT_EFFECT_CHANGED on "player")
    ctrl:RefreshEffects(nil, "player")
    check(#view._effects == 3, "T20: Player buff update ignored while on enemy mock (effects count is still 3 sample debuffs)")
    check(view._effects[1].name ~= "Major Sorcery", "T20: Player buff 'Major Sorcery' not transferred to enemy mock")

    -- 3. Switch to Player preview
    ctrl:ToggleMoveModeTarget()
    check(ctrl:GetMoveModeTarget() == "player", "T20: Switched to player preview")
    check(#view._effects == 2, "T20: Player preview displays player's 2 buffs")
    check(view._effects[1].name == "Major Sorcery", "T20: First effect on player preview is Major Sorcery")

    -- 4. Switch back to Enemy preview: player buffs must NOT linger or leak!
    ctrl:ToggleMoveModeTarget()
    check(ctrl:GetMoveModeTarget() == "enemy", "T20: Switched back to enemy preview")
    check(#view._effects == 3, "T20: Enemy preview restored sample effects (not player buffs)")
    check(view._effects[1].name ~= "Major Sorcery", "T20: Enemy preview no longer has player buffs")

    -- 5. Check Template debuffs immutability
    local tankBefore = TC.BUILDER_TEMPLATES.tank.debuffs[1].tag
    ctrl:SwapPrivilegedDebuffs(1, 2)
    local tankAfter = TC.BUILDER_TEMPLATES.tank.debuffs[1].tag
    check(tankBefore == tankAfter, "T20: SwapPrivilegedDebuffs does not mutate static BUILDER_TEMPLATES.tank.debuffs")
end

-- ── Test 21: Player vs Team Debuff Origin Logic ────────────────
do
    DoesUnitExist = function() return true end
    AreUnitsEqual = function() return false end

    local mockEffects = {}
    local adapter = {
        ReadIdentity = function(self) return { name = "Boss Dragon", reaction = UNIT_REACTION_HOSTILE, attackable = true } end,
        ReadVitals   = function(self) return { healthKnown = true, currentHealth = 5000000, maxHealth = 5000000, shield = 0 } end,
        ReadEffects  = function(self) return mockEffects end,
        IsInTrial    = function(self) return false end,
    }
    local view = makeView()
    local native = makeNative()
    local state = TS.New()
    local ctrl = TC.New({
        state = state, adapter = adapter, eventBindings = makeBindings(),
        nativeBridge = native, view = view, settings = makeSettings(),
    })

    -- Scenario 1: Player timer > Team timer for Crusher -> player wins (fromPlayer = true, timer = 8s)
    mockEffects = {
        { name = "Crusher", abilityId = 17906, timer = 8, playerTimer = 8, teamTimer = 4, castByPlayer = true, castByTeam = true },
    }
    ctrl:RefreshTarget()
    local pCrusher = nil
    for _, d in ipairs(view._privileged or {}) do
        if d.tag == "CRUSH" then pCrusher = d break end
    end
    check(pCrusher ~= nil, "T21: Found Crusher on Line 3")
    check(pCrusher.fromPlayer == true, "T21: Crusher fromPlayer is true when playerTimer (8s) > teamTimer (4s)")
    check(pCrusher.timerText == "8s", "T21: Crusher displays highest timer (8s)")

    -- Scenario 2: Team timer > Player timer for Crusher -> team wins (fromPlayer = false, timer = 12s)
    mockEffects = {
        { name = "Crusher", abilityId = 17906, timer = 12, playerTimer = 4, teamTimer = 12, castByPlayer = true, castByTeam = true },
    }
    ctrl:RefreshEffects()
    pCrusher = nil
    for _, d in ipairs(view._privileged or {}) do
        if d.tag == "CRUSH" then pCrusher = d break end
    end
    check(pCrusher ~= nil and pCrusher.fromPlayer == false, "T21: Crusher fromPlayer is false when teamTimer (12s) > playerTimer (4s)")
    check(pCrusher.timerText == "12s", "T21: Crusher displays team's higher timer (12s)")

    -- Scenario 3: Pair debuff (Breach): Major from player (15s > 8s), Minor from team (20s > 5s)
    mockEffects = {
        { name = "Major Breach", majorAbilityId = 61743, abilityId = 61743, timer = 15, playerTimer = 15, teamTimer = 8, castByPlayer = true, castByTeam = true },
        { name = "Minor Breach", minorAbilityId = 61742, abilityId = 61742, timer = 20, playerTimer = 5, teamTimer = 20, castByPlayer = true, castByTeam = true },
    }
    ctrl:RefreshEffects()
    local pBreach = nil
    for _, d in ipairs(view._privileged or {}) do
        if d.tag == "BREACH" then pBreach = d break end
    end
    check(pBreach ~= nil, "T21: Found Breach pair on Line 3")
    check(pBreach.majorFromPlayer == true, "T21: Major Breach majorFromPlayer is true (player 15s > team 8s)")
    check(pBreach.majorTimerText == "15s", "T21: Major Breach shows player timer 15s")
    check(pBreach.minorFromPlayer == false, "T21: Minor Breach minorFromPlayer is false (team 20s > player 5s)")
    check(pBreach.minorTimerText == "20s", "T21: Minor Breach shows team timer 20s")
end

-- ── Test 22: Layout Switching (classic vs compact) ─────────────
do
    DoesUnitExist = function() return true end
    AreUnitsEqual = function() return false end

    local adapter = {
        ReadIdentity = function(self) return { name = "Boss Dragon", reaction = UNIT_REACTION_HOSTILE, attackable = true } end,
        ReadVitals   = function(self) return { healthKnown = true, currentHealth = 5000000, maxHealth = 5000000, shield = 0 } end,
        ReadEffects  = function(self)
            return {
                { name = "Crusher", abilityId = 17906, timer = 8, playerTimer = 8, teamTimer = 0, castByPlayer = true },
            }
        end,
        IsInTrial    = function(self) return false end,
    }
    local view = makeView()
    local native = makeNative()
    local state = TS.New()
    local settings = makeSettings({ layout = "classic" })
    local ctrl = TC.New({
        state = state, adapter = adapter, eventBindings = makeBindings(),
        nativeBridge = native, view = view, settings = settings,
    })

    -- 1. In classic layout, enemy has NO privileged debuffs row
    ctrl:RefreshTarget()
    check(view._privileged ~= nil and #view._privileged == 0, "T22: In classic layout, privileged debuffs row is empty")

    -- 2. Switch to compact layout -> Line 3 privileged debuffs are populated!
    settings:Set("layout", "compact")
    ctrl:SetLayout("compact")
    check(view._privileged ~= nil and #view._privileged > 0, "T22: In compact layout, privileged debuffs row is populated")
    check(view._privileged[1].tag == "CRUSH", "T22: Crusher is displayed on Line 3 in compact layout")

    -- 3. Switch back to classic layout -> Line 3 privileged debuffs are removed again!
    settings:Set("layout", "classic")
    ctrl:SetLayout("classic")
    check(view._privileged ~= nil and #view._privileged == 0, "T22: Switching back to classic layout empties privileged debuffs")
end

print(string.format("[TargetControllerTest] %d passed, %d failed", pass, fail))
if fail > 0 then
    for _, e in ipairs(errors) do print("  " .. e) end
end
if fail > 0 then os.exit(1) end
