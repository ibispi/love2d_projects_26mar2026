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
local i18n = require("lib.i18n")
local fonts = require("lib.fonts")
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
    langSelectorOpen = false
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
local langFont = nil

local menuButtons = {
    { label = "New Game",  enabled = true,  action = "new_game" },
    { label = "Continue",  enabled = true,  action = "continue" },
    { label = "Options",   enabled = true,  action = "options" },
    { label = "Gallery",   enabled = true,  action = "gallery" },
    { label = "Quit",      enabled = true,  action = "quit" },
}

local menuSelectedIndex = 1
local langSelectorOpen = false  -- is the language popup open?

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

-- Language selector geometry helpers
local FLAG_SIZE = 40       -- flag icon size in menu corner
local FLAG_GAP = 10        -- gap between flags in popup
local FLAG_POPUP_PAD = 12  -- padding inside popup

local function getLangButtonRect(w, h)
    return { x = w - FLAG_SIZE - 20, y = 20, w = FLAG_SIZE, h = FLAG_SIZE }
end

local function getLangPopupRects(w, h)
    local langs = i18n.getLanguages()
    local count = #langs
    local popupW = count * (FLAG_SIZE + FLAG_GAP) - FLAG_GAP + FLAG_POPUP_PAD * 2
    local popupH = FLAG_SIZE + FLAG_POPUP_PAD * 2
    local popupX = w - popupW - 20
    local popupY = 20 + FLAG_SIZE + 8

    local rects = {}
    for i, lang in ipairs(langs) do
        rects[i] = {
            x = popupX + FLAG_POPUP_PAD + (i - 1) * (FLAG_SIZE + FLAG_GAP),
            y = popupY + FLAG_POPUP_PAD,
            w = FLAG_SIZE,
            h = FLAG_SIZE,
            code = lang.code,
            name = lang.name,
        }
    end
    return { x = popupX, y = popupY, w = popupW, h = popupH }, rects
end

local function menuMousepressed(x, y, button)
    if button ~= 1 then return end
    local w, h = love.graphics.getDimensions()

    -- Language popup clicks (check first if open)
    if langSelectorOpen then
        local popupRect, flagRects = getLangPopupRects(w, h)
        for _, fr in ipairs(flagRects) do
            if x >= fr.x and x <= fr.x + fr.w and y >= fr.y and y <= fr.y + fr.h then
                i18n.setLanguage(fr.code)
                settings.set("language", fr.code)
                langSelectorOpen = false
                return
            end
        end
        -- Click outside popup closes it
        langSelectorOpen = false
        return
    end

    -- Language flag button
    local langBtn = getLangButtonRect(w, h)
    if x >= langBtn.x - 4 and x <= langBtn.x + langBtn.w + 4 and y >= langBtn.y - 4 and y <= langBtn.y + langBtn.h + 4 then
        langSelectorOpen = not langSelectorOpen
        return
    end

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
    local sub = i18n.t("A Pool Roguelike")
    local mf = love.graphics.getFont()
    love.graphics.print(sub, w / 2 - mf:getWidth(sub) / 2, h * 0.15 + tf:getHeight() + 10)

    local rects = getMenuButtonRects(w, h)
    local mx, my = love.mouse.getPosition()

    for i, btn in ipairs(menuButtons) do
        local r = rects[i]
        local hover = btn.enabled and mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
        local selected = (i == menuSelectedIndex)
        local displayLabel = i18n.t(btn.label)

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
        love.graphics.print(displayLabel, r.x + r.w / 2 - f:getWidth(displayLabel) / 2, r.y + r.h / 2 - f:getHeight() / 2)
    end

    -- Language flag button (top-right corner)
    local langBtn = getLangButtonRect(w, h)
    local langHover = mx >= langBtn.x and mx <= langBtn.x + langBtn.w and my >= langBtn.y and my <= langBtn.y + langBtn.h
    local currentFlag = i18n.getCurrentFlag()

    -- Button background
    love.graphics.setColor(langHover and 0.25 or 0.15, langHover and 0.28 or 0.17, langHover and 0.45 or 0.28, 0.9)
    love.graphics.rectangle("fill", langBtn.x - 4, langBtn.y - 4, langBtn.w + 8, langBtn.h + 8, 6, 6)
    love.graphics.setColor(1, 1, 1, langHover and 0.7 or 0.4)
    love.graphics.setLineWidth(langHover and 2 or 1)
    love.graphics.rectangle("line", langBtn.x - 4, langBtn.y - 4, langBtn.w + 8, langBtn.h + 8, 6, 6)

    if currentFlag then
        local iw, ih = currentFlag:getDimensions()
        local scale = math.min(langBtn.w / iw, langBtn.h / ih)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(currentFlag, langBtn.x + (langBtn.w - iw * scale) / 2, langBtn.y + (langBtn.h - ih * scale) / 2, 0, scale, scale)
    else
        love.graphics.setColor(1, 1, 1, 0.6)
        if langFont then love.graphics.setFont(langFont) end
        local code = i18n.getLanguageCode()
        love.graphics.print(code, langBtn.x + 4, langBtn.y + 8)
    end

    -- Language popup
    if langSelectorOpen then
        local popupRect, flagRects = getLangPopupRects(w, h)

        -- Popup background
        love.graphics.setColor(0.08, 0.08, 0.14, 0.95)
        love.graphics.rectangle("fill", popupRect.x, popupRect.y, popupRect.w, popupRect.h, 8, 8)
        love.graphics.setColor(0.5, 0.5, 0.65, 0.6)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", popupRect.x, popupRect.y, popupRect.w, popupRect.h, 8, 8)

        local currentCode = i18n.getLanguageCode()

        for _, fr in ipairs(flagRects) do
            local fHover = mx >= fr.x and mx <= fr.x + fr.w and my >= fr.y and my <= fr.y + fr.h
            local isActive = (fr.code == currentCode)

            -- Highlight border for active/hovered
            if isActive then
                love.graphics.setColor(0.4, 0.5, 0.9, 0.8)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", fr.x - 3, fr.y - 3, fr.w + 6, fr.h + 6, 4, 4)
            elseif fHover then
                love.graphics.setColor(0.6, 0.65, 0.9, 0.5)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", fr.x - 3, fr.y - 3, fr.w + 6, fr.h + 6, 4, 4)
            end

            -- Draw flag
            local flagImg = i18n.getFlag(fr.code)
            if flagImg then
                local iw, ih = flagImg:getDimensions()
                local scale = math.min(fr.w / iw, fr.h / ih)
                love.graphics.setColor(1, 1, 1, (fHover or isActive) and 1 or 0.7)
                love.graphics.draw(flagImg, fr.x + (fr.w - iw * scale) / 2, fr.y + (fr.h - ih * scale) / 2, 0, scale, scale)
            else
                love.graphics.setColor(0.3, 0.3, 0.4)
                love.graphics.rectangle("fill", fr.x, fr.y, fr.w, fr.h, 4, 4)
                love.graphics.setColor(1, 1, 1, 0.5)
                if langFont then love.graphics.setFont(langFont) end
                love.graphics.print(fr.code, fr.x + 4, fr.y + 10)
            end

            -- Tooltip with language name on hover
            if fHover then
                love.graphics.setColor(0, 0, 0, 0.85)
                if langFont then love.graphics.setFont(langFont) end
                local nameW = langFont:getWidth(fr.name)
                local tipX = fr.x + fr.w / 2 - nameW / 2 - 6
                local tipY = fr.y + fr.h + 6
                love.graphics.rectangle("fill", tipX, tipY, nameW + 12, langFont:getHeight() + 8, 4, 4)
                love.graphics.setColor(1, 1, 1)
                love.graphics.print(fr.name, tipX + 6, tipY + 4)
            end
        end
    end
end

function love.load()
    love.window.setTitle("Billiards")
    love.graphics.setBackgroundColor(0, 0, 0)

    settings.load()
    settings.applyDisplay()

    i18n.load()
    i18n.setLanguage(settings.get("language") or "en")

    titleFont = fonts.get(64)
    menuFont = fonts.get(28)
    langFont = fonts.get(16)

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
