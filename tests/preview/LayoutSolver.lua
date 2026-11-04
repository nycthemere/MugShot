-- =========================================================
-- MugShot - LayoutSolver  (tests/preview/LayoutSolver.lua)
-- Resolves ESO UI relative anchors and dimensions to
-- absolute pixel bounding boxes (x, y, w, h).
-- =========================================================

local LayoutSolver = {}

-- ESO Anchor constants matching EsoMock
local TOPLEFT     = _G.TOPLEFT     or 0
local TOPRIGHT    = _G.TOPRIGHT    or 1
local BOTTOMLEFT  = _G.BOTTOMLEFT  or 2
local BOTTOMRIGHT = _G.BOTTOMRIGHT or 3
local CENTER      = _G.CENTER      or 4
local LEFT        = _G.LEFT        or 5
local RIGHT       = _G.RIGHT       or 6
local TOP         = _G.TOP         or 7
local BOTTOM      = _G.BOTTOM      or 8

local function GetAnchorPointCoords(box, point)
    local x, y, w, h = box.x, box.y, box.w, box.h
    if point == TOPLEFT then     return x, y
    elseif point == TOP then     return x + w / 2, y
    elseif point == TOPRIGHT then return x + w, y
    elseif point == LEFT then     return x, y + h / 2
    elseif point == CENTER then   return x + w / 2, y + h / 2
    elseif point == RIGHT then    return x + w, y + h / 2
    elseif point == BOTTOMLEFT then return x, y + h
    elseif point == BOTTOM then   return x + w / 2, y + h
    elseif point == BOTTOMRIGHT then return x + w, y + h
    end
    return x, y
end

function LayoutSolver.Resolve(ctrl, resolvedBoxes, screenW, screenH)
    if not ctrl then return nil end
    if resolvedBoxes[ctrl] then return resolvedBoxes[ctrl] end

    -- GuiRoot is the root viewport
    if ctrl.name == "GuiRoot" then
        local box = { x = 0, y = 0, w = screenW or 1280, h = screenH or 720 }
        resolvedBoxes[ctrl] = box
        return box
    end

    local w, h = ctrl.width or 0, ctrl.height or 0

    -- If label has no explicit dimensions, give it reasonable bounds for text rendering
    if ctrl.controlType == CT_LABEL then
        local txtLen = ctrl.text and #ctrl.text or 0
        if w <= 0 then w = math.max(140, txtLen * 10) end
        if h <= 0 then h = 22 end
    end
    local anchors = ctrl.anchors or {}

    if #anchors == 0 then
        local pBox = (ctrl.parent and LayoutSolver.Resolve(ctrl.parent, resolvedBoxes, screenW, screenH))
            or { x = 0, y = 0, w = screenW or 1280, h = screenH or 720 }
        local box = { x = pBox.x, y = pBox.y, w = w, h = h }
        resolvedBoxes[ctrl] = box
        return box
    end

    if #anchors == 1 then
        local a = anchors[1]
        local relTo = a.relativeTo or ctrl.parent
        local relBox = LayoutSolver.Resolve(relTo, resolvedBoxes, screenW, screenH)
            or { x = 0, y = 0, w = screenW or 1280, h = screenH or 720 }

        local targetX, targetY = GetAnchorPointCoords(relBox, a.relativePoint or a.point or TOPLEFT)
        targetX = targetX + (a.offsetX or 0)
        targetY = targetY + (a.offsetY or 0)

        local myPoint = a.point or TOPLEFT
        local curX, curY = targetX, targetY

        if myPoint == TOPLEFT then
            curX, curY = targetX, targetY
        elseif myPoint == TOP then
            curX, curY = targetX - w / 2, targetY
        elseif myPoint == TOPRIGHT then
            curX, curY = targetX - w, targetY
        elseif myPoint == LEFT then
            curX, curY = targetX, targetY - h / 2
        elseif myPoint == CENTER then
            curX, curY = targetX - w / 2, targetY - h / 2
        elseif myPoint == RIGHT then
            curX, curY = targetX - w, targetY - h / 2
        elseif myPoint == BOTTOMLEFT then
            curX, curY = targetX, targetY - h
        elseif myPoint == BOTTOM then
            curX, curY = targetX - w / 2, targetY - h
        elseif myPoint == BOTTOMRIGHT then
            curX, curY = targetX - w, targetY - h
        end

        local box = { x = curX, y = curY, w = w, h = h }
        resolvedBoxes[ctrl] = box
        return box
    end

    if #anchors >= 2 then
        local a1, a2 = anchors[1], anchors[2]
        local rel1 = LayoutSolver.Resolve(a1.relativeTo or ctrl.parent, resolvedBoxes, screenW, screenH)
        local rel2 = LayoutSolver.Resolve(a2.relativeTo or ctrl.parent, resolvedBoxes, screenW, screenH)

        local x1, y1 = GetAnchorPointCoords(rel1, a1.relativePoint or a1.point)
        local x2, y2 = GetAnchorPointCoords(rel2, a2.relativePoint or a2.point)
        x1 = x1 + (a1.offsetX or 0)
        y1 = y1 + (a1.offsetY or 0)
        x2 = x2 + (a2.offsetX or 0)
        y2 = y2 + (a2.offsetY or 0)

        local boxW = math.abs(x2 - x1)
        local boxH = math.abs(y2 - y1)
        local finalX = math.min(x1, x2)
        local finalY = math.min(y1, y2)
        local finalW = (boxW > 0) and boxW or w
        local finalH = (boxH > 0) and boxH or h

        -- Dual horizontal stretch (e.g. BOTTOMLEFT and BOTTOMRIGHT)
        if (a1.point == BOTTOMLEFT and a2.point == BOTTOMRIGHT) or (a1.point == TOPLEFT and a2.point == TOPRIGHT) then
            finalW = math.abs(x2 - x1)
            finalX = math.min(x1, x2)
            finalH = (h > 0) and h or 18
            if a1.point == BOTTOMLEFT then
                finalY = y1 - finalH
            end
        end

        local box = { x = finalX, y = finalY, w = finalW, h = finalH }
        resolvedBoxes[ctrl] = box
        return box
    end
end

return LayoutSolver
