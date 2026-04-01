-- Load screen UI: paged list of saved checkpoints
local save = require("lib.save")
local i18n = require("lib.i18n")
local fonts = require("lib.fonts")

local M = {}

local currentPage = 1
local selectedIndex = 0  -- global checkpoint index (1-based), 0 = none
local gridFont = nil
local titleFont = nil
local smallFont = nil

-- Layout constants
local SLOTS_PER_PAGE = 6
local SLOT_PAD = 40
local SLOT_GAP = 12
local SLOT_TOP = 100
local SLOT_BOTTOM = 80

function M.load()
    gridFont = fonts.get(20)
    titleFont = fonts.get(36)
    smallFont = fonts.get(16)
end

local function totalPages()
    return math.max(1, math.ceil(save.getCheckpointCount() / SLOTS_PER_PAGE))
end

-- Open the load screen, auto-select last checkpoint on last page
function M.reset()
    local count = save.getCheckpointCount()
    if count > 0 then
        currentPage = totalPages()
        selectedIndex = count -- select the last one
    else
        currentPage = 1
        selectedIndex = 0
    end
end

-- Get the checkpoint indices on the current page
local function getPageIndices()
    local count = save.getCheckpointCount()
    local startIdx = (currentPage - 1) * SLOTS_PER_PAGE + 1
    local endIdx = math.min(startIdx + SLOTS_PER_PAGE - 1, count)
    local indices = {}
    for i = startIdx, endIdx do
        table.insert(indices, i)
    end
    return indices
end

-- Slot rects for current page
local function getSlotRects(w, h)
    local slotW = w * 0.6
    local slotH = 70
    local startX = w / 2 - slotW / 2
    local indices = getPageIndices()

    local rects = {}
    for slot, cpIdx in ipairs(indices) do
        rects[cpIdx] = {
            x = startX,
            y = SLOT_TOP + (slot - 1) * (slotH + SLOT_GAP),
            w = slotW,
            h = slotH,
        }
    end
    return rects
end

local function getPageArrowRects(w, h)
    local arrowW = 50
    local arrowH = 44
    local gap = 20
    local centerX = w / 2
    local y = h - SLOT_BOTTOM + (SLOT_BOTTOM - arrowH) / 2
    return {
        left = { x = centerX - arrowW - gap, y = y, w = arrowW, h = arrowH },
        right = { x = centerX + gap, y = y, w = arrowW, h = arrowH },
    }
end

local function getBackRect(w, h)
    return { x = 20, y = 20, w = 100, h = 44 }
end

local function getLoadRect(w, h)
    return { x = w - 180, y = 20, w = 150, h = 44 }
end

local function isInside(mx, my, r)
    return mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
end

local function drawButton(r, label, hover, font, enabled)
    if enabled == false then
        love.graphics.setColor(0.1, 0.1, 0.14, 0.5)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
        love.graphics.setColor(0.25, 0.25, 0.3, 0.4)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 6, 6)
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

local function formatTimestamp(ts)
    if not ts then return "" end
    return os.date("%Y-%m-%d %H:%M", ts)
end

function M.draw(w, h)
    -- Background
    love.graphics.setColor(0.06, 0.06, 0.1)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Title bar
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, w, SLOT_TOP - 10)

    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 1, 1)
    local title = i18n.t("Load Game")
    love.graphics.print(title, w / 2 - titleFont:getWidth(title) / 2, 25)

    local mx, my = love.mouse.getPosition()

    -- Back button
    local back = getBackRect(w, h)
    drawButton(back, i18n.t("Back"), isInside(mx, my, back), gridFont)

    -- Load button
    local loadBtn = getLoadRect(w, h)
    local canLoad = selectedIndex > 0
    drawButton(loadBtn, i18n.t("Load"), canLoad and isInside(mx, my, loadBtn), gridFont, canLoad)

    -- Save slots
    local count = save.getCheckpointCount()
    if count == 0 then
        love.graphics.setFont(gridFont)
        love.graphics.setColor(0.4, 0.4, 0.5)
        local noSaves = i18n.t("No saved checkpoints")
        love.graphics.print(noSaves, w / 2 - gridFont:getWidth(noSaves) / 2, h * 0.4)
    else
        local rects = getSlotRects(w, h)
        for cpIdx, r in pairs(rects) do
            local cp = save.getCheckpoint(cpIdx)
            if cp then
                local isSelected = (cpIdx == selectedIndex)
                local hover = isInside(mx, my, r)

                -- Slot background
                if isSelected then
                    love.graphics.setColor(0.2, 0.25, 0.45, 0.9)
                elseif hover then
                    love.graphics.setColor(0.15, 0.18, 0.3, 0.85)
                else
                    love.graphics.setColor(0.1, 0.11, 0.18, 0.8)
                end
                love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 8, 8)

                -- Border
                love.graphics.setColor(1, 1, 1, isSelected and 0.6 or (hover and 0.4 or 0.2))
                love.graphics.setLineWidth(isSelected and 2 or 1)
                love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 8, 8)

                -- Slot number
                love.graphics.setFont(smallFont)
                love.graphics.setColor(0.5, 0.5, 0.6)
                love.graphics.print(string.format("#%d", cpIdx), r.x + 15, r.y + 10)

                -- Label
                love.graphics.setFont(gridFont)
                love.graphics.setColor(1, 1, 1)
                love.graphics.print(cp.label or "Checkpoint", r.x + 60, r.y + 12)

                -- Timestamp
                love.graphics.setFont(smallFont)
                love.graphics.setColor(0.6, 0.6, 0.7)
                love.graphics.print(formatTimestamp(cp.timestamp), r.x + 60, r.y + 40)

                -- Script info
                local scriptInfo = cp.scriptModule or ""
                -- Show just the last part of the module path
                scriptInfo = scriptInfo:match("([^%.]+)$") or scriptInfo
                love.graphics.setColor(0.45, 0.45, 0.55)
                love.graphics.print(scriptInfo, r.x + r.w - smallFont:getWidth(scriptInfo) - 15, r.y + 40)
            end
        end

        -- Page controls
        local pages = totalPages()
        if pages > 1 then
            local pageArrows = getPageArrowRects(w, h)

            drawButton(pageArrows.left, "<", currentPage > 1 and isInside(mx, my, pageArrows.left), gridFont, currentPage > 1)
            drawButton(pageArrows.right, ">", currentPage < pages and isInside(mx, my, pageArrows.right), gridFont, currentPage < pages)

            -- Page indicator
            love.graphics.setColor(0.7, 0.7, 0.8)
            love.graphics.setFont(gridFont)
            local pageText = string.format("%d / %d", currentPage, pages)
            love.graphics.print(pageText, w / 2 - gridFont:getWidth(pageText) / 2, pageArrows.left.y + pageArrows.left.h / 2 - gridFont:getHeight() / 2)
        end
    end
end

-- Returns: "back", "load" (with selectedIndex), or nil
function M.mousepressed(x, y, button, w, h)
    if button ~= 1 then return nil end

    -- Back button
    local back = getBackRect(w, h)
    if isInside(x, y, back) then
        return "back"
    end

    -- Load button
    local loadBtn = getLoadRect(w, h)
    if selectedIndex > 0 and isInside(x, y, loadBtn) then
        return "load"
    end

    -- Page arrows
    local pages = totalPages()
    if pages > 1 then
        local pageArrows = getPageArrowRects(w, h)
        if currentPage > 1 and isInside(x, y, pageArrows.left) then
            currentPage = currentPage - 1
            return "page"
        end
        if currentPage < pages and isInside(x, y, pageArrows.right) then
            currentPage = currentPage + 1
            return "page"
        end
    end

    -- Slot clicks
    local rects = getSlotRects(w, h)
    for cpIdx, r in pairs(rects) do
        if isInside(x, y, r) then
            if selectedIndex == cpIdx then
                -- Double-click to load
                return "load"
            end
            selectedIndex = cpIdx
            return "select"
        end
    end

    return nil
end

function M.keypressed(key)
    if key == "escape" or key == "backspace" then
        return "back"
    elseif key == "return" or key == "space" then
        if selectedIndex > 0 then
            return "load"
        end
    elseif key == "up" then
        if selectedIndex > 1 then
            selectedIndex = selectedIndex - 1
            -- Switch page if needed
            currentPage = math.ceil(selectedIndex / SLOTS_PER_PAGE)
        end
    elseif key == "down" then
        if selectedIndex < save.getCheckpointCount() then
            selectedIndex = selectedIndex + 1
            currentPage = math.ceil(selectedIndex / SLOTS_PER_PAGE)
        end
    elseif key == "left" then
        if currentPage > 1 then
            currentPage = currentPage - 1
        end
    elseif key == "right" then
        if currentPage < totalPages() then
            currentPage = currentPage + 1
        end
    end
    return "consumed"
end

function M.getSelectedIndex()
    return selectedIndex
end

return M
