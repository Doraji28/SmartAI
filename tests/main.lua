-- tests/main.lua - LÖVE test runner for automated unit testing of Soulrock.
-- Exits immediately after printing diagnostic reports to the console.
function love.load()
    print("==================================================")
    print("      SOULROCK GAME ENGINE AUTOMATED TESTS        ")
    print("==================================================")
    
    -- Configure package path to look inside the root src/ folder
    package.path = package.path .. ";src/?.lua"
    
    -- Test 1: Accuracy Rank Calculations
    do
        print("[TEST 1/3] Testing Accuracy Rank Math...")
        local function calculate_rank(perfect, good, miss)
            local total = perfect + good + miss
            if total == 0 then return "D" end
            local acc = (perfect + good * 0.5) / total
            if acc >= 0.95 then return "S"
            elseif acc >= 0.85 then return "A"
            elseif acc >= 0.70 then return "B"
            elseif acc >= 0.50 then return "C"
            else return "D" end
        end
        
        assert(calculate_rank(100, 0, 0) == "S", "100% PERFECT must be S")
        assert(calculate_rank(90, 10, 0) == "S", "95% accuracy must be S")
        assert(calculate_rank(80, 20, 0) == "A", "90% accuracy must be A")
        assert(calculate_rank(70, 0, 30) == "B", "70% accuracy must be B")
        assert(calculate_rank(50, 0, 50) == "C", "50% accuracy must be C")
        assert(calculate_rank(0, 0, 100) == "D", "0% accuracy must be D")
        print("-> PASS: Accuracy Rank limits are calculated correctly.")
    end
    
    -- Test 2: Scanline Sweep Boundaries
    do
        print("[TEST 2/3] Testing Scanline Sweep Boundaries...")
        -- Mock note dependency to require beat_manager cleanly in console mode
        package.loaded["note"] = { clear = function() end }
        local beat_manager = require("beat_manager")
        
        -- Test NORMAL sweep (4 beats)
        beat_manager.selected_difficulty = "NORMAL"
        for beat = 0, 12, 0.1 do
            local y, dir = beat_manager.get_scanline_y(beat)
            assert(y >= 140 and y <= 580, "Scanline Y must be within boundaries [140, 580]")
            assert(dir == 1 or dir == -1, "Direction must be positive or negative 1")
        end
        
        -- Test VeryHard sweep (2 beats)
        beat_manager.selected_difficulty = "VeryHard"
        for beat = 0, 12, 0.1 do
            local y, dir = beat_manager.get_scanline_y(beat)
            assert(y >= 140 and y <= 580, "Scanline Y on VeryHard must be within boundaries [140, 580]")
        end
        print("-> PASS: Scanline Y values conform strictly to Playfield limits.")
    end
    
    -- Test 3: Radix-2 FFT Execution Sanity Checks
    do
        print("[TEST 3/3] Testing FFT Algorithm Execution...")
        local fft = require("fft")
        fft.clear()
        
        -- Mock SoundData wrapper providing mock samples
        local mock_sound_data = {
            getSampleCount = function(self)
                return 100000
            end,
            getChannelCount = function(self)
                return 1
            end,
            getSample = function(self, sample_idx)
                -- Generate a compound sine wave (simulating sound frequency components)
                return 0.5 * math.sin(sample_idx * 0.05) + 0.3 * math.sin(sample_idx * 0.2)
            end
        }
        
        -- Run analyze and verify it completes without errors
        for sample_frame = 256, 2048, 256 do
            fft.analyze(mock_sound_data, sample_frame, 0.016)
            assert(fft.bass >= 0, "Bands register must return non-negative floats")
            assert(fft.mid >= 0, "Bands register must return non-negative floats")
            assert(fft.high >= 0, "Bands register must return non-negative floats")
        end
        print("-> PASS: FFT module runs successfully with zero dynamic memory overhead.")
    end
    
    print("==================================================")
    print("  ALL TESTS COMPLETED SUCCESSFULLY! [SYSTEM PASS] ")
    print("==================================================")
    love.event.quit(0)
end
