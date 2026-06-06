-- HUD & Judgment Overlay for Soulrock.
-- Handles crosshairs, beat indicators, health/heat bars, combos, ratings, and game states.
local font_manager = require("font_manager")
local beat_manager = require("beat_manager")
local grid_renderer = require("grid_renderer")
local ui_overlay = {}

-- Rating popup states
ui_overlay.rating_text = ""
ui_overlay.rating_timer = 0.0
ui_overlay.rating_scale = 1.0
ui_overlay.rating_color = {1, 1, 1, 1}

-- Update rating timers
function ui_overlay.update(dt)
    if ui_overlay.rating_timer > 0 then
        ui_overlay.rating_timer = ui_overlay.rating_timer - dt
        ui_overlay.rating_scale = math.max(1.0, ui_overlay.rating_scale - 3.5 * dt)
    end
end

-- Trigger a judgment popup rating
function ui_overlay.trigger_rating(rating)
    ui_overlay.rating_text = rating
    ui_overlay.rating_timer = 0.65 -- Show for 0.65 seconds
    ui_overlay.rating_scale = 1.5
    
    if rating == "PERFECT" then
        ui_overlay.rating_color = {1.0, 0.85, 0.1, 1.0} -- Glowing gold
    elseif rating == "COOL" then
        ui_overlay.rating_color = {0.2, 0.85, 0.95, 1.0} -- Glowing cyan
    else
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
    -- 2. CONTRACTING NOTE TIMING RING (RHYTHM HELPER)
    -----------------------------------------------------
    local note_mod = require("note")
    local closest_note = nil
    local min_beat_diff = 999
    
    for _, n in ipairs(note_mod.active_notes) do
        if n.type == "breakable" or (n.type == "laser" and not n.is_holding) then
            local diff = n.target_beat - beat_manager.current_beat
            if diff > -0.3 and diff < 1.5 then
                if math.abs(diff) < math.abs(min_beat_diff) then
                    min_beat_diff = diff
                    closest_note = n
                end
            end
        end
    end
    
    if closest_note then
        local time_offset = min_beat_diff * beat_manager.beat_interval
        
        if time_offset > 0 then
            -- Note is approaching. Circle contracts from 80 to 26.
            -- Starts contracting from 0.45 beats away (prevents overlaps on fast 0.5-beat notes)
            local progress = math.min(1.0, min_beat_diff / 0.45)
            local ring_r = 26 + 54 * progress
            local ring_alpha = 0.25 + 0.65 * (1.0 - progress)
            
            -- Color feedback based on timing window
            local ring_color = {0.2, 0.95, 0.3, ring_alpha} -- Green (incoming)
            if time_offset <= 0.22 then
                ring_color = {0.2, 0.85, 0.95, 0.9} -- Cyan (Cool range!)
                if time_offset <= 0.08 then
                    ring_color = {1.0, 0.85, 0.1, 0.95} -- Gold (Perfect range!)
                end
            end
            
            love.graphics.setColor(ring_color)
            love.graphics.setLineWidth(2.5)
            love.graphics.circle("line", cx, cy, ring_r)
            
            -- Draw a faint outer guide ring at target radius 26
            love.graphics.setColor(ring_color[1], ring_color[2], ring_color[3], 0.2)
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", cx, cy, 26)
        else
            -- Note is slightly past (late hit window)
            local progress_late = math.min(1.0, math.abs(time_offset) / 0.22)
            local ring_alpha = 0.8 * (1.0 - progress_late)
            
            -- Red alert for late clicks
            love.graphics.setColor(0.95, 0.2, 0.2, ring_alpha)
            love.graphics.setLineWidth(2.5)
            love.graphics.circle("line", cx, cy, 26)
        end
    else
        -- Idle state: draw a very faint, pulsing heartbeat circle around crosshair (pulsing faster)
        local pulse = 26 + 6 * (0.5 + 0.5 * math.sin(time * 12))
        love.graphics.setColor(0.2, 0.95, 0.3, 0.18)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", cx, cy, pulse)
    end

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
    
    -- Labels
    local active_track = beat_manager.track
    local boss_title = "BOSS: " .. active_track.boss_name
    local bar_color = active_track.color
    
    -- Check phases
    if is_groggy then
        boss_title = "BOSS CORE GROGGY - DEALS 2X DAMAGE!"
        bar_color = {0.85, 0.2, 0.85, 0.95} -- Purple groggy bar
    elseif beat_manager.is_groggy_phase() then
        if boss_shield > 0 then
            boss_title = "SHIELD SYSTEM INTRUSION - HIT PERFECTS!"
            bar_color = {0.98, 0.85, 0.15, 0.95} -- Gold shield bar
        else
            boss_title = "CORE SHIELD BROKEN - GROGGY!"
            bar_color = {0.85, 0.2, 0.85, 0.95}
        end
    end
    
    love.graphics.setFont(font_small)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(boss_title, bx_c, by_c - 20)
    
    -- Fill bar
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", bx_c, by_c, boss_w, boss_h, 4)
    
    local boss_val = boss_hp
    if beat_manager.is_groggy_phase() and boss_shield > 0 then
        boss_val = boss_shield
    end
    
    love.graphics.setColor(bar_color)
    love.graphics.rectangle("fill", bx_c, by_c, boss_w * (boss_val / 100), boss_h, 4)
    
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
end

-- Renders the game screens (Victory / Loss / Loading)
function ui_overlay.draw_screen_state(state, score, max_combo)
    local screen_w, screen_h = 1280, 720
    local center_x = screen_w / 2
    local center_y = screen_h / 2
    local time = love.timer.getTime()
    
    local font_title = font_manager.get_font(36)
    local font_large = font_manager.get_font(28)
    local font_body = font_manager.get_font(18)
    local font_small = font_manager.get_font(14)
    
    love.graphics.push()
    
    -- Draw semi-transparent black backing card
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screen_w, screen_h)
    
    -- Add glowing tech borders
    love.graphics.setColor(0.15, 0.75, 0.9, 0.25)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", 20, 20, screen_w - 40, screen_h - 40, 16)
    
    if state == "defeat" then
        -- Menu cards
        love.graphics.setFont(font_title)
        love.graphics.setColor(0.95, 0.15, 0.15, 1.0)
        local title_w = font_title:getWidth("SYSTEM CRITICAL: DEFEATED")
        love.graphics.print("SYSTEM CRITICAL: DEFEATED", center_x - title_w/2, center_y - 120)
        
        love.graphics.setFont(font_body)
        love.graphics.setColor(1, 1, 1, 0.8)
        local s_w = font_body:getWidth("보스 에너지 핵의 탄막 공격에 시스템이 과열되었습니다.")
        love.graphics.print("보스 에너지 핵의 탄막 공격에 시스템이 과열되었습니다.", center_x - s_w/2, center_y - 50)
        
        -- Score details
        love.graphics.setFont(font_body)
        love.graphics.setColor(0.2, 0.8, 0.95, 0.9)
        love.graphics.printf(string.format("최종 점수: %d", score), 0, center_y + 10, screen_w, "center")
        love.graphics.printf(string.format("최대 콤보: %d", max_combo), 0, center_y + 40, screen_w, "center")
        
        -- Action Prompts
        love.graphics.setFont(font_small)
        love.graphics.setColor(1, 1, 1, 0.5 + 0.4 * math.sin(time * 4))
        love.graphics.printf("마우스 좌클릭 또는 R 키를 눌러 재시도", 0, center_y + 105, screen_w, "center")
        love.graphics.printf("M 키를 눌러 스테이지 선택 화면으로 이동", 0, center_y + 130, screen_w, "center")
        love.graphics.printf("ESC 키를 눌러 종료", 0, center_y + 155, screen_w, "center")
        
    elseif state == "victory" then
        -- Clear victory menu
        love.graphics.setFont(font_title)
        love.graphics.setColor(1.0, 0.85, 0.15, 0.95 + 0.05 * math.sin(time * 12))
        local title_w = font_title:getWidth("NEXUS CORE DESTROYED: VICTORY!")
        love.graphics.print("NEXUS CORE DESTROYED: VICTORY!", center_x - title_w/2, center_y - 120)
        
        love.graphics.setFont(font_body)
        love.graphics.setColor(0.2, 0.95, 0.3, 0.95)
        local s_w = font_body:getWidth("보스 에너지 핵을 성공적으로 제압하고 네트워크를 정화했습니다!")
        love.graphics.print("보스 에너지 핵을 성공적으로 제압하고 네트워크를 정화했습니다!", center_x - s_w/2, center_y - 50)
        
        -- Final stats
        love.graphics.setFont(font_large)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.printf(string.format("최종 스코어: %d", score), 0, center_y + 10, screen_w, "center")
        love.graphics.printf(string.format("최대 콤보: %d", max_combo), 0, center_y + 45, screen_w, "center")
        
        -- Prompts
        love.graphics.setFont(font_small)
        love.graphics.setColor(1, 1, 1, 0.5 + 0.4 * math.sin(time * 4))
        love.graphics.printf("마우스 좌클릭 또는 R 키를 눌러 다시 하기", 0, center_y + 110, screen_w, "center")
        love.graphics.printf("M 키를 눌러 스테이지 선택 화면으로 이동", 0, center_y + 135, screen_w, "center")
        love.graphics.printf("ESC 키를 눌러 게임 종료", 0, center_y + 160, screen_w, "center")
    end
    
    love.graphics.pop()
end

-- Renders the futuristic 2D Stage Selection Menu
function ui_overlay.draw_stage_select_menu(mx, my)
    local screen_w, screen_h = 1280, 720
    local center_x = screen_w / 2
    local time = love.timer.getTime()
    
    local font_title = font_manager.get_font(36)
    local font_mid = font_manager.get_font(20)
    local font_body = font_manager.get_font(14)
    local font_small = font_manager.get_font(12)
    local grid_renderer = require("grid_renderer")
    
    love.graphics.push()
    
    -- Main Menu Background Overlay
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", 0, 0, screen_w, screen_h)
    
    -- Header Title
    love.graphics.setFont(font_title)
    love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
    local title_txt = "SOULROCK"
    local title_w = font_title:getWidth(title_txt)
    love.graphics.print(title_txt, center_x - title_w/2, 60)
    
    -- Subtitle
    love.graphics.setFont(font_small)
    love.graphics.setColor(0.2, 0.8, 0.95, 0.8)
    local sub_txt = "SELECT TARGET ENCOUNTER & SOUNDTRACK TIMELINE"
    local sub_w = font_small:getWidth(sub_txt)
    love.graphics.print(sub_txt, center_x - sub_w/2, 110)
    
    -- Decorative scanner line
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.15, 0.75, 0.9, 0.35)
    love.graphics.line(center_x - 300, 130, center_x + 300, 130)
    
    -- Renders the 2 cards
    local cards = beat_manager.stages
    local card_w = 360
    local card_h = 420
    local start_x = 240
    local start_y = 180
    local spacing = 80
    
    for idx, card in ipairs(cards) do
        local cx = start_x + (idx - 1) * (card_w + spacing)
        local cy = start_y
        
        -- Check mouse hover
        local is_hovered = (mx >= cx and mx <= cx + card_w and my >= cy and my <= cy + card_h)
        
        -- Hover offset animations
        local target_y = cy
        local scale_multiplier = 1.0
        if is_hovered then
            target_y = cy - 10
            scale_multiplier = 1.05
        end
        
        -- Glassmorphic Card Frame
        love.graphics.setColor(0.05, 0.06, 0.1, 0.88)
        love.graphics.rectangle("fill", cx, target_y, card_w, card_h, 12)
        
        -- Glowing neon borders matching stage color config
        local col = card.color
        local glow_alpha = is_hovered and 0.9 or 0.22
        local line_w = is_hovered and 3 or 1.5
        
        love.graphics.setLineWidth(line_w)
        love.graphics.setColor(col[1], col[2], col[3], glow_alpha)
        love.graphics.rectangle("line", cx, target_y, card_w, card_h, 12)
        
        -- Additional ambient corner glow
        if is_hovered then
            love.graphics.setColor(col[1], col[2], col[3], 0.15 * (0.8 + 0.2 * math.sin(time * 15)))
            love.graphics.rectangle("fill", cx, target_y, card_w, card_h, 12)
        end
        
        -- 1. Draw Boss Icon
        local icon_cx = cx + card_w / 2
        local icon_cy = target_y + 110
        local icon_scale = 1.5 * scale_multiplier
        grid_renderer.draw_boss_icon(idx, icon_cx, icon_cy, icon_scale, time)
        
        -- 2. Stage Number
        love.graphics.setFont(font_small)
        love.graphics.setColor(col[1], col[2], col[3], 0.85)
        love.graphics.printf(string.format("STAGE 0%d", idx), cx, target_y + 210, card_w, "center")
        
        -- 3. Boss Name
        love.graphics.setFont(font_mid)
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.printf(card.boss_name, cx, target_y + 230, card_w, "center")
        
        -- 4. Song Name
        love.graphics.setFont(font_body)
        love.graphics.setColor(0.7, 0.8, 0.9, 0.9)
        love.graphics.printf(card.name, cx, target_y + 270, card_w, "center")
        
        -- 5. Audio properties (BPM / Duration)
        love.graphics.setFont(font_small)
        love.graphics.setColor(0.5, 0.6, 0.7, 0.85)
        local total_seconds = math.floor(card.total_beats * (60 / card.bpm))
        local minutes = math.floor(total_seconds / 60)
        local seconds = total_seconds % 60
        love.graphics.printf(string.format("TEMPO: %d BPM  |  TIME: %02d:%02d", card.bpm, minutes, seconds), cx, target_y + 300, card_w, "center")
        
        -- 6. Difficulty Level Badge
        love.graphics.setFont(font_small)
        local diff_col = (card.difficulty == "HARD") and {0.95, 0.15, 0.15, 0.9} or {0.2, 0.95, 0.35, 0.9}
        love.graphics.setColor(diff_col)
        love.graphics.printf("DIFFICULTY: " .. card.difficulty, cx, target_y + 330, card_w, "center")
        
        -- 7. Call To Action flashing text
        if is_hovered then
            love.graphics.setFont(font_small)
            love.graphics.setColor(1, 0.9, 0.2, 0.7 + 0.3 * math.sin(time * 18))
            love.graphics.printf("-> CLICK TO INTERFACE <-", cx, target_y + 380, card_w, "center")
        else
            love.graphics.setFont(font_small)
            love.graphics.setColor(1, 1, 1, 0.35)
            love.graphics.printf(string.format("PRESS [%d] TO INTERFACE", idx), cx, target_y + 380, card_w, "center")
        end
    end
    
    -- Bottom general information
    love.graphics.setFont(font_small)
    love.graphics.setColor(1, 1, 1, 0.38)
    love.graphics.printf("마우스로 카드 선택 또는 키보드 숫자 키 [1] 또는 [2] 눌러 실행", 0, screen_h - 50, screen_w, "center")
    
    love.graphics.pop()
end

return ui_overlay
