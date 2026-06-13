-- Sound Synthesizer for Soulrock.
-- Generates procedural cyberpunk rock loops and combat sound effects on startup.
local sound_synth = {}

local SAMPLE_RATE = 44100
local PI = math.pi

-- Pre-generated sound sources
sound_synth.music_tracks = {}
sound_synth.music_loop = nil -- Active music source pointer
sound_synth.sfx_shoot = nil
sound_synth.sfx_perfect = nil
sound_synth.sfx_cool = nil
sound_synth.sfx_miss = nil
sound_synth.sfx_overheat = nil

-- Simple pseudo-random helper for noise generation (since math.random is stateful)
local function get_noise(seed)
    local x = math.sin(seed) * 10000
    return x - math.floor(x)
end

-- 1. Synthesize Combat Sound Effects
local function synth_shoot()
    local len = math.floor(SAMPLE_RATE * 0.12)
    local sd = love.sound.newSoundData(len, SAMPLE_RATE, 16, 1)
    for i = 0, len - 1 do
        local t = i / SAMPLE_RATE
        -- Frequency pitch slide from 900 Hz down to 200 Hz
        local freq = 900 * math.exp(-t * 20)
        local val = math.sin(t * 2 * PI * freq) * math.exp(-t * 15)
        sd:setSample(i, val * 0.3)
    end
    return love.audio.newSource(sd)
end

local function synth_perfect()
    local len = math.floor(SAMPLE_RATE * 0.28)
    local sd = love.sound.newSoundData(len, SAMPLE_RATE, 16, 1)
    for i = 0, len - 1 do
        local t = i / SAMPLE_RATE
        -- Explosive white noise mixed with sine drop
        local freq = 200 * math.exp(-t * 12)
        local sine = math.sin(t * 2 * PI * freq) * 0.3
        local noise = (math.random() * 2.0 - 1.0) * 0.7
        local val = (sine + noise) * math.exp(-t * 8)
        sd:setSample(i, val * 0.45)
    end
    return love.audio.newSource(sd)
end

local function synth_cool()
    local len = math.floor(SAMPLE_RATE * 0.18)
    local sd = love.sound.newSoundData(len, SAMPLE_RATE, 16, 1)
    for i = 0, len - 1 do
        local t = i / SAMPLE_RATE
        -- Mild snap (highpass noise + pop)
        local noise = (math.random() * 2.0 - 1.0) * 0.5
        local sine = math.sin(t * 2 * PI * 300) * 0.5
        local val = (sine + noise) * math.exp(-t * 12)
        sd:setSample(i, val * 0.35)
    end
    return love.audio.newSource(sd)
end

local function synth_overheat()
    local len = math.floor(SAMPLE_RATE * 0.4)
    local sd = love.sound.newSoundData(len, SAMPLE_RATE, 16, 1)
    for i = 0, len - 1 do
        local t = i / SAMPLE_RATE
        -- Harsh low saw buzz around 75 Hz
        local freq = 75
        local saw = ((t * freq) % 1.0 - 0.5) * 2.0
        local val = saw * math.exp(-t * 4)
        sd:setSample(i, val * 0.38)
    end
    return love.audio.newSource(sd)
end

local function synth_miss()
    local len = math.floor(SAMPLE_RATE * 0.15)
    local sd = love.sound.newSoundData(len, SAMPLE_RATE, 16, 1)
    for i = 0, len - 1 do
        local t = i / SAMPLE_RATE
        -- Dull thud
        local freq = 100 * math.exp(-t * 22)
        local val = math.sin(t * 2 * PI * freq) * math.exp(-t * 25)
        sd:setSample(i, val * 0.4)
    end
    return love.audio.newSource(sd)
end

-- 2. Synthesize specific music track loop
local function synth_music_track(track_type)
    local bpm = 140
    local total_beats = 16
    
    if track_type == 1 then
        bpm = 140 -- Neon Cyber Rock
    elseif track_type == 2 then
        bpm = 170 -- Speed Metal Valkyrie
    elseif track_type == 3 then
        bpm = 110 -- Retro Synth Odyssey
    end
    
    local beat_interval = 60 / bpm
    local total_duration = total_beats * beat_interval
    local len = math.floor(SAMPLE_RATE * total_duration)
    local sd = love.sound.newSoundData(len, SAMPLE_RATE, 16, 1)
    
    -- Frequency maps
    local bass_pitches_rock = { 82.4, 82.4, 82.4, 82.4, 98.0, 98.0, 98.0, 98.0, 110.0, 110.0, 110.0, 110.0, 73.4, 73.4, 73.4, 73.4 }
    local lead_pitches_rock = { 164.8, 196.0, 220.0, 246.9, 196.0, 246.9, 293.6, 246.9, 220.0, 261.6, 329.6, 261.6, 246.9, 220.0, 196.0, 185.0 }
    
    local bass_pitches_metal = { 55.0, 55.0, 55.0, 55.0, 65.4, 65.4, 65.4, 65.4, 73.4, 73.4, 73.4, 73.4, 49.0, 49.0, 49.0, 49.0 } -- Heavy A-minor / F / G / E
    local lead_pitches_metal = { 220.0, 261.6, 293.7, 329.6, 349.2, 329.6, 293.7, 261.6, 329.6, 392.0, 440.0, 392.0, 329.6, 293.7, 261.6, 246.9 }

    local bass_pitches_synth = { 73.4, 73.4, 73.4, 73.4, 58.2, 58.2, 58.2, 58.2, 65.4, 65.4, 65.4, 65.4, 73.4, 73.4, 73.4, 73.4 } -- D-minor progressive
    local lead_pitches_synth = { 146.8, 146.8, 174.6, 174.6, 196.0, 196.0, 220.0, 196.0, 174.6, 174.6, 196.0, 196.0, 174.6, 146.8, 130.8, 146.8 }

    for i = 0, len - 1 do
        local t = i / SAMPLE_RATE
        local beat = t / beat_interval
        local val = 0.0
        
        if track_type == 1 then
            -- =====================================================
            -- CYBER ROCK (140 BPM)
            -- =====================================================
            -- 1. Kick (odd beats)
            for b = 0, total_beats - 1, 2 do
                local dt = t - (b * beat_interval)
                if dt >= 0 and dt < 0.18 then
                    local freq = 140 * math.exp(-dt * 28)
                    val = val + math.sin(dt * 2 * PI * freq) * math.exp(-dt * 15) * 0.42
                end
            end
            -- 2. Snare (even beats)
            for b = 1, total_beats - 1, 2 do
                local dt = t - (b * beat_interval)
                if dt >= 0 and dt < 0.18 then
                    local noise = get_noise(i) * 2.0 - 1.0
                    local sine = math.sin(dt * 2 * PI * 180) * 0.22
                    val = val + (sine + noise * 0.6) * math.exp(-dt * 16) * 0.3
                end
            end
            -- 3. Bass
            local bass_note_idx = math.floor(beat * 2)
            local bass_trigger = bass_note_idx * (beat_interval / 2)
            local bass_dt = t - bass_trigger
            if bass_dt >= 0 and bass_dt < (beat_interval / 2) then
                local freq = bass_pitches_rock[math.floor(bass_note_idx / 2) % 16 + 1]
                local saw = ((bass_dt * freq) % 1.0 - 0.5) * 2.0
                val = val + saw * math.exp(-bass_dt * 12) * 0.28
            end
            -- 4. Lead
            local lead_note_idx = math.floor(beat)
            local lead_trigger = lead_note_idx * beat_interval
            local lead_dt = t - lead_trigger
            if lead_dt >= 0 and lead_dt < beat_interval then
                local freq = lead_pitches_rock[lead_note_idx % 16 + 1]
                local sqr = math.sin(lead_dt * 2 * PI * freq) >= 0 and 0.5 or -0.5
                val = val + sqr * math.exp(-lead_dt * 6) * 0.12
            end
            
        elseif track_type == 2 then
            -- =====================================================
            -- SPEED METAL (170 BPM)
            -- =====================================================
            -- 1. Double Kick (triggers on every 8th note!)
            for b = 0, total_beats * 2 - 1 do
                local dt = t - (b * (beat_interval / 2))
                if dt >= 0 and dt < 0.12 then
                    local freq = 120 * math.exp(-dt * 35)
                    val = val + math.sin(dt * 2 * PI * freq) * math.exp(-dt * 20) * 0.45
                end
            end
            -- 2. Snare (beats 2, 4, 6, 8, etc.)
            for b = 1, total_beats - 1, 2 do
                local dt = t - (b * beat_interval)
                if dt >= 0 and dt < 0.15 then
                    local noise = get_noise(i) * 2.0 - 1.0
                    val = val + noise * math.exp(-dt * 22) * 0.35
                end
            end
            -- 3. Fast Metal Riffing Bass
            local bass_note_idx = math.floor(beat * 4) -- 16th notes!
            local bass_trigger = bass_note_idx * (beat_interval / 4)
            local bass_dt = t - bass_trigger
            if bass_dt >= 0 and bass_dt < (beat_interval / 4) then
                local freq = bass_pitches_metal[math.floor(bass_note_idx / 4) % 16 + 1]
                -- Chugging saw wave
                local saw = ((bass_dt * freq) % 1.0 - 0.5) * 2.0
                val = val + saw * math.exp(-bass_dt * 15) * 0.3
            end
            -- 4. Fast Shredding Lead
            local lead_note_idx = math.floor(beat * 2) -- 8th notes!
            local lead_trigger = lead_note_idx * (beat_interval / 2)
            local lead_dt = t - lead_trigger
            if lead_dt >= 0 and lead_dt < (beat_interval / 2) then
                local freq = lead_pitches_metal[math.floor(lead_note_idx) % 16 + 1] * 1.5
                local sqr = math.sin(lead_dt * 2 * PI * freq) >= 0 and 0.5 or -0.5
                val = val + sqr * math.exp(-lead_dt * 8) * 0.14
            end
            
        elseif track_type == 3 then
            -- =====================================================
            -- RETRO SYNTH (110 BPM)
            -- =====================================================
            -- 1. Slow Kick (beat 1 and 3 of every measure)
            for b = 0, total_beats - 1 do
                if b % 4 == 0 or b % 4 == 2 then
                    local dt = t - (b * beat_interval)
                    if dt >= 0 and dt < 0.25 then
                        local freq = 110 * math.exp(-dt * 18)
                        val = val + math.sin(dt * 2 * PI * freq) * math.exp(-dt * 8) * 0.5
                    end
                end
            end
            -- 2. Slow Snare (beat 2 and 4 of every measure)
            for b = 0, total_beats - 1 do
                if b % 4 == 1 or b % 4 == 3 then
                    local dt = t - (b * beat_interval)
                    if dt >= 0 and dt < 0.25 then
                        local noise = get_noise(i) * 2.0 - 1.0
                        local low_pass_noise = (noise + get_noise(i + 1)) * 0.5
                        val = val + low_pass_noise * math.exp(-dt * 10) * 0.22
                    end
                end
            end
            -- 3. Fat Synthwave Bass (jumping octaves, 8th notes)
            local bass_note_idx = math.floor(beat * 2)
            local bass_trigger = bass_note_idx * (beat_interval / 2)
            local bass_dt = t - bass_trigger
            if bass_dt >= 0 and bass_dt < (beat_interval / 2) then
                local p_idx = math.floor(bass_note_idx / 2) % 16 + 1
                local freq = bass_pitches_synth[p_idx]
                -- Octave jumping
                if bass_note_idx % 2 == 1 then
                    freq = freq * 2.0
                end
                local saw = ((bass_dt * freq) % 1.0 - 0.5) * 2.0
                val = val + saw * math.exp(-bass_dt * 8) * 0.35
            end
            -- 4. Smooth Triangle Lead
            local lead_note_idx = math.floor(beat)
            local lead_trigger = lead_note_idx * beat_interval
            local lead_dt = t - lead_trigger
            if lead_dt >= 0 and lead_dt < beat_interval then
                local freq = lead_pitches_synth[lead_note_idx % 16 + 1] * 2.0
                -- Triangle wave synthesizer
                local tri = math.abs((lead_dt * freq) % 1.0 - 0.5) * 4.0 - 1.0
                val = val + tri * math.exp(-lead_dt * 4) * 0.18
            end
        end
        
        -- Clamp sample values
        val = math.max(-1.0, math.min(1.0, val))
        sd:setSample(i, val)
    end
    
    local source = love.audio.newSource(sd)
    source:setLooping(true)
    return source
end

local music_paths = {
    [1] = "Music/Boss1/KILLI.mp3",
    [2] = "Music/Boss2/Dreaming in the Ether.mp3",
    [3] = "Music/Boss3/Dreamsteps.mp3",
    [4] = "Music/Boss4/Second Run-Ethereal Memories.mp3",
    [5] = "Music/Boss5/Second Run - yeon.mp3",
    [6] = "Music/Boss6/Shadows creeping on the floor,.mp3",
    [7] = "Music/Boss7/CantStop.mp3",
    [8] = "Music/Boss8/DorajiBasement.mp3",
    [9] = "Music/Boss9/Wire Live.mp3",
    [10] = "Music/Boss10/Signal Detonator.mp3",
    [11] = "Music/Boss11/Doraniscence.mp3"
}

sound_synth.current_sound_data = nil
sound_synth.current_static_source = nil

-- Initialize and synthesize all assets
function sound_synth.init()
    print("Synthesizing audio assets in memory...")
    sound_synth.sfx_shoot = synth_shoot()
    sound_synth.sfx_perfect = synth_perfect()
    sound_synth.sfx_cool = synth_cool()
    sound_synth.sfx_miss = synth_miss()
    sound_synth.sfx_overheat = synth_overheat()
    
    -- Load actual MP3 files for the stages
    print("Loading MP3 music tracks from Music/...")
    sound_synth.music_tracks = {}
    for idx = 1, 11 do
        local ok, src = pcall(love.audio.newSource, music_paths[idx], "stream")
        if ok then
            sound_synth.music_tracks[idx] = src
            sound_synth.music_tracks[idx]:setLooping(false)
        else
            print("Warning: Failed to load stream track " .. idx .. ": " .. tostring(src))
        end
    end
    
    -- Set default active source
    sound_synth.music_loop = sound_synth.music_tracks[1]
    
    print("Audio assets initialized successfully!")
end

-- Select track loop
function sound_synth.select_track(idx)
    -- Clean up static sources if returning to menu
    sound_synth.current_sound_data = nil
    sound_synth.current_static_source = nil
    if sound_synth.music_tracks[idx] then
        sound_synth.music_loop = sound_synth.music_tracks[idx]
    end
end

-- Load static game track for real-time FFT
function sound_synth.load_game_track(idx)
    if sound_synth.music_loop then
        sound_synth.music_loop:stop()
    end
    
    local path = music_paths[idx]
    if not path then return nil end
    
    print("Loading game track " .. idx .. " as static SoundData for real-time FFT...")
    local ok, sd = pcall(love.sound.newSoundData, path)
    if ok then
        sound_synth.current_sound_data = sd
        sound_synth.current_static_source = love.audio.newSource(sd)
        sound_synth.current_static_source:setLooping(false)
        sound_synth.music_loop = sound_synth.current_static_source
        print("Successfully loaded static SoundData!")
    else
        print("Failed to load static SoundData: " .. tostring(sd))
        sound_synth.current_sound_data = nil
        sound_synth.current_static_source = nil
        sound_synth.music_loop = sound_synth.music_tracks[idx]
    end
end

-- SFX Play Wrappers
function sound_synth.play_shoot()
    sound_synth.sfx_shoot:clone():play()
end

function sound_synth.play_perfect()
    sound_synth.sfx_perfect:clone():play()
end

function sound_synth.play_cool()
    sound_synth.sfx_cool:clone():play()
end

function sound_synth.play_miss()
    sound_synth.sfx_miss:clone():play()
end

function sound_synth.play_overheat()
    sound_synth.sfx_overheat:clone():play()
end

return sound_synth
