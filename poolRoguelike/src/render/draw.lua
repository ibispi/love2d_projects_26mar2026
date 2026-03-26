local M = {}

local function drawTable(state, config)
    love.graphics.setColor(config.COLOR_RAIL)
    love.graphics.rectangle("fill",
        config.TABLE_PADDING, config.TABLE_PADDING,
        config.WINDOW_W - config.TABLE_PADDING * 2, config.WINDOW_H - config.TABLE_PADDING * 2,
        8, 8)

    love.graphics.setColor(config.COLOR_TABLE)
    love.graphics.rectangle("fill",
        state.tableLeft, state.tableTop,
        state.tableW, state.tableH)
end

local function drawHoles(state, config)
    local hr = config.HOLE_RADIUS
    for _, hole in ipairs(state.holes) do
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.circle("fill", hole.x, hole.y, hr + 3)
        love.graphics.setColor(config.COLOR_HOLE)
        love.graphics.circle("fill", hole.x, hole.y, hr)
    end
end

local function drawBall(state, config, ball, color)
    local r = config.BALL_RADIUS
    local x, y = ball.body:getPosition()

    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.circle("fill", x + 2, y + 2, r)

    love.graphics.setColor(color)
    love.graphics.circle("fill", x, y, r)

    love.graphics.setColor(config.COLOR_OUTLINE)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", x, y, r)

    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.circle("fill", x - 3, y - 3, r * 0.35)
end

local function drawAimLine(state, config)
    local cueBall = state.cueBall
    local bx, by = cueBall.body:getPosition()
    local mx, my = love.mouse.getPosition()

    local dx = mx - bx
    local dy = my - by
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return end
    dx, dy = dx / len, dy / len

    love.graphics.setColor(config.COLOR_AIM)
    love.graphics.setLineWidth(1.5)
    local dotSpacing = 12
    local dotLength = 6
    local br = config.BALL_RADIUS
    for i = 0, 25 do
        local startDist = br + 10 + i * dotSpacing
        local endDist = startDist + dotLength
        love.graphics.line(
            bx + dx * startDist, by + dy * startDist,
            bx + dx * endDist, by + dy * endDist
        )
    end
end

local function drawCueStick(state, config)
    local cueBall = state.cueBall
    local bx, by = cueBall.body:getPosition()
    local oppositeAngle = state.aimAngle + math.pi

    local br = config.BALL_RADIUS
    local cueGap = br + 6
    local startX = bx + math.cos(oppositeAngle) * cueGap
    local startY = by + math.sin(oppositeAngle) * cueGap
    local endX = bx + math.cos(oppositeAngle) * (cueGap + config.CUE_LENGTH)
    local endY = by + math.sin(oppositeAngle) * (cueGap + config.CUE_LENGTH)

    love.graphics.setColor(0, 0, 0, 0.2)
    love.graphics.setLineWidth(config.CUE_WIDTH + 2)
    love.graphics.line(startX + 2, startY + 2, endX + 2, endY + 2)

    love.graphics.setColor(config.COLOR_CUE)
    love.graphics.setLineWidth(config.CUE_WIDTH)
    love.graphics.line(startX, startY, endX, endY)

    love.graphics.setColor(0.9, 0.85, 0.7)
    love.graphics.setLineWidth(config.CUE_WIDTH)
    local tipLen = 15
    local tipEndX = startX + math.cos(oppositeAngle) * tipLen
    local tipEndY = startY + math.sin(oppositeAngle) * tipLen
    love.graphics.line(startX, startY, tipEndX, tipEndY)
end

local function drawPowerMeter(state, config)
    local barW = 300
    local barH = 30
    local barX = (config.WINDOW_W - barW) / 2
    local barY = config.WINDOW_H - 60

    love.graphics.setColor(config.COLOR_POWER_BG)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 6, 6)

    local pl = state.powerLevel
    local fillColor = {
        config.COLOR_POWER_FILL[1] + (config.COLOR_POWER_HIGH[1] - config.COLOR_POWER_FILL[1]) * pl,
        config.COLOR_POWER_FILL[2] + (config.COLOR_POWER_HIGH[2] - config.COLOR_POWER_FILL[2]) * pl,
        config.COLOR_POWER_FILL[3] + (config.COLOR_POWER_HIGH[3] - config.COLOR_POWER_FILL[3]) * pl,
    }
    love.graphics.setColor(fillColor)
    love.graphics.rectangle("fill", barX + 3, barY + 3, (barW - 6) * pl, barH - 6, 4, 4)

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", barX, barY, barW, barH, 6, 6)

    love.graphics.setColor(config.COLOR_UI_TEXT)
    local pctText = string.format("%d%%", math.floor(pl * 100))
    local font = love.graphics.getFont()
    love.graphics.print(pctText, barX + barW / 2 - font:getWidth(pctText) / 2, barY + barH / 2 - font:getHeight() / 2)
end

local function drawDeckPanel(state, config)
    local panelX = config.WINDOW_W - 140
    local panelY = 50
    local panelW = 130
    local panelH = 160

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 6, 6)

    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("Deck:", panelX + 10, panelY + 8)

    love.graphics.setColor(config.COLOR_WHITE)
    love.graphics.circle("fill", panelX + 22, panelY + 38, 8)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.circle("line", panelX + 22, panelY + 38, 8)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("x1 Cue Ball", panelX + 35, panelY + 30)

    love.graphics.setColor(config.COLOR_RED)
    love.graphics.circle("fill", panelX + 22, panelY + 62, 8)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.circle("line", panelX + 22, panelY + 62, 8)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print(string.format("x%d Red Balls", config.NUM_RED_BALLS), panelX + 35, panelY + 54)

    love.graphics.setColor(config.COLOR_HOLE)
    love.graphics.circle("fill", panelX + 22, panelY + 86, 8)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("x1 Pocket", panelX + 35, panelY + 78)

    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.print(string.format("Target: %d", state.targetScore), panelX + 10, panelY + 110)
    love.graphics.print(string.format("Per Ball: %d", config.POINTS_PER_BALL), panelX + 10, panelY + 130)
end

local function drawUI(state, config)
    local font = love.graphics.getFont()
    local phase = state.gamePhase

    love.graphics.setColor(config.COLOR_UI_BG)
    love.graphics.rectangle("fill", 0, 0, config.WINDOW_W, 36, 0, 0)

    love.graphics.setColor(config.COLOR_UI_TEXT)
    local scoreText = string.format("Score: %d / Target: %d", state.score, state.targetScore)
    love.graphics.print(scoreText, 20, 10)

    local remainText = string.format("Red Balls: %d", #state.redBalls)
    love.graphics.print(remainText, 300, 10)

    local phaseText = ""
    if phase == "aim" then
        phaseText = "AIM - Click to set angle"
    elseif phase == "power" then
        phaseText = "POWER - Click to shoot!"
    elseif phase == "moving" then
        phaseText = "..."
    end
    love.graphics.print(phaseText, config.WINDOW_W - font:getWidth(phaseText) - 20, 10)

    drawDeckPanel(state, config)

    if phase == "roundComplete" then
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", 0, 0, config.WINDOW_W, config.WINDOW_H)

        love.graphics.setColor(1, 1, 1)
        local msg = "ROUND COMPLETE!"
        local msg2 = string.format("Final Score: %d", state.score)
        local msg3 = "Click or press SPACE to restart"
        love.graphics.print(msg, config.WINDOW_W / 2 - font:getWidth(msg) / 2, config.WINDOW_H / 2 - 40)
        love.graphics.print(msg2, config.WINDOW_W / 2 - font:getWidth(msg2) / 2, config.WINDOW_H / 2)
        love.graphics.print(msg3, config.WINDOW_W / 2 - font:getWidth(msg3) / 2, config.WINDOW_H / 2 + 40)
    end
end

function M.draw(state, config)
    love.graphics.setColor(config.COLOR_BG)
    love.graphics.rectangle("fill", 0, 0, config.WINDOW_W, config.WINDOW_H)

    drawTable(state, config)
    drawHoles(state, config)

    for _, ball in ipairs(state.redBalls) do
        if not ball.pocketed then
            drawBall(state, config, ball, config.COLOR_RED)
        end
    end

    local cueBall = state.cueBall
    if cueBall and not cueBall.pocketed then
        drawBall(state, config, cueBall, config.COLOR_WHITE)
    end

    local phase = state.gamePhase
    if phase == "aim" and cueBall and not cueBall.pocketed then
        drawAimLine(state, config)
        drawCueStick(state, config)
    end

    if phase == "power" then
        drawPowerMeter(state, config)
        if cueBall and not cueBall.pocketed then
            drawCueStick(state, config)
        end
    end

    drawUI(state, config)
end

return M
