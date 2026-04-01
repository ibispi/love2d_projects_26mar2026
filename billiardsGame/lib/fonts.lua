-- Shared font module: provides Unicode-capable fonts for all UI
-- Uses a bundled TTF font to support accented, Cyrillic, CJK characters etc.
local M = {}

local FONT_PATH = "content/fonts/arial.ttf"
local cache = {} -- [size] = font object

function M.get(size)
    if not cache[size] then
        if love.filesystem.getInfo(FONT_PATH) then
            cache[size] = love.graphics.newFont(FONT_PATH, size)
        else
            -- Fallback to default (ASCII-only)
            cache[size] = love.graphics.newFont(size)
        end
    end
    return cache[size]
end

return M
