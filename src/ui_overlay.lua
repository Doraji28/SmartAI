-- HUD & Judgment Overlay for Soulrock.
-- Handles crosshairs, beat indicators, health/heat bars, combos, ratings, and game states.
local font_manager = require("font_manager")
local beat_manager = require("beat_manager")
local grid_renderer = require("grid_renderer")
local fft_analyzer = require("fft")
local ui_overlay = {}

-- Rating popup states
ui_overlay.rating_text = ""
ui_overlay.rating_timer = 0.0
ui_overlay.rating_scale = 1.0
ui_overlay.rating_color = {1, 1, 1, 1}

-- Update rating timers & menu scroll animations
function ui_overlay.update(dt)
    if ui_overlay.rating_timer > 0 then
        ui_overlay.rating_timer = ui_overlay.rating_timer - dt
        ui_overlay.rating_scale = math.max(1.0, ui_overlay.rating_scale - 3.5 * dt)
    end
    
    -- Smooth scroll interpolation for song list
    ui_overlay.scroll_y = ui_overlay.scroll_y + (ui_overlay.target_scroll_y - ui_overlay.scroll_y) * 12.0 * dt
end

-- Trigger a judgment popup rating
function ui_overlay.trigger_rating(rating)
    ui_overlay.rating_text = rating
    ui_overlay.rating_timer = 0.65 -- Show for 0.65 seconds
    ui_overlay.rating_scale = 1.6
    
    if rating == "PERFECT" then
        ui_overlay.rating_color = {1.0, 0.85, 0.1, 1.0} -- Glowing gold/yellow
    elseif rating == "GOOD" then
        ui_overlay.rating_color = {0.2, 0.85, 0.95, 1.0} -- Glowing cyan
    elseif rating == "BAD" then
        ui_overlay.rating_color = {0.85, 0.2, 0.85, 1.0} -- Purple
    else
        ui_overlay.rating_text = "MISS"
        ui_overlay.rating_color = {0.95, 0.2, 0.2, 1.0} -- Red
    end
end

-- Draw HUD elements
-- player_hp: integer (0 to 100)
-- gun_heat: float (0 to 1)
-- is_overheated: boolean
-- boss_hp: float (0 to 100)
-- boss_shield: float (0 to 100)
-- boss_max_hp: float (e.g. 100)
-- score: integer
-- combo: integer
-- is_groggy: boolean
function ui_overlay.draw_hud(player_hp, gun_heat, is_overheated, boss_hp, boss_shield, score, combo, is_groggy, mx, my)
    local screen_w, screen_h = 1280, 720
    local center_x = screen_w / 2
    local center_y = screen_h / 2
    local cx = mx or center_x
    local cy = my or center_y
    local time = love.timer.getTime()
    
    local font_large = font_manager.get_font(28)
    local font_mid = font_manager.get_font(18)
    local font_body = font_manager.get_font(14)
    local font_small = font_manager.get_font(12)
    
    -----------------------------------------------------
    -- 1. CENTRAL RETICLE (CROSSHAIR)
    -----------------------------------------------------
    local crosshair_color = is_overheated and {0.95, 0.2, 0.2, 0.9} or {0.2, 0.95, 0.3, 0.95}
    love.graphics.setColor(crosshair_color)
    love.graphics.setLineWidth(2)
    
    -- Draw outer crosshair circle at cursor (Larger: radius 26)
    love.graphics.circle("line", cx, cy, 26)
    
    -- Center dot
    love.graphics.circle("fill", cx, cy, 2)
    
    -- Draw four crosshair spokes starting from radius 30
    local spoke_start = 30
    local spoke_len = 8
    love.graphics.line(cx - spoke_start - spoke_len, cy, cx - spoke_start, cy)
    love.graphics.line(cx + spoke_start, cy, cx + spoke_start + spoke_len, cy)
    love.graphics.line(cx, cy - spoke_start - spoke_len, cx, cy - spoke_start)
    love.graphics.line(cx, cy + spoke_start, cx, cy + spoke_start + spoke_len)
    
    -----------------------------------------------------
    -- 2. CURSOR PULSE RETICLE
    -----------------------------------------------------
    -- Idle state: draw a very faint, pulsing heartbeat circle around crosshair
    local pulse = 26 + 6 * (0.5 + 0.5 * math.sin(time * 12))
    love.graphics.setColor(0.2, 0.95, 0.3, 0.18)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", cx, cy, pulse)

    -----------------------------------------------------
    -- 3. GUN HEAT BAR (BELOW CROSSHAIR)
    -----------------------------------------------------
    local heat_y = cy + 36
    local heat_w = 120
    local heat_h = 6
    
    -- Glass backing
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", cx - heat_w/2, heat_y, heat_w, heat_h, 2)
    
    -- Fill
    local heat_color = is_overheated and {0.95, 0.1, 0.1, 0.9} or {0.98, 0.55, 0.1, 0.8}
    love.graphics.setColor(heat_color)
    love.graphics.rectangle("fill", cx - heat_w/2, heat_y, heat_w * gun_heat, heat_h, 2)
    
    -- Border outline
    love.graphics.setColor(1, 1, 1, 0.15)
    love.graphics.rectangle("line", cx - heat_w/2, heat_y, heat_w, heat_h, 2)
    
    -- Overheated Text flash
    if is_overheated then
        love.graphics.setFont(font_small)
        love.graphics.setColor(0.95, 0.15, 0.15, 0.5 + 0.5 * math.sin(time * 20))
        love.graphics.printf("OVERHEATED", cx - 60, heat_y + 10, 120, "center")
    end

    -----------------------------------------------------
    -- 4. PLAYER HP BAR (BOTTOM LEFT)
    -----------------------------------------------------
    local hud_y = screen_h - 60
    local hp_w = 360
    local hp_h = 18
    
    -- Backing Card (glassmorphism)
    love.graphics.setColor(0.06, 0.08, 0.12, 0.8)
    love.graphics.rectangle("fill", 40, hud_y - 28, hp_w + 30, 48, 8)
    love.graphics.setColor(1, 1, 1, 0.12)
    love.graphics.rectangle("line", 40, hud_y - 28, hp_w + 30, 48, 8)
    
    -- HP Text (No numbers, just a cyberpunk label)
    love.graphics.setFont(font_body)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.print("SYSTEM INTEGRITY", 50, hud_y - 20)
    
    -- HP Bar glass fill
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 50, hud_y + 2, hp_w, hp_h, 3)
    
    -- Color changes based on remaining health
    local hp_bar_color = {0, 0.75, 0.95, 0.85} -- blue cyan
    if player_hp < 30 then
        hp_bar_color = {0.95, 0.2, 0.2, 0.85} -- critical red
    elseif player_hp < 60 then
        hp_bar_color = {0.98, 0.75, 0.1, 0.85} -- yellow warning
    end
    
    love.graphics.setColor(hp_bar_color)
    love.graphics.rectangle("fill", 50, hud_y + 2, hp_w * (player_hp / 100), hp_h, 3)
    
    love.graphics.setColor(1, 1, 1, 0.15)
    love.graphics.rectangle("line", 50, hud_y + 2, hp_w, hp_h, 3)

    -----------------------------------------------------
    -- 5. BOSS HP & SHIELD STATUS (TOP CENTER)
    -----------------------------------------------------
    local boss_w = 480
    local boss_h = 16
    local bx_c = center_x - boss_w/2
    local by_c = 40
    
    -- Boss glass container card
    love.graphics.setColor(0.06, 0.08, 0.12, 0.85)
    love.graphics.rectangle("fill", bx_c - 15, by_c - 28, boss_w + 30, 50, 10)
    love.graphics.setColor(1, 1, 1, 0.15)
    love.graphics.rectangle("line", bx_c - 15, by_c - 28, boss_w + 30, 50, 10)
    
    -- Labels (Timeline progress based on beat completion)
    local active_track = beat_manager.track
    local total_beats = active_track.total_beats
    local progress = math.min(1.0, beat_manager.current_beat / (total_beats - 1))
    
    local display_diff = beat_manager.selected_difficulty
    if display_diff == "VeryHard" then display_diff = "VERY HARD" end
    local boss_title = "SONG: " .. active_track.name .. " [" .. display_diff .. "] (SuperDoraji) - " .. string.format("%d%%", math.floor(progress * 100))
    local bar_color = active_track.color
    
    love.graphics.setFont(font_small)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(boss_title, bx_c, by_c - 20)
    
    -- Fill bar
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", bx_c, by_c, boss_w, boss_h, 4)
    
    love.graphics.setColor(bar_color)
    love.graphics.rectangle("fill", bx_c, by_c, boss_w * progress, boss_h, 4)
    
    love.graphics.setColor(1, 1, 1, 0.15)
    love.graphics.rectangle("line", bx_c, by_c, boss_w, boss_h, 4)

    -----------------------------------------------------
    -- 6. SCORE & COMBO HUD (TOP RIGHT & LEFT)
    -----------------------------------------------------
    -- Score (Top Right)
    love.graphics.setColor(0.06, 0.08, 0.12, 0.8)
    love.graphics.rectangle("fill", screen_w - 200, 20, 160, 48, 8)
    love.graphics.setColor(1, 1, 1, 0.12)
    love.graphics.rectangle("line", screen_w - 200, 20, 160, 48, 8)
    
    love.graphics.setFont(font_small)
    love.graphics.setColor(0.6, 0.7, 0.8, 0.85)
    love.graphics.print("SCORE", screen_w - 188, 26)
    love.graphics.setFont(font_mid)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.print(string.format("%06d", score), screen_w - 188, 40)
    
    -- Combo (Left panel, floating)
    if combo > 0 then
        local combo_scale = 1.0 + 0.28 * grid_renderer.beat_pulse
        love.graphics.push()
        love.graphics.translate(80, 150)
        love.graphics.scale(combo_scale, combo_scale)
        
        -- Draw glowing combo count
        love.graphics.setFont(font_large)
        love.graphics.setColor(1.0, 0.9, 0.2, 0.9)
        love.graphics.print(tostring(combo), 0, 0)
        
        love.graphics.setFont(font_small)
        love.graphics.setColor(1, 1, 1, 0.75)
        love.graphics.print("COMBO", 2, 28)
        
        love.graphics.pop()
    end
    
    -----------------------------------------------------
    -- 7. JUDGMENT RATING TEXT POPUP
    -----------------------------------------------------
    if ui_overlay.rating_timer > 0 then
        -- Fade rating popup out
        local alpha = math.min(1.0, ui_overlay.rating_timer / 0.15)
        love.graphics.push()
        love.graphics.translate(center_x, center_y - 75)
        
        -- Scale rating popup
        love.graphics.scale(ui_overlay.rating_scale, ui_overlay.rating_scale)
        
        love.graphics.setFont(font_large)
        love.graphics.setColor(ui_overlay.rating_color[1], ui_overlay.rating_color[2], ui_overlay.rating_color[3], alpha)
        
        -- Center text
        local txt_w = font_large:getWidth(ui_overlay.rating_text)
        love.graphics.print(ui_overlay.rating_text, -txt_w / 2, -15)
        
        love.graphics.pop()
    end

    -----------------------------------------------------
    -- 8. AUDIO SPECTRUM VISUALIZER (BOTTOM RIGHT, SYMMETRICAL TO HP BAR)
    -----------------------------------------------------
    local spec_x = screen_w - 40 - (hp_w + 30)
    local spec_y = hud_y - 28
    
    -- Backing Card (glassmorphism)
    love.graphics.setColor(0.06, 0.08, 0.12, 0.8)
    love.graphics.rectangle("fill", spec_x, spec_y, hp_w + 30, 48, 8)
    love.graphics.setColor(1, 1, 1, 0.12)
    love.graphics.rectangle("line", spec_x, spec_y, hp_w + 30, 48, 8)
    
    -- Title Label
    love.graphics.setFont(font_body)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.print("FREQUENCY SPECTRUM", spec_x + 10, spec_y + 8)
    
    -- Background area for bars
    local bar_area_x = spec_x + 180
    local bar_area_y = hud_y - 20
    local bar_area_w = hp_w - 160 -- 200
    local bar_area_h = 32
    
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", bar_area_x, bar_area_y, bar_area_w, bar_area_h, 3)
    love.graphics.setColor(1, 1, 1, 0.15)
    love.graphics.rectangle("line", bar_area_x, bar_area_y, bar_area_w, bar_area_h, 3)
    
    -- Draw 16 bars
    local num_bars = 16
    local total_spacing = 3.0
    local bar_w = (bar_area_w - (num_bars - 1) * total_spacing - 6) / num_bars
    
    local col = beat_manager.track.color
    
    for b = 1, num_bars do
        local gain = 35 + b * 15
        local val = fft_analyzer.bands[b] or 0.0
        local bar_h = math.min(bar_area_h - 4, val * gain)
        if bar_h < 1 then bar_h = 1 end
        
        local bx = bar_area_x + (b - 1) * (bar_w + total_spacing) + 3
        local by = bar_area_y + bar_area_h - bar_h - 2
        
        -- Bloom effect (soft background glow)
        love.graphics.setColor(col[1], col[2], col[3], 0.25)
        love.graphics.rectangle("fill", bx - 1, by - 1, bar_w + 2, bar_h + 1, 1)
        
        -- Core bar
        local ratio = (b - 1) / (num_bars - 1)
        love.graphics.setColor(col[1] * 0.8 + 0.2, col[2] * 0.8 + 0.2, col[3] * 0.8 + 0.2, 0.85)
        love.graphics.rectangle("fill", bx, by, bar_w, bar_h, 1)
    end

end

-- Renders the game screens (Victory / Loss / Loading)
function ui_overlay.draw_screen_state(state, score, max_combo, rank, mx, my)
    local screen_w, screen_h = 1280, 720
    local center_x = screen_w / 2
    local center_y = screen_h / 2
    local time = love.timer.getTime()
    mx = mx or 0
    my = my or 0
    rank = rank or "D"
    
    local font_title = font_manager.get_font(24)
    local font_large = font_manager.get_font(28)
    local font_body = font_manager.get_font(16)
    local font_small = font_manager.get_font(12)
    local font_rank = font_manager.get_font(72)
    
    love.graphics.push()
    
    -- Draw semi-transparent black backing overlay
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, screen_w, screen_h)
    
    -- Draw result card box (centered glass card)
    local card_w, card_h = 480, 500
    local card_x = center_x - card_w / 2
    local card_y = center_y - card_h / 2
    
    -- Glass Backing
    love.graphics.setColor(0.04, 0.06, 0.1, 0.94)
    love.graphics.rectangle("fill", card_x, card_y, card_w, card_h, 16)
    
    -- Stage specific colors
    local active_stage = beat_manager.track
    local theme_col = active_stage.color
    
    -- Card glowing border
    love.graphics.setLineWidth(2)
    love.graphics.setColor(theme_col[1], theme_col[2], theme_col[3], 0.35)
    love.graphics.rectangle("line", card_x, card_y, card_w, card_h, 16)
    
    -- Inner card grid lines (tech details)
    love.graphics.setColor(1, 1, 1, 0.05)
    love.graphics.setLineWidth(1)
    love.graphics.line(card_x + 30, card_y + 130, card_x + card_w - 30, card_y + 130)
    love.graphics.line(card_x + 30, card_y + 360, card_x + card_w - 30, card_y + 360)
    
    -----------------------------------------------------
    -- 1. DRAW RANK / GRADE
    -----------------------------------------------------
    local rank_color = {0.95, 0.15, 0.15, 1.0} -- Red for D
    if rank == "S" then
        rank_color = {1.0, 0.85, 0.1, 1.0} -- Gold for S
    elseif rank == "A" then
        rank_color = {0.2, 0.85, 0.95, 1.0} -- Cyan for A
    elseif rank == "B" then
        rank_color = {0.85, 0.2, 0.85, 1.0} -- Purple for B
    elseif rank == "C" then
        rank_color = {0.95, 0.55, 0.15, 1.0} -- Orange for C
    end
    
    -- Glow effect for rank
    love.graphics.setFont(font_rank)
    love.graphics.setColor(rank_color[1], rank_color[2], rank_color[3], 0.35 + 0.15 * math.sin(time * 8))
    local rw = font_rank:getWidth(rank)
    love.graphics.print(rank, center_x - rw / 2 - 2, card_y + 40 - 2)
    love.graphics.print(rank, center_x - rw / 2 + 2, card_y + 40 + 2)
    
    -- Core rank text
    love.graphics.setColor(rank_color)
    love.graphics.print(rank, center_x - rw / 2, card_y + 40)
    
    -- Sublabel
    love.graphics.setFont(font_small)
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.printf("GRADE", 0, card_y + 25, screen_w, "center")
    
    -----------------------------------------------------
    -- 2. DRAW STATE TITLES
    -----------------------------------------------------
    if state == "defeat" then
        love.graphics.setFont(font_title)
        love.graphics.setColor(0.95, 0.15, 0.15, 0.95)
        love.graphics.printf("SYSTEM CRITICAL: DEFEATED", 0, card_y + 155, screen_w, "center")
        
        love.graphics.setFont(font_body)
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.printf("노트 입력 타이밍을 놓쳐 시스템 싱크가 유실되었습니다.", card_x + 30, card_y + 195, card_w - 60, "center")
    else
        love.graphics.setFont(font_title)
        love.graphics.setColor(1.0, 0.85, 0.15, 0.95)
        love.graphics.printf("TIMELINE COMPLETED: VICTORY!", 0, card_y + 155, screen_w, "center")
        
        love.graphics.setFont(font_body)
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.printf("음악과 시스템 동기화를 완벽하게 완료했습니다!", card_x + 30, card_y + 195, card_w - 60, "center")
    end
    
    -----------------------------------------------------
    -- 3. DRAW SCORES & COMBOS
    -----------------------------------------------------
    -- Score row
    love.graphics.setFont(font_body)
    love.graphics.setColor(0.6, 0.7, 0.8, 0.8)
    love.graphics.print("FINAL SCORE", card_x + 50, card_y + 260)
    
    love.graphics.setFont(font_large)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(string.format("%06d", score), card_x + 230, card_y + 250, card_w - 280, "right")
    
    -- Combo row
    love.graphics.setFont(font_body)
    love.graphics.setColor(0.6, 0.7, 0.8, 0.8)
    love.graphics.print("MAX COMBO", card_x + 50, card_y + 310)
    
    love.graphics.setFont(font_large)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(string.format("%d Hits", max_combo), card_x + 230, card_y + 300, card_w - 280, "right")
    
    -----------------------------------------------------
    -- 4. BUTTONS (RETRY / STAGE)
    -----------------------------------------------------
    local btn_y = card_y + 390
    local btn_w, btn_h = 160, 50
    local rx, ry = center_x - 190, btn_y
    local sx, sy = center_x + 30, btn_y
    
    local retry_hover = (mx >= rx and mx <= rx + btn_w and my >= ry and my <= ry + btn_h)
    local stage_hover = (mx >= sx and mx <= sx + btn_w and my >= sy and my <= sy + btn_h)
    
    -- RETRY BUTTON
    love.graphics.setColor(0.06, 0.08, 0.12, 0.9)
    love.graphics.rectangle("fill", rx, ry, btn_w, btn_h, 8)
    
    local r_alpha = retry_hover and 0.95 or 0.45
    love.graphics.setLineWidth(retry_hover and 2.5 or 1.2)
    love.graphics.setColor(theme_col[1], theme_col[2], theme_col[3], r_alpha)
    love.graphics.rectangle("line", rx, ry, btn_w, btn_h, 8)
    
    if retry_hover then
        love.graphics.setColor(theme_col[1], theme_col[2], theme_col[3], 0.1)
        love.graphics.rectangle("fill", rx, ry, btn_w, btn_h, 8)
    end
    
    love.graphics.setFont(font_body)
    love.graphics.setColor(1, 1, 1, retry_hover and 1.0 or 0.8)
    love.graphics.printf("RETRY [R]", rx, ry + 15, btn_w, "center")
    
    -- STAGE BUTTON
    love.graphics.setColor(0.06, 0.08, 0.12, 0.9)
    love.graphics.rectangle("fill", sx, sy, btn_w, btn_h, 8)
    
    local s_alpha = stage_hover and 0.95 or 0.45
    love.graphics.setLineWidth(stage_hover and 2.5 or 1.2)
    love.graphics.setColor(theme_col[1], theme_col[2], theme_col[3], s_alpha)
    love.graphics.rectangle("line", sx, sy, btn_w, btn_h, 8)
    
    if stage_hover then
        love.graphics.setColor(theme_col[1], theme_col[2], theme_col[3], 0.1)
        love.graphics.rectangle("fill", sx, sy, btn_w, btn_h, 8)
    end
    
    love.graphics.setFont(font_body)
    love.graphics.setColor(1, 1, 1, stage_hover and 1.0 or 0.8)
    love.graphics.printf("STAGE [M]", sx, sy + 15, btn_w, "center")
    
    love.graphics.pop()
end

-- Renders the futuristic 2D Stage Selection Menu
-- Selection and scroll states for the menu
ui_overlay.selected_idx = 1
ui_overlay.scroll_y = 0.0
ui_overlay.target_scroll_y = -120.0

-- Select active stage (updates preview soundtrack loop)
function ui_overlay.select_stage(idx)
    local max_idx = #beat_manager.stages
    if idx < 1 then idx = 1 end
    if idx > max_idx then idx = max_idx end
    
    if ui_overlay.selected_idx ~= idx then
        local sound_synth = require("sound_synth")
        ui_overlay.selected_idx = idx
        
        -- Stop current loop, select track and restart preview
        sound_synth.music_loop:stop()
        sound_synth.select_track(idx)
        sound_synth.music_loop:seek(0)
        sound_synth.music_loop:play()
    end
    
    -- Recalculate target scroll to center the selected card
    local card_step = 90
    ui_overlay.target_scroll_y = (idx - 1) * card_step - 220
end

function ui_overlay.select_next()
    ui_overlay.select_stage(ui_overlay.selected_idx + 1)
end

function ui_overlay.select_prev()
    ui_overlay.select_stage(ui_overlay.selected_idx - 1)
end

-- Scroll menu with mouse wheel
function ui_overlay.scroll_menu(direction)
    if direction > 0 then
        ui_overlay.select_prev()
    elseif direction < 0 then
        ui_overlay.select_next()
    end
end

-- Detect mouse hovering over cards or button
function ui_overlay.get_hovered_card(mx, my)
    local cards = beat_manager.stages
    local card_step = 90
    local card_w = 360
    local card_h = 75
    local start_x = 840
    local start_y = 180
    
    for idx = 1, #cards do
        local is_selected = (idx == ui_overlay.selected_idx)
        local cx = start_x
        if is_selected then
            cx = start_x - 45
        end
        local cy = start_y + (idx - 1) * card_step - ui_overlay.scroll_y
        
        if mx >= cx and mx <= cx + card_w and my >= cy and my <= cy + card_h then
            return idx
        end
    end
    
    -- Check details difficulty tabs hover
    local tab_y, tab_h = 450, 30
    if my >= tab_y and my <= tab_y + tab_h then
        if mx >= 180 and mx <= 260 then
            return "diff_NORMAL"
        elseif mx >= 270 and mx <= 350 then
            return "diff_HARD"
        elseif mx >= 360 and mx <= 470 then
            return "diff_VeryHard"
        end
    end
    
    -- Check details play button hover
    local play_x = 100
    local play_y = 530
    local play_w = 360
    local play_h = 60
    if mx >= play_x and mx <= play_x + play_w and my >= play_y and my <= play_y + play_h then
        return "play"
    end
    
    return nil
end

-- Renders the futuristic 2D Stage Selection Menu (OSU!-style sliding list)
function ui_overlay.draw_stage_select_menu(mx, my)
    local screen_w, screen_h = 1280, 720
    local center_x = screen_w / 2
    local time = love.timer.getTime()
    local sound_synth = require("sound_synth")
    
    local font_title = font_manager.get_font(36)
    local font_large = font_manager.get_font(28)
    local font_mid = font_manager.get_font(18)
    local font_body = font_manager.get_font(14)
    local font_small = font_manager.get_font(12)
    local grid_renderer = require("grid_renderer")
    
    love.graphics.push()
    
    -- Main Menu Background Overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screen_w, screen_h)
    
    -- Header Title
    love.graphics.setFont(font_title)
    love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
    local title_txt = "SOULROCK"
    local title_w = font_title:getWidth(title_txt)
    love.graphics.print(title_txt, center_x - title_w/2, 45)
    
    -- Subtitle
    love.graphics.setFont(font_small)
    love.graphics.setColor(0.2, 0.8, 0.95, 0.8)
    local sub_txt = "SELECT TARGET ENCOUNTER & SOUNDTRACK TIMELINE"
    local sub_w = font_small:getWidth(sub_txt)
    love.graphics.print(sub_txt, center_x - sub_w/2, 95)
    
    -- Decorative scanner line
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.15, 0.75, 0.9, 0.3)
    love.graphics.line(center_x - 300, 115, center_x + 300, 115)
    
    -----------------------------------------------------
    -- 1. LEFT SIDE - SELECTED SONG DETAILS
    -----------------------------------------------------
    local cards = beat_manager.stages
    local selected_card = cards[ui_overlay.selected_idx]
    
    if selected_card then
        -- Glassmorphic details panel
        love.graphics.setColor(0.04, 0.05, 0.08, 0.85)
        love.graphics.rectangle("fill", 40, 140, 480, 500, 16)
        
        local theme_col = selected_card.color
        love.graphics.setColor(theme_col[1], theme_col[2], theme_col[3], 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", 40, 140, 480, 500, 16)
        
        -- Decorative corner glowing lines
        love.graphics.setColor(theme_col[1], theme_col[2], theme_col[3], 0.08)
        love.graphics.rectangle("fill", 40, 140, 480, 500, 16)
        
        -- Large rotating Boss preview
        local icon_cx = 40 + 240
        local icon_cy = 140 + 130
        local icon_scale = 2.4
        grid_renderer.draw_boss_icon(ui_overlay.selected_idx, icon_cx, icon_cy, icon_scale, time)
        
        -- Stage Number
        love.graphics.setFont(font_small)
        love.graphics.setColor(theme_col[1], theme_col[2], theme_col[3], 0.95)
        love.graphics.print(string.format("STAGE 0%d", ui_overlay.selected_idx), 70, 325)
        
        -- Song Name
        love.graphics.setFont(font_large)
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.print(selected_card.name, 70, 345)
        
        -- Composer / Artist
        love.graphics.setFont(font_mid)
        love.graphics.setColor(0.7, 0.8, 0.9, 0.9)
        love.graphics.print("SuperDoraji", 70, 385)
        
        -- Metadata Properties
        love.graphics.setFont(font_body)
        love.graphics.setColor(0.5, 0.6, 0.7, 0.85)
        local total_seconds = math.floor(selected_card.total_beats * (60 / selected_card.bpm))
        local minutes = math.floor(total_seconds / 60)
        local seconds = total_seconds % 60
        love.graphics.print(string.format("TEMPO: %d BPM  |  TIME: %02d:%02d", selected_card.bpm, minutes, seconds), 70, 425)
        
        -- Difficulty Selector Tabs
        love.graphics.print("DIFFICULTY: ", 70, 458)
        
        local hovered_idx = ui_overlay.get_hovered_card(mx, my)
        local tab_y, tab_h = 450, 30
        local tab1_x, tab1_w = 180, 80
        local tab2_x, tab2_w = 270, 80
        local tab3_x, tab3_w = 360, 110
        
        -- 1. NORMAL Tab drawing
        local t1_active = (beat_manager.selected_difficulty == "NORMAL")
        local t1_hover = (hovered_idx == "diff_NORMAL")
        love.graphics.setLineWidth(t1_active and 2 or 1)
        if t1_active then
            love.graphics.setColor(0.2, 0.95, 0.35, 0.25)
            love.graphics.rectangle("fill", tab1_x, tab_y, tab1_w, tab_h, 6)
            love.graphics.setColor(0.2, 0.95, 0.35, 0.95)
        elseif t1_hover then
            love.graphics.setColor(0.2, 0.95, 0.35, 0.1)
            love.graphics.rectangle("fill", tab1_x, tab_y, tab1_w, tab_h, 6)
            love.graphics.setColor(0.2, 0.95, 0.35, 0.6)
        else
            love.graphics.setColor(1, 1, 1, 0.2)
        end
        love.graphics.rectangle("line", tab1_x, tab_y, tab1_w, tab_h, 6)
        love.graphics.setFont(font_small)
        love.graphics.setColor(1, 1, 1, (t1_active or t1_hover) and 1.0 or 0.5)
        love.graphics.printf("NORMAL", tab1_x, tab_y + 8, tab1_w, "center")
        
        -- 2. HARD Tab drawing
        local t2_active = (beat_manager.selected_difficulty == "HARD")
        local t2_hover = (hovered_idx == "diff_HARD")
        love.graphics.setLineWidth(t2_active and 2 or 1)
        if t2_active then
            love.graphics.setColor(0.95, 0.55, 0.15, 0.25)
            love.graphics.rectangle("fill", tab2_x, tab_y, tab2_w, tab_h, 6)
            love.graphics.setColor(0.95, 0.55, 0.15, 0.95)
        elseif t2_hover then
            love.graphics.setColor(0.95, 0.55, 0.15, 0.1)
            love.graphics.rectangle("fill", tab2_x, tab_y, tab2_w, tab_h, 6)
            love.graphics.setColor(0.95, 0.55, 0.15, 0.6)
        else
            love.graphics.setColor(1, 1, 1, 0.2)
        end
        love.graphics.rectangle("line", tab2_x, tab_y, tab2_w, tab_h, 6)
        love.graphics.setColor(1, 1, 1, (t2_active or t2_hover) and 1.0 or 0.5)
        love.graphics.printf("HARD", tab2_x, tab_y + 8, tab2_w, "center")
        
        -- 3. VERY HARD Tab drawing
        local t3_active = (beat_manager.selected_difficulty == "VeryHard")
        local t3_hover = (hovered_idx == "diff_VeryHard")
        love.graphics.setLineWidth(t3_active and 2 or 1)
        if t3_active then
            love.graphics.setColor(0.95, 0.15, 0.15, 0.25)
            love.graphics.rectangle("fill", tab3_x, tab_y, tab3_w, tab_h, 6)
            love.graphics.setColor(0.95, 0.15, 0.15, 0.95)
        elseif t3_hover then
            love.graphics.setColor(0.95, 0.15, 0.15, 0.1)
            love.graphics.rectangle("fill", tab3_x, tab_y, tab3_w, tab_h, 6)
            love.graphics.setColor(0.95, 0.15, 0.15, 0.6)
        else
            love.graphics.setColor(1, 1, 1, 0.2)
        end
        love.graphics.rectangle("line", tab3_x, tab_y, tab3_w, tab_h, 6)
        love.graphics.setColor(1, 1, 1, (t3_active or t3_hover) and 1.0 or 0.5)
        love.graphics.printf("VERY HARD", tab3_x, tab_y + 8, tab3_w, "center")
        
        -- Interface Launch Button
        local play_hovered = (ui_overlay.get_hovered_card(mx, my) == "play")
        local play_x, play_y, play_w, play_h = 100, 530, 360, 60
        
        love.graphics.setColor(0.06, 0.08, 0.12, 0.9)
        love.graphics.rectangle("fill", play_x, play_y, play_w, play_h, 8)
        
        local btn_alpha = play_hovered and 0.95 or 0.45
        love.graphics.setColor(theme_col[1], theme_col[2], theme_col[3], btn_alpha)
        love.graphics.setLineWidth(play_hovered and 3 or 1.5)
        love.graphics.rectangle("line", play_x, play_y, play_w, play_h, 8)
        
        if play_hovered then
            love.graphics.setColor(theme_col[1], theme_col[2], theme_col[3], 0.12 * (0.8 + 0.2 * math.sin(time * 15)))
            love.graphics.rectangle("fill", play_x, play_y, play_w, play_h, 8)
        end
        
        love.graphics.setFont(font_mid)
        love.graphics.setColor(1, 1, 1, play_hovered and 1.0 or 0.8)
        love.graphics.printf(play_hovered and "-> CLICK TO INTERFACE <-" or "INTERFACE SYSTEM", play_x, play_y + 18, play_w, "center")
    end
    
    -----------------------------------------------------
    -- 2. RIGHT SIDE - OSU!-STYLE SLIDING SONG LIST
    -----------------------------------------------------
    local card_step = 90
    local card_w = 360
    local card_h = 75
    local start_x = 840
    local start_y = 180
    
    -- Draw container frame boundaries or scrollbar helper
    for idx, card in ipairs(cards) do
        local is_selected = (idx == ui_overlay.selected_idx)
        local hovered_idx = ui_overlay.get_hovered_card(mx, my)
        local is_hovered = (hovered_idx == idx)
        
        local cx = start_x
        if is_selected then
            cx = start_x - 45 -- Slide left when selected
        elseif is_hovered then
            cx = start_x - 15 -- Slight nudge when hovered
        end
        
        local cy = start_y + (idx - 1) * card_step - ui_overlay.scroll_y
        
        -- Clip elements off screen boundaries
        if cy > 100 and cy < 660 then
            local col = card.color
            
            -- Glassmorphic Card Backing
            love.graphics.setColor(0.05, 0.06, 0.1, is_selected and 0.95 or 0.8)
            love.graphics.rectangle("fill", cx, cy, card_w, card_h, 8)
            
            -- Border neon glow matching stage colors
            local glow_alpha = is_selected and 0.95 or (is_hovered and 0.7 or 0.25)
            local line_w = is_selected and 2.5 or 1.2
            
            love.graphics.setLineWidth(line_w)
            love.graphics.setColor(col[1], col[2], col[3], glow_alpha)
            love.graphics.rectangle("line", cx, cy, card_w, card_h, 8)
            
            -- Inner fill flash for selected/hovered card
            if is_selected then
                love.graphics.setColor(col[1], col[2], col[3], 0.12 + 0.05 * math.sin(time * 12))
                love.graphics.rectangle("fill", cx, cy, card_w, card_h, 8)
            elseif is_hovered then
                love.graphics.setColor(col[1], col[2], col[3], 0.05)
                love.graphics.rectangle("fill", cx, cy, card_w, card_h, 8)
            end
            
            -- Card Visuals: Mini rotating boss icon on the left of each card!
            grid_renderer.draw_boss_icon(idx, cx + 45, cy + 37.5, 0.55, time)
            
            -- Song Name
            love.graphics.setFont(font_body)
            love.graphics.setColor(1, 1, 1, is_selected and 1.0 or 0.8)
            love.graphics.print(card.name, cx + 90, cy + 14)
            
            -- Artist Name
            love.graphics.setFont(font_small)
            love.graphics.setColor(0.6, 0.7, 0.8, is_selected and 0.9 or 0.65)
            love.graphics.print("SuperDoraji", cx + 90, cy + 38)
            
            -- Difficulty text badge on far right of card showing current selected difficulty
            local display_diff = beat_manager.selected_difficulty
            local diff_col = {0.2, 0.95, 0.35, 0.85}
            local diff_label = "NORMAL"
            if display_diff == "HARD" then
                diff_col = {0.95, 0.55, 0.15, 0.85}
                diff_label = "HARD"
            elseif display_diff == "VeryHard" then
                diff_col = {0.95, 0.15, 0.15, 0.85}
                diff_label = "V.HARD"
            end
            love.graphics.setFont(font_small)
            love.graphics.setColor(diff_col)
            local diff_txt_w = font_small:getWidth(diff_label)
            love.graphics.print(diff_label, cx + card_w - diff_txt_w - 20, cy + 28)
        end
    end
    
    -- Bottom general information
    love.graphics.setFont(font_small)
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.printf("마우스 휠 스크롤 또는 방향키 [▲][▼]로 곡 이동  |  선택된 곡을 한번 더 클릭하거나 [Enter]를 눌러 실행", 0, screen_h - 45, screen_w, "center")
    
    love.graphics.pop()
end

-- Renders the futuristic main title screen
function ui_overlay.draw_main_screen()
    local screen_w, screen_h = 1280, 720
    local center_x = screen_w / 2
    local center_y = screen_h / 2
    local time = love.timer.getTime()
    
    local font_title = font_manager.get_font(48)
    local font_subtitle = font_manager.get_font(20)
    local font_prompt = font_manager.get_font(16)
    
    -- Draw a subtle dark overlay on the bottom part to make text readable
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", 0, screen_h - 180, screen_w, 180)
    
    -- Glowing title banner
    local title_txt = "SOULROCK"
    love.graphics.setFont(font_title)
    
    -- Glow effect: draw offset versions in magenta and cyan
    love.graphics.setColor(0.95, 0.15, 0.75, 0.45 + 0.15 * math.sin(time * 10))
    love.graphics.printf(title_txt, -2, screen_h - 142, screen_w, "center")
    
    love.graphics.setColor(0.15, 0.75, 0.9, 0.45 + 0.15 * math.sin(time * 10))
    love.graphics.printf(title_txt, 2, screen_h - 138, screen_w, "center")
    
    -- Main white text
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(title_txt, 0, screen_h - 140, screen_w, "center")
    
    -- Subtitle
    local sub_txt = "최고의 음악들과 함께 즐기는 리듬게임"
    love.graphics.setFont(font_subtitle)
    love.graphics.setColor(0.7, 0.8, 0.9, 0.85)
    love.graphics.printf(sub_txt, 0, screen_h - 90, screen_w, "center")
    
    -- Press key prompt (Pulsing opacity)
    local prompt_txt = "PRESS ANY KEY OR CLICK TO INTERFACE"
    love.graphics.setFont(font_prompt)
    local alpha = 0.45 + 0.45 * math.sin(time * 4)
    love.graphics.setColor(0.2, 0.95, 0.35, alpha)
    love.graphics.printf(prompt_txt, 0, screen_h - 50, screen_w, "center")
    
    -- Corner tech lines
    local padding = 30
    local len = 40
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.15, 0.75, 0.9, 0.6)
    
    -- Top-Left
    love.graphics.line(padding, padding, padding + len, padding)
    love.graphics.line(padding, padding, padding, padding + len)
    -- Top-Right
    love.graphics.line(screen_w - padding, padding, screen_w - padding - len, padding)
    love.graphics.line(screen_w - padding, padding, screen_w - padding, padding + len)
    -- Bottom-Left
    love.graphics.line(padding, screen_h - padding, padding + len, screen_h - padding)
    love.graphics.line(padding, screen_h - padding, padding, screen_h - padding - len)
    -- Bottom-Right
    love.graphics.line(screen_w - padding, screen_h - padding, screen_w - padding - len, screen_h - padding)
    love.graphics.line(screen_w - padding, screen_h - padding, screen_w - padding, screen_h - padding - len)
end

return ui_overlay
