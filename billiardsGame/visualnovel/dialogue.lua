-- Dialogue system: reads script tables and drives progression
local characters = require("visualnovel.characters")
local save = require("lib.save")

local M = {}

-- Callbacks set by main.lua
M.onStartMatch = nil
M.onScriptEnd = nil
M.onCheckpoint = nil  -- called with (label) when a checkpoint is hit

-- Story variables: shared state that persists across scripts
M.variables = {}

-- Track the current script module path (for save/load)
M.currentScriptModule = nil

-- When true, we're replaying events silently (no typewriter, no waiting)
local replaying = false

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
            if replaying then
                -- During replay, skip dialogue without waiting
                -- But still set the speaker so character state is correct
                characters.setSpeaker(event.character)
                state.index = state.index + 1
            else
                state.currentSpeaker = event.character
                state.currentText = event.text
                state.displayedText = ""
                state.charTimer = 0
                state.textComplete = false
                state.waitingForInput = true
                state.choices = nil
                characters.setSpeaker(event.character)
                return
            end

        elseif event.type == "choice" then
            if replaying then
                -- Choices can't be replayed (they require input)
                -- This shouldn't happen if checkpoints are placed well
                state.index = state.index + 1
            else
                state.choices = event.choices
                state.waitingForInput = true
                state.currentSpeaker = nil
                state.currentText = ""
                state.displayedText = ""
                state.textComplete = true
                return
            end

        elseif event.type == "background" then
            characters.setBackground(event.image, event.color, event.label)
            state.index = state.index + 1

        elseif event.type == "show" then
            characters.show(event.character, event.position, event.expression)
            -- During replay, make characters appear instantly
            if replaying then
                characters.snapOpacity(event.character)
            end
            state.index = state.index + 1

        elseif event.type == "hide" then
            characters.hide(event.character)
            if replaying then
                characters.removeInstantly(event.character)
            end
            state.index = state.index + 1

        elseif event.type == "expression" then
            characters.setExpression(event.character, event.expression)
            state.index = state.index + 1

        elseif event.type == "label" then
            state.index = state.index + 1

        elseif event.type == "goto" then
            local target = state.labelMap[event.target]
            if target then
                state.index = target + 1
            else
                state.index = state.index + 1
            end

        elseif event.type == "set_var" then
            M.variables[event.name] = event.value
            state.index = state.index + 1

        elseif event.type == "add_var" then
            local current = M.variables[event.name] or 0
            M.variables[event.name] = current + (event.amount or 1)
            state.index = state.index + 1

        elseif event.type == "unlock_gallery" then
            save.unlockGallery(event.index)
            state.index = state.index + 1

        elseif event.type == "checkpoint" then
            if not replaying then
                -- Fire the checkpoint callback (main.lua will save)
                if M.onCheckpoint then
                    M.onCheckpoint(event.label or "Checkpoint")
                end
            end
            state.index = state.index + 1

        elseif event.type == "start_match" then
            if replaying then
                -- During replay, skip match starts
                state.index = state.index + 1
            else
                if M.onStartMatch then
                    M.onStartMatch(event.opponent)
                end
                state.index = state.index + 1
                return
            end

        else
            state.index = state.index + 1
        end
    end

    -- End of script reached
    state.waitingForInput = false
    state.choices = nil
    if not replaying then
        if M.onScriptEnd then
            M.onScriptEnd()
        end
    end
end

function M.start(script, scriptModule)
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
    M.currentScriptModule = scriptModule
    replaying = false
    characters.reset()
    processEvent()
end

-- Resume from a checkpoint: replay events 1..targetIndex silently, then continue normally
function M.resume(script, scriptModule, targetIndex)
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
    M.currentScriptModule = scriptModule
    characters.reset()

    -- Replay silently up to the target index
    replaying = true
    while state.index < targetIndex and state.index <= #state.script do
        processEvent()
        -- processEvent may have stopped at a dialogue/choice during replay,
        -- but since replaying=true it should skip them. If somehow stuck, break.
        if state.waitingForInput then
            state.waitingForInput = false
            state.index = state.index + 1
        end
    end
    replaying = false

    -- Now process events normally from the target index
    state.index = targetIndex
    processEvent()
end

function M.getIndex()
    return state.index
end

function M.update(dt)
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
        return
    end

    if not state.textComplete then
        state.displayedText = state.currentText
        state.textComplete = true
        return
    end

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
