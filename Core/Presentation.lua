-- =========================================================
-- MugShot - Presentation  (Core/Presentation.lua)
-- Transforms raw TargetState data into display-ready tables
-- consumed by TargetFrameView.  No ESO globals required;
-- pure data transformation with safe fallbacks.
-- =========================================================

local Presentation = {}

-- Helper to abbreviate large numbers cleanly (2.1m, 24.3k, etc.)
-- Abbreviate a number for display.
-- Examples:
--   950     -> "950"
--   2500    -> "2.5k"
--   5000    -> "5k"
--   24300   -> "24.3k"
--   2100000 -> "2.1m"
--   3000000 -> "3m"
local function FormatNumber(num)
    if not num then
        return "0"
    end

    if ZO_AbbreviateAndLocalizeNumber and NUMBER_ABBREVIATION_PRECISION_TENTHS then
        return ZO_AbbreviateAndLocalizeNumber(
                num,
                NUMBER_ABBREVIATION_PRECISION_TENTHS,
                true
        )
    end

    local function abbreviate(value, suffix)
        local precision = value >= 10 and 0 or 1
        local text = string.format("%." .. precision .. "f", value)

        -- Remove a trailing zero only when it carries no information:
        -- "5.0" becomes "5", while "2.5" remains "2.5".
        text = text:gsub("%.0$", "")

        return text .. suffix
    end

    if num >= 1000000 then
        return abbreviate(num / 1000000, "m")
    elseif num >= 1000 then
        return abbreviate(num / 1000, "k")
    end

    return tostring(math.floor(num))
end

-- ── BuildIdentity ─────────────────────────────────────────
-- @param  state     MugShot.TargetState instance
-- @param  _settings table returned by Settings:Get()
-- @return table  {
--     displayName    : string   (what to show in the name label)
--     r, g, b        : number   (reaction colour, 0–1 range)
--     portraitTexture: string | nil
--     raceIcon       : string | nil
--     allianceIcon   : string | nil
--     allianceColor  : table | nil
-- }
function Presentation.BuildIdentity(state, _settings)
    local id = state.identity

    -- Prefer the display name for players; fall back to name, then "Unknown"
    local nameStr
    if id.isPlayer and id.displayName and id.displayName ~= "" then
        nameStr = id.displayName
    elseif id.name and id.name ~= "" then
        nameStr = id.name
    else
        nameStr = (MugShot.GetText and MugShot.GetText("UNKNOWN")) or "Unknown"
    end

    -- Default colour: neutral grey when no reaction colour is set
    local r, g, b = 0.8, 0.8, 0.8
    if id.reactionR ~= nil then
        r, g, b = id.reactionR, id.reactionG, id.reactionB
    end

    local portraitTexture = id.portraitTexture
    local portraitCoords  = id.portraitCoords

    local isDummyOrMissing = not portraitTexture or portraitTexture == ""
        or (type(portraitTexture) == "string" and (portraitTexture:find("campaignbrowser_guestcampaign", 1, true) or portraitTexture:find("icon_missing", 1, true)))

    -- If user explicitly disabled custom Hodor icons in settings, or if portrait is a dummy/question mark, fall back to class icon
    if id.classIcon and id.classIcon ~= "" then
        if (_settings and _settings.useHodorIcons == false) or isDummyOrMissing then
            portraitTexture = id.classIcon
            portraitCoords  = nil
        end
    end

    return {
        displayName     = nameStr,
        r               = r,
        g               = g,
        b               = b,
        portraitTexture = portraitTexture,
        portraitCoords  = portraitCoords,
        raceIcon        = id.raceIcon,
        allianceIcon    = id.allianceIcon,
        allianceColor   = id.allianceColor,
    }
end

-- ── BuildVitals ───────────────────────────────────────────
-- @param  state     MugShot.TargetState instance
-- @param  _settings table returned by Settings:Get()
-- @return table  {
--     healthKnown   : bool
--     percentText   : string         e.g. "70%" or "100%"
--     healthText    : string | nil   e.g. "2.1M/3M" or "24.3K/24.3K [3.6K]"
--     healthPercent : number | nil   0–1
--     shieldPercent : number | nil   0–1
--     shield        : number
-- }
function Presentation.BuildVitals(state, _settings)
    local v = state.vitals

    if not v.healthKnown then
        return {
            healthKnown   = false,
            percentText   = "",
            healthText    = nil,
            healthPercent = nil,
            shieldPercent = 0,
            shield        = 0,
        }
    end

    local cur = v.currentHealth or 0
    local max = v.maxHealth     or 0
    local shield = v.shield     or 0
    local pct = (max > 0) and (cur / max) or 0
    local shieldPct = (max > 0) and (shield / max) or 0
    if shieldPct > 1 then shieldPct = 1 end

    local percentText = string.format("%d%%", math.floor(pct * 100 + 0.5))
    local healthText = FormatNumber(cur) .. "/" .. FormatNumber(max)
    if shield > 0 then
        healthText = healthText .. " [" .. FormatNumber(shield) .. "]"
    end

    return {
        healthKnown   = true,
        percentText   = percentText,
        healthText    = healthText,
        healthPercent = pct,
        shieldPercent = shieldPct,
        shield        = shield,
    }
end

-- ── FormatTimer ───────────────────────────────────────────
-- Formats countdown seconds cleanly:
--   < 60s  -> seconds ("59", "1")
--   >= 60s -> minutes ("1m", "59m")
--   >= 1h  -> hours ("1h", "2h")
local function FormatTimer(timer)
    if not timer or timer <= 0 then
        return ""
    end

    if timer >= 3600 then
        return string.format("%dh", math.floor(timer / 3600))
    elseif timer >= 60 then
        return string.format("%dm", math.floor(timer / 60))
    else
        local ceilTime = math.ceil(timer)
        if ceilTime >= 60 then
            return "1m"
        elseif ceilTime > 0 then
            return tostring(ceilTime)
        end
        return ""
    end
end

-- ── BuildEffects ──────────────────────────────────────────
-- Transforms raw active buffs into displayable items.
-- No artificial cap: renders all active buffs.
-- @param  state     MugShot.TargetState instance
-- @param  _settings table
-- @return table array of { icon, timerText, stackText }
function Presentation.BuildEffects(state, _settings)
    local raw = state.effects or {}
    local items = {}

    for i = 1, #raw do
        local eff = raw[i]
        local timerText = FormatTimer(eff.timer)

        local stackText = ""
        if eff.stackCount and eff.stackCount > 1 then
            stackText = tostring(eff.stackCount)
        end

        table.insert(items, {
            icon      = eff.icon,
            timerText = timerText,
            stackText = stackText,
        })
    end

    return items
end

MugShot.Presentation = Presentation
MugShot.logger:Info("=== Presentation loaded ===")
