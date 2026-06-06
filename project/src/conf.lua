-- conf.lua - LÖVE Window & Module Settings for Soulrock
function love.conf(t)
    t.title = "Soulrock - 1인칭 2.5D 리듬 슈팅 액션"
    t.author = "Antigravity"
    t.version = "11.5"
    
    -- Window dimensions
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = false
    t.window.centered = true
    t.window.vsync = 1
    t.window.msaa = 8
    
    -- Console setting (lovec.exe handles stdout directly)
    t.console = false
    
    -- Modules to enable
    t.modules.audio = true
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.thread = true
    t.modules.timer = true
    t.modules.window = true
end
