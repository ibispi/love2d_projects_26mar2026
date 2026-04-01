-- Settings persistence: display, audio, text, gameplay
local M = {}

local SETTINGS_FILE = "settings.sav"

-- Available resolutions (width x height)
M.RESOLUTIONS = {
    {1280, 720},
    {1366, 768},
    {1600, 900},
    {1920, 1080},
    {2560, 1440},
}

-- Text speed presets: label -> characters per second
M.TEXT_SPEEDS = {
    {label = "Slow",    value = 20},
    {label = "Medium",  value = 40},
    {label = "Fast",    value = 80},
    {label = "Instant", value = 999999},
}

-- Current settings with defaults
local defaults = {
    fullscreen = false,
    resolutionIndex = 4,  -- 1920x1080
    volume = 1.0,
    muted = false,
    textSpeedIndex = 2,   -- Medium
    language = "en",      -- language code
}

local current = {}

-- Deep copy defaults into current
local function resetToDefaults()
    for k, v in pairs(defaults) do
        current[k] = v
    end
end

-- Serialize a table to a Lua string (mirrors lib/save.lua)
local function serialize(t, indent)
    indent = indent or ""
    local parts = {}
    table.insert(parts, "{\n")
    local nextIndent = indent .. "  "

    local keys = {}
    for k in pairs(t) do table.insert(keys, k) end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then return tostring(a) < tostring(b) end
        return type(a) < type(b)
    end)

    for _, k in ipairs(keys) do
        local v = t[k]
        local keyStr
        if type(k) == "number" then
            keyStr = "[" .. k .. "]"
        else
            keyStr = '["' .. tostring(k) .. '"]'
        end

        local valStr
        if type(v) == "table" then
            valStr = serialize(v, nextIndent)
        elseif type(v) == "string" then
            local escaped = v:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
            valStr = '"' .. escaped .. '"'
        elseif type(v) == "boolean" then
            valStr = tostring(v)
        else
            valStr = tostring(v)
        end

        table.insert(parts, nextIndent .. keyStr .. " = " .. valStr .. ",\n")
    end
    table.insert(parts, indent .. "}")
    return table.concat(parts)
end

function M.save()
    local content = "return " .. serialize(current) .. "\n"
    love.filesystem.write(SETTINGS_FILE, content)
end

function M.load()
    resetToDefaults()
    if love.filesystem.getInfo(SETTINGS_FILE) then
        local chunk, err = love.filesystem.load(SETTINGS_FILE)
        if chunk then
            local ok, data = pcall(chunk)
            if ok and type(data) == "table" then
                for k, v in pairs(data) do
                    if defaults[k] ~= nil then
                        current[k] = v
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Getters
---------------------------------------------------------------------------

function M.get(key)
    return current[key]
end

function M.getResolution()
    local idx = current.resolutionIndex or 4
    return M.RESOLUTIONS[idx] or M.RESOLUTIONS[4]
end

function M.getTextSpeed()
    local idx = current.textSpeedIndex or 2
    return M.TEXT_SPEEDS[idx] or M.TEXT_SPEEDS[2]
end

function M.getEffectiveVolume()
    if current.muted then return 0 end
    return current.volume
end

---------------------------------------------------------------------------
-- Setters (auto-save)
---------------------------------------------------------------------------

function M.set(key, value)
    current[key] = value
    M.save()
end

-- Apply display settings to the window
function M.applyDisplay()
    local res = M.getResolution()
    local w, h = res[1], res[2]
    local fs = current.fullscreen
    love.window.setMode(w, h, {
        resizable = not fs,
        fullscreen = fs,
        fullscreentype = "desktop",
    })
end

return M
