-- Profile save system using love.filesystem (writes to the save directory)
local M = {}

local PROFILE_FILE = "profile.sav"
local CHECKPOINTS_FILE = "checkpoints.sav"

local profile = {
    unlockedGallery = {}, -- [index] = true for unlocked images
}

-- Checkpoints: ordered list, newest last
-- Each: { label, scriptModule, eventIndex, variables, storyPlayed, timestamp }
local checkpoints = {}

-- Serialize a table to a Lua string
local function serialize(t, indent)
    indent = indent or ""
    local parts = {}
    table.insert(parts, "{\n")
    local nextIndent = indent .. "  "

    -- Sort keys for deterministic output
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
            -- Escape special characters in strings
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

local function writeFile(filename, data)
    local content = "return " .. serialize(data) .. "\n"
    love.filesystem.write(filename, content)
end

local function readFile(filename)
    if love.filesystem.getInfo(filename) then
        local chunk, err = love.filesystem.load(filename)
        if chunk then
            local ok, data = pcall(chunk)
            if ok and type(data) == "table" then
                return data
            end
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Profile (gallery unlocks)
---------------------------------------------------------------------------

function M.save()
    writeFile(PROFILE_FILE, profile)
end

function M.load()
    local data = readFile(PROFILE_FILE)
    if data then
        profile.unlockedGallery = data.unlockedGallery or {}
    else
        profile.unlockedGallery = {}
    end

    -- Load checkpoints
    local cpData = readFile(CHECKPOINTS_FILE)
    if cpData then
        checkpoints = cpData
    else
        checkpoints = {}
    end
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

---------------------------------------------------------------------------
-- Checkpoints
---------------------------------------------------------------------------

function M.saveCheckpoint(label, scriptModule, eventIndex, variables, storyPlayed)
    local cp = {
        label = label or "Checkpoint",
        scriptModule = scriptModule,
        eventIndex = eventIndex,
        variables = {},
        storyPlayed = {},
        timestamp = os.time(),
    }
    -- Deep copy variables
    for k, v in pairs(variables) do
        cp.variables[k] = v
    end
    -- Deep copy storyPlayed
    for k, v in pairs(storyPlayed) do
        cp.storyPlayed[k] = v
    end

    table.insert(checkpoints, cp)
    writeFile(CHECKPOINTS_FILE, checkpoints)
end

function M.getCheckpoints()
    return checkpoints
end

function M.getCheckpointCount()
    return #checkpoints
end

function M.getCheckpoint(index)
    return checkpoints[index]
end

function M.hasCheckpoints()
    return #checkpoints > 0
end

return M
