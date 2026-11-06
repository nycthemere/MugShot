-- =========================================================
-- MugShot - EsoUiRenderer  (tests/preview/EsoUiRenderer.lua)
-- Completely agnostic renderer for ESO UI controls in Love2D.
-- Does not contain ANY MugShot-specific rules or hacks:
-- reads only standard ESO control properties:
--   - Dimensions, anchors (via LayoutSolver)
--   - CT_BACKDROP: centerColor, edgeColor
--   - CT_TEXTURE: texture, textureCoords, color
--   - CT_LABEL: text, color, font, hAlign, vAlign
-- =========================================================

local LayoutSolver = require("LayoutSolver")

local EsoUiRenderer = {}
EsoUiRenderer.__index = EsoUiRenderer

-- ESO Alignment Constants
local TEXT_ALIGN_LEFT   = 0
local TEXT_ALIGN_CENTER = 1
local TEXT_ALIGN_RIGHT  = 2
local TEXT_ALIGN_TOP    = 0
local TEXT_ALIGN_BOTTOM = 2

local function IsEffectivelyVisible(ctrl)
    local cur = ctrl
    while cur do
        if cur.hidden == true then return false end
        cur = cur.parent
    end
    return true
end

function EsoUiRenderer.New(fonts)
    local self = setmetatable({}, EsoUiRenderer)
    self.fonts = fonts or {}
    return self
end

function EsoUiRenderer:ResolveFont(ctrl)
    local f = self.fonts.fontMain
    local name = ctrl.name or ""
    local fontDef = ctrl.font or ""

    if name:find("TargetName") or name:find("Percentage") then
        f = self.fonts.fontTitle or f
    elseif name:find("PrivilegedSingle") then
        f = self.fonts.fontSmall or f
    elseif name:find("PrivilegedHeader") then
        f = self.fonts.fontTiny or self.fonts.fontSmall or f
    elseif name:find("PrivilegedMajor") or name:find("PrivilegedMinor") then
        f = self.fonts.fontTiny or self.fonts.fontSmall or f
    elseif name:find("LineHandleText") then
        f = self.fonts.fontSmall or f
    elseif name:find("MoveTargetBtn") or name:find("BadgeToggle") then
        f = self.fonts.fontBadge or self.fonts.fontSmall or f
    elseif name:find("Timer") then
        f = self.fonts.fontTimer or f
    elseif name:find("Stack") or name:find("Source") then
        f = self.fonts.fontBadge or f
    elseif fontDef:find("9") or fontDef:find("10") then
        f = self.fonts.fontTiny or self.fonts.fontSmall or f
    elseif fontDef:find("11") or fontDef:find("12") then
        f = self.fonts.fontSmall or f
    elseif fontDef:find("16") or fontDef:find("18") or fontDef:find("20") then
        f = self.fonts.fontTitle or f
    end

    return f
end

function EsoUiRenderer:Draw(controls, sw, sh)
    local boxes = {}
    local drawList = {}

    for _, ctrl in pairs(controls or {}) do
        if IsEffectivelyVisible(ctrl) and ctrl.name ~= "GuiRoot" then
            local box = LayoutSolver.Resolve(ctrl, boxes, sw, sh)
            if box and box.w > 0 and box.h > 0 then
                local layer = ctrl.drawLayer or 0
                local level = (ctrl.GetDrawLevel and ctrl:GetDrawLevel()) or ctrl.drawLevel or 0
                table.insert(drawList, { ctrl = ctrl, box = box, layer = layer, level = level })
            end
        end
    end

    table.sort(drawList, function(a, b)
        if a.layer ~= b.layer then
            return a.layer < b.layer
        end
        return a.level < b.level
    end)

    for _, item in ipairs(drawList) do
        local ctrl = item.ctrl
        local b = item.box

        -- 1. Backdrop Controls
        if ctrl.controlType == CT_BACKDROP then
            local cc = ctrl.centerColor or { 0.08, 0.08, 0.08, 1.0 }
            love.graphics.setColor(cc[1], cc[2], cc[3], cc[4] or 1.0)
            love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)

            local ec = ctrl.edgeColor or { 0.12, 0.14, 0.18, 1.0 }
            love.graphics.setColor(ec[1] or 0.12, ec[2] or 0.14, ec[3] or 0.18, ec[4] or 1.0)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", b.x, b.y, b.w, b.h)

        -- 2. Texture Controls
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
                love.graphics.setFont(self.fonts.fontSmall)
                love.graphics.printf(shortName:sub(1, 12), b.x + 2, b.y + b.h / 2 - 6, b.w - 4, "center")

            elseif isEffectIcon then
                love.graphics.setColor(0.10, 0.12, 0.15, 1.0)
                love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
                love.graphics.setColor(0.24, 0.28, 0.35, 0.8)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", b.x, b.y, b.w, b.h)

                local shortName = (ctrl.texture or ""):match("([^/]+)%.dds$") or ""
                if shortName ~= "" and (self.fonts.fontTiny or self.fonts.fontSmall) then
                    love.graphics.setFont(self.fonts.fontTiny or self.fonts.fontSmall)
                    love.graphics.setColor(0.65, 0.70, 0.78, 0.75)
                    local abbr = shortName:gsub("ability_", ""):gsub("debuff_", ""):gsub("buff_", ""):sub(1, 4):upper()
                    love.graphics.printf(abbr, b.x, b.y + b.h - 11, b.w, "center")
                end

            elseif isBadge then
                local tc = ctrl.color or { 1.0, 1.0, 1.0, 1.0 }
                love.graphics.setColor(0.08, 0.10, 0.12, 0.95)
                love.graphics.circle("fill", b.x + b.w / 2, b.y + b.h / 2, b.w / 2)
                love.graphics.setColor(tc[1], tc[2], tc[3], tc[4] or 1.0)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", b.x + b.w / 2, b.y + b.h / 2, b.w / 2)

                local badgeLetter = ctrl.name:find("Race") and "R" or "A"
                love.graphics.setFont(self.fonts.fontSmall)
                love.graphics.printf(badgeLetter, b.x, b.y + b.h / 2 - 6, b.w, "center")

            else
                local tc = ctrl.color or { 1.0, 1.0, 1.0, 1.0 }
                love.graphics.setColor(tc[1], tc[2], tc[3], tc[4] or 1.0)
                love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
            end

        -- 3. Label Controls
        elseif ctrl.controlType == CT_LABEL then
            local text = ctrl:GetText()
            if text and text ~= "" then
                local col = ctrl.color or { 1.0, 1.0, 1.0, 1.0 }
                local f = self:ResolveFont(ctrl)
                love.graphics.setFont(f)

                local align = "left"
                local textX = b.x
                local textW = b.w
                local textY = b.y

                -- Generic Horizontal Alignment
                if ctrl.hAlign == TEXT_ALIGN_RIGHT then
                    align = "right"
                    textX = b.x
                    textW = b.w - 2
                elseif ctrl.hAlign == TEXT_ALIGN_CENTER then
                    align = "center"
                    textX = b.x
                    textW = b.w
                else
                    align = "left"
                    textX = b.x
                    textW = b.w
                end

                -- Generic Vertical Alignment
                if ctrl.vAlign == TEXT_ALIGN_CENTER then
                    textY = b.y + math.floor((b.h - f:getHeight()) / 2)
                elseif ctrl.vAlign == TEXT_ALIGN_BOTTOM then
                    textY = b.y + b.h - f:getHeight() - 1
                else
                    textY = b.y + 1
                end

                -- 4-way contrast outline
                love.graphics.setColor(0.0, 0.0, 0.0, 0.95)
                love.graphics.printf(text, textX + 1, textY + 1, textW, align)
                love.graphics.printf(text, textX - 1, textY + 1, textW, align)
                love.graphics.printf(text, textX + 1, textY - 1, textW, align)
                love.graphics.printf(text, textX - 1, textY - 1, textW, align)

                -- Foreground text color directly from control
                love.graphics.setColor(col[1], col[2], col[3], col[4] or 1.0)
                love.graphics.printf(text, textX, textY, textW, align)
            end
        end
    end
end

return EsoUiRenderer
