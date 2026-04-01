-- Options menu UI
local settings = require("lib.settings")
local i18n = require("lib.i18n")
local fonts = require("lib.fonts")

local M = {}

local titleFont = nil
local sectionFont = nil
local labelFont = nil
local smallFont = nil

-- Layout
local SECTION_GAP = 18
local ROW_H = 44
local ROW_GAP = 6
local LEFT_COL = 0.18   -- label x as fraction of w
local RIGHT_COL = 0.48  -- control x as fraction of w
local CONTROL_W = 360

-- Scroll
local scrollY = 0
local contentHeight = 0

-- Which slider is being dragged (nil or {key=..., ...})
local dragging = nil

function M.load()
    titleFont   = fonts.get(36)
    sectionFont = fonts.get(24)
    labelFont   = fonts.get(20)
    smallFont   = fonts.get(16)
end

---------------------------------------------------------------------------
-- Row building helpers
---------------------------------------------------------------------------

local rows = {} -- rebuilt each frame

local function addSection(label)
    table.insert(rows, {type = "section", label = label})
end

local function addToggle(label, key)
    table.insert(rows, {type = "toggle", label = label, key = key})
end

local function addSelector(label, key, options, displayFn)
    table.insert(rows, {type = "selector", label = label, key = key, options = options, display = displayFn})
end

local function addSlider(label, key, min, max)
    table.insert(rows, {type = "slider", label = label, key = key, min = min, max = max})
end

local function buildRows()
    rows = {}

    -- Display
    addSection(i18n.t("Display"))
    addToggle(i18n.t("Fullscreen"), "fullscreen")
    addSelector(i18n.t("Resolution"), "resolutionIndex", settings.RESOLUTIONS, function(res)
        return string.format("%dx%d", res[1], res[2])
    end)

    -- Audio
    addSection(i18n.t("Audio"))
    addSlider(i18n.t("Volume"), "volume", 0, 1)
    addToggle(i18n.t("Mute"), "muted")

    -- Text
    addSection(i18n.t("Text"))
    addSelector(i18n.t("Text Speed"), "textSpeedIndex", settings.TEXT_SPEEDS, function(entry)
        return i18n.t(entry.label)
    end)
end

---------------------------------------------------------------------------
-- Geometry helpers
---------------------------------------------------------------------------

local function getBackRect(w, h)
    return {x = 20, y = 20, w = 100, h = 44}
end

local function isInside(mx, my, r)
    return mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
end

-- Get the y position for a given row index (1-based), accounting for section gaps
local function getRowY(index)
    local y = 110 -- start below title bar
    for i = 1, index - 1 do
        if rows[i].type == "section" then
            y = y + ROW_H + SECTION_GAP
        else
            y = y + ROW_H + ROW_GAP
        end
    end
    return y
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function drawButton(r, label, hover, font, enabled)
    if enabled == false then
        love.graphics.setColor(0.1, 0.1, 0.14, 0.5)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
        love.graphics.setColor(0.3, 0.3, 0.35)
    elseif hover then
        love.graphics.setColor(0.2, 0.25, 0.45, 0.9)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
        love.graphics.setColor(0.7, 0.75, 1, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 6, 6)
        love.graphics.setColor(1, 1, 1)
    else
        love.graphics.setColor(0.12, 0.14, 0.22, 0.85)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
        love.graphics.setColor(0.5, 0.5, 0.6, 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 6, 6)
        love.graphics.setColor(0.85, 0.85, 0.9)
    end
    love.graphics.setFont(font)
    love.graphics.print(label, r.x + r.w / 2 - font:getWidth(label) / 2, r.y + r.h / 2 - font:getHeight() / 2)
end

local function drawArrowButton(r, text, hover, enabled)
    if enabled == false then
        love.graphics.setColor(0.15, 0.15, 0.2, 0.4)
    elseif hover then
        love.graphics.setColor(0.3, 0.35, 0.55, 0.9)
    else
        love.graphics.setColor(0.18, 0.2, 0.3, 0.8)
    end
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 4, 4)

    if enabled == false then
        love.graphics.setColor(0.3, 0.3, 0.35)
    elseif hover then
        love.graphics.setColor(1, 1, 1)
    else
        love.graphics.setColor(0.7, 0.7, 0.8)
    end
    love.graphics.setFont(labelFont)
    love.graphics.print(text, r.x + r.w / 2 - labelFont:getWidth(text) / 2, r.y + r.h / 2 - labelFont:getHeight() / 2)
end

function M.draw(w, h)
    buildRows()

    -- Background
    love.graphics.setColor(0.06, 0.06, 0.1)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Title bar
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, w, 90)

    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 1, 1)
    local title = i18n.t("Options")
    love.graphics.print(title, w / 2 - titleFont:getWidth(title) / 2, 25)

    local mx, my = love.mouse.getPosition()

    -- Back button
    local back = getBackRect(w, h)
    drawButton(back, i18n.t("Back"), isInside(mx, my, back), labelFont)

    -- Clip and scroll content area
    love.graphics.setScissor(0, 90, w, h - 90)
    love.graphics.push()
    love.graphics.translate(0, -scrollY)

    local labelX = w * LEFT_COL
    local controlX = w * RIGHT_COL
    local arrowW = 36
    local arrowH = 34

    for i, row in ipairs(rows) do
        local y = getRowY(i)

        if row.type == "section" then
            love.graphics.setFont(sectionFont)
            love.graphics.setColor(0.6, 0.65, 0.85)
            love.graphics.print(row.label, labelX, y + 8)

            -- Divider line
            love.graphics.setColor(0.25, 0.25, 0.35)
            love.graphics.setLineWidth(1)
            love.graphics.line(labelX, y + ROW_H + 2, w - labelX, y + ROW_H + 2)

        elseif row.type == "toggle" then
            love.graphics.setFont(labelFont)
            love.graphics.setColor(0.85, 0.85, 0.9)
            love.graphics.print(row.label, labelX + 20, y + ROW_H / 2 - labelFont:getHeight() / 2)

            local val = settings.get(row.key)
            local toggleW = 70
            local toggleH = 32
            local toggleX = controlX
            local toggleY = y + ROW_H / 2 - toggleH / 2
            local toggleR = {x = toggleX, y = toggleY, w = toggleW, h = toggleH}
            local hover = isInside(mx, my + scrollY, toggleR)

            -- Track background
            if val then
                love.graphics.setColor(0.2, 0.5, 0.3, 0.9)
            else
                love.graphics.setColor(0.2, 0.2, 0.25, 0.9)
            end
            love.graphics.rectangle("fill", toggleX, toggleY, toggleW, toggleH, toggleH / 2, toggleH / 2)

            -- Border
            if hover then
                love.graphics.setColor(0.7, 0.75, 1, 0.6)
            else
                love.graphics.setColor(0.4, 0.4, 0.5, 0.4)
            end
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", toggleX, toggleY, toggleW, toggleH, toggleH / 2, toggleH / 2)

            -- Knob
            local knobR = toggleH / 2 - 4
            local knobX = val and (toggleX + toggleW - knobR - 6) or (toggleX + knobR + 6)
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("fill", knobX, toggleY + toggleH / 2, knobR)

            -- Label
            love.graphics.setFont(smallFont)
            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.print(val and i18n.t("On") or i18n.t("Off"), toggleX + toggleW + 12, y + ROW_H / 2 - smallFont:getHeight() / 2)

        elseif row.type == "selector" then
            love.graphics.setFont(labelFont)
            love.graphics.setColor(0.85, 0.85, 0.9)
            love.graphics.print(row.label, labelX + 20, y + ROW_H / 2 - labelFont:getHeight() / 2)

            local idx = settings.get(row.key) or 1
            local current = row.options[idx]
            local displayText = current and row.display(current) or "?"

            -- Left arrow
            local leftR = {x = controlX, y = y + ROW_H / 2 - arrowH / 2, w = arrowW, h = arrowH}
            local canLeft = idx > 1
            drawArrowButton(leftR, "<", canLeft and isInside(mx, my + scrollY, leftR), canLeft)

            -- Value text
            love.graphics.setFont(labelFont)
            love.graphics.setColor(1, 1, 1)
            local textX = controlX + arrowW + 10
            local textW = CONTROL_W - arrowW * 2 - 20
            love.graphics.print(displayText, textX + textW / 2 - labelFont:getWidth(displayText) / 2, y + ROW_H / 2 - labelFont:getHeight() / 2)

            -- Right arrow
            local rightR = {x = controlX + CONTROL_W - arrowW, y = y + ROW_H / 2 - arrowH / 2, w = arrowW, h = arrowH}
            local canRight = idx < #row.options
            drawArrowButton(rightR, ">", canRight and isInside(mx, my + scrollY, rightR), canRight)

        elseif row.type == "slider" then
            love.graphics.setFont(labelFont)
            love.graphics.setColor(0.85, 0.85, 0.9)
            love.graphics.print(row.label, labelX + 20, y + ROW_H / 2 - labelFont:getHeight() / 2)

            local val = settings.get(row.key) or 0
            local sliderX = controlX
            local sliderW = CONTROL_W - 60
            local sliderY = y + ROW_H / 2
            local barH = 6
            local knobR = 10

            -- Track
            love.graphics.setColor(0.2, 0.2, 0.25, 0.9)
            love.graphics.rectangle("fill", sliderX, sliderY - barH / 2, sliderW, barH, barH / 2, barH / 2)

            -- Fill
            local fillW = sliderW * val
            love.graphics.setColor(0.3, 0.45, 0.7, 0.9)
            love.graphics.rectangle("fill", sliderX, sliderY - barH / 2, fillW, barH, barH / 2, barH / 2)

            -- Knob
            local knobX = sliderX + fillW
            local knobRect = {x = knobX - knobR, y = sliderY - knobR, w = knobR * 2, h = knobR * 2}
            local hover = isInside(mx, my + scrollY, knobRect) or (dragging and dragging.key == row.key)
            love.graphics.setColor(hover and 1 or 0.85, hover and 1 or 0.85, 1)
            love.graphics.circle("fill", knobX, sliderY, knobR)

            -- Percentage text
            love.graphics.setFont(smallFont)
            love.graphics.setColor(0.7, 0.7, 0.8)
            love.graphics.print(string.format("%d%%", math.floor(val * 100 + 0.5)), sliderX + sliderW + 12, y + ROW_H / 2 - smallFont:getHeight() / 2)
        end
    end

    -- Track content height for scrolling
    if #rows > 0 then
        contentHeight = getRowY(#rows) + ROW_H + 40
    end

    love.graphics.pop()
    love.graphics.setScissor()
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function M.mousepressed(x, y, button, w, h)
    if button ~= 1 then return nil end

    -- Back button
    local back = getBackRect(w, h)
    if isInside(x, y, back) then
        return "back"
    end

    -- Adjust y for scroll
    local ay = y + scrollY

    local labelX = w * LEFT_COL
    local controlX = w * RIGHT_COL
    local arrowW = 36
    local arrowH = 34

    for i, row in ipairs(rows) do
        local ry = getRowY(i)

        if row.type == "toggle" then
            local toggleW = 70
            local toggleH = 32
            local toggleX = controlX
            local toggleY = ry + ROW_H / 2 - toggleH / 2
            local toggleR = {x = toggleX, y = toggleY, w = toggleW, h = toggleH}
            if isInside(x, ay, toggleR) then
                local val = settings.get(row.key)
                settings.set(row.key, not val)
                if row.key == "fullscreen" or row.key == "resolutionIndex" then
                    settings.applyDisplay()
                end
                return "changed"
            end

        elseif row.type == "selector" then
            local idx = settings.get(row.key) or 1

            local leftR = {x = controlX, y = ry + ROW_H / 2 - arrowH / 2, w = arrowW, h = arrowH}
            if idx > 1 and isInside(x, ay, leftR) then
                settings.set(row.key, idx - 1)
                if row.key == "resolutionIndex" then
                    settings.applyDisplay()
                end
                return "changed"
            end

            local rightR = {x = controlX + CONTROL_W - arrowW, y = ry + ROW_H / 2 - arrowH / 2, w = arrowW, h = arrowH}
            if idx < #row.options and isInside(x, ay, rightR) then
                settings.set(row.key, idx + 1)
                if row.key == "resolutionIndex" then
                    settings.applyDisplay()
                end
                return "changed"
            end

        elseif row.type == "slider" then
            local sliderX = controlX
            local sliderW = CONTROL_W - 60
            local sliderY = ry + ROW_H / 2
            local hitH = 20

            local sliderRect = {x = sliderX, y = sliderY - hitH, w = sliderW, h = hitH * 2}
            if isInside(x, ay, sliderRect) then
                dragging = {key = row.key, sliderX = sliderX, sliderW = sliderW, min = row.min, max = row.max}
                local t = math.max(0, math.min(1, (x - sliderX) / sliderW))
                local val = row.min + t * (row.max - row.min)
                settings.set(row.key, val)
                return "changed"
            end
        end
    end

    return nil
end

function M.mousereleased(x, y, button)
    if button == 1 then
        dragging = nil
    end
end

function M.mousemoved(x, y)
    if dragging then
        local t = math.max(0, math.min(1, (x - dragging.sliderX) / dragging.sliderW))
        local val = dragging.min + t * (dragging.max - dragging.min)
        settings.set(dragging.key, val)
    end
end

function M.wheelmoved(wx, wy)
    local maxScroll = math.max(0, contentHeight - love.graphics.getHeight() + 90)
    scrollY = math.max(0, math.min(maxScroll, scrollY - wy * 40))
end

function M.keypressed(key)
    if key == "escape" or key == "backspace" then
        return "back"
    end
    return "consumed"
end

function M.reset()
    scrollY = 0
    dragging = nil
    buildRows()
end

return M
