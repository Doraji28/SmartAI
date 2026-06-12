-- Beat & Timeline Chart Manager for Soulrock.
-- Defines the rhythm track chart, spawns notes at appropriate beats, and tracks stages.
local note = require("note")
local beat_manager = {}

-- Configured Boss Stages
beat_manager.stages = {
    {
        name = "Cyber Core",
        boss_name = "NEXUS CORE",
        bpm = 89.95,
        track_idx = 1,
        color = {0.15, 0.75, 0.9, 0.95},       -- Turquoise
        shield_color = {0.2, 0.85, 0.95, 0.95},
        total_beats = 228,
        start_offset = 0.15,
        difficulty = "NORMAL",
        bg_image_path = "Music/Boss1/SIng.png"
    },
    {
        name = "Ether Run",
        boss_name = "VALKYRIE ZERO",
        bpm = 127.11,
        track_idx = 2,
        color = {0.95, 0.15, 0.15, 0.95},      -- Crimson Red
        shield_color = {0.95, 0.25, 0.25, 0.95},
        total_beats = 436,
        start_offset = 0.10,
        difficulty = "HARD",
        bg_image_path = "Music/Boss2/애니기타.png"
    },
    {
        name = "Dreamsteps",
        boss_name = "GLADE GUARDIAN",
        bpm = 115.0,
        track_idx = 3,
        color = {0.15, 0.9, 0.4, 0.95},        -- Neon Green
        shield_color = {0.25, 0.95, 0.5, 0.95},
        total_beats = 346,
        start_offset = 0.12,
        difficulty = "NORMAL",
        bg_image_path = "Music/Boss3/몽환 피아노.png"
    },
    {
        name = "Ethereal Memories",
        boss_name = "AETHER WARDEN",
        bpm = 125.0,
        track_idx = 4,
        color = {0.75, 0.15, 0.9, 0.95},       -- Purple
        shield_color = {0.85, 0.25, 0.95, 0.95},
        total_beats = 370,
        start_offset = 0.15,
        difficulty = "HARD",
        bg_image_path = "Music/Boss4/몽환피아노2.png"
    },
    {
        name = "Second Run (Talesweaver)",
        boss_name = "VANILLA MOOD",
        bpm = 130.0,
        track_idx = 5,
        color = {0.95, 0.55, 0.15, 0.95},      -- Orange
        shield_color = {0.95, 0.65, 0.25, 0.95},
        total_beats = 257,
        start_offset = 0.08,
        difficulty = "NORMAL",
        bg_image_path = "Music/Boss5/아름다운풍경.png"
    },
    {
        name = "Shadow Creep",
        boss_name = "SHADOW REAP",
        bpm = 140.0,
        track_idx = 6,
        color = {0.95, 0.85, 0.15, 0.95},      -- Yellow
        shield_color = {0.95, 0.9, 0.25, 0.95},
        total_beats = 303,
        start_offset = 0.10,
        difficulty = "HARD",
        bg_image_path = "Music/Boss6/ROCKER.png"
    },
    {
        name = "멈추지 않아 비상",
        boss_name = "NEON IDOL",
        bpm = 134.0,
        track_idx = 7,
        color = {0.95, 0.15, 0.75, 0.95},      -- Magenta/Pink
        shield_color = {0.95, 0.25, 0.85, 0.95},
        total_beats = 375,
        start_offset = 0.10,
        difficulty = "HARD",
        bg_image_path = "Music/Boss7/남자아이돌.png"
    }
}

beat_manager.active_stage_idx = 1
beat_manager.track = beat_manager.stages[1]
beat_manager.beat_interval = 60 / beat_manager.track.bpm
beat_manager.current_beat = 0.0
beat_manager.last_integer_beat = -1

local chart = {}
local spawned_flags = {}

function beat_manager.get_scanline_y(beat)
    local y_min = 140
    local y_max = 580
    local sweep_beats = 4.0
    local phase = (beat / sweep_beats) % 2.0
    
    if phase < 1.0 then
        local progress = phase
        return y_min + progress * (y_max - y_min), 1 -- Y coordinate, direction (1 = down)
    else
        local progress = phase - 1.0
        return y_max - progress * (y_max - y_min), -1 -- Y coordinate, direction (-1 = up)
    end
end

local function add_note(note_type, target_beat, end_beat)
    -- Calculate Y position deterministically from target_beat using scanline Y
    local ry, direction = beat_manager.get_scanline_y(target_beat)
    
    local rx = 0
    local prev = chart[#chart]
    
    if not prev then
        -- Start near center
        rx = 1280 / 2 + math.random(-100, 100)
    else
        -- Generate position relative to previous note with a comfortable X distance
        local dist_x = math.random(160, 320)
        local sign = math.random() > 0.5 and 1 or -1
        rx = prev.x + sign * dist_x
        
        -- Wrap around or bounce within playfield boundaries
        if rx < 150 or rx > 1130 then
            rx = math.random(250, 1030)
        end
    end

    table.insert(chart, {
        type = note_type,
        beat = target_beat,
        end_beat = end_beat,
        x = rx,
        y = ry,
        scan_dir = direction
    })
end

-- Compose a custom chart dynamically depending on the selected stage
local function build_chart(stage_idx)
    chart = {}
    spawned_flags = {}
    
    local track = beat_manager.stages[stage_idx]
    local total_beats = track.total_beats
    local groggy_start = math.floor(total_beats * 0.45)
    local groggy_end = math.floor(total_beats * 0.75)
    
    -- Seed random generator so chart is deterministic for each stage
    math.randomseed(stage_idx * 12345)
    
    -- Set comfortable spacing depending on the stage BPM.
    local laser_wait, breakable_wait, laser_duration
    if track.bpm <= 100 then
        laser_wait = 6
        breakable_wait = 4
        laser_duration = 2
    else
        laser_wait = 8
        breakable_wait = 5
        laser_duration = 3
    end
    
    local boss_beats = {}
    local b = 4
    while b < total_beats - 8 do
        local is_in_groggy = (b >= groggy_start and b <= groggy_end)
        local r = math.random()
        
        if r < 0.22 then
            local end_beat = b + laser_duration
            -- Ensure laser doesn't cross sweep boundary (every 4 beats the scanline bounces)
            if math.floor(b / 4.0) ~= math.floor(end_beat / 4.0) then
                end_beat = math.floor(end_beat / 4.0) * 4.0
            end
            
            local actual_duration = end_beat - b
            if actual_duration >= 0.5 then
                add_note("laser", b, end_beat)
                -- Block out the laser duration and its wait cooldown
                local total_wait = actual_duration + (laser_wait - laser_duration)
                for step = b, b + total_wait - 0.5, 0.5 do
                    boss_beats[step] = true
                end
                b = b + total_wait
            else
                -- Fallback: spawn a breakable note instead of a too-short laser
                add_note("breakable", b)
                boss_beats[b] = true
                boss_beats[b - 0.5] = true
                boss_beats[b + 0.5] = true
                b = b + breakable_wait
            end
        elseif r < 0.48 then
            -- Spawn a Drag Chain of 3 to 5 notes
            local chain_len = math.random(3, 5)
            local step = 0.35
            for i = 1, chain_len do
                local note_beat = b + (i - 1) * step
                add_note("drag", note_beat)
                boss_beats[math.floor(note_beat * 2) / 2] = true
            end
            b = b + math.ceil(chain_len * step + 1)
        else
            add_note("breakable", b)
            boss_beats[b] = true
            boss_beats[b - 0.5] = true
            boss_beats[b + 0.5] = true
            b = b + breakable_wait
        end
    end
    
    -- Fill in rhythm "beat" notes on integer beats (1.0-beat step instead of 0.5-beat)
    for beat = 4, total_beats - 8, 1.0 do
        if not boss_beats[beat] then
            add_note("beat", beat)
        end
    end
    
    -- Sort notes in chart chronologically by target beat
    table.sort(chart, function(x, y) return x.beat < y.beat end)
    
    -- Assign combo sequence numbers (1 to 8) to sorted notes
    local combo_num = 1
    for i, item in ipairs(chart) do
        item.combo_num = combo_num
        combo_num = combo_num + 1
        if combo_num > 8 then
            combo_num = 1
        end
    end
end

-- Select active stage
function beat_manager.select_stage(idx)
    if beat_manager.stages[idx] then
        beat_manager.active_stage_idx = idx
        beat_manager.track = beat_manager.stages[idx]
        beat_manager.beat_interval = 60 / beat_manager.track.bpm
    end
end

-- Initialize beat states
function beat_manager.init()
    build_chart(beat_manager.active_stage_idx)
    beat_manager.current_beat = 0.0
    beat_manager.last_integer_beat = -1
    note.clear()
end

-- Update beat position and trigger spawns
function beat_manager.update(audio_time)
    if audio_time < beat_manager.track.start_offset then
        beat_manager.current_beat = 0.0
        return false
    end
    
    beat_manager.current_beat = (audio_time - beat_manager.track.start_offset) / beat_manager.beat_interval
    
    local int_beat = math.floor(beat_manager.current_beat)
    local is_new_beat = false
    if int_beat > beat_manager.last_integer_beat then
        is_new_beat = true
        beat_manager.last_integer_beat = int_beat
    end
    
    -- Spawn notes (spawn 2.5 beats ahead of target)
    local travel_beats = 2.5
    for idx, item in ipairs(chart) do
        if not spawned_flags[idx] then
            if beat_manager.current_beat >= item.beat - travel_beats then
                spawned_flags[idx] = true
                note.spawn(item.type, item.beat, travel_beats, item.x, item.y, item.end_beat, item.combo_num)
            end
        end
    end
    
    return is_new_beat
end

-- Check current phase
function beat_manager.is_groggy_phase()
    local track = beat_manager.track
    local groggy_start = math.floor(track.total_beats * 0.45)
    local groggy_end = math.floor(track.total_beats * 0.75)
    return beat_manager.current_beat >= groggy_start and beat_manager.current_beat <= groggy_end
end

function beat_manager.get_groggy_limit()
    local track = beat_manager.track
    return math.floor(track.total_beats * 0.75)
end

function beat_manager.is_outro_phase()
    local track = beat_manager.track
    local groggy_end = math.floor(track.total_beats * 0.75)
    return beat_manager.current_beat > groggy_end
end

function beat_manager.get_total_duration()
    return beat_manager.track.duration
end

return beat_manager
