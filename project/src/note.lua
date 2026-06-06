-- 2.5D Rhythm Note Manager for Soulrock.
-- Handles notes spawning, movement, time-based Z updating, and click judgments.
local grid_renderer = require("grid_renderer")
local sound_synth = require("sound_synth")

local note = {}

note.active_notes = {}

-- Spawns a new note
-- Spawns a new note at static screen coordinates mapped from corners
function note.spawn(note_type, target_beat, travel_beats, start_x, start_y, end_beat)
    local n = {}
    n.type = note_type          -- "breakable" or "laser"
    n.target_beat = target_beat
    n.travel_beats = travel_beats or 4
    n.start_x = start_x or 0.0
    n.start_y = start_y or -0.5
    n.end_beat = end_beat       -- Only for lasers
    
    n.hit_evaluated = false
    n.release_evaluated = false
    n.is_holding = false
    
    -- Map corner coordinates to static screen positions (rhythm targets)
    local center_x = 1280 / 2
    local center_y = 720 / 2
    n.screen_x = center_x + n.start_x * 220
    n.screen_y = center_y + n.start_y * 180
    
    n.z = 10.0
    
    table.insert(note.active_notes, n)
end

-- Clear all notes
function note.clear()
    note.active_notes = {}
end

-- Update all notes
-- Returns: list of missed notes triggering damage
function note.update_all(dt, current_time, beat_interval, is_mouse_down)
    local misses = 0
    local current_beat = current_time / beat_interval
    
    for i = #note.active_notes, 1, -1 do
        local n = note.active_notes[i]
        
        local start_beat = n.target_beat - n.travel_beats
        local progress = (current_beat - start_beat) / n.travel_beats
        
        if progress < 0 then progress = 0 end
        
        -- Keep Z updating for visual status/laser checks
        n.z = 10.0 - 9.5 * progress
        
        -- Check for Auto-Miss (passed the timing window)
        if n.type == "breakable" then
            if progress >= 1.0 + (0.15 / beat_interval) then -- exceeded cool window
                table.remove(note.active_notes, i)
                misses = misses + 1
            end
        elseif n.type == "laser" then
            -- If laser start is passed without being held
            if not n.is_holding and current_beat >= n.target_beat + (0.15 / beat_interval) then
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
                    table.remove(note.active_notes, i)
                    sound_synth.play_perfect()
                end
            end
        elseif n.type == "beat" then
            if progress >= 1.0 + (0.15 / beat_interval) then -- exceeded cool window
                table.remove(note.active_notes, i)
                -- Silent removal, no misses increment
            end
        end
    end
    
    return misses
end

-- Evaluates click hit (when player clicks mouse)
-- Verify timing AND mouse pointer proximity to static note screen coordinates
-- Returns: rating ("PERFECT", "COOL", or nil), damage (to boss), note_type
function note.check_hit(current_time, beat_interval, mx, my)
    local current_beat = current_time / beat_interval
    local best_idx = nil
    local min_dist = 9999.0
    
    -- 1. Try to find a boss note (breakable or laser) first
    for i, n in ipairs(note.active_notes) do
        if n.type == "breakable" or (n.type == "laser" and not n.is_holding) then
            local beat_dist = math.abs(current_beat - n.target_beat)
            local time_offset = beat_dist * beat_interval
            
            -- Generous timing window: up to 0.22s (COOL window)
            if time_offset <= 0.22 then
                -- Spatial check: distance from click to static note position
                local dist_px = math.sqrt((mx - n.screen_x)^2 + (my - n.screen_y)^2)
                
                -- Generous hit bounding box (fixed 80px radius for stationary cards)
                local hit_radius = 80
                
                if dist_px <= hit_radius then
                    if beat_dist < min_dist then
                        min_dist = beat_dist
                        best_idx = i
                    end
                end
            end
        end
    end
    
    -- 2. If no boss note is within range, check for a "beat" note
    if not best_idx then
        for i, n in ipairs(note.active_notes) do
            if n.type == "beat" then
                local beat_dist = math.abs(current_beat - n.target_beat)
                local time_offset = beat_dist * beat_interval
                
                if time_offset <= 0.22 then
                    if beat_dist < min_dist then
                        min_dist = beat_dist
                        best_idx = i
                    end
                end
            end
        end
    end
    
    if not best_idx then return nil, 0, nil end
    
    local target_note = note.active_notes[best_idx]
    local time_offset = min_dist * beat_interval -- convert beat dist to seconds
    
    -- Generous ratings
    if time_offset <= 0.08 then
        -- PERFECT (<= 0.08s)
        if target_note.type == "breakable" or target_note.type == "beat" then
            table.remove(note.active_notes, best_idx)
            sound_synth.play_perfect()
        else
            -- Laser starts holding
            target_note.is_holding = true
            sound_synth.play_shoot()
        end
        return "PERFECT", (target_note.type == "beat" and 0 or 15), target_note.type
    elseif time_offset <= 0.22 then
        -- COOL (<= 0.22s)
        if target_note.type == "breakable" or target_note.type == "beat" then
            table.remove(note.active_notes, best_idx)
            sound_synth.play_cool()
        else
            -- Laser starts holding
            target_note.is_holding = true
            sound_synth.play_shoot()
        end
        return "COOL", (target_note.type == "beat" and 0 or 8), target_note.type
    end
    
    return nil, 0, nil
end

-- Draw active notes (Stationary targets with shrinking timing circles)
function note.draw_all(time)
    local beat_manager = require("beat_manager")
    local current_beat = beat_manager.current_beat
    
    for _, n in ipairs(note.active_notes) do
        local sx, sy = n.screen_x, n.screen_y
        
        love.graphics.push()
        love.graphics.translate(sx, sy)
        
        local start_beat = n.target_beat - n.travel_beats
        local progress = (current_beat - start_beat) / n.travel_beats
        if progress < 0 then progress = 0 end
        if progress > 1.0 then progress = 1.0 end
        
        if n.type == "breakable" then
            -- Draw static crystal core
            -- Glowing polygon fill
            love.graphics.setColor(0.95, 0.2, 0.2, 0.35 + 0.15 * math.sin(time * 12))
            love.graphics.polygon("fill", 0, -30, 24, 0, 0, 30, -24, 0)
            
            -- Outlines
            love.graphics.setColor(1, 0.35, 0.35, 0.95)
            love.graphics.setLineWidth(2.5)
            love.graphics.polygon("line", 0, -27, 22, 0, 0, 27, -22, 0)
            
            -- Inner core
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.polygon("fill", 0, -11, 8, 0, 0, 11, -8, 0)
            
        elseif n.type == "laser" then
            -- Draw static laser anchor
            local laser_color = n.is_holding and {0.2, 0.8, 1.0, 0.9} or {0.2, 0.5, 0.95, 0.85}
            
            love.graphics.setColor(laser_color)
            love.graphics.setLineWidth(3)
            love.graphics.circle("line", 0, 0, 24)
            
            -- Inner core
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.circle("fill", 0, 0, 10)
            
            -- Electricity arcs if held
            if n.is_holding then
                love.graphics.setColor(0.5, 0.9, 1.0, 0.7)
                love.graphics.setLineWidth(1)
                for i = 1, 4 do
                    local rx = math.random(-20, 20)
                    local ry = math.random(-20, 20)
                    love.graphics.line(0, 0, rx, ry)
                end
            end
        end
        
        love.graphics.pop()
    end
end

return note
