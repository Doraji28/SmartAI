-- Visual Effects & Glitch Manager for Soulrock.
-- Handles screen shakes, damage flashes, glitch scanlines, sparks, and laser beams.
local fx_manager = {}

fx_manager.shake_intensity = 0.0
fx_manager.shake_duration = 0.0
fx_manager.damage_flash = 0.0
fx_manager.glitch_intensity = 0.0
fx_manager.particles = {}

-- Update all fx timers
function fx_manager.update(dt)
    -- Camera shake decay
    if fx_manager.shake_duration > 0 then
        fx_manager.shake_duration = fx_manager.shake_duration - dt
        if fx_manager.shake_duration <= 0 then
            fx_manager.shake_intensity = 0.0
        end
    end
    
    -- Damage vignette decay
    fx_manager.damage_flash = math.max(0.0, fx_manager.damage_flash - 2.8 * dt)
    
    -- Glitch decay
    fx_manager.glitch_intensity = math.max(0.0, fx_manager.glitch_intensity - 3.0 * dt)
    
    -- Update particles
    for i = #fx_manager.particles, 1, -1 do
        local p = fx_manager.particles[i]
        p.x = p.x + p.dx * dt
        p.y = p.y + p.dy * dt
        p.dy = p.dy + p.gravity * dt -- fall
        p.age = p.age + dt
        if p.age >= p.max_age then
            table.remove(fx_manager.particles, i)
        end
    end
end

-- Trigger screen shake
function fx_manager.trigger_shake(intensity, duration)
    fx_manager.shake_intensity = intensity
    fx_manager.shake_duration = duration
end

-- Trigger damage vignette flash
function fx_manager.trigger_damage()
    fx_manager.damage_flash = 1.0
    fx_manager.trigger_shake(6.0, 0.25) -- Reduced shake from 12.0
    fx_manager.glitch_intensity = 0.4   -- Reduced glitch from 0.8
end

-- Trigger glitch burst (e.g. on overheat)
function fx_manager.trigger_glitch()
    fx_manager.glitch_intensity = 0.5   -- Reduced glitch from 1.0
    fx_manager.trigger_shake(3.0, 0.2)  -- Reduced shake from 6.0
end

-- Spawn neon sparks at position (screen coordinates)
function fx_manager.spawn_sparks(x, y, color)
    color = color or {1, 0.9, 0.2, 1}
    for i = 1, 15 do
        local angle = math.random() * math.pi * 2
        local speed = math.random(80, 240)
        local p = {
            x = x,
            y = y,
            dx = math.cos(angle) * speed,
            dy = math.sin(angle) * speed - 50, -- slight upward velocity boost
            gravity = 250,
            color = {color[1], color[2], color[3], 1.0},
            size = math.random(2, 4),
            age = 0,
            max_age = math.random(3, 6) * 0.1
        }
        table.insert(fx_manager.particles, p)
    end
end

-- Apply screen shake translation (call before drawing main content)
function fx_manager.apply_shake()
    if fx_manager.shake_duration > 0 and fx_manager.shake_intensity > 0 then
        local dx = (math.random() * 2.0 - 1.0) * fx_manager.shake_intensity
        local dy = (math.random() * 2.0 - 1.0) * fx_manager.shake_intensity
        love.graphics.translate(dx, dy)
    end
end

-- Draw particles
function fx_manager.draw_particles()
    love.graphics.setLineWidth(1)
    for _, p in ipairs(fx_manager.particles) do
        -- Fade out particle
        local alpha = 1.0 - (p.age / p.max_age)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        
        -- Draw simple sparks as circles/squares
        love.graphics.circle("fill", p.x, p.y, p.size)
    end
end

-- Draw boss-to-player laser beam
-- bx, by: boss screen coordinates
-- is_holding: boolean (for color/spark changes)
-- mx, my: mouse target coordinates
function fx_manager.draw_laser_beam(bx, by, is_holding, mx, my)
    local screen_w, screen_h = 1280, 720
    local tx = mx or (screen_w / 2)
    local ty = my or (screen_h / 2)
    local pulse_time = love.timer.getTime()
    
    -- Beam thickness fluctuations
    local width = (25 + 10 * math.sin(pulse_time * 25))
    
    -- Colors (Softened opacity values)
    local outer_color = is_holding and {0.2, 0.8, 1.0, 0.3} or {0.9, 0.15, 0.15, 0.25}
    local inner_color = {1, 1, 1, 0.75}
    
    love.graphics.push()
    
    -- Draw outer thick beam
    love.graphics.setColor(outer_color)
    love.graphics.setLineWidth(width)
    love.graphics.line(bx, by, tx, ty)
    
    -- Draw inner core (Thinner)
    love.graphics.setColor(inner_color)
    love.graphics.setLineWidth(width * 0.2)
    love.graphics.line(bx, by, tx, ty)
    
    -- Draw splash sparks at targeting position
    if is_holding then
        love.graphics.setColor(0.3, 0.9, 1.0, 0.8)
        love.graphics.setLineWidth(2)
        for i = 1, 6 do
            local rot = pulse_time * 5 + i * (math.pi / 3)
            local rx = tx + math.cos(rot) * (30 + math.random(0, 10))
            local ry = ty + math.sin(rot) * (30 + math.random(0, 10))
            love.graphics.line(tx, ty, rx, ry)
        end
    else
        -- Unblocked damage flash (Softer, slower pulse warning instead of hard fast flashing)
        love.graphics.setColor(1.0, 0.2, 0.2, 0.08 + 0.04 * math.sin(pulse_time * 8))
        love.graphics.circle("fill", tx, ty, 40 + 10 * math.sin(pulse_time * 8))
    end
    
    love.graphics.pop()
end

-- Renders damage vignettes and screen glitches on top of the scene
function fx_manager.draw_screen_overlays(w, h)
    love.graphics.push()
    
    -----------------------------------------------------
    -- 1. NEON RED DAMAGE VIGNETTE
    -----------------------------------------------------
    if fx_manager.damage_flash > 0 then
        local df = fx_manager.damage_flash
        love.graphics.setColor(0.9, 0.05, 0.05, df * 0.18) -- Reduced alpha from 0.4
        
        local border = 45 * df
        -- Left border
        love.graphics.rectangle("fill", 0, 0, border, h)
        -- Right border
        love.graphics.rectangle("fill", w - border, 0, border, h)
        -- Top border
        love.graphics.rectangle("fill", 0, 0, w, border)
        -- Bottom border
        love.graphics.rectangle("fill", 0, h - border, w, border)
        
        -- Inner red vignette frame (Softer alpha and line width)
        love.graphics.setLineWidth(2 * df)
        love.graphics.setColor(0.95, 0.1, 0.1, df * 0.25) -- Reduced alpha from 0.7
        love.graphics.rectangle("line", border, border, w - 2*border, h - 2*border)
    end
    
    -----------------------------------------------------
    -- 2. DIGITAL CRT SCANLINE & CHROMATIC ABERRATION OVERLAYS
    -----------------------------------------------------
    if fx_manager.glitch_intensity > 0 then
        local gi = fx_manager.glitch_intensity
        local t = love.timer.getTime()
        
        -- Draw a few horizontal glitch strips
        for i = 1, math.random(2, 5) do
            local sy = math.floor(math.sin(t * (10 + i)) * 360 + 360)
            local sh = math.random(5, 25)
            
            -- Color shift strip (cyan/magenta - reduced alpha for player comfort)
            if math.random() > 0.5 then
                love.graphics.setColor(0, 0.8, 1, 0.08 * gi) -- Reduced from 0.25
            else
                love.graphics.setColor(1, 0, 0.8, 0.08 * gi) -- Reduced from 0.25
            end
            
            love.graphics.rectangle("fill", 0, sy, w, sh)
        end
        
        -- Draw horizontal white static signal lines (reduced opacity)
        love.graphics.setColor(1, 1, 1, 0.06 * gi) -- Reduced from 0.18
        for i = 1, 3 do
            local line_y = (t * 800 + i * 200) % h
            love.graphics.setLineWidth(1)
            love.graphics.line(0, line_y, w, line_y)
        end
        
        -- Glitch text warning if extremely high
        if gi > 0.8 then
            love.graphics.setColor(1, 0.1, 0.1, 0.5)
            love.graphics.rectangle("fill", w/2 - 100, 80, 200, 3)
        end
    end
    
    love.graphics.pop()
end

return fx_manager
