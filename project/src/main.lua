-- main.lua - 1인칭 2.5D 리듬 슈팅 액션: Soulrock
local font_manager = require("font_manager")
local sound_synth = require("sound_synth")
local beat_manager = require("beat_manager")
local grid_renderer = require("grid_renderer")
local fx_manager = require("fx_manager")
local ui_overlay = require("ui_overlay")
local note = require("note")

-- Game State Variables
local game_state = "playing" -- "playing", "victory", "defeat"
local player_hp = 100
local gun_heat = 0.0
local is_overheated = false
local overheat_timer = 0.0
local score = 0
local combo = 0
local max_combo = 0

-- Boss States
local boss_hp = 100
local boss_shield = 100
local is_groggy = false
local shield_blast_triggered = false

-- Boss positioning coordinates (updated by renderer)
local boss_x = 0.0
local boss_y = -0.5

-- Setup and start a new game session
local function reset_game()
    player_hp = 100
    gun_heat = 0.0
    is_overheated = false
    overheat_timer = 0.0
    score = 0
    combo = 0
    max_combo = 0
    
    boss_hp = 100
    boss_shield = 100
    is_groggy = false
    shield_blast_triggered = false
    
    game_state = "playing"
    
    beat_manager.init()
    
    -- Restart procedural music soundtrack loop
    sound_synth.music_loop:seek(0)
    sound_synth.music_loop:play()
end

function love.load()
    -- Initialize components
    font_manager.init()
    sound_synth.init()
    
    -- Start in the Stage Selection Menu
    game_state = "menu"
end

function love.update(dt)
    if game_state == "menu" then
        -- Keep grid animations moving in the menu background
        grid_renderer.update(dt)
        fx_manager.update(dt)
        return
    end
    
    if game_state ~= "playing" then return end
    
    -- 1. Sync timeline with audio playback position
    local music_time = sound_synth.music_loop:tell()
    local is_new_beat = beat_manager.update(music_time)
    
    if is_new_beat then
        -- Pulse grid and camera zoom on beat kick
        grid_renderer.trigger_beat()
    end
    
    -- 2. Update visual systems and animations
    grid_renderer.update(dt)
    fx_manager.update(dt)
    ui_overlay.update(dt)
    
    -- 3. Update active notes
    local is_mouse_down = love.mouse.isDown(1)
    local misses = note.update_all(dt, music_time, beat_manager.beat_interval, is_mouse_down)
    
    if misses > 0 then
        -- Apply damage on missed notes
        player_hp = math.max(0, player_hp - misses * 8)
        combo = 0
        fx_manager.trigger_damage()
        sound_synth.play_miss()
    end
    
    -- 4. Check for active lasers (holding recovers HP, unblocked drains HP)
    -- Also apply continuous passive HP drain over time (rhythm pressure)
    player_hp = math.max(0, player_hp - 2.0 * dt)
    
    for _, n in ipairs(note.active_notes) do
        if n.type == "laser" then
            if n.is_holding then
                player_hp = math.min(100, player_hp + 6.5 * dt) -- Hold laser to recover
            elseif n.z <= 0.6 then
                player_hp = math.max(0, player_hp - 18 * dt) -- Unblocked laser damage
                combo = 0
                if math.random() > 0.88 then
                    fx_manager.trigger_damage()
                end
            end
        end
    end
    
    -- 5. Weapon Overheat Cooling Logic
    if is_overheated then
        overheat_timer = overheat_timer - dt
        gun_heat = math.max(0.0, overheat_timer / 0.5)
        if overheat_timer <= 0 then
            is_overheated = false
            gun_heat = 0.0
        end
    else
        gun_heat = math.max(0.0, gun_heat - 1.5 * dt)
    end
    
    -- 6. Groggy Shield blast penalty check (groggy end is reached and shield is still up)
    local groggy_end = beat_manager.get_groggy_limit()
    if beat_manager.current_beat >= groggy_end and not is_groggy and not shield_blast_triggered then
        shield_blast_triggered = true
        if boss_shield > 0 then
            -- Deal massive punishment damage
            player_hp = math.max(0, player_hp - 40)
            fx_manager.trigger_damage()
            fx_manager.trigger_shake(20.0, 0.5)
            sound_synth.play_overheat()
        end
    end
    
    -- 6.5. Update boss HP based on song progress (decreases from 100 to 0)
    local total_beats = beat_manager.track.total_beats
    local progress = math.min(1.0, beat_manager.current_beat / (total_beats - 1))
    boss_hp = math.max(0, 100 * (1.0 - progress))
    
    -- 7. Victory / Defeat State evaluations
    if player_hp <= 0 then
        game_state = "defeat"
        sound_synth.music_loop:stop()
        sound_synth.play_overheat()
    elseif beat_manager.current_beat >= beat_manager.track.total_beats - 1 then
        game_state = "victory"
        sound_synth.music_loop:stop()
        sound_synth.play_perfect()
        -- Health bonus multiplier
        score = score + player_hp * 60
    end
end

function love.draw()
    -- Clear background (analog dark scan)
    love.graphics.clear(0.04, 0.04, 0.08)
    
    -- Apply screen shake and render grid, boss, notes, particles
    love.graphics.push()
    fx_manager.apply_shake()
    
    -- Draw perspective wireframe corridor
    grid_renderer.draw_tunnel(love.timer.getTime())
    
    if game_state == "menu" then
        love.graphics.pop() -- Pop shake before drawing 2D UI
        local mx, my = love.mouse.getPosition()
        ui_overlay.draw_stage_select_menu(mx, my)
        return
    end
    
    -- Draw boss at Z=10.0 and capture its float offset coordinates
    local is_boss_charging = false
    local is_laser_held = false
    
    for _, n in ipairs(note.active_notes) do
        if n.type == "laser" and n.z <= 4.0 then
            is_boss_charging = true
            is_laser_held = n.is_holding
        end
    end
    
    -- Pass dynamic boss color, shield color, and stage index
    boss_x, boss_y = grid_renderer.draw_boss(
        love.timer.getTime(), 
        boss_shield, 
        is_groggy, 
        is_boss_charging,
        beat_manager.track.color,
        beat_manager.track.shield_color,
        beat_manager.active_stage_idx
    )
    
    -- Get current mouse position for aiming
    local mx, my = love.mouse.getPosition()
    
    -- Render laser beam overlay if active (directs to the stationary laser note)
    if is_boss_charging then
        local bx_screen, by_screen = grid_renderer.project(boss_x, boss_y)
        local lx, ly = mx, my
        for _, n in ipairs(note.active_notes) do
            if n.type == "laser" and n.z <= 4.0 then
                lx, ly = n.screen_x, n.screen_y
                break
            end
        end
        fx_manager.draw_laser_beam(bx_screen, by_screen, is_laser_held, lx, ly)
    end
    
    -- Draw active note crystals and guides
    note.draw_all(love.timer.getTime())
    
    -- Draw spark particles
    fx_manager.draw_particles()
    
    love.graphics.pop()
    
    -- Render glitch scanline filters
    fx_manager.draw_screen_overlays(1280, 720)
    
    -- Render HUD indicators (pass mx, my to draw crosshair at cursor)
    ui_overlay.draw_hud(player_hp, gun_heat, is_overheated, boss_hp, boss_shield, score, combo, is_groggy, mx, my)
    
    -- Render Victory/Defeat screen overlays
    if game_state ~= "playing" then
        ui_overlay.draw_screen_state(game_state, score, max_combo)
    end
end

function love.mousepressed(x, y, button)
    if button ~= 1 then return end
    
    if game_state == "menu" then
        -- Stage Select Click Detection
        local card_w = 360
        local card_h = 420
        local start_x = 240
        local start_y = 180
        local spacing = 80
        local clicked_idx = nil
        for idx = 1, 2 do
            local cx = start_x + (idx - 1) * (card_w + spacing)
            local cy = start_y
            if x >= cx and x <= cx + card_w and y >= cy and y <= cy + card_h then
                clicked_idx = idx
                break
            end
        end
        if clicked_idx then
            beat_manager.select_stage(clicked_idx)
            sound_synth.select_track(clicked_idx)
            reset_game()
        end
        return
    end
    
    if game_state ~= "playing" then
        reset_game()
        return
    end
    
    -- Shoot locking on overheat
    if is_overheated then
        sound_synth.play_overheat()
        return
    end
    
    -- Play shot effect
    sound_synth.play_shoot()
    
    -- Check timing and alignment (pass x, y click coordinates)
    local music_time = sound_synth.music_loop:tell()
    local rating, dmg, note_type = note.check_hit(music_time, beat_manager.beat_interval, x, y)
    
    if rating then
        -- Display rating popup
        ui_overlay.trigger_rating(rating)
        combo = combo + 1
        if combo > max_combo then max_combo = combo end
        
        -- Score formatting
        local mult = math.min(5, math.floor(combo / 10) + 1)
        local base_points = (rating == "PERFECT" and 100 or 50)
        score = score + base_points * mult
        
        -- Player HP recovery on successful hits (beat notes give less HP)
        if note_type == "beat" then
            if rating == "PERFECT" then
                player_hp = math.min(100, player_hp + 2.0)
            elseif rating == "COOL" then
                player_hp = math.min(100, player_hp + 1.0)
            end
        else
            if rating == "PERFECT" then
                player_hp = math.min(100, player_hp + 8.0)
            elseif rating == "COOL" then
                player_hp = math.min(100, player_hp + 4.0)
            end
        end
        
        -- Apply damage to boss / trigger sparks
        if note_type == "beat" then
            -- For beat notes, spawn nice subtle sparks at click point without screen shake
            local color = (rating == "PERFECT") and {1.0, 0.9, 0.4} or {0.4, 0.9, 1.0}
            fx_manager.spawn_sparks(x, y, color)
        else
            -- Boss target hits trigger massive screen shake and boss shield/HP damage
            if beat_manager.is_groggy_phase() and boss_shield > 0 then
                if rating == "PERFECT" then
                    boss_shield = math.max(0, boss_shield - 20)
                    fx_manager.spawn_sparks(x, y, {0.2, 0.85, 0.95}) -- Cyan sparks at click point
                    fx_manager.trigger_shake(8.0, 0.15)
                elseif rating == "COOL" then
                    boss_shield = math.max(0, boss_shield - 10)
                    fx_manager.spawn_sparks(x, y, {0.2, 0.85, 0.95})
                    fx_manager.trigger_shake(5.0, 0.12)
                end
                
                if boss_shield <= 0 then
                    is_groggy = true
                    sound_synth.play_perfect()
                    fx_manager.trigger_shake(16.0, 0.35)
                end
            else
                -- Normal phase or groggy phase (shield already broken)
                local color = (rating == "PERFECT") and {1.0, 0.85, 0.1} or {0.2, 0.85, 0.95}
                fx_manager.spawn_sparks(x, y, color)
                fx_manager.trigger_shake((rating == "PERFECT") and 10.0 or 5.0, 0.16)
            end
        end
    else
        -- Shoot miss / off-beat trigger / off-target trigger -> Trigger Gun Overheat
        combo = 0
        gun_heat = 1.0
        is_overheated = true
        overheat_timer = 0.5 -- 0.5s shoot lock
        ui_overlay.trigger_rating("MISS")
        sound_synth.play_overheat()
        fx_manager.trigger_glitch()
        
        -- Penalty damage on missed/off-beat shots
        player_hp = math.max(0, player_hp - 5.0)
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif game_state == "menu" then
        if key == "1" or key == "kp1" then
            beat_manager.select_stage(1)
            sound_synth.select_track(1)
            reset_game()
        elseif key == "2" or key == "kp2" then
            beat_manager.select_stage(2)
            sound_synth.select_track(2)
            reset_game()
        end
    else
        -- Playing or result screen
        if key == "r" then
            reset_game()
        elseif key == "m" then
            game_state = "menu"
            sound_synth.music_loop:stop()
        end
    end
end
