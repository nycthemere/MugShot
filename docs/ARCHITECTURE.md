# MugShot — Architecture

## Overview

**MugShot** is an Elder Scrolls Online addon that replaces the default reticle-over target frame (`ZO_TargetUnitFramereticleover`) with a custom, repositionable, high-fidelity UI panel inspired by Hyperioxes' TargetFrame.

```text
MugShot/
├── Namespace.lua             Global table declaration
├── Defaults.lua              SavedVariables default values
├── Constants.lua             Addon-wide constants, colors & logger setup
├── Localisation.lua          Bilingual localization dictionary (fr / en)
├── Settings.lua              SavedVariables load/merge/persist (MugShotSV)
├── Main.lua                  Bootstrap, lifecycle management & slash commands
├── Data/
│   └── Portraits.lua         Boss, dummy, race and alliance portrait mappings
├── Core/
│   ├── TargetState.lua       Canonical runtime state (generation, exists, identity, vitals, effects)
│   ├── TargetPolicy.lua      Display-gate logic (ShouldDisplay)
│   ├── Presentation.lua      State → display-table transformation (pure Lua, lowercase m/k)
│   └── TargetController.lua  Orchestrator; coordinates state, adapter, policy, view & bridge
├── ESO/
│   ├── EsoAdapter.lua        Thin wrapper around raw ESO API calls (identity, vitals, shield, effects)
│   ├── EventBindings.lua     EVENT_MANAGER subscriptions and dynamic effect ticker
│   └── NativeFrameBridge.lua Reversible suppression of ZO_TargetUnitFramereticleover
├── UI/
│   ├── Style.lua             Central style constants, fonts, dimensions and color tables
│   └── TargetFrameView.lua   UI control construction, scene fragments & drag-and-drop
├── docs/
│   ├── ARCHITECTURE.md       ← this file
│   ├── API_NOTES.md          ESO API reference and findings
│   ├── TEST_PLAN.md          Testing strategy and scenarios
│   └── HANDOFF.md            Current state and handoff guide
└── tests/
    ├── run.lua               Combined test runner
    ├── TargetStateTest.lua
    ├── TargetPolicyTest.lua
    ├── PresentationTest.lua
    └── TargetControllerTest.lua
```

---

## Data Flow

```text
ESO Events (RETICLE_TARGET_CHANGED / POWER_UPDATE / ATTRIBUTE_VISUAL / EFFECT_CHANGED)
  │
  ▼
EventBindings  ──────────────────────────────────────────┐
  │                                                      │
  ▼                                                      │
TargetController.RefreshTarget()                         │
  ├─ state:ResetForTargetChange()   (increments gen)     │
  ├─ DoesUnitExist("reticleover")                        │
  │   └─ false → view:SetVisible(false)                  │
  │              nativeBridge:SetReplacementActive(false)│
  │              eventBindings:StopEffectTimer()         │
  │                                                      │
  └─ true → adapter:ReadIdentity()                       │
            adapter:ReadVitals()                         │
            adapter:ReadShield()                         │
            adapter:ReadEffects()                        │
            TargetPolicy.ShouldDisplay()                 │
            Presentation.BuildIdentity()                 │
            Presentation.BuildVitals()                   │
            Presentation.BuildEffects()                  │
            view:SetIdentity()                           │
            view:SetVitals()                             │
            view:SetEffects()                            │
            view:SetVisible(true)                        │
            nativeBridge:SetReplacementActive(true)      │
            eventBindings:CheckEffectTimer()             │
                                                         │
TargetController.RefreshVitals(cur, max, eff)  ◄─────────┤
  ├─ guard: state.exists == false → return               │
  ├─ state.vitals update                                 │
  └─ Presentation.BuildVitals() → view:SetVitals()       │
                                                         │
TargetController.RefreshShield(shield)        ◄─────────┤
  ├─ guard: state.exists == false → return               │
  ├─ state.vitals.shield update                          │
  └─ Presentation.BuildVitals() → view:SetVitals()       │
                                                         │
TargetController.RefreshEffects()              ◄─────────┘
  ├─ guard: state.exists == false → return
  ├─ adapter:ReadEffects() → state.effects update
  └─ Presentation.BuildEffects() → view:SetEffects()
```

---

## Generation Fence

`TargetState.generation` is incremented on every `ResetForTargetChange()`. Any callback that captures a generation value and fires asynchronously compares its captured generation to the current one and bails out if they differ. This prevents stale callbacks from overwriting the UI after a target change.

---

## Module Contracts

| Module | Input | Output / Side-effect |
|--------|-------|----------------------|
| `TargetState` | Mutated by controller | Exposes `generation`, `exists`, `identity`, `vitals`, `effects` |
| `TargetPolicy` | `(state, settings)` | `bool` — determines whether the frame should render |
| `Presentation` | `(state, settings)` | Pure display tables with formatted texts (`2.1m/3m`, `[3.6k]`) |
| `EsoAdapter` | `unitTag` | Safe extraction of identity, power, shield values, and active buffs |
| `EventBindings` | `controller` | Manages event subscriptions and periodic 250 ms effect timer |
| `NativeFrameBridge` | `active` | Safely hides or restores `ZO_TargetUnitFramereticleover` |
| `TargetFrameView` | Presentation tables | Renders status bar, shield overlay, portrait box, badges, and buff icons |
| `Settings` | SavedVariables table | Loads, merges with `Defaults`, and persists layout changes |
| `Localisation` | Client language | Supplies translated strings for chat, UI labels, and diagnostic output |
| `TargetController` | All of the above | Central orchestrator containing zero direct ESO UI code |

---

## Drag & Position Persistence

1. Repositioning mode is entered via `/mugshotmove`.
2. The game camera is set to UI mode (`SetGameCameraUIMode(true)`), displaying the mouse cursor.
3. The frame displays a live **WYSIWYG** representation of the player's character with a glowing cyan border (`0.2, 0.8, 1.0, 1.0`): live health updates, live damage shields, live buffs/debuffs, and real-time 250ms countdown timers.
4. Controls inside the frame handle `OnMouseDown` (`frame:StartMoving()`) and `OnMouseUp` (`frame:StopMovingOrResizing()`).
5. On mouse release, the primary anchor (`frame:GetAnchor(0)`) is captured and persisted to `MugShotSV`.
6. Retyping `/mugshotmove` locks the frame, restores normal camera mode, and switches back to live targeting.

---

## Scene Integration

The frame is attached to both `HUD_SCENE` and `HUD_UI_SCENE` via `ZO_HUDFadeSceneFragment:New(frame)`.
A conditional visibility check (`fragment:SetConditional(...)`) ensures the frame remains visible when entering chat mode (pressing `Enter`), inventory, or menus where HUD UI fragments are active, while hiding automatically when the reticle target is lost.

---

## Slash Commands

| Command | Description |
|---------|-------------|
| `/mugshot` | Toggle addon enabled / disabled |
| `/mugshotmove` | Toggle frame repositioning mode (unlocks frame, enables cursor & dummy preview) |
| `/mugshotreset` | Reset position to default (TOPLEFT 100, 200) and unlock for moving |
| `/mugshothodor` | Toggle custom HodorReflexes / LibCustomIcons avatars on/off (fallback to class icon) |

---

## Portrait & Avatar Resolution

When a player (self in move mode, or targeted player) is displayed:
1. **Custom Avatar**: If `useHodorIcons` is enabled (default: `true`), MugShot queries `LibCustomIcons` (`GetStatic` / `GetAnimated`) or `HodorReflexes.util.GetUserIcon` / `HodorReflexes.users` for the unit's `@displayName`. If found, the custom texture and sprite atlas coordinates (`portraitCoords`) are applied.
2. **Class Icon Fallback**: If no custom icon exists, or if `useHodorIcons` is toggled off (`/mugshothodor`), MugShot seamlessly falls back to the native gamepad class icon (`/esoui/art/icons/class/gamepad/gp_class_<class>.dds`).
3. **Monsters / NPCs**: Specific portraits (rockgrove bosses, dummies, trials) or monster defaults are displayed.
