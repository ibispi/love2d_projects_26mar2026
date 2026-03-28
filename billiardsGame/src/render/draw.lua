local rules = require("src.game.rules")

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

local function drawPockets(state, config)
    local hr = config.HOLE_RADIUS*config.HOLE_DRAWN_RADIUS_MULTIPLIER
    for _, pocket in ipairs(state.pockets) do
        -- Outer shadow ring
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.circle("fill", pocket.x, pocket.y, hr + 4)
        -- Dark ring
        love.graphics.setColor(0.03, 0.03, 0.03)
        love.graphics.circle("fill", pocket.x, pocket.y, hr + 2)
        -- Pocket hole
        love.graphics.setColor(config.COLOR_HOLE)
        love.graphics.circle("fill", pocket.x, pocket.y, hr)
    end
end

local function drawBall(state, config, ball, color)
    local r = config.BALL_RADIUS
    local x, y = ball.body:getPosition()

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.circle("fill", x + 2, y + 2, r)

    -- Main color
    love.graphics.setColor(color)
    love.graphics.circle("fill", x, y, r)

    -- Outline
    love.graphics.setColor(config.COLOR_OUTLINE)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", x, y, r)

    -- Shine
    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.circle("fill", x - 3, y - 3, r * 0.35)
end

local function drawBlackBall(state, config, ball)
    local r = config.BALL_RADIUS
    local x, y = ball.body:getPosition()

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.circle("fill", x + 2, y + 2, r)

    -- Main black
    love.graphics.setColor(config.COLOR_BLACK)
    love.graphics.circle("fill", x, y, r)

    -- White dot in center to distinguish from pockets
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", x, y, r * 0.6)

    -- "8" text
    love.graphics.setColor(0, 0, 0)
    local font = love.graphics.getFont()
    local text = "8"
    love.graphics.print(text, x - font:getWidth(text) / 2, y - font:getHeight() / 2)

    -- Outline
    love.graphics.setColor(config.COLOR_OUTLINE)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", x, y, r)
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

local function getColorForBall(config, ballColor)
    if ballColor == "red" then return config.COLOR_RED
    elseif ballColor == "blue" then return config.COLOR_BLUE
    else return config.COLOR_BLACK
    end
end

local function drawUI(state, config)
    local font = love.graphics.getFont()
    local phase = state.gamePhase

    -- Top bar background
    love.graphics.setColor(config.COLOR_UI_BG)
    love.graphics.rectangle("fill", 0, 0, config.WINDOW_W, 40, 0, 0)

    love.graphics.setColor(config.COLOR_UI_TEXT)

    -- Turn indicator
    local turnText
    if state.currentPlayer == 1 then
        turnText = "YOUR TURN"
    else
        turnText = "OPPONENT'S TURN"
    end
    love.graphics.print(turnText, 20, 12)

    -- Ball counts
    local redCount = rules.countBallsByColor(state, "red")
    local blueCount = rules.countBallsByColor(state, "blue")

    -- Red count with colored indicator
    local countX = 200
    love.graphics.setColor(config.COLOR_RED)
    love.graphics.circle("fill", countX, 20, 8)
    love.graphics.setColor(config.COLOR_OUTLINE)
    love.graphics.circle("line", countX, 20, 8)
    love.graphics.setColor(config.COLOR_UI_TEXT)
    love.graphics.print(string.format(": %d", redCount), countX + 12, 12)

    -- Blue count with colored indicator
    countX = 290
    love.graphics.setColor(config.COLOR_BLUE)
    love.graphics.circle("fill", countX, 20, 8)
    love.graphics.setColor(config.COLOR_OUTLINE)
    love.graphics.circle("line", countX, 20, 8)
    love.graphics.setColor(config.COLOR_UI_TEXT)
    love.graphics.print(string.format(": %d", blueCount), countX + 12, 12)

    -- Player color assignment
    local assignText
    if state.playerColor then
        assignText = string.format("You: %s", string.upper(state.playerColor))
    else
        assignText = "Color: not assigned"
    end
    love.graphics.print(assignText, 380, 12)

    -- Phase indicator
    local phaseText = ""
    if phase == "aim" then
        phaseText = "AIM - Click to set angle"
    elseif phase == "power" then
        phaseText = "POWER - Click to shoot!"
    elseif phase == "moving" then
        phaseText = "..."
    elseif phase == "turnOver" then
        if state.currentPlayer == 1 then
            phaseText = "Switching turns..."
        else
            phaseText = "Opponent is thinking..."
        end
    end
    love.graphics.setColor(config.COLOR_UI_TEXT)
    love.graphics.print(phaseText, config.WINDOW_W - font:getWidth(phaseText) - 20, 12)

    -- Game over overlay
    if state.gameResult then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, config.WINDOW_W, config.WINDOW_H)

        love.graphics.setColor(1, 1, 1)
        local msg, msg2
        if state.gameResult == "win" then
            msg = "YOU WIN!"
        else
            msg = "YOU LOSE!"
        end
        msg2 = "Click or press SPACE to restart"
        love.graphics.print(msg, config.WINDOW_W / 2 - font:getWidth(msg) / 2, config.WINDOW_H / 2 - 30)
        love.graphics.print(msg2, config.WINDOW_W / 2 - font:getWidth(msg2) / 2, config.WINDOW_H / 2 + 20)
    end
end

function M.draw(state, config)
    love.graphics.setColor(config.COLOR_BG)
    love.graphics.rectangle("fill", 0, 0, config.WINDOW_W, config.WINDOW_H)

    drawTable(state, config)
    drawPockets(state, config)

    -- Draw object balls
    for _, ball in ipairs(state.balls) do
        if not ball.pocketed then
            if ball.ballColor == "black" then
                drawBlackBall(state, config, ball)
            else
                drawBall(state, config, ball, getColorForBall(config, ball.ballColor))
            end
        end
    end

    -- Draw cue ball
    local cueBall = state.cueBall
    if cueBall and not cueBall.pocketed then
        drawBall(state, config, cueBall, config.COLOR_WHITE)
    end

    -- Aim and cue stick
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
