-- conf.lua - LÖVE Window & Module Settings for Soulrock
function love.conf(t)
    t.title = "Soulrock - 최고의 음악들과 함께 즐기는 리듬게임"
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
