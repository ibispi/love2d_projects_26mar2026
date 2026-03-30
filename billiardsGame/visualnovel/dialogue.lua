-- Dialogue system: reads script tables and drives progression
local characters = require("visualnovel.characters")

local M = {}

-- Callbacks set by main.lua
M.onStartMatch = nil
M.onScriptEnd = nil

-- Story variables: shared state that persists across scripts
M.variables = {}

local state = {
    script = nil,        -- the loaded script table
    index = 0,           -- current event index
    -- Current dialogue line display
    currentSpeaker = nil,    -- character key or nil
    currentText = "",        -- full text of current line
    displayedText = "",      -- text shown so far (typewriter)
    charTimer = 0,           -- typewriter timer
    textSpeed = 40,          -- characters per second
    textComplete = false,    -- has full text been revealed
    -- Choices
    choices = nil,           -- table of choice options, or nil
    -- Label index for fast lookup
    labelMap = {},
    -- Waiting for input
    waitingForInput = false,
}

local function buildLabelMap(script)
    local map = {}
    for i, event in ipairs(script) do
        if event.type == "label" then
            map[event.name] = i
        end
    end
    return map
end

local function processEvent()
    while state.index <= #state.script do
        local event = state.script[state.index]
        if not event then break end

        if event.type == "dialogue" then
            state.currentSpeaker = event.character
            state.currentText = event.text
            state.displayedText = ""
            state.charTimer = 0
            state.textComplete = false
            state.waitingForInput = true
            state.choices = nil
            -- Dim all, brighten speaker
            characters.setSpeaker(event.character)
            return

        elseif event.type == "choice" then
            state.choices = event.choices
            state.waitingForInput = true
            state.currentSpeaker = nil
            state.currentText = ""
            state.displayedText = ""
            state.textComplete = true
            return

        elseif event.type == "background" then
            characters.setBackground(event.image, event.color, event.label)
            state.index = state.index + 1

        elseif event.type == "show" then
            characters.show(event.character, event.position, event.expression)
            state.index = state.index + 1

        elseif event.type == "hide" then
            characters.hide(event.character)
            state.index = state.index + 1

        elseif event.type == "expression" then
            characters.setExpression(event.character, event.expression)
            state.index = state.index + 1

        elseif event.type == "label" then
            -- Labels are just markers, skip
            state.index = state.index + 1

        elseif event.type == "goto" then
            local target = state.labelMap[event.target]
            if target then
                state.index = target + 1 -- skip past the label itself
            else
                state.index = state.index + 1
            end

        elseif event.type == "set_var" then
            M.variables[event.name] = event.value
            state.index = state.index + 1

        elseif event.type == "add_var" then
            -- Increment (or decrement) a numeric variable by amount (default 1)
            local current = M.variables[event.name] or 0
            M.variables[event.name] = current + (event.amount or 1)
            state.index = state.index + 1

        elseif event.type == "start_match" then
            if M.onStartMatch then
                M.onStartMatch(event.opponent)
            end
            state.index = state.index + 1
            return

        else
            -- Unknown event, skip
            state.index = state.index + 1
        end
    end

    -- End of script reached
    state.waitingForInput = false
    state.choices = nil
    if M.onScriptEnd then
        M.onScriptEnd()
    end
end

function M.start(script)
    state.script = script
    state.index = 1
    state.labelMap = buildLabelMap(script)
    state.currentSpeaker = nil
    state.currentText = ""
    state.displayedText = ""
    state.charTimer = 0
    state.textComplete = false
    state.choices = nil
    state.waitingForInput = false
    characters.reset()
    processEvent()
end

function M.update(dt)
    -- Typewriter effect
    if not state.textComplete and #state.currentText > 0 then
        state.charTimer = state.charTimer + dt * state.textSpeed
        local charsToShow = math.floor(state.charTimer)
        if charsToShow >= #state.currentText then
            state.displayedText = state.currentText
            state.textComplete = true
        else
            state.displayedText = string.sub(state.currentText, 1, charsToShow)
        end
    end
end

function M.advance()
    if state.choices then
        -- Can't advance during choices, must click one
        return
    end

    if not state.textComplete then
        -- Complete the text instantly
        state.displayedText = state.currentText
        state.textComplete = true
        return
    end

    -- Move to next event
    state.index = state.index + 1
    state.waitingForInput = false
    processEvent()
end

function M.selectChoice(choiceIndex)
    if not state.choices then return end
    local choice = state.choices[choiceIndex]
    if not choice then return end

    local target = state.labelMap[choice.next]
    if target then
        state.index = target + 1
    else
        state.index = state.index + 1
    end
    state.choices = nil
    state.waitingForInput = false
    processEvent()
end

function M.getState()
    return state
end

return M
