-- 2.5D Rhythm Note Manager for Soulrock.
-- Handles notes spawning, movement, time-based Z updating, and click judgments.
local grid_renderer = require("grid_renderer")
local sound_synth = require("sound_synth")

local note = {}

note.active_notes = {}

-- Spawns a new note
-- Spawns a new note at static screen coordinates mapped from corners
-- Spawns a new note at absolute screen coordinates with combo sequence number
function note.spawn(note_type, target_beat, travel_beats, screen_x, screen_y, end_beat, combo_num)
    local n = {}
    n.type = note_type          -- "breakable", "laser", or "beat"
    n.target_beat = target_beat
    n.travel_beats = travel_beats or 2.5
    n.end_beat = end_beat       -- Only for lasers
    n.combo_num = combo_num or 1
    
    n.hit_evaluated = false
    n.release_evaluated = false
    n.is_holding = false
    
    n.screen_x = screen_x
    n.screen_y = screen_y
    
    n.z = 10.0
    
    table.insert(note.active_notes, n)
end

note.hit_feedbacks = {}

-- Clear all notes
function note.clear()
    note.active_notes = {}
    note.hit_feedbacks = {}
end

-- Spawns hit feedback animation
function note.spawn_hit_feedback(note_type, x, y, color)
    local fb = {
        type = note_type,
        x = x,
        y = y,
        color = color or {0.15, 0.75, 0.9},
        age = 0,
        max_age = 0.25, -- 250ms animation duration
    }
    table.insert(note.hit_feedbacks, fb)
end

-- Update active feedback timings
function note.update_feedbacks(dt)
    for i = #note.hit_feedbacks, 1, -1 do
        local fb = note.hit_feedbacks[i]
        fb.age = fb.age + dt
        if fb.age >= fb.max_age then
            table.remove(note.hit_feedbacks, i)
        end
    end
end

-- Get next hit target (the oldest active note that is not yet held)
function note.get_next_target()
    for _, n in ipairs(note.active_notes) do
        if n.type ~= "drag" and not n.is_holding then
            return n
        end
    end
    return nil
end

-- Update all notes
-- Returns: count of missed notes triggering damage
function note.update_all(dt, current_time, beat_interval, is_mouse_down, mx, my)
    -- Update existing hit feedback timings
    note.update_feedbacks(dt)
    
    local misses = 0
    local hits = {}
    local current_beat = current_time / beat_interval
    
    for i = #note.active_notes, 1, -1 do
        local n = note.active_notes[i]
        
        local start_beat = n.target_beat - n.travel_beats
        local progress = (current_beat - start_beat) / n.travel_beats
        
        if progress < 0 then progress = 0 end
        
        -- Keep Z updating for visual status/laser checks
        n.z = 10.0 - 9.5 * math.min(1.0, progress)
        
        -- Check for Drag note hover hit (Cursor overlaps active drag note when held)
        if n.type == "drag" and is_mouse_down and not n.hit_evaluated then
            local beat_dist = math.abs(current_beat - n.target_beat)
            local time_offset = beat_dist * beat_interval
            
            if time_offset <= 0.35 then
                local dist = math.sqrt((mx - n.screen_x)^2 + (my - n.screen_y)^2)
                if dist <= 90 then -- generous hitbox for drag
                    n.hit_evaluated = true
                    local rating = "GOOD"
                    if time_offset <= 0.15 then
                        rating = "PERFECT"
                    end
                    table.insert(hits, {rating = rating, note_type = n.type, x = n.screen_x, y = n.screen_y})
                    note.spawn_hit_feedback("drag", n.screen_x, n.screen_y, {0.95, 0.15, 0.55}) -- Spawn drag splash
                    table.remove(note.active_notes, i)
                    goto next_loop
                end
            end
        end
        
        -- Check for Auto-Miss (passed the timing window)
        if n.type == "breakable" or n.type == "beat" or n.type == "drag" then
            if current_beat >= n.target_beat + (0.40 / beat_interval) then -- exceeded 400ms (BAD window)
                table.remove(note.active_notes, i)
                misses = misses + 1
            end
        elseif n.type == "laser" then
            -- Auto-activation: if the player is holding the key and hovering when the note is active
            if not n.is_holding then
                local time_offset = math.abs(current_beat - n.target_beat) * beat_interval
                if time_offset <= 0.25 and is_mouse_down then
                    local dist = math.sqrt((mx - n.screen_x)^2 + (my - n.screen_y)^2)
                    if dist <= 90 then
                        n.is_holding = true
                        sound_synth.play_shoot()
                        note.spawn_hit_feedback("laser_start", n.screen_x, n.screen_y, {0.2, 0.95, 0.3}) -- Spawn laser start lock-on
                        
                        -- Set timing rating on activation
                        local rating = "BAD"
                        if time_offset <= 0.15 then
                            rating = "PERFECT"
                        elseif time_offset <= 0.22 then
                            rating = "GOOD"
                        end
                        n.activate_rating = rating
                    end
                end
            end
            
            -- If laser start is passed without being held within 400ms
            if not n.is_holding and current_beat >= n.target_beat + (0.40 / beat_interval) then
                table.remove(note.active_notes, i)
                misses = misses + 1
            -- If currently holding
            elseif n.is_holding then
                if not is_mouse_down then
                    -- Early release! Miss!
                    table.remove(note.active_notes, i)
                    sound_synth.play_miss()
                    misses = misses + 1
                elseif current_beat >= n.end_beat then
                    -- Successfully held to the end!
                    note.spawn_hit_feedback("laser", n.screen_x, n.screen_y, {0.2, 0.95, 0.3}) -- Spawn laser completion explosion
                    table.remove(note.active_notes, i)
                    sound_synth.play_perfect()
                    
                    -- Score and trigger rating popup only when successfully held to the end
                    local rating = n.activate_rating or "PERFECT"
                    table.insert(hits, {rating = rating, note_type = n.type, x = n.screen_x, y = n.screen_y})
                end
            end
        end
        ::next_loop::
    end
    
    return misses, hits
end

-- Evaluates click hit (when player clicks mouse)
-- Verify timing, sequence order, and cursor proximity to target circle across all active notes spatially
-- Returns: rating ("300", "100", "50", or nil), damage (to boss), note_type
function note.check_hit(current_time, beat_interval, mx, my)
    local current_beat = current_time / beat_interval
    
    local best_note = nil
    local best_idx = nil
    local best_dist = 999999
    
    -- Search all active notes for the spatially closest valid target within timing window
    for idx, n in ipairs(note.active_notes) do
        if n.type ~= "drag" and not n.is_holding then
            local beat_dist = math.abs(current_beat - n.target_beat)
            local time_offset = beat_dist * beat_interval
            
            if time_offset <= 0.40 then
                local dist_px = math.sqrt((mx - n.screen_x)^2 + (my - n.screen_y)^2)
                local hit_radius = 90
                
                if dist_px <= hit_radius then
                    if dist_px < best_dist then
                        best_dist = dist_px
                        best_note = n
                        best_idx = idx
                    end
                end
            end
        end
    end
    
    if not best_note then return nil, 0, nil end
    
    local n = best_note
    local beat_dist = math.abs(current_beat - n.target_beat)
    local time_offset = beat_dist * beat_interval
    
    local rating = "BAD"
    if time_offset <= 0.15 then
        rating = "PERFECT"
    elseif time_offset <= 0.28 then
        rating = "GOOD"
    end
    
    local damage = 0
    if n.type == "breakable" or n.type == "laser" then
        damage = (rating == "PERFECT" and 20 or (rating == "GOOD" and 10 or 5))
    end
    
    if n.type == "breakable" or n.type == "beat" then
        local beat_manager = require("beat_manager")
        local stage_color = beat_manager.track.color or {0.15, 0.75, 0.9, 0.95}
        note.spawn_hit_feedback(n.type, n.screen_x, n.screen_y, stage_color) -- Spawn tap visual ripple
        table.remove(note.active_notes, best_idx)
        if rating == "PERFECT" then
            sound_synth.play_perfect()
        else
            sound_synth.play_cool()
        end
        return rating, damage, n.type
    else
        -- Laser starts holding, defer scoring and rating popup until successful release at end
        n.is_holding = true
        n.activate_rating = rating
        note.spawn_hit_feedback("laser_start", n.screen_x, n.screen_y, {0.2, 0.95, 0.3}) -- Spawn hold start ripple
        sound_synth.play_shoot()
        return nil, 0, nil
    end
end

-- Draw the Cytus horizontal scanline
function note.draw_scanline(time)
    local beat_manager = require("beat_manager")
    local sy, direction = beat_manager.get_scanline_y(beat_manager.current_beat)
    local stage_color = beat_manager.track.color or {0.15, 0.75, 0.9, 0.95}
    
    love.graphics.push()
    
    -- Glow trail
    for i = 1, 6 do
        local alpha = 0.04 * (7 - i)
        love.graphics.setColor(stage_color[1], stage_color[2], stage_color[3], alpha)
        love.graphics.setLineWidth(i * 2)
        love.graphics.line(120, sy, 1160, sy)
    end
    
    -- White core line
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.setLineWidth(2.5)
    love.graphics.line(120, sy, 1160, sy)
    
    -- Dotted side anchors
    love.graphics.setColor(stage_color)
    love.graphics.circle("fill", 120, sy, 6)
    love.graphics.circle("fill", 1160, sy, 6)
    
    -- Glow aura on anchors
    love.graphics.setColor(stage_color[1], stage_color[2], stage_color[3], 0.3 + 0.2 * math.sin(time * 10))
    love.graphics.circle("fill", 120, sy, 12)
    love.graphics.circle("fill", 1160, sy, 12)
    
    -- Direction arrows
    local font_manager = require("font_manager")
    local font_arrow = font_manager.get_font(14)
    love.graphics.setFont(font_arrow)
    love.graphics.setColor(1, 1, 1, 0.7)
    if direction == 1 then
        love.graphics.print("▼", 96, sy - 8)
        love.graphics.print("▼", 1172, sy - 8)
    else
        love.graphics.print("▲", 96, sy - 8)
        love.graphics.print("▲", 1172, sy - 8)
    end
    
    love.graphics.pop()
end

-- Draw active 2D notes in Cytus standard visual style
function note.draw_all(time)
    local beat_manager = require("beat_manager")
    local font_manager = require("font_manager")
    local current_beat = beat_manager.current_beat
    local font_num = font_manager.get_font(20)
    
    -- Active stage color
    local stage_color = beat_manager.track.color or {0.15, 0.75, 0.9, 0.95}
    
    for _, n in ipairs(note.active_notes) do
        local sx, sy = n.screen_x, n.screen_y
        
        -- Draw drag chain connecting lines first (behind circles)
        if n.type == "drag" then
            local next_drag = nil
            for _, other in ipairs(note.active_notes) do
                if other.type == "drag" and other.target_beat > n.target_beat and other.target_beat - n.target_beat < 1.0 then
                    if not next_drag or other.target_beat < next_drag.target_beat then
                        next_drag = other
                    end
                end
            end
            
            if next_drag then
                -- Determine chain opacity based on average progress
                local start_beat = n.target_beat - n.travel_beats
                local progress = (current_beat - start_beat) / n.travel_beats
                local alpha = progress < 0.4 and (progress / 0.4) or 1.0
                
                -- Draw a connecting neon track line
                love.graphics.setColor(stage_color[1], stage_color[2], stage_color[3], alpha * 0.45)
                love.graphics.setLineWidth(6)
                love.graphics.line(n.screen_x, n.screen_y, next_drag.screen_x, next_drag.screen_y)
                
                -- Inner white trace line
                love.graphics.setColor(1.0, 1.0, 1.0, alpha * 0.5)
                love.graphics.setLineWidth(2)
                love.graphics.line(n.screen_x, n.screen_y, next_drag.screen_x, next_drag.screen_y)
            end
        end
        
        love.graphics.push()
        love.graphics.translate(sx, sy)
        
        local start_beat = n.target_beat - n.travel_beats
        local progress = (current_beat - start_beat) / n.travel_beats
        if progress < 0 then progress = 0 end
        
        -- Sizing (drag notes are smaller)
        local base_r = 52
        if n.type == "drag" then
            base_r = 28
        end
        
        -- Determine opacity (fade in as progress goes 0.0 -> 0.4)
        local alpha = 1.0
        if progress < 0.4 then
            alpha = progress / 0.4
        end
        -- Fade out if missed/past timing
        if progress > 1.0 then
            if n.type == "laser" and n.is_holding then
                alpha = 1.0
            else
                alpha = math.max(0.0, 1.0 - (progress - 1.0) / (0.40 / n.travel_beats))
            end
        end
        
        -- 0. Draw Laser Track (behind note body)
        if n.type == "laser" then
            local end_y = beat_manager.get_scanline_y(n.end_beat)
            local ry_end = end_y - sy
            
            -- Outer glowing thick line
            love.graphics.setColor(stage_color[1], stage_color[2], stage_color[3], alpha * 0.25)
            love.graphics.setLineWidth(24)
            love.graphics.line(0, 0, 0, ry_end)
            
            -- Inner glow line
            love.graphics.setColor(stage_color[1], stage_color[2], stage_color[3], alpha * 0.45)
            love.graphics.setLineWidth(10)
            love.graphics.line(0, 0, 0, ry_end)
            
            -- Core white track line
            love.graphics.setColor(1.0, 1.0, 1.0, alpha * 0.55)
            love.graphics.setLineWidth(3)
            love.graphics.line(0, 0, 0, ry_end)
            
            -- End cap line
            love.graphics.setColor(stage_color[1], stage_color[2], stage_color[3], alpha * 0.85)
            love.graphics.setLineWidth(4)
            love.graphics.line(-18, ry_end, 18, ry_end)
            
            -- If holding, draw hold progress fill
            if n.is_holding then
                local hold_duration = n.end_beat - n.target_beat
                local hold_progress = (current_beat - n.target_beat) / hold_duration
                hold_progress = math.min(1.0, math.max(0.0, hold_progress))
                local ry_progress = ry_end * hold_progress
                
                -- Glowing green track fill
                local fill_color = {0.2, 0.95, 0.3}
                love.graphics.setColor(fill_color[1], fill_color[2], fill_color[3], alpha * 0.7)
                love.graphics.setLineWidth(18)
                love.graphics.line(0, 0, 0, ry_progress)
                
                -- White core progress line
                love.graphics.setColor(1.0, 1.0, 1.0, alpha * 0.95)
                love.graphics.setLineWidth(4)
                love.graphics.line(0, 0, 0, ry_progress)
                
                -- Shimmering diamond sparks along the green held line
                local num_sparkles = 10
                for j = 1, num_sparkles do
                    local t_part = (j - 1) / (num_sparkles - 1)
                    local sparkle_y = ry_progress * t_part
                    
                    local shimmer = 0.5 + 0.5 * math.sin(time * 20 + j * 1.5)
                    local offset_x = math.sin(time * 12 + j * 2.3) * 5 * shimmer
                    local size = 3 + 4 * shimmer
                    
                    love.graphics.setColor(1.0, 1.0, 1.0, alpha * 0.75 * shimmer)
                    love.graphics.polygon("fill", 
                        offset_x, sparkle_y - size, 
                        offset_x + size/2, sparkle_y, 
                        offset_x, sparkle_y + size, 
                        offset_x - size/2, sparkle_y
                    )
                end
                
                -- Outward spray of spark particles at the active contact point
                for j = 1, 6 do
                    local angle = time * 6 + j * (math.pi / 3)
                    local dist = 12 + 10 * math.sin(time * 15 + j)
                    local sx_part = math.cos(angle) * dist
                    local sy_part = ry_progress + math.sin(angle) * dist
                    local size = 2 + 3 * (0.5 + 0.5 * math.cos(time * 25 + j))
                    
                    love.graphics.setColor(0.3, 0.95, 0.5, alpha * 0.85)
                    love.graphics.circle("fill", sx_part, sy_part, size)
                end
                
                -- Circular progress ring around the note head showing remaining duration
                love.graphics.setColor(0.2, 0.95, 0.3, alpha * 0.9)
                love.graphics.setLineWidth(4)
                local start_angle = -math.pi / 2
                local end_angle = start_angle + math.pi * 2 * (1.0 - hold_progress)
                love.graphics.arc("line", "open", 0, 0, base_r + 10, start_angle, end_angle, 32)
                
                -- Active contact point pulse at scanline
                love.graphics.setColor(fill_color[1], fill_color[2], fill_color[3], alpha * 0.45)
                love.graphics.circle("fill", 0, ry_progress, 16 + 5 * math.sin(time * 18))
                love.graphics.setColor(1.0, 1.0, 1.0, alpha * 0.95)
                love.graphics.circle("fill", 0, ry_progress, 6)
            end
        end

        -- 1. Draw Cytus-style pulsing outer circle timing indicator
        local pulse_scale = 1.0 + 0.15 * (1.0 - math.min(1.0, progress))
        local pulse_r = base_r * pulse_scale
        local pulse_alpha = alpha * 0.45
        if progress >= 1.0 then
            pulse_alpha = 0.0
        end
        
        love.graphics.setColor(stage_color[1], stage_color[2], stage_color[3], pulse_alpha)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", 0, 0, pulse_r)
        
        -- 2. Draw Hit Circle Fill & Border
        local circle_color = stage_color
        if n.type == "laser" and n.is_holding then
            circle_color = {0.2, 0.95, 0.3, 0.9} -- green glowing when held
        elseif n.type == "drag" then
            circle_color = {0.95, 0.15, 0.55, 0.9} -- deep pink/magenta for drag notes
        end
        
        -- Fill
        love.graphics.setColor(circle_color[1], circle_color[2], circle_color[3], alpha * 0.25)
        love.graphics.circle("fill", 0, 0, base_r)
        
        -- Border
        love.graphics.setColor(circle_color[1], circle_color[2], circle_color[3], alpha * 0.9)
        love.graphics.setLineWidth(3.5)
        love.graphics.circle("line", 0, 0, base_r)
        
        -- White inner border
        love.graphics.setColor(1.0, 1.0, 1.0, alpha * 0.8)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", 0, 0, base_r - 2)
        
        -- 3. Draw Note specific internals
        if n.type == "laser" then
            -- Draw a central glowing anchor ring for the laser node
            love.graphics.setColor(1, 1, 1, alpha * 0.75)
            love.graphics.setLineWidth(3)
            love.graphics.circle("line", 0, 0, 18)
            
            love.graphics.setColor(circle_color[1], circle_color[2], circle_color[3], alpha * 0.5)
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", 0, 0, base_r - 8)
        elseif n.type == "breakable" then
            -- Breakable diamond crest in center
            love.graphics.setColor(1.0, 0.3, 0.3, alpha * 0.7)
            love.graphics.polygon("fill", 0, -12, 12, 0, 0, 12, -12, 0)
        elseif n.type == "drag" then
            -- Small central white core for drag nodes
            love.graphics.setColor(1.0, 1.0, 1.0, alpha * 0.95)
            love.graphics.circle("fill", 0, 0, 8)
        end
        
        -- 4. Draw Combo Number (centered, only for tap and hold notes, not drag notes)
        if n.type ~= "drag" then
            love.graphics.setFont(font_num)
            love.graphics.setColor(1.0, 1.0, 1.0, alpha * 0.95)
            local num_str = tostring(n.combo_num)
            local tw = font_num:getWidth(num_str)
            local th = font_num:getHeight()
            love.graphics.print(num_str, -tw/2, -th/2)
        end
        
        love.graphics.pop()
    end
    
    -- Draw active hit feedback animations
    for _, fb in ipairs(note.hit_feedbacks) do
        local t = fb.age / fb.max_age
        love.graphics.push()
        love.graphics.translate(fb.x, fb.y)
        
        local color = fb.color
        
        if fb.type == "drag" then
            -- Drag note hit explosion: juicy expansion & particles
            local alpha = 1.0 - t
            
            -- 1. Expanding hollow ring
            local r_ring = 28 + (65 - 28) * t
            love.graphics.setColor(color[1], color[2], color[3], alpha * 0.75)
            love.graphics.setLineWidth(3.0 * (1.0 - t))
            love.graphics.circle("line", 0, 0, r_ring)
            
            -- 2. Expanding filled core
            local r_fill = 12 + (32 - 12) * t
            love.graphics.setColor(color[1], color[2], color[3], alpha * 0.45)
            love.graphics.circle("fill", 0, 0, r_fill)
            
            -- 3. Diagnostic diagonal micro-shards
            love.graphics.setLineWidth(1.5)
            for j = 1, 4 do
                local angle = (j - 1) * (math.pi / 2) + math.pi/4 + t * 0.5
                local dist = 18 + 40 * t
                local shard_x = math.cos(angle) * dist
                local shard_y = math.sin(angle) * dist
                
                -- Draw a small diamond shard
                local size = 4 * (1.0 - t)
                love.graphics.setColor(1, 1, 1, alpha * 0.9)
                love.graphics.polygon("fill", 
                    shard_x, shard_y - size, 
                    shard_x + size, shard_y, 
                    shard_x, shard_y + size, 
                    shard_x - size, shard_y
                )
            end
            
        elseif fb.type == "laser_start" then
            -- Hold note initial lock-on ripple
            local alpha = 1.0 - t
            local r_ring = 52 + (90 - 52) * t
            love.graphics.setColor(color[1], color[2], color[3], alpha * 0.8)
            love.graphics.setLineWidth(2.5 * (1.0 - t))
            love.graphics.circle("line", 0, 0, r_ring)
            
            -- Concentric inner ring
            local r_ring2 = 30 + (50 - 30) * t
            love.graphics.setColor(1.0, 1.0, 1.0, alpha * 0.6)
            love.graphics.setLineWidth(1.0)
            love.graphics.circle("line", 0, 0, r_ring2)
            
        elseif fb.type == "laser" then
            -- Hold note completion explosion (big, satisfying green splash)
            local alpha = 1.0 - t
            
            -- Concentric rings
            local r1 = 52 + (120 - 52) * t
            love.graphics.setColor(color[1], color[2], color[3], alpha * 0.9)
            love.graphics.setLineWidth(4.0 * (1.0 - t))
            love.graphics.circle("line", 0, 0, r1)
            
            local r2 = 30 + (80 - 30) * t
            love.graphics.setColor(1.0, 1.0, 1.0, alpha * 0.7)
            love.graphics.setLineWidth(2.0 * (1.0 - t))
            love.graphics.circle("line", 0, 0, r2)
            
            -- 6 outward expanding dots
            for j = 1, 6 do
                local angle = (j - 1) * (math.pi * 2 / 6) + t * 0.8
                local dist = 40 + 70 * t
                local dot_x = math.cos(angle) * dist
                local dot_y = math.sin(angle) * dist
                love.graphics.setColor(color[1], color[2], color[3], alpha * 0.9)
                love.graphics.circle("fill", dot_x, dot_y, 4 * (1.0 - t))
            end
            
        else
            -- Tap notes (breakable/beat): dramatic neon blast
            local alpha = 1.0 - t
            
            -- 1. Outer main expanding ring
            local r1 = 52 + (110 - 52) * t
            love.graphics.setColor(color[1], color[2], color[3], alpha * 0.85)
            love.graphics.setLineWidth(4.0 * (1.0 - t))
            love.graphics.circle("line", 0, 0, r1)
            
            -- 2. Inner secondary ring
            local r2 = 30 + (80 - 30) * t
            love.graphics.setColor(1.0, 1.0, 1.0, alpha * 0.6)
            love.graphics.setLineWidth(2.0 * (1.0 - t))
            love.graphics.circle("line", 0, 0, r2)
            
            -- 3. Expanding glowing center fill
            local r_fill = 20 + (50 - 20) * t
            love.graphics.setColor(color[1], color[2], color[3], alpha * 0.35)
            love.graphics.circle("fill", 0, 0, r_fill)
            
            -- 4. Crosshair spokes expanding outward
            love.graphics.setColor(color[1], color[2], color[3], alpha * 0.5)
            love.graphics.setLineWidth(1.5)
            local spoke_start = 20 + 35 * t
            local spoke_len = 10 * (1.0 - t)
            for j = 1, 4 do
                local angle = (j - 1) * (math.pi / 2)
                local c = math.cos(angle)
                local s = math.sin(angle)
                love.graphics.line(c * spoke_start, s * spoke_start, c * (spoke_start + spoke_len), s * (spoke_start + spoke_len))
            end
        end
        
        love.graphics.pop()
    end
end

return note
