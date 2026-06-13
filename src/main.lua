-- main.lua - 1인칭 2.5D 리듬 슈팅 액션: Soulrock
local font_manager = require("font_manager")
local sound_synth = require("sound_synth")
local beat_manager = require("beat_manager")
local grid_renderer = require("grid_renderer")
local fx_manager = require("fx_manager")
local ui_overlay = require("ui_overlay")
local note = require("note")
local fft_analyzer = require("fft")

-- Game State Variables
local game_state = "playing" -- "playing", "victory", "defeat"
local player_hp = 100
local gun_heat = 0.0
local is_overheated = false
local overheat_timer = 0.0
local score = 0
local combo = 0
local max_combo = 0
local hit_perfect = 0
local hit_good = 0
local hit_miss = 0

-- Boss States
local boss_hp = 100
local boss_shield = 100
local is_groggy = false
local shield_blast_triggered = false

-- Boss positioning coordinates (updated by renderer)
local boss_x = 0.0
local boss_y = -0.5

-- Calculate accuracy grade (S, A, B, C, D)
local function get_accuracy_rank()
    local total_notes = hit_perfect + hit_good + hit_miss
    if total_notes == 0 then return "D" end
    
    local acc = (hit_perfect + hit_good * 0.5) / total_notes
    if acc >= 0.95 then
        return "S"
    elseif acc >= 0.85 then
        return "A"
    elseif acc >= 0.70 then
        return "B"
    elseif acc >= 0.50 then
        return "C"
    else
        return "D"
    end
end

-- Setup and start a new game session
local function reset_game()
    player_hp = 100
    gun_heat = 0.0
    is_overheated = false
    overheat_timer = 0.0
    score = 0
    combo = 0
    max_combo = 0
    hit_perfect = 0
    hit_good = 0
    hit_miss = 0
    
    boss_hp = 100
    boss_shield = 100
    is_groggy = false
    shield_blast_triggered = false
    
    game_state = "playing"
    
    beat_manager.init()
    
    -- Load static game track for gameplay
    sound_synth.load_game_track(beat_manager.active_stage_idx)
    
    -- Restart procedural music soundtrack loop
    sound_synth.music_loop:seek(0)
    sound_synth.music_loop:play()
end

-- Stage Background Images Cache
local stage_bgs = {}
local main_bg_img = nil

local function draw_bg_image(img, opacity)
    if not img then return end
    local screen_w, screen_h = 1280, 720
    local img_w, img_h = img:getDimensions()
    local scale = math.max(screen_w / img_w, screen_h / img_h)
    local tx = (screen_w - img_w * scale) / 2
    local ty = (screen_h - img_h * scale) / 2
    love.graphics.setColor(1, 1, 1, opacity)
    love.graphics.draw(img, tx, ty, 0, scale, scale)
end

function love.load()
    -- Initialize components
    font_manager.init()
    sound_synth.init()
    
    -- Load main screen image
    local ok, img = pcall(love.graphics.newImage, "Main/Main.png")
    if ok then
        main_bg_img = img
    else
        print("Failed to load main background: " .. tostring(img))
    end
    
    -- Start in the Main Screen
    game_state = "main"
    
    -- Start playing the first track preview
    ui_overlay.select_stage(1)
    
    -- Load background images
    for idx, stage in ipairs(beat_manager.stages) do
        if stage.bg_image_path then
            local ok, img = pcall(love.graphics.newImage, stage.bg_image_path)
            if ok then
                stage_bgs[idx] = img
            else
                print("Failed to load background for stage " .. idx .. ": " .. tostring(img))
            end
        end
    end
end

function love.update(dt)
    if game_state == "main" then
        fx_manager.update(dt)
        fft_analyzer.clear()
        return
    end
    
    if game_state == "menu" then
        -- Keep grid animations moving in the menu background
        grid_renderer.update(dt)
        fx_manager.update(dt)
        ui_overlay.update(dt)
        fft_analyzer.clear()
        return
    end
    
    if game_state ~= "playing" then 
        fft_analyzer.clear()
        return 
    end
    
    -- 1. Sync timeline with audio playback position
    local is_playing = sound_synth.music_loop:isPlaying()
    if not is_playing and beat_manager.current_beat > 5.0 and player_hp > 0 then
        game_state = "victory"
        sound_synth.music_loop:stop()
        sound_synth.play_perfect()
        -- Health bonus multiplier
        score = score + player_hp * 60
        return
    end
    
    local music_time = sound_synth.music_loop:tell()
    local is_new_beat = beat_manager.update(music_time)
    
    -- Update FFT analysis if we have static SoundData
    if sound_synth.current_sound_data and is_playing then
        local current_sample = sound_synth.music_loop:tell("samples")
        fft_analyzer.analyze(sound_synth.current_sound_data, current_sample, dt)
    else
        fft_analyzer.clear()
    end
    
    if is_new_beat then
        -- Pulse grid and camera zoom on beat kick
        grid_renderer.trigger_beat()
    end
    
    -- 2. Update visual systems and animations
    grid_renderer.update(dt)
    fx_manager.update(dt)
    ui_overlay.update(dt)
    
    -- 3. Update active notes
    local is_held = love.mouse.isDown(1) or love.keyboard.isDown("z") or love.keyboard.isDown("x")
    local mx, my = love.mouse.getPosition()
    local misses, hits = note.update_all(dt, music_time, beat_manager.beat_interval, is_held, mx, my)
    
    if misses > 0 then
        -- Apply damage on missed notes
        player_hp = math.max(0, player_hp - misses * 5)
        combo = 0
        hit_miss = hit_miss + misses
        fx_manager.trigger_damage()
        sound_synth.play_miss()
        ui_overlay.trigger_rating("BAD")
    end
    
    for _, hit in ipairs(hits) do
        -- Register drag hit
        ui_overlay.trigger_rating(hit.rating)
        combo = combo + 1
        if combo > max_combo then max_combo = combo end
        
        if hit.rating == "PERFECT" then
            hit_perfect = hit_perfect + 1
        else
            hit_good = hit_good + 1
        end
        
        local base_points = (hit.rating == "PERFECT" and 300 or 100)
        local mult = math.min(5, math.floor(combo / 10) + 1)
        score = score + base_points * mult
        
        player_hp = math.min(100, player_hp + (hit.rating == "PERFECT" and 4.0 or 2.0))
        sound_synth.play_cool()
        if hit.rating == "PERFECT" then
            fx_manager.spawn_perfect_burst(hit.x, hit.y, beat_manager.track.color)
        else
            fx_manager.spawn_sparks(hit.x, hit.y, beat_manager.track.color)
        end
    end
    
    -- 4. Check for active lasers (holding recovers HP, unblocked drains HP)
    -- Also apply continuous passive HP drain over time (rhythm pressure)
    player_hp = math.max(0, player_hp - 1.5 * dt)
    
    for _, n in ipairs(note.active_notes) do
        if n.type == "laser" then
            if n.is_holding then
                player_hp = math.min(100, player_hp + 6.5 * dt) -- Hold laser to recover
            elseif beat_manager.current_beat >= n.target_beat then
                player_hp = math.max(0, player_hp - 10 * dt) -- Unblocked laser damage
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
    
    -- 6. Groggy Shield blast penalty check (disabled - no barrier)

    
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
    
    if game_state == "main" then
        draw_bg_image(main_bg_img, 1.0)
        fx_manager.draw_screen_overlays(1280, 720)
        ui_overlay.draw_main_screen()
        return
    end
    
    -- Draw stage background image if available
    local active_bg = nil
    if game_state == "menu" then
        active_bg = stage_bgs[ui_overlay.selected_idx]
        draw_bg_image(active_bg, 0.70) -- 70% opacity in menu for high visibility
    else
        active_bg = stage_bgs[beat_manager.active_stage_idx]
        local bg_opacity = 0.45 + 0.20 * fft_analyzer.bass -- Dynamic bass glow
        draw_bg_image(active_bg, bg_opacity)
    end
    
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
    
    -- Draw active note crystals and guides
    note.draw_all(love.timer.getTime())
    
    -- Draw Cytus scanline overlay
    note.draw_scanline(love.timer.getTime())
    
    -- Draw spark particles
    fx_manager.draw_particles()
    
    love.graphics.pop()
    
    -- Render glitch scanline filters
    fx_manager.draw_screen_overlays(1280, 720)
    
    -- Render HUD indicators (pass mx, my to draw crosshair at cursor)
    ui_overlay.draw_hud(player_hp, gun_heat, is_overheated, boss_hp, boss_shield, score, combo, is_groggy, mx, my)
    
    -- Render Victory/Defeat screen overlays
    if game_state == "victory" or game_state == "defeat" then
        local mx, my = love.mouse.getPosition()
        ui_overlay.draw_screen_state(game_state, score, max_combo, get_accuracy_rank(), mx, my)
    end
end

local function shoot_at(mx, my)
    -- Check timing and alignment (pass click coordinates)
    local music_time = sound_synth.music_loop:tell()
    local rating, dmg, note_type = note.check_hit(music_time, beat_manager.beat_interval, mx, my)
    
    -- Play shot effect
    sound_synth.play_shoot()
    
    if rating then
        -- Display rating popup (PERFECT, GOOD, BAD)
        ui_overlay.trigger_rating(rating)
        combo = combo + 1
        if combo > max_combo then max_combo = combo end
        
        if rating == "PERFECT" then
            hit_perfect = hit_perfect + 1
        elseif rating == "GOOD" then
            hit_good = hit_good + 1
        else
            hit_miss = hit_miss + 1
        end
        
        local mult = math.min(5, math.floor(combo / 10) + 1)
        local base_points = 50
        if rating == "PERFECT" then
            base_points = 300
        elseif rating == "GOOD" then
            base_points = 100
        end
        score = score + base_points * mult
        
        -- Player HP recovery based on rating
        local hp_gain = 1.0
        if rating == "PERFECT" then
            hp_gain = 6.0
        elseif rating == "GOOD" then
            hp_gain = 3.0
        end
        player_hp = math.min(100, player_hp + hp_gain)
        
        -- Spawn flashy or subtle sparks at click point without screen shake
        local color = (rating == "PERFECT") and {1.0, 0.9, 0.4} or {0.4, 0.9, 1.0}
        if rating == "PERFECT" then
            fx_manager.spawn_perfect_burst(mx, my, color)
        else
            fx_manager.spawn_sparks(mx, my, color)
        end
    end
end

function love.mousepressed(x, y, button)
    if button ~= 1 then return end
    
    if game_state == "main" then
        game_state = "menu"
        sound_synth.play_cool()
        return
    end
    
    if game_state == "menu" then
        local hovered = ui_overlay.get_hovered_card(x, y)
        if hovered then
            if hovered == "play" then
                beat_manager.select_stage(ui_overlay.selected_idx)
                sound_synth.select_track(ui_overlay.selected_idx)
                reset_game()
            elseif type(hovered) == "number" then
                if hovered == ui_overlay.selected_idx then
                    -- Double-click to start
                    beat_manager.select_stage(hovered)
                    sound_synth.select_track(hovered)
                    reset_game()
                else
                    ui_overlay.select_stage(hovered)
                end
            elseif type(hovered) == "string" and string.sub(hovered, 1, 5) == "diff_" then
                local diff = string.sub(hovered, 6)
                beat_manager.selected_difficulty = diff
                sound_synth.play_cool()
            end
        end
        return
    end
    
    if game_state == "victory" or game_state == "defeat" then
        local center_x, center_y = 1280 / 2, 720 / 2
        local rx, ry = center_x - 190, center_y + 140
        local sx, sy = center_x + 30, center_y + 140
        
        if x >= rx and x <= rx + 160 and y >= ry and y <= ry + 50 then
            sound_synth.play_cool()
            reset_game()
        elseif x >= sx and x <= sx + 160 and y >= sy and y <= sy + 50 then
            sound_synth.play_cool()
            game_state = "menu"
            sound_synth.music_loop:stop()
            sound_synth.select_track(ui_overlay.selected_idx)
            sound_synth.music_loop:seek(0)
            sound_synth.music_loop:play()
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
    
    shoot_at(x, y)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif game_state == "main" then
        game_state = "menu"
        sound_synth.play_cool()
        return
    elseif game_state == "menu" then
        if key == "up" then
            ui_overlay.select_prev()
        elseif key == "down" then
            ui_overlay.select_next()
        elseif key == "left" then
            if beat_manager.selected_difficulty == "VeryHard" then
                beat_manager.selected_difficulty = "HARD"
            elseif beat_manager.selected_difficulty == "HARD" then
                beat_manager.selected_difficulty = "NORMAL"
            end
            sound_synth.play_cool()
        elseif key == "right" then
            if beat_manager.selected_difficulty == "NORMAL" then
                beat_manager.selected_difficulty = "HARD"
            elseif beat_manager.selected_difficulty == "HARD" then
                beat_manager.selected_difficulty = "VeryHard"
            end
            sound_synth.play_cool()
        elseif key == "return" or key == "kpenter" or key == "space" then
            beat_manager.select_stage(ui_overlay.selected_idx)
            sound_synth.select_track(ui_overlay.selected_idx)
            reset_game()
        elseif key >= "1" and key <= "9" then
            ui_overlay.select_stage(tonumber(key))
        elseif key:sub(1,2) == "kp" and key:sub(3) >= "1" and key:sub(3) <= "9" then
            ui_overlay.select_stage(tonumber(key:sub(3)))
        end
    else
        -- Playing or result screen
        if key == "r" then
            reset_game()
        elseif key == "m" then
            game_state = "menu"
            sound_synth.music_loop:stop()
            -- Play preview music for selected track
            sound_synth.select_track(ui_overlay.selected_idx)
            sound_synth.music_loop:seek(0)
            sound_synth.music_loop:play()
        elseif (key == "z" or key == "x") and game_state == "playing" then
            -- Shoot locking on overheat
            if is_overheated then
                sound_synth.play_overheat()
                return
            end
            local mx, my = love.mouse.getPosition()
            shoot_at(mx, my)
        end
    end
end

function love.wheelmoved(x, y)
    if game_state == "menu" then
        ui_overlay.scroll_menu(y)
    end
end
