-- Perspective Grid & Tunnel Renderer for Soulrock.
-- Simulates 3D perspective tunnel wireframe and sways the final boss.
local grid_renderer = {}
local fft_analyzer = require("fft")

grid_renderer.beat_pulse = 0.0
grid_renderer.move_offset = 0.0
grid_renderer.boss_shield_rotation = 0.0

-- Camera parameters
local screen_w, screen_h = 1280, 720
local center_x = screen_w / 2
local center_y = screen_h / 2

local function draw_polygon_outline(cx, cy, radius, segments, angle_offset)
    angle_offset = angle_offset or 0
    local points = {}
    for i = 1, segments do
        local angle = angle_offset + (i - 1) * (math.pi * 2 / segments)
        table.insert(points, cx + math.cos(angle) * radius)
        table.insert(points, cy + math.sin(angle) * radius)
    end
    love.graphics.polygon("line", points)
end

local function draw_polygon_filled(cx, cy, radius, segments, angle_offset)
    angle_offset = angle_offset or 0
    local points = {}
    for i = 1, segments do
        local angle = angle_offset + (i - 1) * (math.pi * 2 / segments)
        table.insert(points, cx + math.cos(angle) * radius)
        table.insert(points, cy + math.sin(angle) * radius)
    end
    love.graphics.polygon("fill", points)
end

-- Projection function
function grid_renderer.project(x, y, z, zoom_override)
    local zoom = zoom_override or (400 + 40 * grid_renderer.beat_pulse)
    z = z or 10.0
    if z <= 0.05 then z = 0.05 end
    
    local sx = center_x + (x * zoom / z)
    local sy = center_y + (y * zoom / z)
    return sx, sy
end

-- Update offsets
function grid_renderer.update(dt, bpm_speed)
    -- Decay beat pulse
    grid_renderer.beat_pulse = math.max(0.0, grid_renderer.beat_pulse - 6.0 * dt)
    
    -- Speed of grid travel relative to time
    grid_renderer.move_offset = grid_renderer.move_offset - 2.8 * dt
    if grid_renderer.move_offset <= -2.0 then
        grid_renderer.move_offset = grid_renderer.move_offset + 2.0
    end
    
    -- Spin shield (faster when treble/high frequencies are high)
    grid_renderer.boss_shield_rotation = grid_renderer.boss_shield_rotation + (1.2 + fft_analyzer.high * 4.5) * dt
end

-- Trigger a beat pulse
function grid_renderer.trigger_beat()
    grid_renderer.beat_pulse = 1.0
end

-- Draw the perspective tunnel grid
function grid_renderer.draw_tunnel(time)
    local pulse = grid_renderer.beat_pulse + fft_analyzer.bass * 1.5
    if pulse > 1.8 then pulse = 1.8 end
    
    -- Pulse colors: fade between neon purple and bright neon magenta/white
    local grid_r = 0.4 + 0.6 * pulse
    local grid_g = 0.1 + 0.7 * pulse
    local grid_b = 0.7 + 0.3 * pulse
    
    love.graphics.setColor(grid_r, grid_g, grid_b, 0.45 + 0.25 * pulse)
    love.graphics.setLineWidth(1.5 + 2.5 * pulse)
    
    local zoom = 400 + 40 * pulse
    
    -----------------------------------------------------
    -- 1. DRAW LONGITUDINAL TUNNEL WALL LINES (Z: 0.5 -> 10.0)
    -----------------------------------------------------
    local z_start = 0.5
    local z_end = 10.0
    
    -- Floor points
    local floor_y = 1.8
    for x = -3, 3, 1.5 do
        local x1, y1 = grid_renderer.project(x, floor_y, z_start, zoom)
        local x2, y2 = grid_renderer.project(x, floor_y, z_end, zoom)
        love.graphics.line(x1, y1, x2, y2)
    end
    
    -- Ceiling points
    local ceiling_y = -1.8
    for x = -3, 3, 1.5 do
        local x1, y1 = grid_renderer.project(x, ceiling_y, z_start, zoom)
        local x2, y2 = grid_renderer.project(x, ceiling_y, z_end, zoom)
        love.graphics.line(x1, y1, x2, y2)
    end
    
    -- Side walls
    local wall_x_left = -3.5
    local wall_x_right = 3.5
    for y = -1.2, 1.2, 0.8 do
        local x1, y1 = grid_renderer.project(wall_x_left, y, z_start, zoom)
        local x2, y2 = grid_renderer.project(wall_x_left, y, z_end, zoom)
        love.graphics.line(x1, y1, x2, y2)
        
        x1, y1 = grid_renderer.project(wall_x_right, y, z_start, zoom)
        x2, y2 = grid_renderer.project(wall_x_right, y, z_end, zoom)
        love.graphics.line(x1, y1, x2, y2)
    end
    
    -----------------------------------------------------
    -- 2. DRAW TRANSVERSE DEPTH RINGS (Moving closer)
    -----------------------------------------------------
    -- We draw concentric rings representing the tunnel segment divisions
    love.graphics.setLineWidth(1.0 + 1.5 * pulse)
    
    for i = 0, 8 do
        local z = 10.0 - i * 1.25 + grid_renderer.move_offset
        if z > z_start and z < z_end then
            -- Calculate opacity based on depth (fog effect)
            local alpha = (1.0 - (z / z_end)) * 0.7
            love.graphics.setColor(grid_r, grid_g, grid_b, alpha)
            
            -- Apply a vibration scale based on mid frequencies
            local vibration = 1.0 + 0.08 * fft_analyzer.mid * math.sin(time * 12 + z)
            
            -- Project corner coordinates
            local xl, yt = grid_renderer.project(-3.5 * vibration, -1.8 * vibration, z, zoom)
            local xr, yb = grid_renderer.project(3.5 * vibration, 1.8 * vibration, z, zoom)
            
            -- Draw rectangular ring
            love.graphics.rectangle("line", xl, yt, xr - xl, yb - yt)
        end
    end
end

local function draw_abstract_boss_core(time, scale, stage_idx, main_color, glow_color, is_groggy, is_charging, line_width)
    -- Disabled: Return immediately to hide the boss body so the background wallpaper is fully visible.
    return
end

local function draw_abstract_boss_core_impl(time, scale, stage_idx, main_color, glow_color, is_groggy, is_charging, line_width)
    -- 1. Dark Background Fill
    love.graphics.setColor(0.04, 0.04, 0.08, 0.96)
    
    if stage_idx == 2 then
        -- VALKYRIE ZERO (Arrowhead Core)
        love.graphics.polygon("fill", 
            0, -38 * scale,
            38 * scale, -22 * scale,
            18 * scale, 20 * scale,
            0, 36 * scale,
            -18 * scale, 20 * scale,
            -38 * scale, -22 * scale
        )
    elseif stage_idx == 3 then
        -- GLADE GUARDIAN (Spiked Octagon)
        love.graphics.polygon("fill", 
            0, -40 * scale,
            24 * scale, -24 * scale,
            36 * scale, 0,
            24 * scale, 24 * scale,
            0, 40 * scale,
            -24 * scale, 24 * scale,
            -36 * scale, 0,
            -24 * scale, -24 * scale
        )
    elseif stage_idx == 4 then
        -- AETHER WARDEN (Diamond)
        love.graphics.polygon("fill", 
            0, -32 * scale,
            30 * scale, 0,
            24 * scale, 30 * scale,
            0, 42 * scale,
            -24 * scale, 30 * scale,
            -30 * scale, 0
        )
    elseif stage_idx == 5 then
        -- VANILLA MOOD (Star Core)
        love.graphics.polygon("fill", 
            0, -42 * scale,
            15 * scale, -15 * scale,
            42 * scale, 0,
            15 * scale, 15 * scale,
            0, 42 * scale,
            -15 * scale, 15 * scale,
            -42 * scale, 0,
            -15 * scale, -15 * scale
        )
    elseif stage_idx == 6 then
        -- SHADOW REAP (Reaper Hood Shape)
        love.graphics.polygon("fill", 
            0, -42 * scale,
            32 * scale, -12 * scale,
            20 * scale, 32 * scale,
            0, 20 * scale,
            -20 * scale, 32 * scale,
            -32 * scale, -12 * scale
        )
    elseif stage_idx == 7 then
        -- NEON IDOL (Pentagon Core)
        love.graphics.polygon("fill", 
            0, -40 * scale,
            38 * scale, -12 * scale,
            24 * scale, 34 * scale,
            -24 * scale, 34 * scale,
            -38 * scale, -12 * scale
        )
    else
        -- NEXUS CORE (Hexagon)
        love.graphics.polygon("fill", 
            0, -35 * scale,
            28 * scale, -12 * scale,
            22 * scale, 25 * scale,
            0, 38 * scale,
            -22 * scale, 25 * scale,
            -28 * scale, -12 * scale
        )
    end
    
    -- 2. Neon Outlines
    love.graphics.setColor(main_color)
    love.graphics.setLineWidth(line_width)
    
    if stage_idx == 2 then
        -- Valkyrie Arrowhead
        love.graphics.polygon("line", 
            0, -38 * scale,
            38 * scale, -22 * scale,
            18 * scale, 20 * scale,
            0, 36 * scale,
            -18 * scale, 20 * scale,
            -38 * scale, -22 * scale
        )
        -- Inner geometric detail (nested smaller arrowhead)
        love.graphics.setLineWidth(line_width * 0.6)
        love.graphics.polygon("line", 
            0, -25 * scale,
            24 * scale, -14 * scale,
            11 * scale, 12 * scale,
            0, 22 * scale,
            -11 * scale, 12 * scale,
            -24 * scale, -14 * scale
        )
        -- Cyber stabilizer wings (no eyebrows, no horns!)
        love.graphics.setLineWidth(line_width * 0.8)
        love.graphics.line(-22 * scale, 5 * scale, -45 * scale, -15 * scale)
        love.graphics.line(-45 * scale, -15 * scale, -30 * scale, -18 * scale)
        love.graphics.line(22 * scale, 5 * scale, 45 * scale, -15 * scale)
        love.graphics.line(45 * scale, -15 * scale, 30 * scale, -18 * scale)
        
    elseif stage_idx == 3 then
        -- Glade Guardian Octagon
        love.graphics.polygon("line", 
            0, -40 * scale,
            24 * scale, -24 * scale,
            36 * scale, 0,
            24 * scale, 24 * scale,
            0, 40 * scale,
            -24 * scale, 24 * scale,
            -36 * scale, 0,
            -24 * scale, -24 * scale
        )
        -- Nested inner octagon
        love.graphics.setLineWidth(line_width * 0.6)
        love.graphics.polygon("line", 
            0, -25 * scale,
            15 * scale, -15 * scale,
            22 * scale, 0,
            15 * scale, 15 * scale,
            0, 25 * scale,
            -15 * scale, 15 * scale,
            -22 * scale, 0,
            -15 * scale, -15 * scale
        )
        -- High tech crosshair grid lines
        love.graphics.line(-36 * scale, 0, 36 * scale, 0)
        love.graphics.line(0, -40 * scale, 0, 40 * scale)
        
        -- Tech sub-nodes (sleek lines with tiny circles)
        love.graphics.circle("line", -36 * scale, 0, 4 * scale)
        love.graphics.circle("line", 36 * scale, 0, 4 * scale)
        
    elseif stage_idx == 4 then
        -- Aether Warden Diamond
        love.graphics.polygon("line", 
            0, -32 * scale,
            30 * scale, 0,
            24 * scale, 30 * scale,
            0, 42 * scale,
            -24 * scale, 30 * scale,
            -30 * scale, 0
        )
        -- Inner diamond
        love.graphics.setLineWidth(line_width * 0.6)
        love.graphics.polygon("line", 
            0, -20 * scale,
            18 * scale, 0,
            14 * scale, 18 * scale,
            0, 25 * scale,
            -14 * scale, 18 * scale,
            -18 * scale, 0
        )
        -- Clean tech bracket on top (replaces the cartoonish crown)
        love.graphics.setLineWidth(line_width * 0.8)
        love.graphics.line(-20 * scale, -38 * scale, 20 * scale, -38 * scale)
        love.graphics.line(-20 * scale, -38 * scale, -20 * scale, -32 * scale)
        love.graphics.line(20 * scale, -38 * scale, 20 * scale, -32 * scale)
        love.graphics.line(0, -38 * scale, 0, -46 * scale)
        love.graphics.circle("fill", 0, -46 * scale, 3 * scale)
        
    elseif stage_idx == 5 then
        -- Vanilla Mood Star Core
        love.graphics.polygon("line", 
            0, -42 * scale,
            15 * scale, -15 * scale,
            42 * scale, 0,
            15 * scale, 15 * scale,
            0, 42 * scale,
            -15 * scale, 15 * scale,
            -42 * scale, 0,
            -15 * scale, -15 * scale
        )
        -- Concentric circle and rotating tech details
        love.graphics.setLineWidth(line_width * 0.6)
        love.graphics.circle("line", 0, 0, 18 * scale)
        
        love.graphics.push()
        love.graphics.rotate(-time * 1.0)
        love.graphics.rectangle("line", -12 * scale, -12 * scale, 24 * scale, 24 * scale)
        love.graphics.pop()
        
        -- Diagnostic cross lines
        love.graphics.line(-25 * scale, -25 * scale, 25 * scale, 25 * scale)
        love.graphics.line(-25 * scale, 25 * scale, 25 * scale, -25 * scale)
        
    elseif stage_idx == 6 then
        -- Shadow Reap Hood Core
        love.graphics.polygon("line", 
            0, -42 * scale,
            32 * scale, -12 * scale,
            20 * scale, 32 * scale,
            0, 20 * scale,
            -20 * scale, 32 * scale,
            -32 * scale, -12 * scale
        )
        -- Concentric inner shapes
        love.graphics.setLineWidth(line_width * 0.6)
        love.graphics.polygon("line", 
            0, -28 * scale,
            20 * scale, -8 * scale,
            12 * scale, 18 * scale,
            0, 10 * scale,
            -12 * scale, 18 * scale,
            -20 * scale, -8 * scale
        )
        -- Tech wing stabilizers
        love.graphics.setLineWidth(line_width * 0.8)
        love.graphics.line(-32 * scale, -12 * scale, -48 * scale, -20 * scale)
        love.graphics.line(32 * scale, -12 * scale, 48 * scale, -20 * scale)
        
        -- Outer target radar circle (broken segments)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(main_color[1], main_color[2], main_color[3], 0.45)
        for i = 1, 8 do
            local start_arc = time * 0.5 + (i - 1) * (math.pi * 2 / 8)
            local end_arc = start_arc + (math.pi / 8)
            love.graphics.arc("line", "open", 0, 0, 52 * scale, start_arc, end_arc, 8)
        end
        
    elseif stage_idx == 7 then
        -- Neon Idol Pentagon
        love.graphics.polygon("line", 
            0, -40 * scale,
            38 * scale, -12 * scale,
            24 * scale, 34 * scale,
            -24 * scale, 34 * scale,
            -38 * scale, -12 * scale
        )
        -- Inner geometric detail
        love.graphics.setLineWidth(line_width * 0.6)
        love.graphics.polygon("line", 
            0, -25 * scale,
            24 * scale, -8 * scale,
            15 * scale, 21 * scale,
            -15 * scale, 21 * scale,
            -24 * scale, -8 * scale
        )
        -- Glowing star lines
        love.graphics.line(0, -40 * scale, 24 * scale, 34 * scale)
        love.graphics.line(24 * scale, 34 * scale, -38 * scale, -12 * scale)
        love.graphics.line(-38 * scale, -12 * scale, 38 * scale, -12 * scale)
        love.graphics.line(38 * scale, -12 * scale, -24 * scale, 34 * scale)
        love.graphics.line(-24 * scale, 34 * scale, 0, -40 * scale)
    else
        -- Nexus Core Hexagon
        love.graphics.polygon("line", 
            0, -35 * scale,
            28 * scale, -12 * scale,
            22 * scale, 25 * scale,
            0, 38 * scale,
            -22 * scale, 25 * scale,
            -28 * scale, -12 * scale
        )
        -- Inner nested hexagon
        love.graphics.setLineWidth(line_width * 0.6)
        love.graphics.polygon("line", 
            0, -22 * scale,
            17 * scale, -8 * scale,
            14 * scale, 16 * scale,
            0, 24 * scale,
            -14 * scale, 16 * scale,
            -17 * scale, -8 * scale
        )
        -- Horizontal tech line and vertical antenna elements
        love.graphics.line(-22 * scale, 15 * scale, 22 * scale, 15 * scale)
        love.graphics.line(0, -35 * scale, 0, 10 * scale)
        
        -- Left/Right small nodes
        love.graphics.line(-10 * scale, -22 * scale, -18 * scale, -38 * scale)
        love.graphics.line(10 * scale, -22 * scale, 18 * scale, -38 * scale)
        love.graphics.circle("fill", -18 * scale, -38 * scale, 2 * scale)
        love.graphics.circle("fill", 18 * scale, -38 * scale, 2 * scale)
    end
    
    -- 3. Abstract Reactor Core (Replace the Cartoonish Eye, Blush & Eyebrows!)
    -- Concentric pulsing glow
    local pulse_r = (8 + 3 * math.sin(time * 8)) * scale
    love.graphics.setColor(glow_color[1], glow_color[2], glow_color[3], 0.2 + 0.1 * math.sin(time * 8))
    love.graphics.circle("fill", 0, 0, pulse_r)
    
    love.graphics.setColor(glow_color[1], glow_color[2], glow_color[3], 0.4 + 0.2 * math.sin(time * 8))
    love.graphics.circle("fill", 0, 0, pulse_r * 0.7)
    
    -- Center Core Node
    love.graphics.setColor(glow_color)
    love.graphics.circle("fill", 0, 0, 4 * scale)
    
    -- Tiny orbital micro-nodes rotating around center
    love.graphics.setLineWidth(1)
    love.graphics.setColor(main_color[1], main_color[2], main_color[3], 0.6)
    love.graphics.circle("line", 0, 0, 13 * scale)
    
    love.graphics.push()
    love.graphics.rotate(time * 3.0)
    love.graphics.circle("fill", 13 * scale, 0, 2.5 * scale)
    love.graphics.circle("fill", -13 * scale, 0, 2.5 * scale)
    love.graphics.pop()
end

-- Renders the cyber-boss at Z = 10.0
function grid_renderer.draw_boss(time, boss_hp_pct, is_groggy, is_charging, boss_color, shield_color, stage_idx)
    local z = 10.0
    local zoom = 400 + 40 * (grid_renderer.beat_pulse + fft_analyzer.bass * 1.5)
    stage_idx = stage_idx or 1
    
    -- Hover sway animation
    local hover_x = math.sin(time * 1.5) * 0.4
    local hover_y = -0.5 + math.cos(time * 2.0) * 0.18
    
    -- Project boss center
    local bx, by = grid_renderer.project(hover_x, hover_y, z, zoom)
    local boss_scale = (155 / z) * (1.0 + 0.05 * grid_renderer.beat_pulse + 0.12 * fft_analyzer.mid)
    
    love.graphics.push()
    love.graphics.translate(bx, by)
    
    -----------------------------------------------------
    -- 1. DRAW ROTATING NEON SHIELD RINGS (DISABLED - NO BARRIER)
    -----------------------------------------------------
    -- Shield rings drawing commented out as the barrier concept is removed.
    
    -----------------------------------------------------
    -- 2. DRAW BOSS BODY (ABSTRACT NEON TARGET NODE)
    -----------------------------------------------------
    local base_color = boss_color or {0.15, 0.75, 0.9, 0.95}
    local main_color = is_groggy and {0.7, 0.15, 0.15, 0.9} or base_color
    local glow_color = is_groggy and {1.0, 0.2, 0.2, 1.0} or {1.0, 0.9, 0.2, 1.0}
    
    draw_abstract_boss_core(time, boss_scale, stage_idx, main_color, glow_color, is_groggy, is_charging, 3)
    
    love.graphics.pop()
    
    return hover_x, hover_y -- Return coordinates for notes spawner
end

-- Renders a spinning music vinyl record icon for stage select cards
function grid_renderer.draw_boss_icon(stage_idx, cx, cy, boss_scale, time)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    
    local base_color = {0.15, 0.75, 0.9, 0.95} -- Turquoise
    if stage_idx == 2 then base_color = {0.95, 0.15, 0.15, 0.95}
    elseif stage_idx == 3 then base_color = {0.15, 0.9, 0.4, 0.95}
    elseif stage_idx == 4 then base_color = {0.75, 0.15, 0.9, 0.95}
    elseif stage_idx == 5 then base_color = {0.95, 0.55, 0.15, 0.95}
    elseif stage_idx == 6 then base_color = {0.95, 0.85, 0.15, 0.95}
    elseif stage_idx == 7 then base_color = {0.95, 0.15, 0.75, 0.95}
    end
    
    -- Draw vinyl record body (dark grey circle)
    local outer_r = 50 * boss_scale
    love.graphics.setColor(0.08, 0.08, 0.1, 0.95)
    love.graphics.circle("fill", 0, 0, outer_r)
    
    -- Draw vinyl grooves (concentric circles)
    love.graphics.setLineWidth(1)
    for r = 15, 45, 6 do
        love.graphics.setColor(0.2, 0.2, 0.25, 0.4 + 0.1 * math.sin(time * 2 + r))
        love.graphics.circle("line", 0, 0, r * boss_scale)
    end
    
    -- Draw glowing track light reflection (two arc wedges)
    love.graphics.push()
    love.graphics.rotate(time * 0.8) -- slowly spin
    love.graphics.setLineWidth(4 * boss_scale)
    love.graphics.setColor(base_color[1], base_color[2], base_color[3], 0.25)
    love.graphics.arc("line", "open", 0, 0, 32 * boss_scale, -0.4, 0.4, 16)
    love.graphics.arc("line", "open", 0, 0, 32 * boss_scale, math.pi - 0.4, math.pi + 0.4, 16)
    love.graphics.pop()
    
    -- Center label circle
    local center_r = 13 * boss_scale
    love.graphics.setColor(base_color[1], base_color[2], base_color[3], 0.85)
    love.graphics.circle("fill", 0, 0, center_r)
    
    -- Small center hole
    love.graphics.setColor(0.04, 0.04, 0.08, 1)
    love.graphics.circle("fill", 0, 0, 3 * boss_scale)
    
    -- Outer glowing ring
    love.graphics.setLineWidth(1.5)
    love.graphics.setColor(base_color[1], base_color[2], base_color[3], 0.45)
    love.graphics.circle("line", 0, 0, outer_r + 2 * boss_scale)
    
    love.graphics.pop()
end

return grid_renderer
