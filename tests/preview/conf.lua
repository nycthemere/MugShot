-- =========================================================
-- MugShot - Love2D Preview Configuration
-- (tests/preview/conf.lua)
-- Run with:  love tests/preview
-- =========================================================

function love.conf(t)
    t.identity = "mugshot_preview"
    t.window.title = "MugShot — Live Target Frame UI Preview"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.minwidth = 800
    t.window.minheight = 600
    t.window.vsync = 1

    t.modules.audio = false
    t.modules.physics = false
    t.modules.joystick = false
    t.modules.touch = false
end
