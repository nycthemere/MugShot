# MugShot

A custom target frame with personalized portraits, buff and debuff tracking, and configurable display settings.

<!-- commits:start -->
<!-- ESOUI:start -->
## History

### 2026.11.05-101115 — Synchronize test harness and preview simulator with 3-line UI, debuff origins, and interactive Move Mode.

#### Added

- Differentiate player vs team debuff origins in preview with white/cyan timer labels and paired badges;
- Add 3-line compact target frame layout to preview simulator with 5-slot privileged debuffs row;
- Add interactive Move Mode handles for line swapping ([L1], [L2], [L3]), 6 quadrants, and debuff slots;
- Add [L] / [C] preview shortcut to toggle between 3-line compact and 2-line classic layouts;
- Add [O] shortcut to cycle debuff origin scenarios (mixed, all-player, all-team) on active targets;
- Add [P] shortcut and Move Mode button to toggle preview between enemy and player frames;
- Add [F2], [F3], and [F4] shortcuts to load tank, healer, and DPS role debuff templates on Line 3;
- Add unit tests for Target Dummy reaction switch and privileged debuffs suppression;
- Add unit tests for player vs team debuff origin resolution and paired Major/Minor origin colors;
- Add unit tests for runtime classic vs compact layout toggling and settings sync.

#### Fixed

- Fix Love2D UI renderer sorting by drawLevel within drawLayer, preventing backdrop occlusion;
- Correct Move Mode hit-testing bounding box to capture line swap handles positioned left of frame;
- Update simulator quadrant hit-testing to recognize 6-quadrant coordinate keys;
- Ensure race and alliance badge toggles remain hidden on non-player targets in Move Mode.

#### Improved

- Bump AddOnVersion to 101115 and Version to 2026.11.05-101115 in manifest, constants, and documentation;
- Default simulator startup layout to 3-line compact mode for immediate privileged debuffs inspection;
- Align module watch order in preview orchestrator with manifest load sequence;
- Update top HUD bar with layout and move target badges, and expand [F1] help modal.

### 2026.11.01-101111 — Align preview reset with native ESO move mode, resolve LayoutSolver anchors, and sanitize Love2D typography.

#### Fixed

- Align [R] key in preview simulator with authentic native ESO /mugshot reset behavior by centering the frame at TOP (0, 88), unlocking it, activating Move Mode, and freeing the mouse cursor;
- Correct inverted anchor constants (TOP and LEFT) in LayoutSolver to match EsoMock specifications;
- Fix frame dragging hit-testing to dynamically query resolved layout bounding boxes;
- Replace unrenderable Unicode emojis and symbols with standard text to prevent tofu glyph boxes in Love2D;
- Strip raw ESO color markup (|c...|r) from HUD chat notifications.

#### Improved

- Bump AddOnVersion to 101111 and Version to 2026.11.01-101111 in manifest, constants, and documentation;
- Align reset notification message in Localisation.lua with native centered top positioning;
- Decouple reload anchor overrides in preview main orchestrator, relying on TargetFrameView:ApplyLayout.

### 2026.10.31-101047 — Modularize preview simulator, decouple 3D arena from UI rendering, and align test harness with native ESO events.

#### Fixed

- Prevent buff and debuff truncation during simulator stress tests ([T]) and manual additions ([B]) in solo mode by flagging catalog samples as player-cast;
- Eliminate spurious cyan borders in solo mode within the preview engine by ensuring multi-source merges require active group or companion status;
- Prevent text alignment drift in Love2D by deriving label coordinates from native hAlign and vAlign control properties instead of hardcoded font heuristics.

#### Added

- Add Arena3D.lua to isolate first-person camera projection, WASD/ZQSD movement, arena geometry, and crosshair raycast targeting;
- Add Entities.lua to centralize interactive target definitions, sample buff catalogs, and event-driven state transitions;
- Add EsoUiRenderer.lua as a decoupled, agnostic renderer for ESO backdrop, texture, and label controls in Love2D.

#### Improved

- Refactor tests/preview/main.lua from a monolithic 1350-line file into a concise orchestrator managing the arena, mock engine, and UI renderer;
- Drive simulator mutations purely through standard ESO events (EVENT_RETICLE_TARGET_CHANGED, EVENT_POWER_UPDATE, EVENT_EFFECT_CHANGED, EVENT_GROUP_MEMBER_JOINED/LEFT) rather than invoking private controller methods;
- Update EsoAdapterTest.lua to validate unfiltered group debuff display, multi-cast badge merging, and strict solo-mode isolation.

#### Removed

- Remove hardcoded control-name branches (isTimer, isSource, isStack) from the preview drawing pipeline;
- Remove obsolete unit tests that asserted against the deleted debuff whitelist and name pre-caching routines.

### 2026.10.31-101047 — Improve target tracking, refine effect layouts, and align default frame positioning.

#### Fixed

- Prevent the target frame from targeting the local player when enemies die in third-person view by checking AreUnitsEqual against "player";
- Clear dead targets promptly by aligning EVENT_UNIT_DEATH_STATE_CHANGED handling with native ZOS behavior and removing the ineffective C++ event filter;
- Prevent buff and debuff text clipping by positioning source multipliers at BOTTOMLEFT and stack counts at TOPRIGHT on the outer slot frame, with centered timers set to 13pt bold.

#### Added

- Add `/mugshot debuffs [on|off]` to toggle group and companion debuff tracking, enabled by default;
- Add a 350 ms target retention grace period during active combat to reduce frame flicker during dodges and rapid camera movements;
- Centralize UI and reaction colors in Constants.RGBA.

#### Improved

- Align the default frame position with the native ESO target frame anchor: TOP, GuiRoot, TOP, 0, 88;
- Reuse Defaults.position as the single source of truth for `/mugshot reset`;
- Recycle active buff and debuff parsing buffers to reduce garbage collection overhead;
- Decouple Move Mode from gameplay by registering player vitals listeners only while configuring the frame;
- Resolve tracked group debuff names dynamically through GetAbilityName(abilityId) to support the game client's language without manual translation tables.

#### Removed

- Remove the hardcoded multilingual dictionary for tracked group debuffs;
- Remove redundant API existence guards and duplicate event filter checks.

### 2026.10.30-101046 — Eliminate redundant API guards, leverage native event filters, and streamline namespace.

- Consolidate addon initialization into Defaults.lua and remove obsolete Namespace.lua;
- Cache MugShot namespace locally across all modules for optimized upvalue access;
- Utilize native EVENT_MANAGER filters for EVENT_ADD_ON_LOADED, power, and shield events;
- Remove redundant nil checks and pcall wrappers around standard ESO UI and engine APIs;
- Add AI disclosure notice and remove version constraints from OptionalDependsOn in manifest.

### 2026.10.29-101045 — Streamline effect filtering, optimize rendering, and eliminate target flicker.

- Filter effects by castByPlayer during extraction to remove raid clutter and avoid unnecessary allocations;
- Replace effect truncation with preallocated slots and dynamic row expansion;
- Reuse presentation buffers and share timer and stack strings to minimize garbage collection;
- Add UI dirty flags to skip redundant updates and layout recalculations;
- Cache frequently used Lua and ESO functions in local upvalues;
- Keep the native target frame suppressed during target changes and target loss;
- Replace fade transitions with immediate visibility updates;
- Refactor target policies into extensible strategies;
- Unify slash commands with optional LibSlashCommander autocompletion and native fallback;
- Use official ESO APIs for trial detection.

### 2026.10.28-101044 — Refactor portraits, improve frame layouts, and fix move-mode vitals.

- Resolve portrait icons dynamically through collectible and ability APIs using a unified mapping;
- Prevent reticleover target updates from overwriting player preview vitals in move mode (/mugshot move);
- Clear the target frame when the target dies (EVENT_UNIT_DEATH_STATE_CHANGED);
- Expand the health bar to full width when no portrait icon is displayed;
- Remove the 10-effect limit on buffs and debuffs, and format durations over 60 seconds in minutes or hours.

### 2026.10.26-101000 — Align addon manifest and metadata with ESOUI compliance guidelines.
<!-- ESOUI:end -->
### 2026-10-26 — Enhance UI layout and colors, add live move preview, Hodor icon support, and fix class portrait fallbacks.

### 2026-10-25 — Initial stable release.

<!-- commits:end -->
