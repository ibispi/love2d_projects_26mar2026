-- Character display: sprites, positions, transitions, backgrounds
local M = {}

-- Active characters on screen: { [name] = { position, expression, opacity, targetOpacity } }
local activeChars = {}
local speakerName = nil

-- Background state
local bg = {
    image = nil,    -- loaded love2d image or nil
    color = nil,    -- {r, g, b} fallback color
    label = nil,    -- text label for placeholder
}

-- Character definitions (colors for placeholder rectangles)
local charDefs = {
    scarlett = { color = {0.85, 0.15, 0.15}, displayName = "Scarlett" },
    marina   = { color = {0.15, 0.7, 0.65},  displayName = "Marina" },
    diana    = { color = {0.6, 0.15, 0.75},   displayName = "Diana" },
    player   = { color = {0.3, 0.5, 0.9},     displayName = "You" },
}

-- Position X ratios (0-1 across screen width)
local positionX = {
    left = 0.22,
    center = 0.5,
    right = 0.78,
}

local FADE_SPEED = 4.0 -- opacity units per second

function M.reset()
    activeChars = {}
    speakerName = nil
    bg = { image = nil, color = nil, label = nil }
end

function M.setBackground(imagePath, color, label)
    if imagePath and love.filesystem.getInfo(imagePath) then
        bg.image = love.graphics.newImage(imagePath)
    else
        bg.image = nil
    end
    bg.color = color
    bg.label = label

    -- If no color and no image, derive a color from the label
    if not bg.color and not bg.image then
        bg.color = {0.15, 0.2, 0.25}
        bg.label = label or (imagePath and imagePath:match("([^/]+)%.") or "Scene")
    end
end

function M.show(name, position, expression)
    activeChars[name] = {
        position = position or "center",
        expression = expression or "neutral",
        opacity = 0,
        targetOpacity = 1,
    }
end

function M.hide(name)
    if activeChars[name] then
        activeChars[name].targetOpacity = 0
    end
end

function M.setExpression(name, expression)
    if activeChars[name] then
        activeChars[name].expression = expression
    end
end

function M.setSpeaker(name)
    speakerName = name
end

-- Instantly set a character's opacity to its target (for replay/load)
function M.snapOpacity(name)
    if activeChars[name] then
        activeChars[name].opacity = activeChars[name].targetOpacity
    end
end

-- Instantly remove a character (for replay/load)
function M.removeInstantly(name)
    activeChars[name] = nil
end

function M.update(dt)
    local toRemove = {}
    for name, char in pairs(activeChars) do
        -- Fade toward target opacity
        if char.opacity < char.targetOpacity then
            char.opacity = math.min(char.targetOpacity, char.opacity + FADE_SPEED * dt)
        elseif char.opacity > char.targetOpacity then
            char.opacity = math.max(char.targetOpacity, char.opacity - FADE_SPEED * dt)
        end
        -- Remove fully faded out characters
        if char.targetOpacity == 0 and char.opacity <= 0 then
            table.insert(toRemove, name)
        end
    end
    for _, name in ipairs(toRemove) do
        activeChars[name] = nil
    end
end

function M.drawBackground(w, h)
    if bg.image then
        love.graphics.setColor(1, 1, 1)
        local iw, ih = bg.image:getDimensions()
        local scale = math.max(w / iw, h / ih)
        love.graphics.draw(bg.image, w / 2, h / 2, 0, scale, scale, iw / 2, ih / 2)
    elseif bg.color then
        love.graphics.setColor(bg.color)
        love.graphics.rectangle("fill", 0, 0, w, h)
        if bg.label then
            love.graphics.setColor(1, 1, 1, 0.3)
            local font = love.graphics.getFont()
            love.graphics.print(bg.label, w / 2 - font:getWidth(bg.label) / 2, h * 0.1)
        end
    else
        love.graphics.setColor(0.1, 0.1, 0.15)
        love.graphics.rectangle("fill", 0, 0, w, h)
    end
end

function M.draw(w, h)
    local font = love.graphics.getFont()
    local spriteW = w * 0.15
    local spriteH = h * 0.55
    local spriteBottom = h * 0.72 -- bottom of sprite area (above text box)

    for name, char in pairs(activeChars) do
        local def = charDefs[name] or { color = {0.5, 0.5, 0.5}, displayName = name }
        local px = positionX[char.position] or 0.5

        local x = w * px - spriteW / 2
        local y = spriteBottom - spriteH

        -- Dim non-speaking characters
        local dimFactor = 1.0
        if speakerName and speakerName ~= name then
            dimFactor = 0.55
        end

        local alpha = char.opacity * dimFactor

        -- Draw placeholder rectangle
        love.graphics.setColor(def.color[1] * dimFactor, def.color[2] * dimFactor, def.color[3] * dimFactor, alpha)
        love.graphics.rectangle("fill", x, y, spriteW, spriteH, 8, 8)

        -- Border
        love.graphics.setColor(1, 1, 1, alpha * 0.4)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, spriteW, spriteH, 8, 8)

        -- Character name label
        love.graphics.setColor(1, 1, 1, alpha)
        local nameText = def.displayName
        love.graphics.print(nameText, x + spriteW / 2 - font:getWidth(nameText) / 2, y + spriteH / 2 - font:getHeight() / 2)

        -- Expression label
        love.graphics.setColor(1, 1, 1, alpha * 0.6)
        local exprText = "(" .. char.expression .. ")"
        love.graphics.print(exprText, x + spriteW / 2 - font:getWidth(exprText) / 2, y + spriteH / 2 + font:getHeight())
    end
end

return M
