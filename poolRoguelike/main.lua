-- Billiards Roguelike Prototype
-- Love2D (Lua) with love.physics

-- Constants
local WINDOW_W, WINDOW_H = 1280, 720
local TABLE_PADDING = 80
local RAIL_THICKNESS = 18
local BALL_RADIUS = 12
local HOLE_RADIUS = 18
local CUE_LENGTH = 200
local CUE_WIDTH = 6
local NUM_RED_BALLS = 9
local TARGET_SCORE = 50
local POINTS_PER_BALL = 10
local SCRATCH_PENALTY = 5
local REST_THRESHOLD = 0.3
local POWER_OSCILLATE_SPEED = 3.0
local MAX_SHOT_IMPULSE = 800

-- Colors
local COLOR_BG = {0.95, 0.85, 0.2}
local COLOR_TABLE = {0.1, 0.55, 0.15}
local COLOR_RAIL = {0.35, 0.2, 0.08}
local COLOR_RED = {0.85, 0.1, 0.1}
local COLOR_WHITE = {1, 1, 1}
local COLOR_HOLE = {0.05, 0.05, 0.05}
local COLOR_CUE = {0.7, 0.55, 0.25}
local COLOR_AIM = {1, 1, 1, 0.3}
local COLOR_OUTLINE = {0, 0, 0, 0.5}
local COLOR_UI_TEXT = {1, 1, 1}
local COLOR_UI_BG = {0, 0, 0, 0.6}
local COLOR_POWER_BG = {0.2, 0.2, 0.2}
local COLOR_POWER_FILL = {0.2, 0.8, 0.3}
local COLOR_POWER_HIGH = {0.9, 0.2, 0.1}

-- Game state
local world
local cueBall
local redBalls = {}
local holes = {}
local rails = {}

local score = 0
local targetScore = TARGET_SCORE

local gamePhase = "aim" -- "aim", "power", "moving", "roundComplete"
local aimAngle = 0
local powerLevel = 0
local powerDirection = 1
local powerTimer = 0

-- Table bounds (inner playing surface)
local tableLeft, tableTop, tableRight, tableBottom
local tableW, tableH

function love.load()
    love.window.setTitle("Billiards Roguelike")
    love.window.setMode(WINDOW_W, WINDOW_H, {resizable = false})
    love.graphics.setBackgroundColor(COLOR_BG)

    -- Calculate table dimensions
    tableLeft = TABLE_PADDING + RAIL_THICKNESS
    tableTop = TABLE_PADDING + RAIL_THICKNESS
    tableRight = WINDOW_W - TABLE_PADDING - RAIL_THICKNESS
    tableBottom = WINDOW_H - TABLE_PADDING - RAIL_THICKNESS
    tableW = tableRight - tableLeft
    tableH = tableBottom - tableTop

    startRound()
end

function startRound()
    -- Reset state
    score = 0
    gamePhase = "aim"
    redBalls = {}
    holes = {}
    rails = {}

    -- Create physics world (zero gravity for top-down)
    world = love.physics.newWorld(0, 0, true)
    world:setCallbacks(beginContact, nil, nil, nil)

    -- Create table rails (static bodies forming the border)
    createRails()

    -- Place hole first, then balls ensuring no overlaps
    local occupied = {}

    -- Place 1 hole
    local hx, hy = findValidPosition(occupied, HOLE_RADIUS + 30)
    table.insert(occupied, {x = hx, y = hy, r = HOLE_RADIUS + BALL_RADIUS + 5})
    local hole = createHole(hx, hy)
    table.insert(holes, hole)

    -- Place cue ball
    local cx, cy = findValidPosition(occupied, BALL_RADIUS + 10)
    table.insert(occupied, {x = cx, y = cy, r = BALL_RADIUS * 3})
    cueBall = createBall(cx, cy, "cue")

    -- Place red balls
    for i = 1, NUM_RED_BALLS do
        local rx, ry = findValidPosition(occupied, BALL_RADIUS + 5)
        table.insert(occupied, {x = rx, y = ry, r = BALL_RADIUS * 3})
        local ball = createBall(rx, ry, "red")
        table.insert(redBalls, ball)
    end
end

function findValidPosition(occupied, margin)
    local padding = 40
    for attempt = 1, 500 do
        local x = tableLeft + padding + math.random() * (tableW - padding * 2)
        local y = tableTop + padding + math.random() * (tableH - padding * 2)
        local valid = true
        for _, occ in ipairs(occupied) do
            local dx = x - occ.x
            local dy = y - occ.y
            if math.sqrt(dx * dx + dy * dy) < occ.r + margin then
                valid = false
                break
            end
        end
        if valid then return x, y end
    end
    -- Fallback: just return something
    return tableLeft + tableW * 0.5, tableTop + tableH * 0.5
end

function createRails()
    local cx = (tableLeft + tableRight) / 2
    local cy = (tableTop + tableBottom) / 2
    local fullW = tableW + RAIL_THICKNESS * 2
    local fullH = tableH + RAIL_THICKNESS * 2

    -- Top rail
    local top = {}
    top.body = love.physics.newBody(world, cx, tableTop - RAIL_THICKNESS / 2, "static")
    top.shape = love.physics.newRectangleShape(fullW, RAIL_THICKNESS)
    top.fixture = love.physics.newFixture(top.body, top.shape)
    top.fixture:setRestitution(0.85)
    top.fixture:setFriction(0.1)
    table.insert(rails, top)

    -- Bottom rail
    local bot = {}
    bot.body = love.physics.newBody(world, cx, tableBottom + RAIL_THICKNESS / 2, "static")
    bot.shape = love.physics.newRectangleShape(fullW, RAIL_THICKNESS)
    bot.fixture = love.physics.newFixture(bot.body, bot.shape)
    bot.fixture:setRestitution(0.85)
    bot.fixture:setFriction(0.1)
    table.insert(rails, bot)

    -- Left rail
    local left = {}
    left.body = love.physics.newBody(world, tableLeft - RAIL_THICKNESS / 2, cy, "static")
    left.shape = love.physics.newRectangleShape(RAIL_THICKNESS, fullH)
    left.fixture = love.physics.newFixture(left.body, left.shape)
    left.fixture:setRestitution(0.85)
    left.fixture:setFriction(0.1)
    table.insert(rails, left)

    -- Right rail
    local right = {}
    right.body = love.physics.newBody(world, tableRight + RAIL_THICKNESS / 2, cy, "static")
    right.shape = love.physics.newRectangleShape(RAIL_THICKNESS, fullH)
    right.fixture = love.physics.newFixture(right.body, right.shape)
    right.fixture:setRestitution(0.85)
    right.fixture:setFriction(0.1)
    table.insert(rails, right)
end

function createBall(x, y, ballType)
    local ball = {}
    ball.type = ballType
    ball.body = love.physics.newBody(world, x, y, "dynamic")
    ball.body:setBullet(true)
    ball.shape = love.physics.newCircleShape(BALL_RADIUS)
    ball.fixture = love.physics.newFixture(ball.body, ball.shape, 1)
    ball.fixture:setRestitution(0.92)
    ball.fixture:setFriction(0.15)
    ball.body:setLinearDamping(0.65)
    ball.body:setAngularDamping(0.3)
    ball.fixture:setUserData({type = ballType, ball = ball})
    ball.pocketed = false
    return ball
end

function createHole(x, y)
    local hole = {}
    hole.x = x
    hole.y = y
    hole.body = love.physics.newBody(world, x, y, "static")
    hole.shape = love.physics.newCircleShape(HOLE_RADIUS)
    hole.fixture = love.physics.newFixture(hole.body, hole.shape)
    hole.fixture:setSensor(true)
    hole.fixture:setUserData({type = "hole"})
    return hole
end

function beginContact(a, b, contact)
    -- We handle pocketing in update via distance check for more control
end

function love.update(dt)
    if gamePhase == "roundComplete" then return end

    world:update(dt)

    -- Update aim angle
    if gamePhase == "aim" and cueBall and not cueBall.pocketed then
        local mx, my = love.mouse.getPosition()
        local bx, by = cueBall.body:getPosition()
        aimAngle = math.atan2(my - by, mx - bx)
    end

    -- Power meter oscillation
    if gamePhase == "power" then
        powerTimer = powerTimer + dt * POWER_OSCILLATE_SPEED
        powerLevel = (math.sin(powerTimer * math.pi) + 1) / 2 -- 0 to 1
    end

    -- Check pocketing (distance-based)
    checkPocketing()

    -- Check if all balls at rest (during moving phase)
    if gamePhase == "moving" then
        if allBallsAtRest() then
            -- Check round completion
            if score >= targetScore then
                gamePhase = "roundComplete"
            elseif countRedBalls() == 0 then
                gamePhase = "roundComplete"
            else
                gamePhase = "aim"
            end
        end
    end
end

function checkPocketing()
    for _, hole in ipairs(holes) do
        -- Check cue ball
        if cueBall and not cueBall.pocketed then
            local bx, by = cueBall.body:getPosition()
            local dx = bx - hole.x
            local dy = by - hole.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < HOLE_RADIUS * 0.6 then
                -- Scratch!
                score = math.max(0, score - SCRATCH_PENALTY)
                respawnCueBall()
            end
        end

        -- Check red balls
        for i = #redBalls, 1, -1 do
            local ball = redBalls[i]
            if not ball.pocketed then
                local bx, by = ball.body:getPosition()
                local dx = bx - hole.x
                local dy = by - hole.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < HOLE_RADIUS * 0.6 then
                    pocketBall(ball, i)
                end
            end
        end
    end
end

function pocketBall(ball, index)
    ball.pocketed = true
    ball.body:destroy()
    table.remove(redBalls, index)
    score = score + POINTS_PER_BALL
end

function respawnCueBall()
    local cx = tableLeft + tableW * 0.25
    local cy = tableTop + tableH * 0.5
    cueBall.body:setPosition(cx, cy)
    cueBall.body:setLinearVelocity(0, 0)
    cueBall.body:setAngularVelocity(0)
end

function countRedBalls()
    return #redBalls
end

function allBallsAtRest()
    local threshold = REST_THRESHOLD
    if cueBall and not cueBall.pocketed then
        local vx, vy = cueBall.body:getLinearVelocity()
        if math.sqrt(vx * vx + vy * vy) > threshold then return false end
    end
    for _, ball in ipairs(redBalls) do
        if not ball.pocketed then
            local vx, vy = ball.body:getLinearVelocity()
            if math.sqrt(vx * vx + vy * vy) > threshold then return false end
        end
    end
    -- Stop all balls completely when at rest to prevent drift
    if cueBall and not cueBall.pocketed then
        cueBall.body:setLinearVelocity(0, 0)
        cueBall.body:setAngularVelocity(0)
    end
    for _, ball in ipairs(redBalls) do
        if not ball.pocketed then
            ball.body:setLinearVelocity(0, 0)
            ball.body:setAngularVelocity(0)
        end
    end
    return true
end

function love.mousepressed(x, y, button)
    if button == 1 then
        if gamePhase == "aim" then
            -- Lock in angle, go to power phase
            gamePhase = "power"
            powerTimer = 0
            powerLevel = 0
        elseif gamePhase == "power" then
            -- Lock in power, shoot
            shoot()
        elseif gamePhase == "roundComplete" then
            startRound()
        end
    end
end

function love.keypressed(key)
    if key == "space" and gamePhase == "roundComplete" then
        startRound()
    end
    if key == "escape" then
        love.event.quit()
    end
end

function shoot()
    if not cueBall or cueBall.pocketed then
        gamePhase = "aim"
        return
    end

    local force = powerLevel * MAX_SHOT_IMPULSE
    local fx = math.cos(aimAngle) * force
    local fy = math.sin(aimAngle) * force

    cueBall.body:applyLinearImpulse(fx, fy)
    gamePhase = "moving"
end

function love.draw()
    -- Background
    love.graphics.setColor(COLOR_BG)
    love.graphics.rectangle("fill", 0, 0, WINDOW_W, WINDOW_H)

    -- Table surface
    drawTable()

    -- Holes
    drawHoles()

    -- Red balls
    for _, ball in ipairs(redBalls) do
        if not ball.pocketed then
            drawBall(ball, COLOR_RED)
        end
    end

    -- Cue ball
    if cueBall and not cueBall.pocketed then
        drawBall(cueBall, COLOR_WHITE)
    end

    -- Aiming visuals
    if gamePhase == "aim" and cueBall and not cueBall.pocketed then
        drawAimLine()
        drawCueStick()
    end

    -- Power meter
    if gamePhase == "power" then
        drawPowerMeter()
        -- Still show cue stick during power phase
        if cueBall and not cueBall.pocketed then
            drawCueStick()
        end
    end

    -- UI
    drawUI()
end

function drawTable()
    -- Rail border (brown)
    love.graphics.setColor(COLOR_RAIL)
    love.graphics.rectangle("fill",
        TABLE_PADDING, TABLE_PADDING,
        WINDOW_W - TABLE_PADDING * 2, WINDOW_H - TABLE_PADDING * 2,
        8, 8)

    -- Playing surface (green)
    love.graphics.setColor(COLOR_TABLE)
    love.graphics.rectangle("fill",
        tableLeft, tableTop,
        tableW, tableH)
end

function drawHoles()
    for _, hole in ipairs(holes) do
        -- Outer glow
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.circle("fill", hole.x, hole.y, HOLE_RADIUS + 3)
        -- Main hole
        love.graphics.setColor(COLOR_HOLE)
        love.graphics.circle("fill", hole.x, hole.y, HOLE_RADIUS)
    end
end

function drawBall(ball, color)
    local x, y = ball.body:getPosition()

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.circle("fill", x + 2, y + 2, BALL_RADIUS)

    -- Ball body
    love.graphics.setColor(color)
    love.graphics.circle("fill", x, y, BALL_RADIUS)

    -- Outline
    love.graphics.setColor(COLOR_OUTLINE)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", x, y, BALL_RADIUS)

    -- Highlight
    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.circle("fill", x - 3, y - 3, BALL_RADIUS * 0.35)
end

function drawAimLine()
    local bx, by = cueBall.body:getPosition()
    local mx, my = love.mouse.getPosition()

    -- Direction from ball toward mouse
    local dx = mx - bx
    local dy = my - by
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return end
    dx, dy = dx / len, dy / len

    -- Dotted line toward mouse
    love.graphics.setColor(COLOR_AIM)
    love.graphics.setLineWidth(1.5)
    local dotSpacing = 12
    local dotLength = 6
    for i = 0, 25 do
        local startDist = BALL_RADIUS + 10 + i * dotSpacing
        local endDist = startDist + dotLength
        love.graphics.line(
            bx + dx * startDist, by + dy * startDist,
            bx + dx * endDist, by + dy * endDist
        )
    end
end

function drawCueStick()
    local bx, by = cueBall.body:getPosition()

    -- Cue points away from mouse (opposite direction)
    local oppositeAngle = aimAngle + math.pi

    local cueGap = BALL_RADIUS + 6  -- gap between ball and cue tip
    local startX = bx + math.cos(oppositeAngle) * cueGap
    local startY = by + math.sin(oppositeAngle) * cueGap
    local endX = bx + math.cos(oppositeAngle) * (cueGap + CUE_LENGTH)
    local endY = by + math.sin(oppositeAngle) * (cueGap + CUE_LENGTH)

    -- Draw cue as thick line
    -- Cue shadow
    love.graphics.setColor(0, 0, 0, 0.2)
    love.graphics.setLineWidth(CUE_WIDTH + 2)
    love.graphics.line(startX + 2, startY + 2, endX + 2, endY + 2)

    -- Cue body
    love.graphics.setColor(COLOR_CUE)
    love.graphics.setLineWidth(CUE_WIDTH)
    love.graphics.line(startX, startY, endX, endY)

    -- Cue tip (lighter)
    love.graphics.setColor(0.9, 0.85, 0.7)
    love.graphics.setLineWidth(CUE_WIDTH)
    local tipLen = 15
    local tipEndX = startX + math.cos(oppositeAngle) * tipLen
    local tipEndY = startY + math.sin(oppositeAngle) * tipLen
    -- Tip is actually at the start (near ball)
    -- Draw from startX,startY a small portion
    love.graphics.line(startX, startY, tipEndX, tipEndY)
end

function drawPowerMeter()
    -- Horizontal bar power meter
    local barW = 300
    local barH = 30
    local barX = (WINDOW_W - barW) / 2
    local barY = WINDOW_H - 60

    -- Background
    love.graphics.setColor(COLOR_POWER_BG)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 6, 6)

    -- Fill
    local fillColor = {
        COLOR_POWER_FILL[1] + (COLOR_POWER_HIGH[1] - COLOR_POWER_FILL[1]) * powerLevel,
        COLOR_POWER_FILL[2] + (COLOR_POWER_HIGH[2] - COLOR_POWER_FILL[2]) * powerLevel,
        COLOR_POWER_FILL[3] + (COLOR_POWER_HIGH[3] - COLOR_POWER_FILL[3]) * powerLevel,
    }
    love.graphics.setColor(fillColor)
    love.graphics.rectangle("fill", barX + 3, barY + 3, (barW - 6) * powerLevel, barH - 6, 4, 4)

    -- Border
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", barX, barY, barW, barH, 6, 6)

    -- Percentage text
    love.graphics.setColor(COLOR_UI_TEXT)
    local pctText = string.format("%d%%", math.floor(powerLevel * 100))
    local font = love.graphics.getFont()
    love.graphics.print(pctText, barX + barW / 2 - font:getWidth(pctText) / 2, barY + barH / 2 - font:getHeight() / 2)
end

function drawUI()
    local font = love.graphics.getFont()

    -- Score display
    love.graphics.setColor(COLOR_UI_BG)
    love.graphics.rectangle("fill", 0, 0, WINDOW_W, 36, 0, 0)

    love.graphics.setColor(COLOR_UI_TEXT)
    local scoreText = string.format("Score: %d / Target: %d", score, targetScore)
    love.graphics.print(scoreText, 20, 10)

    -- Balls remaining
    local remainText = string.format("Red Balls: %d", countRedBalls())
    love.graphics.print(remainText, 300, 10)

    -- Game phase indicator
    local phaseText = ""
    if gamePhase == "aim" then
        phaseText = "AIM - Click to set angle"
    elseif gamePhase == "power" then
        phaseText = "POWER - Click to shoot!"
    elseif gamePhase == "moving" then
        phaseText = "..."
    elseif gamePhase == "roundComplete" then
        phaseText = ""
    end
    love.graphics.print(phaseText, WINDOW_W - font:getWidth(phaseText) - 20, 10)

    -- Deck display (right side)
    drawDeckPanel()

    -- Round complete overlay
    if gamePhase == "roundComplete" then
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", 0, 0, WINDOW_W, WINDOW_H)

        love.graphics.setColor(1, 1, 1)
        local msg = "ROUND COMPLETE!"
        local msg2 = string.format("Final Score: %d", score)
        local msg3 = "Click or press SPACE to restart"
        -- Use default font, center text
        love.graphics.print(msg, WINDOW_W / 2 - font:getWidth(msg) / 2, WINDOW_H / 2 - 40)
        love.graphics.print(msg2, WINDOW_W / 2 - font:getWidth(msg2) / 2, WINDOW_H / 2)
        love.graphics.print(msg3, WINDOW_W / 2 - font:getWidth(msg3) / 2, WINDOW_H / 2 + 40)
    end
end

function drawDeckPanel()
    -- Small panel on the right showing deck contents
    local panelX = WINDOW_W - 140
    local panelY = 50
    local panelW = 130
    local panelH = 160

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 6, 6)

    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("Deck:", panelX + 10, panelY + 8)

    -- Cue ball icon
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.circle("fill", panelX + 22, panelY + 38, 8)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.circle("line", panelX + 22, panelY + 38, 8)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("x1 Cue Ball", panelX + 35, panelY + 30)

    -- Red ball icon
    love.graphics.setColor(COLOR_RED)
    love.graphics.circle("fill", panelX + 22, panelY + 62, 8)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.circle("line", panelX + 22, panelY + 62, 8)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("x9 Red Balls", panelX + 35, panelY + 54)

    -- Hole icon
    love.graphics.setColor(COLOR_HOLE)
    love.graphics.circle("fill", panelX + 22, panelY + 86, 8)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("x1 Pocket", panelX + 35, panelY + 78)

    -- Target info
    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.print(string.format("Target: %d", targetScore), panelX + 10, panelY + 110)
    love.graphics.print(string.format("Per Ball: %d", POINTS_PER_BALL), panelX + 10, panelY + 130)
end

