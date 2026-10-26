-- =========================================================
-- MugShot - Style  (UI/Style.lua)
-- Central style constants for the target frame UI.
-- Faithfully modelled on TargetFrame / targetframe.png.
-- =========================================================

MugShot.Style = {
    -- Dimensions matching targetframe.png
    BAR_WIDTH         = 300,
    BAR_HEIGHT        = 75,
    PORTRAIT_SIZE     = 75,
    PORTRAIT_BG_SIZE  = 79,
    FRAME_WIDTH       = 382, -- 300 bar + 79 portrait + 3 border
    FRAME_HEIGHT      = 79,

    -- Buff/Debuff effect dimensions
    EFFECT_ICON_SIZE  = 32,
    EFFECT_SLOT_SIZE  = 36,
    EFFECT_GAP        = 2,
    MAX_EFFECTS       = 10,  -- First row of 10 effects

    -- Reaction colours
    REACTION_COLORS = {
        [UNIT_REACTION_HOSTILE]     = { r = 0.84, g = 0.00, b = 0.00 }, -- Enemy Red
        [UNIT_REACTION_FRIENDLY]    = { r = 0.00, g = 0.80, b = 0.00 }, -- Friendly Green
        [UNIT_REACTION_PLAYER_ALLY] = { r = 0.00, g = 0.80, b = 0.00 }, -- Ally Green
        [UNIT_REACTION_NPC_ALLY]    = { r = 0.00, g = 0.80, b = 0.00 }, -- Ally Green
        [UNIT_REACTION_NEUTRAL]     = { r = 0.95, g = 0.80, b = 0.00 }, -- Neutral Yellow
        [UNIT_REACTION_COMPANION]   = { r = 0.00, g = 0.80, b = 0.00 }, -- Companion Green
        [UNIT_REACTION_DEFAULT]     = { r = 0.80, g = 0.80, b = 0.80 }, -- Default Grey
    },

    -- Shield overlay colour (translucent teal/cyan)
    SHIELD_COLOR = { r = 0.50, g = 0.85, b = 1.00, a = 0.65 },

    -- Background bar texture
    BAR_TEXTURE = "/esoui/art/progression/progression_progbar_genericfill.dds",

    -- Fonts
    FONT_PERCENTAGE = "$(BOLD_FONT)|20|soft-shadow-thick",
    FONT_HEALTH     = "$(BOLD_FONT)|18|soft-shadow-thick",
    FONT_NAME       = "$(BOLD_FONT)|18|soft-shadow-thick",
    FONT_TIMER      = "$(BOLD_FONT)|18|soft-shadow-thick",
    FONT_STACK      = "$(BOLD_FONT)|14|soft-shadow-thick",
}

MugShot.logger:Info("=== Style loaded ===")
