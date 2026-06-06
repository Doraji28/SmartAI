-- Font Manager for Soulrock.
-- Handles loading and downloading the Korean NanumGothic TTF font.
local font_manager = {}

local FONT_NAME = "NanumGothic.ttf"
local font_cache = {}

-- Checks if font exists, otherwise downloads it
function font_manager.init()
    love.filesystem.setIdentity("Soulrock")
    
    if not love.filesystem.getInfo(FONT_NAME) then
        print("Korean font not found. Downloading...")
        
        -- Get absolute save directory path
        local save_dir = love.filesystem.getSaveDirectory()
        -- Ensure directory exists by writing a dummy file
        love.filesystem.write("dummy.txt", "")
        love.filesystem.remove("dummy.txt")
        
        -- Download command using curl
        local url = "https://github.com/google/fonts/raw/main/ofl/nanumgothic/NanumGothic-Regular.ttf"
        local cmd = string.format('curl.exe -s -L "%s" -o "%s/%s"', url, save_dir, FONT_NAME)
        
        -- Run synchronously
        local code = os.execute(cmd)
        
        if love.filesystem.getInfo(FONT_NAME) then
            print("Korean font downloaded successfully!")
        else
            print("Warning: Failed to download Korean font. Falling back to default font.")
        end
    else
        print("Korean font found.")
    end
end

-- Get font of specific size (cached)
function font_manager.get_font(size)
    size = size or 14
    if font_cache[size] then
        return font_cache[size]
    end
    
    local font
    if love.filesystem.getInfo(FONT_NAME) then
        font = love.graphics.newFont(FONT_NAME, size)
    else
        font = love.graphics.newFont(size)
    end
    
    font_cache[size] = font
    return font
end

return font_manager
