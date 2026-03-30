-- Main entry point — game state manager
-- States: menu, dialogue, billiards

local billiards = require("billiards.app")
local dialogue = require("visualnovel.dialogue")
local vnui = require("visualnovel.ui")
local characters = require("visualnovel.characters")
local allOpponents = require("scripts.opponents")

local gameState = "menu" -- "menu", "dialogue", "billiards"

-- Story progression: list of script files to play through
local storySequence = {
    "scripts.test_scene",
}
local storyIndex = 1
local currentScript = nil
local lastMatchResult = nil

-- Forward declarations
local function startDialogue(scriptModule)
    currentScript = require(scriptModule)
    dialogue.start(currentScript)
    gameState = "dialogue"
end

local function startBilliards(opponentKey)
    local opponent = allOpponents[opponentKey]
    if not opponent then
        opponent = allOpponents.scarlett
    end
    billiards.start(opponent)
    gameState = "billiards"
end

-- Dialogue system callback when it hits a "start_match" event
dialogue.onStartMatch = function(opponentKey)
    startBilliards(opponentKey)
end

-- Billiards callback when a match ends
billiards.onMatchEnd = function(result)
    lastMatchResult = result
    -- Advance story
    storyIndex = storyIndex + 1
    if storyIndex <= #storySequence then
        startDialogue(storySequence[storyIndex])
    else
        -- No more scripts, go back to menu
        gameState = "menu"
        storyIndex = 1
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
            storyIndex = 1
            -- Clear any cached scripts so they reload fresh
            for _, mod in ipairs(storySequence) do
                package.loaded[mod] = nil
            end
            startDialogue(storySequence[storyIndex])
        end
    elseif gameState == "billiards" then
        billiards.mousepressed(x, y, button)
    elseif gameState == "dialogue" then
        local w, h = love.graphics.getDimensions()
        local handled = vnui.mousepressed(x, y, button, dialogue.getState(), w, h)
        if handled then
            -- Choice was clicked, tell dialogue system
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
            storyIndex = 1
            for _, mod in ipairs(storySequence) do
                package.loaded[mod] = nil
            end
            startDialogue(storySequence[storyIndex])
        end
    end

    if key == "escape" then
        love.event.quit()
    end
end
