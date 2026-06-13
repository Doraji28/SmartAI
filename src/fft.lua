-- project/src/fft.lua
-- Highly optimized real-time FFT analyzer for Love2D.
-- Implements in-place Cooley-Tukey Radix-2 FFT with zero allocation per frame.

local bit = require("bit")
local fft = {}

local N = 256
local NUM_BANDS = 16

-- FFT lookup tables
local fft_cache = nil
local hanning_win = nil
local band_ranges = nil

-- Preallocated arrays for FFT inputs and outputs to avoid garbage collection
local ar = {}
local ai = {}
local spectrum = {}
local smooth_spectrum = {}
local bands = {}
local smooth_bands = {}

-- Initialize arrays
for i = 1, N do
    ar[i] = 0.0
    ai[i] = 0.0
    spectrum[i] = 0.0
    smooth_spectrum[i] = 0.0
end
for i = 1, NUM_BANDS do
    bands[i] = 0.0
    smooth_bands[i] = 0.0
end

-- Export registers
fft.bass = 0.0
fft.mid = 0.0
fft.high = 0.0
fft.bands = smooth_bands

-- Precalculate twiddle factors, bit reversals, and Hanning window
local function init_tables()
    -- 1. Bit-reversal indices
    local rev = {}
    local log2n = math.log(N) / math.log(2)
    for i = 0, N - 1 do
        local r = 0
        local x = i
        for j = 1, log2n do
            r = bit.bor(bit.lshift(r, 1), bit.band(x, 1))
            x = bit.rshift(x, 1)
        end
        rev[i + 1] = r + 1
    end
    
    -- 2. Twiddle factors
    local twiddle = {}
    local m = 1
    while m < N do
        local w_m_r = math.cos(math.pi / m)
        local w_m_i = -math.sin(math.pi / m)
        local w_r, w_i = 1.0, 0.0
        twiddle[m] = {}
        for j = 0, m - 1 do
            twiddle[m][j + 1] = {r = w_r, i = w_i}
            local next_w_r = w_r * w_m_r - w_i * w_m_i
            local next_w_i = w_r * w_m_i + w_i * w_m_r
            w_r, w_i = next_w_r, next_w_i
        end
        m = m * 2
    end
    
    fft_cache = {rev = rev, twiddle = twiddle}
    
    -- 3. Hanning Window
    hanning_win = {}
    for i = 1, N do
        hanning_win[i] = 0.5 * (1.0 - math.cos(2.0 * math.pi * (i - 1) / (N - 1)))
    end
    
    -- 4. Logarithmic Band Ranges (map 1..128 bins to 16 bands)
    band_ranges = {}
    local half_n = N / 2
    local step = math.log(half_n) / NUM_BANDS
    for i = 1, NUM_BANDS do
        local start_bin = math.floor(math.exp((i - 1) * step))
        local end_bin = math.floor(math.exp(i * step))
        if start_bin < 1 then start_bin = 1 end
        if end_bin < start_bin then end_bin = start_bin end
        if end_bin > half_n then end_bin = half_n end
        band_ranges[i] = {start_bin, end_bin}
    end
end

-- Perform in-place FFT
local function compute_fft()
    local rev = fft_cache.rev
    local twiddle = fft_cache.twiddle
    
    -- Bit-reversal permutation
    for i = 1, N do
        local j = rev[i]
        if i < j then
            ar[i], ar[j] = ar[j], ar[i]
            ai[i], ai[j] = ai[j], ai[i]
        end
    end
    
    -- Cooley-Tukey iterative radix-2 algorithm
    local m = 1
    while m < N do
        local tw = twiddle[m]
        local m2 = m * 2
        for k = 0, N - 1, m2 do
            for j = 1, m do
                local w = tw[j]
                local t_r = ar[k + j + m] * w.r - ai[k + j + m] * w.i
                local t_i = ar[k + j + m] * w.i + ai[k + j + m] * w.r
                
                local u_r = ar[k + j]
                local u_i = ai[k + j]
                
                ar[k + j] = u_r + t_r
                ai[k + j] = u_i + t_i
                
                ar[k + j + m] = u_r - t_r
                ai[k + j + m] = u_i - t_i
            end
        end
        m = m2
    end
end

-- Clear all values (when music is paused/stopped)
function fft.clear()
    for i = 1, N do
        spectrum[i] = 0.0
        smooth_spectrum[i] = 0.0
    end
    for i = 1, NUM_BANDS do
        bands[i] = 0.0
        smooth_bands[i] = 0.0
    end
    fft.bass = 0.0
    fft.mid = 0.0
    fft.high = 0.0
end

-- Main analysis function, called every update frame
function fft.analyze(sound_data, current_sample, dt)
    dt = dt or (1 / 60)
    
    if not fft_cache then
        init_tables()
    end
    
    local total_samples = sound_data:getSampleCount()
    local channels = sound_data:getChannelCount()
    
    -- 1. Read samples, apply Hanning window
    for i = 1, N do
        local idx = (current_sample + (i - 1)) % total_samples
        local val = 0.0
        if channels == 2 then
            val = (sound_data:getSample(idx, 1) + sound_data:getSample(idx, 2)) * 0.5
        else
            -- Backwards compatibility with older Love2D versions
            local ok, s = pcall(sound_data.getSample, sound_data, idx, 1)
            if ok then
                val = s
            else
                val = sound_data:getSample(idx)
            end
        end
        
        ar[i] = val * hanning_win[i]
        ai[i] = 0.0
    end
    
    -- 2. Compute FFT
    compute_fft()
    
    -- 3. Calculate magnitudes
    local half_n = N / 2
    for i = 1, half_n do
        local mag = math.sqrt(ar[i] * ar[i] + ai[i] * ai[i])
        -- Magnify for visual scale
        spectrum[i] = (mag * 2.0) / N
    end
    
    -- 4. Logarithmic band grouping
    for b = 1, NUM_BANDS do
        local r = band_ranges[b]
        local sum = 0.0
        local count = 0
        for bin = r[1], r[2] do
            sum = sum + spectrum[bin]
            count = count + 1
        end
        bands[b] = sum / (count > 0 and count or 1)
    end
    
    -- 5. Smoothing (fast rise, slow decay)
    local decay_rate = 8.0
    for b = 1, NUM_BANDS do
        if bands[b] > smooth_bands[b] then
            smooth_bands[b] = bands[b]
        else
            smooth_bands[b] = smooth_bands[b] - (smooth_bands[b] - bands[b]) * decay_rate * dt
        end
        if smooth_bands[b] < 0.0 then smooth_bands[b] = 0.0 end
    end
    
    -- 6. Extract main registers
    -- Bass: Bands 1-3 (20Hz - 250Hz approx)
    -- Mid: Bands 4-10 (250Hz - 2000Hz approx)
    -- High: Bands 11-16 (2000Hz - 20000Hz approx)
    local bass_sum = 0.0
    for b = 1, 3 do bass_sum = bass_sum + smooth_bands[b] end
    fft.bass = math.min(1.0, (bass_sum / 3.0) * 12.0) -- apply gain scaling
    
    local mid_sum = 0.0
    for b = 4, 10 do mid_sum = mid_sum + smooth_bands[b] end
    fft.mid = math.min(1.0, (mid_sum / 7.0) * 18.0)
    
    local high_sum = 0.0
    for b = 11, 16 do high_sum = high_sum + smooth_bands[b] end
    fft.high = math.min(1.0, (high_sum / 6.0) * 25.0)
end

return fft
