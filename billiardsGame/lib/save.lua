-- Profile save system using love.filesystem (writes to the save directory)
local M = {}

local SAVE_FILE = "profile.sav"

local profile = {
    unlockedGallery = {}, -- [index] = true for unlocked images
}

-- Serialize a table to a Lua string
local function serialize(t, indent)
    indent = indent or ""
    local parts = {}
    table.insert(parts, "{\n")
    local nextIndent = indent .. "  "
    for k, v in pairs(t) do
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
            valStr = '"' .. v .. '"'
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
    local data = "return " .. serialize(profile) .. "\n"
    love.filesystem.write(SAVE_FILE, data)
end

function M.load()
    if love.filesystem.getInfo(SAVE_FILE) then
        local chunk, err = love.filesystem.load(SAVE_FILE)
        if chunk then
            local ok, data = pcall(chunk)
            if ok and type(data) == "table" then
                profile.unlockedGallery = data.unlockedGallery or {}
                return
            end
        end
    end
    -- No save or failed to load — use defaults
    profile.unlockedGallery = {}
end

function M.isGalleryUnlocked(index)
    return profile.unlockedGallery[index] == true
end

function M.unlockGallery(index)
    if not profile.unlockedGallery[index] then
        profile.unlockedGallery[index] = true
        M.save()
    end
end

function M.getUnlockedCount()
    local count = 0
    for _, v in pairs(profile.unlockedGallery) do
        if v then count = count + 1 end
    end
    return count
end

return M
