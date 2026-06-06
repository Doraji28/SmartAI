-- Perspective Grid & Tunnel Renderer for Soulrock.
-- Simulates 3D perspective tunnel wireframe and sways the final boss.
local grid_renderer = {}

grid_renderer.beat_pulse = 0.0
grid_renderer.move_offset = 0.0
grid_renderer.boss_shield_rotation = 0.0

-- Camera parameters
local screen_w, screen_h = 1280, 720
local center_x = screen_w / 2
local center_y = screen_h / 2

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
    grid_renderer.move_offset = grid_renderer.move_offset - 1.8 * dt
    if grid_renderer.move_offset <= -2.0 then
        grid_renderer.move_offset = grid_renderer.move_offset + 2.0
    end
    
    -- Spin shield
    grid_renderer.boss_shield_rotation = grid_renderer.boss_shield_rotation + 1.2 * dt
end

-- Trigger a beat pulse
function grid_renderer.trigger_beat()
    grid_renderer.beat_pulse = 1.0
end

-- Draw the perspective tunnel grid
function grid_renderer.draw_tunnel(time)
    local pulse = grid_renderer.beat_pulse
    
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
            
            -- Project corner coordinates
            local xl, yt = grid_renderer.project(-3.5, -1.8, z, zoom)
            local xr, yb = grid_renderer.project(3.5, 1.8, z, zoom)
            
            -- Draw rectangular ring
            love.graphics.rectangle("line", xl, yt, xr - xl, yb - yt)
        end
    end
end

-- -- Renders the menacing cyber-boss at Z = 10.0
-- boss_hp_pct: float (0 to 1) for HP bar
-- is_groggy: boolean
-- is_charging: boolean
-- boss_color: table {r,g,b,a} for core lines
-- shield_color: table {r,g,b,a} for shield ring
-- stage_idx: integer (1 to 3) for design variations
function grid_renderer.draw_boss(time, boss_hp_pct, is_groggy, is_charging, boss_color, shield_color, stage_idx)
    local z = 10.0
    local zoom = 400 + 40 * grid_renderer.beat_pulse
    stage_idx = stage_idx or 1
    
    -- Hover sway animation
    local hover_x = math.sin(time * 1.5) * 0.4
    local hover_y = -0.5 + math.cos(time * 2.0) * 0.18
    
    -- Project boss center
    local bx, by = grid_renderer.project(hover_x, hover_y, z, zoom)
    local boss_scale = (155 / z) * (1.0 + 0.05 * grid_renderer.beat_pulse)
    
    love.graphics.push()
    love.graphics.translate(bx, by)
    
    -----------------------------------------------------
    -- 1. DRAW ROTATING NEON SHIELD RINGS
    -----------------------------------------------------
    if boss_hp_pct > 0 then
        local shield_rot = grid_renderer.boss_shield_rotation
        local ring_radius = 55 * boss_scale
        
        if is_groggy then
            -- Broken / red sputtering ring
            love.graphics.setColor(0.9, 0.2, 0.2, 0.4 + 0.3 * math.sin(time * 15))
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", 0, 0, ring_radius)
        else
            -- Cyber colored ring matching stage config
            local s_col = shield_color or {0.2, 0.85, 0.95, 0.95}
            local ring_r = is_charging and 1.0 or s_col[1]
            local ring_g = is_charging and 0.2 or s_col[2]
            local ring_b = is_charging and 0.2 or s_col[3]
            
            love.graphics.setColor(ring_r, ring_g, ring_b, 0.6)
            love.graphics.setLineWidth(3)
            
            -- Draw 4 segmented arcs to show rotation
            for i = 1, 4 do
                local start_arc = shield_rot + (i - 1) * (math.pi / 2)
                local end_arc = start_arc + (math.pi / 3)
                love.graphics.arc("line", "open", 0, 0, ring_radius, start_arc, end_arc, 16)
            end
            
            -- Outer ring
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", 0, 0, ring_radius + 10 * boss_scale)
        end
    end
    
    -----------------------------------------------------
    -- 2. DRAW BOSS BODY (VECTOR CYBER EYE-SKULL DETAILED BY STAGE)
    -----------------------------------------------------
    local base_color = boss_color or {0.15, 0.75, 0.9, 0.95}
    local main_color = is_groggy and {0.7, 0.15, 0.15, 0.9} or base_color
    local eye_color = is_groggy and {1.0, 0.2, 0.2, 1.0} or {1.0, 0.9, 0.2, 1.0}
    
    -- Face base background filling (Hexagon/Diamond outer skull)
    love.graphics.setColor(0.04, 0.04, 0.08, 0.96)
    
    if stage_idx == 2 then
        -- VALKYRIE ZERO (Sharp double triangular wings)
        love.graphics.polygon("fill", 
            0, -38 * boss_scale,
            38 * boss_scale, -22 * boss_scale,
            18 * boss_scale, 20 * boss_scale,
            0, 36 * boss_scale,
            -18 * boss_scale, 20 * boss_scale,
            -38 * boss_scale, -22 * boss_scale
        )
    elseif stage_idx == 3 then
        -- NEON WARDEN (Wide circular diamond crest)
        love.graphics.polygon("fill", 
            0, -32 * boss_scale,
            30 * boss_scale, 0,
            24 * boss_scale, 30 * boss_scale,
            0, 42 * boss_scale,
            -24 * boss_scale, 30 * boss_scale,
            -30 * boss_scale, 0
        )
    else
        -- NEXUS CORE (Standard hexagonal core)
        love.graphics.polygon("fill", 
            0, -35 * boss_scale,
            28 * boss_scale, -12 * boss_scale,
            22 * boss_scale, 25 * boss_scale,
            0, 38 * boss_scale,
            -22 * boss_scale, 25 * boss_scale,
            -28 * boss_scale, -12 * boss_scale
        )
    end
    
    -- Outlines
    love.graphics.setColor(main_color)
    love.graphics.setLineWidth(3)
    
    if stage_idx == 2 then
        love.graphics.polygon("line", 
            0, -38 * boss_scale,
            38 * boss_scale, -22 * boss_scale,
            18 * boss_scale, 20 * boss_scale,
            0, 36 * boss_scale,
            -18 * boss_scale, 20 * boss_scale,
            -38 * boss_scale, -22 * boss_scale
        )
        -- Valkyrie angry lines detailing
        love.graphics.setLineWidth(1.5)
        love.graphics.line(-38 * boss_scale, -22 * boss_scale, 0, -2 * boss_scale)
        love.graphics.line(38 * boss_scale, -22 * boss_scale, 0, -2 * boss_scale)
        -- Sharp horns
        love.graphics.setLineWidth(2.5)
        love.graphics.line(-15 * boss_scale, -32 * boss_scale, -25 * boss_scale, -52 * boss_scale)
        love.graphics.line(-25 * boss_scale, -52 * boss_scale, -10 * boss_scale, -48 * boss_scale)
        love.graphics.line(15 * boss_scale, -32 * boss_scale, 25 * boss_scale, -52 * boss_scale)
        love.graphics.line(25 * boss_scale, -52 * boss_scale, 10 * boss_scale, -48 * boss_scale)
        
    elseif stage_idx == 3 then
        love.graphics.polygon("line", 
            0, -32 * boss_scale,
            30 * boss_scale, 0,
            24 * boss_scale, 30 * boss_scale,
            0, 42 * boss_scale,
            -24 * boss_scale, 30 * boss_scale,
            -30 * boss_scale, 0
        )
        -- Warden details
        love.graphics.setLineWidth(1.5)
        love.graphics.line(-30 * boss_scale, 0, 30 * boss_scale, 0)
        love.graphics.line(0, -32 * boss_scale, 0, 42 * boss_scale)
        
        -- Crown above head
        love.graphics.setLineWidth(2.5)
        love.graphics.line(-12 * boss_scale, -38 * boss_scale, -18 * boss_scale, -48 * boss_scale)
        love.graphics.line(-18 * boss_scale, -48 * boss_scale, 0, -42 * boss_scale)
        love.graphics.line(0, -42 * boss_scale, 18 * boss_scale, -48 * boss_scale)
        love.graphics.line(18 * boss_scale, -48 * boss_scale, 12 * boss_scale, -38 * boss_scale)
        love.graphics.line(0, -42 * boss_scale, 0, -55 * boss_scale)
        
    else
        love.graphics.polygon("line", 
            0, -35 * boss_scale,
            28 * boss_scale, -12 * boss_scale,
            22 * boss_scale, 25 * boss_scale,
            0, 38 * boss_scale,
            -22 * boss_scale, 25 * boss_scale,
            -28 * boss_scale, -12 * boss_scale
        )
        love.graphics.setLineWidth(1.5)
        love.graphics.line(-22 * boss_scale, 25 * boss_scale, 22 * boss_scale, 25 * boss_scale)
        love.graphics.line(0, -35 * boss_scale, 0, 10 * boss_scale)
        
        -- Antenna horns
        love.graphics.setLineWidth(2.5)
        love.graphics.line(-10 * boss_scale, -32 * boss_scale, -16 * boss_scale, -48 * boss_scale)
        love.graphics.line(10 * boss_scale, -32 * boss_scale, 16 * boss_scale, -48 * boss_scale)
    end
    
    -- Blush/Glow backing
    love.graphics.setColor(eye_color[1], eye_color[2], eye_color[3], 0.15)
    love.graphics.ellipse("fill", -15 * boss_scale, 8 * boss_scale, 8 * boss_scale, 4 * boss_scale)
    love.graphics.ellipse("fill", 15 * boss_scale, 8 * boss_scale, 8 * boss_scale, 4 * boss_scale)

    -- Eyebrows
    love.graphics.setColor(main_color)
    love.graphics.setLineWidth(3.5)
    love.graphics.line(-18 * boss_scale, -12 * boss_scale, -4 * boss_scale, -6 * boss_scale)
    love.graphics.line(18 * boss_scale, -12 * boss_scale, 4 * boss_scale, -6 * boss_scale)

    -- Floating Eye (Center Core)
    love.graphics.setColor(eye_color)
    love.graphics.circle("fill", 0, -2 * boss_scale, 8 * boss_scale)
    
    -- Glow aura
    love.graphics.setColor(eye_color[1], eye_color[2], eye_color[3], 0.3 + 0.25 * math.sin(time * 12))
    love.graphics.circle("fill", 0, -2 * boss_scale, 14 * boss_scale)
    
    love.graphics.pop()
    
    return hover_x, hover_y -- Return coordinates for notes spawner
end

-- Renders a 2D vector face icon of the boss for stage select cards
function grid_renderer.draw_boss_icon(stage_idx, cx, cy, boss_scale, time)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    
    -- Face base background filling (Hexagon/Diamond outer skull)
    love.graphics.setColor(0.04, 0.04, 0.08, 0.96)
    if stage_idx == 2 then
        -- VALKYRIE ZERO
        love.graphics.polygon("fill", 
            0, -38 * boss_scale,
            38 * boss_scale, -22 * boss_scale,
            18 * boss_scale, 20 * boss_scale,
            0, 36 * boss_scale,
            -18 * boss_scale, 20 * boss_scale,
            -38 * boss_scale, -22 * boss_scale
        )
    else
        -- NEXUS CORE
        love.graphics.polygon("fill", 
            0, -35 * boss_scale,
            28 * boss_scale, -12 * boss_scale,
            22 * boss_scale, 25 * boss_scale,
            0, 38 * boss_scale,
            -22 * boss_scale, 25 * boss_scale,
            -28 * boss_scale, -12 * boss_scale
        )
    end
    
    -- Face outlines
    local base_color = {0.15, 0.75, 0.9, 0.95} -- Turquoise
    if stage_idx == 2 then
        base_color = {0.95, 0.15, 0.15, 0.95} -- Crimson Red
    end
    
    love.graphics.setColor(base_color)
    love.graphics.setLineWidth(2)
    
    if stage_idx == 2 then
        love.graphics.polygon("line", 
            0, -38 * boss_scale,
            38 * boss_scale, -22 * boss_scale,
            18 * boss_scale, 20 * boss_scale,
            0, 36 * boss_scale,
            -18 * boss_scale, 20 * boss_scale,
            -38 * boss_scale, -22 * boss_scale
        )
        -- Valkyrie lines detailing
        love.graphics.line(-38 * boss_scale, -22 * boss_scale, 0, -2 * boss_scale)
        love.graphics.line(38 * boss_scale, -22 * boss_scale, 0, -2 * boss_scale)
        -- Sharp horns
        love.graphics.line(-15 * boss_scale, -32 * boss_scale, -25 * boss_scale, -52 * boss_scale)
        love.graphics.line(-25 * boss_scale, -52 * boss_scale, -10 * boss_scale, -48 * boss_scale)
        love.graphics.line(15 * boss_scale, -32 * boss_scale, 25 * boss_scale, -52 * boss_scale)
        love.graphics.line(25 * boss_scale, -52 * boss_scale, 10 * boss_scale, -48 * boss_scale)
    else
        love.graphics.polygon("line", 
            0, -35 * boss_scale,
            28 * boss_scale, -12 * boss_scale,
            22 * boss_scale, 25 * boss_scale,
            0, 38 * boss_scale,
            -22 * boss_scale, 25 * boss_scale,
            -28 * boss_scale, -12 * boss_scale
        )
        love.graphics.line(-22 * boss_scale, 25 * boss_scale, 22 * boss_scale, 25 * boss_scale)
        love.graphics.line(0, -35 * boss_scale, 0, 10 * boss_scale)
        -- Antenna horns
        love.graphics.line(-10 * boss_scale, -32 * boss_scale, -16 * boss_scale, -48 * boss_scale)
        love.graphics.line(10 * boss_scale, -32 * boss_scale, 16 * boss_scale, -48 * boss_scale)
    end
    
    -- Eye glow backing
    local eye_color = {1.0, 0.9, 0.2, 1.0}
    love.graphics.setColor(eye_color[1], eye_color[2], eye_color[3], 0.15)
    love.graphics.ellipse("fill", -15 * boss_scale, 8 * boss_scale, 8 * boss_scale, 4 * boss_scale)
    love.graphics.ellipse("fill", 15 * boss_scale, 8 * boss_scale, 8 * boss_scale, 4 * boss_scale)
    
    -- Eyebrows
    love.graphics.setColor(base_color)
    love.graphics.setLineWidth(2)
    love.graphics.line(-18 * boss_scale, -12 * boss_scale, -4 * boss_scale, -6 * boss_scale)
    love.graphics.line(18 * boss_scale, -12 * boss_scale, 4 * boss_scale, -6 * boss_scale)
    
    -- Central Eye Core
    love.graphics.setColor(eye_color)
    love.graphics.circle("fill", 0, -2 * boss_scale, 6 * boss_scale)
    
    -- Aura pulse
    love.graphics.setColor(eye_color[1], eye_color[2], eye_color[3], 0.25 + 0.2 * math.sin(time * 10))
    love.graphics.circle("fill", 0, -2 * boss_scale, 10 * boss_scale)
    
    -- Rotate-styled outer ring
    local ring_radius = 52 * boss_scale
    love.graphics.setColor(base_color[1], base_color[2], base_color[3], 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", 0, 0, ring_radius)
    
    love.graphics.pop()
end

return grid_renderer
