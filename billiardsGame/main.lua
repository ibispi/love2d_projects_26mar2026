-- Main entry point — game state manager
-- States: menu, dialogue, billiards

local billiards = require("billiards.app")
local dialogue = require("visualnovel.dialogue")
local vnui = require("visualnovel.ui")
local characters = require("visualnovel.characters")
local allOpponents = require("content.scripts.opponents")

local gameState = "menu" -- "menu", "dialogue", "billiards"

-- Story progression: loaded from content/scripts/story.lua
-- Each entry: { script = "module.path", conditions = { var = value, ... } }
-- Entries are consumed (marked played) once started.
local storySequence = {}
local storyPlayed = {} -- [index] = true for consumed entries

-- Load (or reload) the story sequence fresh
local function loadStory()
    package.loaded["content.scripts.story"] = nil
    storySequence = require("content.scripts.story")
    storyPlayed = {}
    dialogue.variables = {}
end

-- Find the first story entry whose conditions match current variables.
-- Returns the index and entry, or nil if nothing available.
-- Check a single condition value against a variable.
-- Simple value: exact equality     e.g. conditions = { match_won = true }
-- Comparison table: { op, value }  e.g. conditions = { wins = { ">=", 3 } }
-- Supported ops: "==", "~=", ">", ">=", "<", "<="
local function checkCondition(actual, expected)
    if type(expected) == "table" then
        local op, val = expected[1], expected[2]
        actual = actual or 0 -- treat nil as 0 for numeric comparisons
        if     op == "==" then return actual == val
        elseif op == "~=" then return actual ~= val
        elseif op == ">"  then return actual >  val
        elseif op == ">=" then return actual >= val
        elseif op == "<"  then return actual <  val
        elseif op == "<=" then return actual <= val
        end
        return false
    end
    return actual == expected
end

local function findNextScript()
    local vars = dialogue.variables
    for i, entry in ipairs(storySequence) do
        if not storyPlayed[i] then
            local match = true
            if entry.conditions then
                for key, expected in pairs(entry.conditions) do
                    if not checkCondition(vars[key], expected) then
                        match = false
                        break
                    end
                end
            end
            if match then
                return i, entry
            end
        end
    end
    return nil, nil
end

-- Try to start the next available dialogue script. Returns true if one was found.
local function tryStartNextDialogue()
    local idx, entry = findNextScript()
    if not idx then
        return false
    end
    storyPlayed[idx] = true
    -- Clear cached script module so it reloads fresh
    package.loaded[entry.script] = nil
    local script = require(entry.script)
    dialogue.start(script)
    gameState = "dialogue"
    return true
end

local function goToMenu()
    gameState = "menu"
end

local function startBilliards(opponentKey)
    local opponent = allOpponents[opponentKey]
    if not opponent then
        opponent = allOpponents.scarlett
    end
    billiards.start(opponent)
    gameState = "billiards"
end

-- Dialogue callback: script hit a "start_match" event
dialogue.onStartMatch = function(opponentKey)
    startBilliards(opponentKey)
end

-- Dialogue callback: script reached the end (no more events)
dialogue.onScriptEnd = function()
    if not tryStartNextDialogue() then
        goToMenu()
    end
end

-- Billiards callback: match ended
billiards.onMatchEnd = function(result)
    -- Set the match_won story variable
    dialogue.variables.match_won = (result == "win")

    -- Try to continue the story, otherwise go to menu
    if not tryStartNextDialogue() then
        goToMenu()
    end
end

local function drawMenu()
    local w, h = love.graphics.getDimensions()

    love.graphics.setColor(0.08, 0.08, 0.12)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local font = love.graphics.getFont()

    love.graphics.setColor(1, 1, 1)
    local title = "BILLIARDS"
    love.graphics.print(title, w / 2 - font:getWidth(title) / 2, h * 0.35)

    love.graphics.setColor(0.7, 0.7, 0.7)
    local sub = "Click or press SPACE to start"
    love.graphics.print(sub, w / 2 - font:getWidth(sub) / 2, h * 0.45)
end

function love.load()
    love.window.setTitle("Billiards")
    love.window.setMode(1920, 1080, {resizable = true})
    love.graphics.setBackgroundColor(0, 0, 0)

    billiards.load()
    vnui.load()
end

function love.update(dt)
    if gameState == "billiards" then
        billiards.update(dt)
    elseif gameState == "dialogue" then
        dialogue.update(dt)
        characters.update(dt)
    end
end

function love.draw()
    if gameState == "menu" then
        drawMenu()
    elseif gameState == "billiards" then
        billiards.draw()
    elseif gameState == "dialogue" then
        local w, h = love.graphics.getDimensions()
        characters.drawBackground(w, h)
        characters.draw(w, h)
        vnui.draw(dialogue.getState(), w, h)
    end
end

function love.mousepressed(x, y, button)
    if gameState == "menu" then
        if button == 1 then
            loadStory()
            if not tryStartNextDialogue() then
                -- No scripts available, nothing to do
            end
        end
    elseif gameState == "billiards" then
        billiards.mousepressed(x, y, button)
    elseif gameState == "dialogue" then
        local w, h = love.graphics.getDimensions()
        local handled = vnui.mousepressed(x, y, button, dialogue.getState(), w, h)
        if handled then
            dialogue.selectChoice(handled)
        else
            if button == 1 then
                dialogue.advance()
            end
        end
    end
end

function love.keypressed(key)
    if gameState == "billiards" then
        billiards.keypressed(key)
    elseif gameState == "dialogue" then
        if key == "space" or key == "return" then
            dialogue.advance()
        end
    elseif gameState == "menu" then
        if key == "space" or key == "return" then
            loadStory()
            if not tryStartNextDialogue() then
                -- No scripts available, nothing to do
            end
        end
    end

    if key == "escape" then
        love.event.quit()
    end
end
