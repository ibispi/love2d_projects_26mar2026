-- Gallery UI: paged grid view with thumbnails, fullscreen viewer with arrow navigation
local save = require("lib.save")
local i18n = require("lib.i18n")
local fonts = require("lib.fonts")

local M = {}

local galleryDefs = {}   -- loaded from content/scripts/gallery.lua
local imageCache = {}    -- [index] = love2d image or false (failed to load)

local mode = "grid"      -- "grid" or "view"
local viewIndex = 0       -- currently viewed image index (1-based)
local currentPage = 1     -- current grid page (1-based)
local gridFont = nil
local titleFont = nil

-- Grid layout constants
local GRID_COLS = 4
local GRID_ROWS = 2       -- rows per page
local GRID_PAD = 40       -- padding from screen edges
local GRID_GAP = 20       -- gap between cells
local GRID_TOP = 100      -- top margin for title bar
local GRID_BOTTOM = 80    -- bottom margin for page controls
local THUMB_ASPECT = 16 / 9

-- Load gallery definitions
function M.load()
    package.loaded["content.scripts.gallery"] = nil
    galleryDefs = require("content.scripts.gallery")
    imageCache = {}
    gridFont = fonts.get(18)
    titleFont = fonts.get(36)
end

-- Get or load an image for a gallery entry (returns image or nil)
local function getImage(index)
    if imageCache[index] ~= nil then
        if imageCache[index] == false then return nil end
        return imageCache[index]
    end
    local entry = galleryDefs[index]
    if entry and entry.image and love.filesystem.getInfo(entry.image) then
        local ok, img = pcall(love.graphics.newImage, entry.image)
        if ok then
            imageCache[index] = img
            return img
        end
    end
    imageCache[index] = false
    return nil
end

-- Build list of unlocked image indices for navigation
local function getUnlockedIndices()
    local list = {}
    for i = 1, #galleryDefs do
        if save.isGalleryUnlocked(i) then
            table.insert(list, i)
        end
    end
    return list
end

local function itemsPerPage()
    return GRID_COLS * GRID_ROWS
end

local function totalPages()
    return math.max(1, math.ceil(#galleryDefs / itemsPerPage()))
end

-- Get the gallery indices that belong to the current page
local function getPageIndices()
    local perPage = itemsPerPage()
    local startIdx = (currentPage - 1) * perPage + 1
    local endIdx = math.min(startIdx + perPage - 1, #galleryDefs)
    local indices = {}
    for i = startIdx, endIdx do
        table.insert(indices, i)
    end
    return indices
end

-- Grid cell layout for current page
local function getGridCells(w, h)
    local usableW = w - GRID_PAD * 2 - GRID_GAP * (GRID_COLS - 1)
    local cellW = usableW / GRID_COLS
    local cellH = cellW / THUMB_ASPECT

    local pageIndices = getPageIndices()
    local cells = {} -- [galleryIndex] = rect

    for slot, galIdx in ipairs(pageIndices) do
        local col = (slot - 1) % GRID_COLS
        local row = math.floor((slot - 1) / GRID_COLS)
        local x = GRID_PAD + col * (cellW + GRID_GAP)
        local y = GRID_TOP + row * (cellH + GRID_GAP + 30) -- 30 for label
        cells[galIdx] = { x = x, y = y, w = cellW, h = cellH }
    end
    return cells
end

-- Arrow button rects for fullscreen view
local function getViewArrowRects(w, h)
    local arrowW = 60
    local arrowH = 80
    local margin = 20
    local centerY = h / 2 - arrowH / 2
    return {
        left = { x = margin, y = centerY, w = arrowW, h = arrowH },
        right = { x = w - margin - arrowW, y = centerY, w = arrowW, h = arrowH },
    }
end

-- Page navigation button rects (bottom of grid view)
local function getPageArrowRects(w, h)
    local arrowW = 50
    local arrowH = 44
    local gap = 20
    local centerX = w / 2
    local y = h - GRID_BOTTOM + (GRID_BOTTOM - arrowH) / 2
    return {
        left = { x = centerX - arrowW - gap, y = y, w = arrowW, h = arrowH },
        right = { x = centerX + gap, y = y, w = arrowW, h = arrowH },
    }
end

-- Back button rect
local function getBackRect(w, h)
    return { x = 20, y = 20, w = 100, h = 44 }
end

---------------------------------------------------------------------------
-- DRAW HELPERS
---------------------------------------------------------------------------

local function drawButton(r, label, hover, font)
    love.graphics.setColor(hover and 0.25 or 0.12, hover and 0.28 or 0.14, hover and 0.45 or 0.22, 0.9)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
    love.graphics.setColor(1, 1, 1, hover and 0.8 or 0.5)
    love.graphics.setLineWidth(hover and 2 or 1)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(font)
    love.graphics.print(label, r.x + r.w / 2 - font:getWidth(label) / 2, r.y + r.h / 2 - font:getHeight() / 2)
end

local function drawDisabledButton(r, label, font)
    love.graphics.setColor(0.1, 0.1, 0.14, 0.5)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
    love.graphics.setColor(0.25, 0.25, 0.3, 0.4)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 6, 6)
    love.graphics.setColor(0.3, 0.3, 0.35)
    love.graphics.setFont(font)
    love.graphics.print(label, r.x + r.w / 2 - font:getWidth(label) / 2, r.y + r.h / 2 - font:getHeight() / 2)
end

local function isInside(mx, my, r)
    return mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
end

---------------------------------------------------------------------------
-- DRAW
---------------------------------------------------------------------------

local function drawGrid(w, h)
    -- Background
    love.graphics.setColor(0.06, 0.06, 0.1)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Title bar
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, w, GRID_TOP - 10)

    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 1, 1)
    local title = i18n.t("Gallery")
    love.graphics.print(title, w / 2 - titleFont:getWidth(title) / 2, 25)

    -- Count
    love.graphics.setFont(gridFont)
    love.graphics.setColor(0.6, 0.6, 0.7)
    local countText = string.format("%d / %d %s", save.getUnlockedCount(), #galleryDefs, i18n.t("unlocked"))
    love.graphics.print(countText, w - GRID_PAD - gridFont:getWidth(countText), 35)

    -- Back button
    local mx, my = love.mouse.getPosition()
    local back = getBackRect(w, h)
    drawButton(back, i18n.t("Back"), isInside(mx, my, back), gridFont)

    -- Grid cells
    local cells = getGridCells(w, h)
    for i, cell in pairs(cells) do
        local unlocked = save.isGalleryUnlocked(i)
        local entry = galleryDefs[i]

        if unlocked then
            -- Try to draw the actual image
            local img = getImage(i)
            if img then
                local iw, ih = img:getDimensions()
                local scale = math.min(cell.w / iw, cell.h / ih)
                local drawX = cell.x + (cell.w - iw * scale) / 2
                local drawY = cell.y + (cell.h - ih * scale) / 2
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(img, drawX, drawY, 0, scale, scale)
            else
                -- Placeholder for unlocked but missing file
                love.graphics.setColor(0.15, 0.25, 0.35)
                love.graphics.rectangle("fill", cell.x, cell.y, cell.w, cell.h, 6, 6)
                love.graphics.setColor(1, 1, 1, 0.5)
                love.graphics.setFont(gridFont)
                local label = i18n.t(entry.title or ("Image " .. i))
                love.graphics.print(label, cell.x + cell.w / 2 - gridFont:getWidth(label) / 2, cell.y + cell.h / 2 - gridFont:getHeight() / 2)
            end

            -- Border
            love.graphics.setColor(0.5, 0.6, 0.8, 0.5)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", cell.x, cell.y, cell.w, cell.h, 6, 6)

            -- Title below
            love.graphics.setColor(0.9, 0.9, 0.95)
            love.graphics.setFont(gridFont)
            local titleText = i18n.t(entry.title or "")
            love.graphics.print(titleText, cell.x + cell.w / 2 - gridFont:getWidth(titleText) / 2, cell.y + cell.h + 6)
        else
            -- Locked cell
            love.graphics.setColor(0.1, 0.1, 0.14)
            love.graphics.rectangle("fill", cell.x, cell.y, cell.w, cell.h, 6, 6)

            love.graphics.setColor(0.25, 0.25, 0.3, 0.6)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", cell.x, cell.y, cell.w, cell.h, 6, 6)

            -- Lock text
            love.graphics.setColor(0.35, 0.35, 0.4)
            love.graphics.setFont(gridFont)
            local lockText = i18n.t("Locked")
            love.graphics.print(lockText, cell.x + cell.w / 2 - gridFont:getWidth(lockText) / 2, cell.y + cell.h / 2 - gridFont:getHeight() / 2)

            -- Title below (hidden)
            love.graphics.setColor(0.3, 0.3, 0.35)
            love.graphics.setFont(gridFont)
            love.graphics.print("???", cell.x + cell.w / 2 - gridFont:getWidth("???") / 2, cell.y + cell.h + 6)
        end
    end

    -- Page controls
    local pages = totalPages()
    if pages > 1 then
        local pageArrows = getPageArrowRects(w, h)

        -- Left arrow
        if currentPage > 1 then
            drawButton(pageArrows.left, "<", isInside(mx, my, pageArrows.left), gridFont)
        else
            drawDisabledButton(pageArrows.left, "<", gridFont)
        end

        -- Right arrow
        if currentPage < pages then
            drawButton(pageArrows.right, ">", isInside(mx, my, pageArrows.right), gridFont)
        else
            drawDisabledButton(pageArrows.right, ">", gridFont)
        end

        -- Page indicator
        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.setFont(gridFont)
        local pageText = string.format("%d / %d", currentPage, pages)
        love.graphics.print(pageText, w / 2 - gridFont:getWidth(pageText) / 2, pageArrows.left.y + pageArrows.left.h / 2 - gridFont:getHeight() / 2)
    end
end

local function drawFullscreen(w, h)
    -- Black background
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local entry = galleryDefs[viewIndex]
    if not entry then return end

    -- Draw image scaled to fill window preserving aspect ratio
    local img = getImage(viewIndex)
    if img then
        local iw, ih = img:getDimensions()
        local scale = math.min(w / iw, h / ih)
        local drawX = (w - iw * scale) / 2
        local drawY = (h - ih * scale) / 2
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(img, drawX, drawY, 0, scale, scale)
    else
        -- Placeholder
        love.graphics.setColor(0.15, 0.2, 0.25)
        love.graphics.rectangle("fill", w * 0.1, h * 0.1, w * 0.8, h * 0.8, 8, 8)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.setFont(titleFont)
        local label = entry.title or ("Image " .. viewIndex)
        love.graphics.print(label, w / 2 - titleFont:getWidth(label) / 2, h / 2 - titleFont:getHeight() / 2)
    end

    -- Title at bottom
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, h - 60, w, 60)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setFont(gridFont)
    local titleText = entry.title or ""
    love.graphics.print(titleText, w / 2 - gridFont:getWidth(titleText) / 2, h - 40)

    -- Navigation arrows
    local unlocked = getUnlockedIndices()
    if #unlocked > 1 then
        local arrows = getViewArrowRects(w, h)
        local mx, my = love.mouse.getPosition()

        for _, side in ipairs({"left", "right"}) do
            local r = arrows[side]
            local hover = isInside(mx, my, r)

            love.graphics.setColor(0, 0, 0, hover and 0.7 or 0.4)
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 8, 8)
            love.graphics.setColor(1, 1, 1, hover and 0.9 or 0.5)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 8, 8)

            -- Arrow character
            love.graphics.setFont(titleFont)
            local arrow = side == "left" and "<" or ">"
            love.graphics.print(arrow, r.x + r.w / 2 - titleFont:getWidth(arrow) / 2, r.y + r.h / 2 - titleFont:getHeight() / 2)
        end
    end

    -- Close hint
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.setFont(gridFont)
    local hint = i18n.t("ESC to close")
    love.graphics.print(hint, w - gridFont:getWidth(hint) - 20, 20)
end

function M.draw(w, h)
    if mode == "grid" then
        drawGrid(w, h)
    elseif mode == "view" then
        drawFullscreen(w, h)
    end
end

---------------------------------------------------------------------------
-- INPUT
---------------------------------------------------------------------------

local function navigateView(direction)
    local unlocked = getUnlockedIndices()
    if #unlocked <= 1 then return end

    -- Find current position in unlocked list
    local pos = 1
    for i, idx in ipairs(unlocked) do
        if idx == viewIndex then
            pos = i
            break
        end
    end

    pos = pos + direction
    if pos < 1 then pos = #unlocked end
    if pos > #unlocked then pos = 1 end
    viewIndex = unlocked[pos]
end

local function changePage(direction)
    local pages = totalPages()
    local newPage = currentPage + direction
    if newPage >= 1 and newPage <= pages then
        currentPage = newPage
    end
end

function M.mousepressed(x, y, button, w, h)
    if button ~= 1 then return nil end

    if mode == "grid" then
        -- Back button
        local back = getBackRect(w, h)
        if isInside(x, y, back) then
            return "back"
        end

        -- Page arrows
        local pages = totalPages()
        if pages > 1 then
            local pageArrows = getPageArrowRects(w, h)
            if currentPage > 1 and isInside(x, y, pageArrows.left) then
                changePage(-1)
                return "page"
            end
            if currentPage < pages and isInside(x, y, pageArrows.right) then
                changePage(1)
                return "page"
            end
        end

        -- Grid cells
        local cells = getGridCells(w, h)
        for i, cell in pairs(cells) do
            if save.isGalleryUnlocked(i) then
                if isInside(x, y, cell) then
                    viewIndex = i
                    mode = "view"
                    return "view"
                end
            end
        end

    elseif mode == "view" then
        -- Arrow buttons
        local arrows = getViewArrowRects(w, h)

        if isInside(x, y, arrows.left) then
            navigateView(-1)
            return "navigate"
        end
        if isInside(x, y, arrows.right) then
            navigateView(1)
            return "navigate"
        end

        -- Click anywhere else closes fullscreen
        mode = "grid"
        return "close"
    end

    return nil
end

function M.keypressed(key)
    if mode == "view" then
        if key == "left" or key == "a" then
            navigateView(-1)
        elseif key == "right" or key == "d" then
            navigateView(1)
        elseif key == "escape" or key == "backspace" then
            mode = "grid"
            return "close"  -- consumed, don't propagate
        end
        return "consumed"
    elseif mode == "grid" then
        if key == "escape" or key == "backspace" then
            return "back"
        elseif key == "left" or key == "a" then
            changePage(-1)
        elseif key == "right" or key == "d" then
            changePage(1)
        end
    end
    return nil
end

function M.reset()
    mode = "grid"
    viewIndex = 0
    currentPage = 1
end

return M
