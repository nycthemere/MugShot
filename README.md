# MugShot

A high-performance target frame addon for Elder Scrolls Online, inspired by Hyperioxes’ TargetFrame. Designed for clarity in combat, it combines personalized portraits and precise buff and debuff tracking with granular controls to tailor the display to your playstyle.

<!-- commits:start -->
## History

- 2026.10.28-101044 — Refactor portraits, improve frame layouts, and fix move-mode vitals
  - Resolve portrait icons dynamically through collectible and ability APIs using a unified mapping.
  - Prevent reticleover target updates from overwriting player preview vitals in move mode (/mugshotmove).
  - Clear the target frame when the target dies (EVENT_UNIT_DEATH_STATE_CHANGED).
  - Expand the health bar to full width when no portrait icon is displayed.
  - Remove the 10-effect limit on buffs and debuffs, and format durations over 60 seconds in minutes or hours.
- 2026.10.26-101000 — Align addon manifest and metadata with ESOUI compliance guidelines.
- 2026-10-26 — Enhance UI layout and colors, add live move preview, Hodor icon support, and fix class portrait fallbacks.
- 2026-10-25 — Initial stable release.

<!-- commits:end -->