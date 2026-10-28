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
        _visible=nil, _reset=false, _identity=nil, _vitals=nil, _effects=nil,
        SetVisible  = function(self,v) self._visible = v end,
        SetIdentity = function(self,p) self._identity = p end,
        SetVitals   = function(self,p) self._vitals = p end,
        SetEffects  = function(self,p) self._effects = p end,
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
    }
end

local function makeSettings(overrides)
    local d = { enabled=true, locked=false,
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
    check(view._visible == false,  "T1: view hidden when no target")
    check(view._reset   == true,   "T1: view.Reset() called when no target")
    check(native._active == false, "T1: nativeBridge deactivated when no target")
    check(state.exists == false,   "T1: state.exists false after no-target refresh")
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
    check(view._identity.displayName == "MyHero", "T9: SetMoveMode displays player character name")
    check(view._identity.portraitTexture == "/esoui/art/icons/class/gamepad/gp_class_sorcerer.dds", "T9: SetMoveMode displays player class portrait")
    check(view._vitals.healthPercent == 1.0, "T9: SetMoveMode displays player vitals")
    check(#view._effects == 1, "T9: SetMoveMode displays player effects")
end

print(string.format("[TargetControllerTest] %d passed, %d failed", pass, fail))
for _, e in ipairs(errors) do print("  " .. e) end
if fail > 0 then os.exit(1) end
