-- Main entry point — game state manager
-- States: menu, dialogue, billiards, gallery, loadscreen, options

local billiards = require("billiards.app")
local dialogue = require("visualnovel.dialogue")
local vnui = require("visualnovel.ui")
local characters = require("visualnovel.characters")
local gallery = require("visualnovel.gallery")
local loadscreen = require("visualnovel.loadscreen")
local optionsMenu = require("options")
local save = require("lib.save")
local settings = require("lib.settings")
local allOpponents = require("content.scripts.opponents")

local gameState = "menu" -- "menu", "dialogue", "billiards", "gallery", "loadscreen", "options"

-- Story progression: loaded from content/scripts/story.lua
-- Each entry: { script = "module.path", conditions = { var = value, ... } }
-- Entries are consumed (marked played) once started.
local storySequence = {}
local storyPlayed = {} -- [index] = true for consumed entries

-- Deep-copy a table so we get a fresh set of defaults each time
local function copyDefaults(t)
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = copyDefaults(v)
        else
            copy[k] = v
        end
    end
    return copy
end

-- Load (or reload) the story sequence fresh
local function loadStory()
    package.loaded["content.scripts.story"] = nil
    package.loaded["content.scripts.variables"] = nil
    storySequence = require("content.scripts.story")
    storyPlayed = {}
    dialogue.variables = copyDefaults(require("content.scripts.variables"))
end

-- Check a single condition value against a variable.
local function checkCondition(actual, expected)
    if type(expected) == "table" then
        local op, val = expected[1], expected[2]
        actual = actual or 0
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
    package.loaded[entry.script] = nil
    local script = require(entry.script)
    dialogue.start(script, entry.script)
    gameState = "dialogue"
    return true
end

-- Forward declaration
local updateContinueButton

local function goToMenu()
    gameState = "menu"
    updateContinueButton()
end

local function startBilliards(opponentKey)
    local opponent = allOpponents[opponentKey]
    if not opponent then
        opponent = allOpponents.scarlett
    end
    billiards.start(opponent)
    gameState = "billiards"
end

-- Load a checkpoint by index
local function loadCheckpoint(cpIndex)
    local cp = save.getCheckpoint(cpIndex)
    if not cp then return end

    -- Reload story sequence
    package.loaded["content.scripts.story"] = nil
    storySequence = require("content.scripts.story")

    -- Restore story variables
    dialogue.variables = copyDefaults(cp.variables or {})

    -- Restore storyPlayed
    storyPlayed = {}
    if cp.storyPlayed then
        for k, v in pairs(cp.storyPlayed) do
            storyPlayed[k] = v
        end
    end

    -- Load the script and resume from checkpoint index
    local scriptModule = cp.scriptModule
    package.loaded[scriptModule] = nil
    local script = require(scriptModule)
    dialogue.resume(script, scriptModule, cp.eventIndex)
    gameState = "dialogue"
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

-- Dialogue callback: checkpoint reached — save game state
dialogue.onCheckpoint = function(label)
    save.saveCheckpoint(
        label,
        dialogue.currentScriptModule,
        dialogue.getIndex(),
        dialogue.variables,
        storyPlayed
    )
end

-- Billiards callback: match ended
billiards.onMatchEnd = function(result)
    dialogue.variables.match_won = (result == "win")

    if not tryStartNextDialogue() then
        goToMenu()
    end
end

-- Main menu
local menuFont = nil
local titleFont = nil

local menuButtons = {
    { label = "New Game",  enabled = true,  action = "new_game" },
    { label = "Continue",  enabled = true,  action = "continue" },
    { label = "Options",   enabled = true,  action = "options" },
    { label = "Gallery",   enabled = true,  action = "gallery" },
    { label = "Quit",      enabled = true,  action = "quit" },
}

local menuSelectedIndex = 1

updateContinueButton = function()
    menuButtons[2].enabled = save.hasCheckpoints()
end

local function getMenuButtonRects(w, h)
    local btnW = 320
    local btnH = 54
    local gap = 14
    local count = #menuButtons
    local totalH = count * btnH + (count - 1) * gap
    local startY = h * 0.48
    local startX = w / 2 - btnW / 2

    local rects = {}
    for i = 1, count do
        rects[i] = {
            x = startX,
            y = startY + (i - 1) * (btnH + gap),
            w = btnW,
            h = btnH,
        }
    end
    return rects
end

local function executeMenuAction(action)
    if action == "new_game" then
        loadStory()
        tryStartNextDialogue()
    elseif action == "options" then
        optionsMenu.reset()
        gameState = "options"
    elseif action == "continue" then
        loadscreen.reset()
        gameState = "loadscreen"
    elseif action == "gallery" then
        gallery.reset()
        gameState = "gallery"
    elseif action == "quit" then
        love.event.quit()
    end
end

local function menuMousepressed(x, y, button)
    if button ~= 1 then return end
    local w, h = love.graphics.getDimensions()
    local rects = getMenuButtonRects(w, h)
    for i, r in ipairs(rects) do
        if menuButtons[i].enabled then
            if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
                executeMenuAction(menuButtons[i].action)
                return
            end
        end
    end
end

local function menuKeypressed(key)
    if key == "up" then
        repeat
            menuSelectedIndex = menuSelectedIndex - 1
            if menuSelectedIndex < 1 then menuSelectedIndex = #menuButtons end
        until menuButtons[menuSelectedIndex].enabled
    elseif key == "down" then
        repeat
            menuSelectedIndex = menuSelectedIndex + 1
            if menuSelectedIndex > #menuButtons then menuSelectedIndex = 1 end
        until menuButtons[menuSelectedIndex].enabled
    elseif key == "return" or key == "space" then
        executeMenuAction(menuButtons[menuSelectedIndex].action)
    end
end

local function drawMenu()
    local w, h = love.graphics.getDimensions()

    love.graphics.setColor(0.06, 0.06, 0.1)
    love.graphics.rectangle("fill", 0, 0, w, h)

    if titleFont then love.graphics.setFont(titleFont) end
    love.graphics.setColor(1, 1, 1)
    local title = "BILLIARDS"
    local tf = love.graphics.getFont()
    love.graphics.print(title, w / 2 - tf:getWidth(title) / 2, h * 0.15)

    if menuFont then love.graphics.setFont(menuFont) end
    love.graphics.setColor(0.5, 0.5, 0.6)
    local sub = "A Pool Roguelike"
    local mf = love.graphics.getFont()
    love.graphics.print(sub, w / 2 - mf:getWidth(sub) / 2, h * 0.15 + tf:getHeight() + 10)

    local rects = getMenuButtonRects(w, h)
    local mx, my = love.mouse.getPosition()

    for i, btn in ipairs(menuButtons) do
        local r = rects[i]
        local hover = btn.enabled and mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
        local selected = (i == menuSelectedIndex)

        if not btn.enabled then
            love.graphics.setColor(0.12, 0.12, 0.18, 0.6)
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 8, 8)
            love.graphics.setColor(0.3, 0.3, 0.35, 0.6)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 8, 8)
            love.graphics.setColor(0.35, 0.35, 0.4)
        elseif hover or selected then
            love.graphics.setColor(0.2, 0.25, 0.45, 0.9)
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 8, 8)
            love.graphics.setColor(0.7, 0.75, 1, 0.8)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 8, 8)
            love.graphics.setColor(1, 1, 1)
        else
            love.graphics.setColor(0.12, 0.14, 0.22, 0.85)
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 8, 8)
            love.graphics.setColor(0.5, 0.5, 0.6, 0.5)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 8, 8)
            love.graphics.setColor(0.85, 0.85, 0.9)
        end

        if menuFont then love.graphics.setFont(menuFont) end
        local f = love.graphics.getFont()
        love.graphics.print(btn.label, r.x + r.w / 2 - f:getWidth(btn.label) / 2, r.y + r.h / 2 - f:getHeight() / 2)
    end
end

function love.load()
    love.window.setTitle("Billiards")
    love.graphics.setBackgroundColor(0, 0, 0)

    settings.load()
    settings.applyDisplay()

    titleFont = love.graphics.newFont(64)
    menuFont = love.graphics.newFont(28)

    save.load()
    billiards.load()
    vnui.load()
    gallery.load()
    loadscreen.load()
    optionsMenu.load()
    updateContinueButton()
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
    elseif gameState == "gallery" then
        local w, h = love.graphics.getDimensions()
        gallery.draw(w, h)
    elseif gameState == "loadscreen" then
        local w, h = love.graphics.getDimensions()
        loadscreen.draw(w, h)
    elseif gameState == "options" then
        local w, h = love.graphics.getDimensions()
        optionsMenu.draw(w, h)
    end
end

function love.mousepressed(x, y, button)
    if gameState == "menu" then
        menuMousepressed(x, y, button)
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
    elseif gameState == "gallery" then
        local w, h = love.graphics.getDimensions()
        local result = gallery.mousepressed(x, y, button, w, h)
        if result == "back" then
            goToMenu()
        end
    elseif gameState == "loadscreen" then
        local w, h = love.graphics.getDimensions()
        local result = loadscreen.mousepressed(x, y, button, w, h)
        if result == "back" then
            goToMenu()
        elseif result == "load" then
            loadCheckpoint(loadscreen.getSelectedIndex())
        end
    elseif gameState == "options" then
        local w, h = love.graphics.getDimensions()
        local result = optionsMenu.mousepressed(x, y, button, w, h)
        if result == "back" then
            goToMenu()
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
        menuKeypressed(key)
    elseif gameState == "gallery" then
        local result = gallery.keypressed(key)
        if result == "back" then
            goToMenu()
            return
        end
    elseif gameState == "loadscreen" then
        local result = loadscreen.keypressed(key)
        if result == "back" then
            goToMenu()
            return
        elseif result == "load" then
            loadCheckpoint(loadscreen.getSelectedIndex())
            return
        end
    elseif gameState == "options" then
        local result = optionsMenu.keypressed(key)
        if result == "back" then
            goToMenu()
            return
        end
    end

    if key == "escape" then
        if gameState == "menu" then
            love.event.quit()
        elseif gameState ~= "gallery" and gameState ~= "loadscreen" and gameState ~= "options" then
            goToMenu()
        end
    end
end

function love.mousereleased(x, y, button)
    if gameState == "options" then
        optionsMenu.mousereleased(x, y, button)
    end
end

function love.mousemoved(x, y)
    if gameState == "options" then
        optionsMenu.mousemoved(x, y)
    end
end

function love.wheelmoved(wx, wy)
    if gameState == "options" then
        optionsMenu.wheelmoved(wx, wy)
    end
end
