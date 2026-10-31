-- =========================================================
-- MugShot - Arena3D  (tests/preview/Arena3D.lua)
-- 3D First-Person Arena with movable camera, authentic ESO
-- reticle targeting raycast, and interactive 3D world entities.
-- Completely decoupled from UI rendering and addon logic.
-- =========================================================

local Arena3D = {}
Arena3D.__index = Arena3D

local math_atan2 = math.atan2 or math.atan

-- Decorative Arena Pillars with Braziers
local ARENA_PILLARS = {
    { x = -16, z = -6 }, { x = 16, z = -6 },
    { x = -16, z = 8 },  { x = 16, z = 8 },
    { x = -16, z = 22 }, { x = 16, z = 22 },
    { x = -8,  z = 28 }, { x = 8,  z = 28 },
}

function Arena3D.New()
    local self = setmetatable({}, Arena3D)
    self.camera = {
        x = 0,
        y = 1.65, -- Eye level in meters
        z = 0,
        yaw = 0,   -- Radians around Y axis
        pitch = 0, -- Radians up/down
        speed = 7.0,
        sprintSpeed = 12.0,
    }
    self.mouseSensitivity = 0.0022
    self.fovFactor = math.tan(math.rad(75 / 2)) -- 75° Field of View
    return self
end

-- ── 3D Projection Math ────────────────────────────────────

function Arena3D:Project3D(x, y, z, sw, sh)
    local cam = self.camera
    local dx = x - cam.x
    local dy = y - cam.y
    local dz = z - cam.z

    -- Yaw rotation (around Y axis)
    local cosY, sinY = math.cos(cam.yaw), math.sin(cam.yaw)
    local x1 = dx * cosY - dz * sinY
    local z1 = dx * sinY + dz * cosY
    local y1 = dy

    -- Pitch rotation (around X axis)
    local cosP, sinP = math.cos(cam.pitch), math.sin(cam.pitch)
    local x2 = x1
    local y2 = y1 * cosP - z1 * sinP
    local z2 = y1 * sinP + z1 * cosP

    if z2 <= 0.25 then
        return nil, nil, z2, 0 -- Clipped behind or too close
    end

    local fovScale = (sw * 0.5) / self.fovFactor
    local sx = sw * 0.5 + (x2 / z2) * fovScale
    local sy = sh * 0.5 - (y2 / z2) * fovScale
    local scale = fovScale / z2

    return sx, sy, z2, scale
end

function Arena3D:DrawLine3D(x1, y1, z1, x2, y2, z2, sw, sh)
    local cam = self.camera
    local cosY, sinY = math.cos(cam.yaw), math.sin(cam.yaw)
    local cosP, sinP = math.cos(cam.pitch), math.sin(cam.pitch)

    local function ToCam(x, y, z)
        local dx, dy, dz = x - cam.x, y - cam.y, z - cam.z
        local rx = dx * cosY - dz * sinY
        local rz = dx * sinY + dz * cosY
        local ry = dy * cosP - rz * sinP
        local cz = dy * sinP + rz * cosP
        return rx, ry, cz
    end

    local cx1, cy1, cz1 = ToCam(x1, y1, z1)
    local cx2, cy2, cz2 = ToCam(x2, y2, z2)

    local near = 0.25
    if cz1 < near and cz2 < near then return end

    if cz1 < near then
        local t = (near - cz1) / (cz2 - cz1)
        cx1 = cx1 + t * (cx2 - cx1)
        cy1 = cy1 + t * (cy2 - cy1)
        cz1 = near
    elseif cz2 < near then
        local t = (near - cz2) / (cx1 - cz2)
        cx2 = cx2 + t * (cx1 - cx2)
        cy2 = cy2 + t * (cy1 - cy2)
        cz2 = near
    end

    local fovScale = (sw * 0.5) / self.fovFactor
    local sx1 = sw * 0.5 + (cx1 / cz1) * fovScale
    local sy1 = sh * 0.5 - (cy1 / cz1) * fovScale
    local sx2 = sw * 0.5 + (cx2 / cz2) * fovScale
    local sy2 = sh * 0.5 - (cy2 / cz2) * fovScale

    love.graphics.line(sx1, sy1, sx2, sy2)
end

-- ── Camera & Controls ─────────────────────────────────────

function Arena3D:Update(dt)
    -- Movement strictly with WASD / ZQSD (Arrow keys are strictly for HP adjustment)
    local moveX, moveZ = 0, 0
    local isDown = love.keyboard.isDown

    if isDown("w") or isDown("z") then moveZ = moveZ + 1 end
    if isDown("s") then moveZ = moveZ - 1 end
    if isDown("d") then moveX = moveX + 1 end
    if isDown("a") or isDown("q") then moveX = moveX - 1 end

    if moveX ~= 0 or moveZ ~= 0 then
        local len = math.sqrt(moveX * moveX + moveZ * moveZ)
        moveX = moveX / len
        moveZ = moveZ / len

        local spd = (isDown("lshift") or isDown("rshift")) and self.camera.sprintSpeed or self.camera.speed
        local cam = self.camera
        local worldDx = moveX * math.cos(cam.yaw) + moveZ * math.sin(cam.yaw)
        local worldDz = -moveX * math.sin(cam.yaw) + moveZ * math.cos(cam.yaw)

        cam.x = math.max(-19.0, math.min(19.0, cam.x + worldDx * spd * dt))
        cam.z = math.max(-9.0, math.min(27.0, cam.z + worldDz * spd * dt))
    end
end

function Arena3D:RotateCamera(dx, dy)
    self.camera.yaw = self.camera.yaw + dx * self.mouseSensitivity
    local maxPitch = math.rad(85)
    self.camera.pitch = math.max(-maxPitch, math.min(maxPitch, self.camera.pitch - dy * self.mouseSensitivity))
end

function Arena3D:SnapCameraTo(entity)
    if not entity then
        self.camera.yaw = 0
        self.camera.pitch = 0
        return
    end
    local cam = self.camera
    local dx = entity.x - cam.x
    local dz = entity.z - cam.z
    local distH = math.sqrt(dx * dx + dz * dz)
    if distH > 0.1 then
        cam.yaw = math_atan2(dx, dz)
        local targetY = entity.y + entity.height * 0.55
        cam.pitch = math_atan2(targetY - cam.y, distH)
    end
end

-- ── Raycast Targeting ─────────────────────────────────────

function Arena3D:FindTargetUnderReticle(entities, sw, sh)
    local reticleX, reticleY = sw * 0.5, sh * 0.5
    local bestHit = nil
    local bestDepth = 999999

    for _, ent in ipairs(entities or {}) do
        local sx, sy, depth, scale = self:Project3D(ent.x, ent.y, ent.z, sw, sh)
        if depth and depth > 0.4 and depth < 35.0 then
            local _, topY = self:Project3D(ent.x, ent.y + ent.height, ent.z, sw, sh)
            if topY then
                local w = ent.radius * 2.2 * scale
                local minX = sx - w * 0.5
                local maxX = sx + w * 0.5
                local minY = math.min(topY, sy)
                local maxY = math.max(topY, sy)

                local pad = math.max(12, 28 * (scale / (scale + 15)))
                if reticleX >= (minX - pad) and reticleX <= (maxX + pad) and
                   reticleY >= (minY - pad) and reticleY <= (maxY + pad) then
                    if depth < bestDepth then
                        bestDepth = depth
                        bestHit = ent
                    end
                end
            end
        end
    end

    return bestHit
end

-- ── 3D Scene Rendering ────────────────────────────────────

function Arena3D:Draw(entities, targetedEntity, globalAnimTime, sw, sh, fonts)
    local cam = self.camera

    -- 1. Sky / Dungeon Ceiling Gradient
    love.graphics.setColor(0.04, 0.05, 0.07, 1.0)
    love.graphics.rectangle("fill", 0, 0, sw, sh * 0.5)
    love.graphics.setColor(0.02, 0.03, 0.04, 1.0)
    love.graphics.rectangle("fill", 0, sh * 0.5, sw, sh * 0.5)

    -- 2. Dungeon Stone Floor Grid
    love.graphics.setColor(0.12, 0.14, 0.18, 0.45)
    love.graphics.setLineWidth(1)
    for gx = -20, 20, 2 do
        self:DrawLine3D(gx, 0, -10, gx, 0, 30, sw, sh)
    end
    for gz = -10, 30, 2 do
        self:DrawLine3D(-20, 0, gz, 20, 0, gz, sw, sh)
    end

    -- 3. Center Ritual Arena Circle
    local segments = 32
    local arenaR = 7.0
    love.graphics.setColor(0.20, 0.28, 0.38, 0.35)
    for i = 1, segments do
        local a1 = (i - 1) * (math.pi * 2 / segments)
        local a2 = i * (math.pi * 2 / segments)
        self:DrawLine3D(math.cos(a1) * arenaR, 0, 10 + math.sin(a1) * arenaR,
                        math.cos(a2) * arenaR, 0, 10 + math.sin(a2) * arenaR, sw, sh)
    end

    -- 4. Arena Boundary Pillars & Animated Fire Braziers
    for _, p in ipairs(ARENA_PILLARS) do
        local psx, psy, pdepth, pscale = self:Project3D(p.x, 0, p.z, sw, sh)
        if pdepth and pdepth > 0.4 then
            local _, topY = self:Project3D(p.x, 5.0, p.z, sw, sh)
            if topY then
                local pw = 1.0 * pscale
                love.graphics.setColor(0.10, 0.12, 0.15, 0.95)
                love.graphics.rectangle("fill", psx - pw * 0.5, topY, pw, psy - topY)
                love.graphics.setColor(0.22, 0.26, 0.32, 0.8)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", psx - pw * 0.5, topY, pw, psy - topY)

                -- Flame flicker
                local flicker = math.sin(globalAnimTime * 12.0 + p.x * 2.1) * 0.15 + 0.85
                local flameR = 0.5 * pscale * flicker
                love.graphics.setColor(1.0, 0.55, 0.15, 0.65)
                love.graphics.circle("fill", psx, topY, flameR)
                love.graphics.setColor(1.0, 0.85, 0.30, 0.85)
                love.graphics.circle("fill", psx, topY, flameR * 0.5)
            end
        end
    end

    -- 5. Depth-Sorted World Target Entities
    local renderList = {}
    for _, ent in ipairs(entities or {}) do
        local dx = ent.x - cam.x
        local dz = ent.z - cam.z
        table.insert(renderList, { ent = ent, dist = math.sqrt(dx * dx + dz * dz) })
    end
    table.sort(renderList, function(a, b) return a.dist > b.dist end)

    for _, item in ipairs(renderList) do
        local ent = item.ent
        local dist = item.dist
        local sx, sy, depth, scale = self:Project3D(ent.x, ent.y, ent.z, sw, sh)

        if depth and depth > 0.3 then
            local _, topY = self:Project3D(ent.x, ent.y + ent.height, ent.z, sw, sh)
            if topY then
                local isTargeted = (targetedEntity == ent)
                local col = ent.color or { 1, 1, 1 }
                local cardW = ent.radius * 2.0 * scale
                local cardH = sy - topY

                -- Ground Reaction Decal
                local groundR = ent.radius * 1.3 * scale
                love.graphics.setColor(col[1], col[2], col[3], isTargeted and 0.45 or 0.22)
                love.graphics.ellipse("fill", sx, sy, groundR, groundR * 0.45)
                love.graphics.setColor(col[1], col[2], col[3], isTargeted and 0.9 or 0.5)
                love.graphics.setLineWidth(isTargeted and 2 or 1)
                love.graphics.ellipse("line", sx, sy, groundR, groundR * 0.45)

                -- 3D Billboard Character Card
                local cardAlpha = ent.isDead and 0.35 or 0.90
                love.graphics.setColor(0.08, 0.10, 0.12, cardAlpha)
                love.graphics.rectangle("fill", sx - cardW * 0.5, topY, cardW, cardH, 6, 6)
                love.graphics.setColor(col[1], col[2], col[3], isTargeted and 1.0 or 0.7)
                love.graphics.setLineWidth(isTargeted and 3 or 1.5)
                love.graphics.rectangle("line", sx - cardW * 0.5, topY, cardW, cardH, 6, 6)

                -- Header
                love.graphics.setColor(col[1], col[2], col[3], 0.25)
                love.graphics.rectangle("fill", sx - cardW * 0.5, topY, cardW, math.min(cardH, 24), 6, 6)

                love.graphics.setFont(fonts.fontSmall)
                love.graphics.setColor(col[1], col[2], col[3], 1.0)
                love.graphics.printf(ent.name, sx - cardW * 0.5, topY + cardH * 0.35, cardW, "center")

                if ent.isDead then
                    love.graphics.setColor(1.0, 0.2, 0.2, 0.95)
                    love.graphics.setFont(fonts.fontTitle)
                    love.graphics.printf("[MORT / DEAD]", sx - cardW * 0.5, topY + cardH * 0.5, cardW, "center")
                end

                -- Targeted Highlight Corner Brackets
                if isTargeted then
                    local pulse = math.sin(globalAnimTime * 8.0) * 4
                    local pad = 8 + pulse
                    love.graphics.setColor(col[1], col[2], col[3], 0.85)
                    love.graphics.setLineWidth(2)

                    local bx1, by1 = sx - cardW * 0.5 - pad, topY - pad
                    local bx2, by2 = sx + cardW * 0.5 + pad, sy + pad
                    local clen = math.min(16, cardW * 0.25)
                    love.graphics.line(bx1, by1 + clen, bx1, by1, bx1 + clen, by1)
                    love.graphics.line(bx2 - clen, by1, bx2, by1, bx2, by1 + clen)
                    love.graphics.line(bx1, by2 - clen, bx1, by2, bx1 + clen, by2)
                    love.graphics.line(bx2 - clen, by2, bx2, by2, bx2, by2 - clen)
                end

                -- Overhead Nameplate
                local npY = topY - 42
                love.graphics.setFont(fonts.fontMain)
                love.graphics.setColor(0, 0, 0, 0.8)
                love.graphics.printf(ent.name, sx - 150 + 1, npY + 1, 300, "center")
                love.graphics.setColor(col[1], col[2], col[3], 1.0)
                love.graphics.printf(ent.name, sx - 150, npY, 300, "center")

                love.graphics.setFont(fonts.fontTiny)
                love.graphics.setColor(0.75, 0.80, 0.85, 0.9)
                local sub = string.format("%s (%.1fm)", ent.title, dist)
                love.graphics.printf(sub, sx - 150, npY + 18, 300, "center")

                -- Mini Health Bar on Target
                local hpBarW = math.max(60, cardW * 0.85)
                local hpBarH = 5
                local hpBarX = sx - hpBarW * 0.5
                local hpBarY = npY + 32

                love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
                love.graphics.rectangle("fill", hpBarX, hpBarY, hpBarW, hpBarH)

                local hpRatio = math.max(0, math.min(1, ent.currentHealth / ent.maxHealth))
                love.graphics.setColor(col[1], col[2], col[3], 0.9)
                love.graphics.rectangle("fill", hpBarX, hpBarY, hpBarW * hpRatio, hpBarH)

                if ent.shieldActive and ent.shield > 0 then
                    local shRatio = math.min(1, ent.shield / ent.maxHealth)
                    love.graphics.setColor(0.2, 0.85, 1.0, 0.8)
                    love.graphics.rectangle("fill", hpBarX, hpBarY + hpBarH, hpBarW * shRatio, 2)
                end
            end
        end
    end
end

-- ── Center Crosshair Reticle ──────────────────────────────

function Arena3D:DrawReticle(sw, sh, hasTarget)
    local cx, cy = sw * 0.5, sh * 0.5
    local rColor = hasTarget and { 0.25, 0.95, 1.0, 0.95 } or { 0.85, 0.88, 0.92, 0.75 }
    local rSize = hasTarget and 14 or 10

    love.graphics.setColor(rColor[1], rColor[2], rColor[3], rColor[4])
    love.graphics.setLineWidth(2)

    love.graphics.line(cx - rSize - 5, cy, cx - 4, cy)
    love.graphics.line(cx + 4, cy, cx + rSize + 5, cy)
    love.graphics.line(cx, cy - rSize - 5, cx, cy - 4)
    love.graphics.line(cx, cy + 4, cx, cy + rSize + 5)

    love.graphics.circle("line", cx, cy, 3)

    if hasTarget then
        love.graphics.setColor(rColor[1], rColor[2], rColor[3], 0.35)
        love.graphics.circle("line", cx, cy, rSize + 6)
    end
end

return Arena3D
