-- Visual novel UI: text box, name plate, choice buttons
local M = {}

local font = nil

-- Character display name lookup
local displayNames = {
    scarlett = "Scarlett",
    marina = "Marina",
    diana = "Diana",
    player = "You",
}

function M.load()
    -- Use default font at a larger size for readability
    font = love.graphics.newFont(24)
end

local function getDisplayName(charKey)
    return displayNames[charKey] or charKey
end

local function drawTextBox(state, w, h)
    if not state.waitingForInput then return end
    if state.choices then return end -- choices have their own display

    local boxH = h * 0.25
    local boxY = h - boxH
    local boxPad = 30
    local textX = boxPad + 20
    local textY = boxY + 50
    local textW = w - textX * 2

    -- Semi-transparent dark box
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, boxY, w, boxH)

    -- Top border line
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.line(0, boxY, w, boxY)

    -- Name plate
    if state.currentSpeaker then
        local name = getDisplayName(state.currentSpeaker)
        local nameW = font:getWidth(name) + 30
        local nameH = 36
        local nameX = boxPad
        local nameY = boxY - nameH + 4

        love.graphics.setColor(0.15, 0.15, 0.25, 0.9)
        love.graphics.rectangle("fill", nameX, nameY, nameW, nameH, 6, 6)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", nameX, nameY, nameW, nameH, 6, 6)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(font)
        love.graphics.print(name, nameX + 15, nameY + nameH / 2 - font:getHeight() / 2)
    end

    -- Dialogue text (with word wrapping)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(font)
    love.graphics.printf(state.displayedText, textX, textY, textW, "left")

    -- Advance indicator (blinking triangle)
    if state.textComplete then
        local blink = math.floor(love.timer.getTime() * 2) % 2
        if blink == 0 then
            love.graphics.setColor(1, 1, 1, 0.7)
            local triX = w - 60
            local triY = h - 40
            love.graphics.polygon("fill", triX, triY, triX + 12, triY + 10, triX - 12, triY + 10)
        end
    end
end

local function getChoiceRects(choices, w, h)
    local btnW = w * 0.4
    local btnH = 50
    local gap = 15
    local totalH = #choices * btnH + (#choices - 1) * gap
    local startY = h * 0.4 - totalH / 2
    local startX = w / 2 - btnW / 2

    local rects = {}
    for i = 1, #choices do
        rects[i] = {
            x = startX,
            y = startY + (i - 1) * (btnH + gap),
            w = btnW,
            h = btnH,
        }
    end
    return rects
end

local function drawChoices(state, w, h)
    if not state.choices then return end

    local rects = getChoiceRects(state.choices, w, h)
    local mx, my = love.mouse.getPosition()

    for i, choice in ipairs(state.choices) do
        local r = rects[i]
        local hover = mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h

        -- Button background
        if hover then
            love.graphics.setColor(0.25, 0.3, 0.5, 0.9)
        else
            love.graphics.setColor(0.1, 0.12, 0.2, 0.85)
        end
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 8, 8)

        -- Border
        love.graphics.setColor(1, 1, 1, hover and 0.6 or 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 8, 8)

        -- Text
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(font)
        love.graphics.print(choice.text, r.x + 20, r.y + r.h / 2 - font:getHeight() / 2)
    end
end

function M.draw(state, w, h)
    if not state then return end
    drawTextBox(state, w, h)
    drawChoices(state, w, h)
end

-- Returns choice index if a choice button was clicked, nil otherwise
function M.mousepressed(x, y, button, state, w, h)
    if button ~= 1 then return nil end
    if not state or not state.choices then return nil end

    local rects = getChoiceRects(state.choices, w, h)
    for i, r in ipairs(rects) do
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
            return i
        end
    end
    return nil
end

return M
