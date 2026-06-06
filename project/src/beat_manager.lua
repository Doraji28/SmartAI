-- Beat & Timeline Chart Manager for Soulrock.
-- Defines the rhythm track chart, spawns notes at appropriate beats, and tracks stages.
local note = require("note")
local beat_manager = {}

-- Configured Boss Stages
beat_manager.stages = {
    {
        name = "Cyber Core",
        boss_name = "NEXUS CORE",
        bpm = 90,
        track_idx = 1,
        color = {0.15, 0.75, 0.9, 0.95},       -- Turquoise
        shield_color = {0.2, 0.85, 0.95, 0.95},
        total_beats = 228,
        start_offset = 0.15,
        difficulty = "NORMAL"
    },
    {
        name = "Ether Run",
        boss_name = "VALKYRIE ZERO",
        bpm = 138,
        track_idx = 2,
        color = {0.95, 0.15, 0.15, 0.95},      -- Crimson Red
        shield_color = {0.95, 0.25, 0.25, 0.95},
        total_beats = 436,
        start_offset = 0.10,
        difficulty = "HARD"
    }
}

beat_manager.active_stage_idx = 1
beat_manager.track = beat_manager.stages[1]
beat_manager.beat_interval = 60 / beat_manager.track.bpm
beat_manager.current_beat = 0.0
beat_manager.last_integer_beat = -1

local chart = {}
local spawned_flags = {}

local function add_note(note_type, target_beat, end_beat)
    table.insert(chart, {
        type = note_type,
        beat = target_beat,
        end_beat = end_beat
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
        
        if r < 0.20 then
            add_note("laser", b, b + laser_duration)
            -- Block out the laser duration and its wait cooldown at 0.5-beat granularity
            for step = b, b + laser_wait - 0.5, 0.5 do
                boss_beats[step] = true
            end
            b = b + laser_wait
        else
            add_note("breakable", b)
            boss_beats[b] = true
            boss_beats[b - 0.5] = true
            boss_beats[b + 0.5] = true
            b = b + breakable_wait
        end
    end
    
    -- Fill in rhythm "beat" notes on all other 0.5-beat steps
    for beat = 4, total_beats - 8, 0.5 do
        if not boss_beats[beat] then
            add_note("beat", beat)
        end
    end
    
    -- Sort notes in chart chronologically by target beat
    table.sort(chart, function(x, y) return x.beat < y.beat end)
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
    
    -- Spawn notes (spawn 4 beats ahead of target)
    local travel_beats = 4.0
    for idx, item in ipairs(chart) do
        if not spawned_flags[idx] then
            if beat_manager.current_beat >= item.beat - travel_beats then
                spawned_flags[idx] = true
                
                if item.type == "beat" then
                    -- Spawn beat notes at static screen center (no random corner positioning)
                    note.spawn(item.type, item.beat, travel_beats, 0.0, 0.0)
                else
                    local corners = {
                        {x = -2.0, y = -1.0},
                        {x = 2.0,  y = -1.0},
                        {x = -2.0, y = 1.0},
                        {x = 2.0,  y = 1.0},
                        {x = 0.0,  y = -0.6}
                    }
                    local c = corners[math.random(1, #corners)]
                    note.spawn(item.type, item.beat, travel_beats, c.x, c.y, item.end_beat)
                end
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
