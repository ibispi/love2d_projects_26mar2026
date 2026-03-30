local config = require("billiards.config")
local physics = require("billiards.physics.table")
local rules = require("billiards.game.rules")
local ai = require("billiards.game.ai")
local render = require("billiards.render.draw")

local state = {
    world = nil,
    cueBall = nil,
    balls = {},       -- all 15 object balls (player color, opponent color, black)
    pockets = {},
    rails = {},
    gamePhase = "aim", -- aim, power, moving, turnOver, aiThinking, gameOver
    aimAngle = 0,
    powerLevel = 0,
    powerTimer = 0,
    tableLeft = 0,
    tableTop = 0,
    tableRight = 0,
    tableBottom = 0,
    tableW = 0,
    tableH = 0,
    currentPlayer = 1,   -- 1 = player, 2 = opponent
    playerColor = "blue",
    opponentColor = "red",
    gameResult = nil,    -- nil, "win", "lose"
    pottedThisTurn = {},
    cueScratchedThisTurn = false,
    turnDelayTimer = 0,
    physicsAccumulator = 0,
    -- Scaling state (computed each frame)
    scale = 1,
    offsetX = 0,
    offsetY = 0,
    -- Render colors (RGB tables)
    playerRenderColor = {},
    opponentRenderColor = {},
    -- Opponent / AI state
    opponent = nil,       -- opponent definition table
    aiThinkTimer = 0,
    aiTargetAngle = 0,
    aiTargetPower = 0,
    aiStartAngle = 0,
    aiThinkDuration = 0, -- total think time for lerp calculation
}

local function computeTableBounds()
    local pad = config.TABLE_PADDING
    local rt = config.RAIL_THICKNESS
    state.tableLeft = pad + rt
    state.tableTop = pad + rt
    state.tableRight = config.DESIGN_W - pad - rt
    state.tableBottom = config.DESIGN_H - pad - rt
    state.tableW = state.tableRight - state.tableLeft
    state.tableH = state.tableBottom - state.tableTop
end

local function updateScale()
    local winW, winH = love.graphics.getDimensions()
    local s = winH / config.DESIGN_H
    state.scale = s
    state.offsetX = (winW - config.DESIGN_W * s) / 2
    state.offsetY = 0
end

-- Convert screen mouse coordinates to design coordinates
local function screenToDesign(sx, sy)
    local dx = (sx - state.offsetX) / state.scale
    local dy = (sy - state.offsetY) / state.scale
    return dx, dy
end

-- RGB distance for color similarity check
local function colorDistance(c1, c2)
    local dr = c1[1] - c2[1]
    local dg = c1[2] - c2[2]
    local db = c1[3] - c2[3]
    return math.sqrt(dr * dr + dg * dg + db * db)
end

-- Angle lerp that handles wrapping around +/- pi
local function lerpAngle(a, b, t)
    local diff = b - a
    while diff > math.pi do diff = diff - 2 * math.pi end
    while diff < -math.pi do diff = diff + 2 * math.pi end
    return a + diff * t
end

-- Smoothstep interpolation
local function smoothstep(t)
    t = math.max(0, math.min(1, t))
    return t * t * (3 - 2 * t)
end

local function createPockets()
    state.pockets = {}
    local tl = state.tableLeft
    local tr = state.tableRight
    local tt = state.tableTop
    local tb = state.tableBottom
    local cx = (tl + tr) / 2

    local inset = config.CENTER_POCKET_INSET
    local positions = {
        {x = tl, y = tt},
        {x = cx, y = tt + inset},
        {x = tr, y = tt},
        {x = tl, y = tb},
        {x = cx, y = tb - inset},
        {x = tr, y = tb},
    }

    for _, pos in ipairs(positions) do
        table.insert(state.pockets, physics.createHole(state, config, pos.x, pos.y))
    end
end

local function createTriangleRack()
    state.balls = {}
    local br = config.BALL_RADIUS
    local rackX = state.tableLeft + state.tableW * 0.72
    local rackCenterY = state.tableTop + state.tableH * 0.5

    local rowDX = br * 2 * math.cos(math.rad(30))

    -- "blue" = player, "red" = opponent, "black" = 8-ball
    local layout = {
        {"red"},
        {"blue", "red"},
        {"red", "black", "blue"},
        {"blue", "red", "blue", "red"},
        {"blue", "red", "blue", "red", "blue"},
    }

    for row, colors in ipairs(layout) do
        local n = #colors
        local x = rackX + (row - 1) * rowDX
        for i, ballColor in ipairs(colors) do
            local y = rackCenterY + (i - 1) * (br * 2) - (n - 1) * br
            local ball = physics.createBall(state, config, x, y, ballColor)
            table.insert(state.balls, ball)
        end
    end
end

local function startAIThinking()
    state.gamePhase = "aiThinking"
    local thinkTime = state.opponent.ai.think_time
    state.aiThinkTimer = thinkTime
    state.aiThinkDuration = thinkTime
    state.aiStartAngle = state.aimAngle

    -- Calculate shot now, animate cue stick during think time
    local angle, power = ai.calculateShot(state, config, state.opponent)
    state.aiTargetAngle = angle
    state.aiTargetPower = power
end

local function startMatch(opponent)
    state.opponent = opponent
    state.gamePhase = "aim"
    state.balls = {}
    state.pockets = {}
    state.rails = {}
    state.currentPlayer = 1
    state.playerColor = "blue"
    state.opponentColor = "red"
    state.gameResult = nil
    state.pottedThisTurn = {}
    state.cueScratchedThisTurn = false
    state.turnDelayTimer = 0
    state.physicsAccumulator = 0
    state.aiThinkTimer = 0
    state.aiTargetAngle = 0
    state.aiTargetPower = 0
    state.aiStartAngle = 0
    state.aiThinkDuration = 0

    -- Set render colors
    state.playerRenderColor = config.PLAYER_COLOR

    -- Check if opponent color is too similar to player color
    if colorDistance(opponent.balls_color, config.PLAYER_COLOR) < config.COLOR_SIMILARITY_THRESHOLD then
        state.opponentRenderColor = opponent.alt_balls_color
    else
        state.opponentRenderColor = opponent.balls_color
    end

    state.world = love.physics.newWorld(0, 0, true)
    physics.setWorldCallbacks(state.world)

    physics.createRails(state, config)
    createPockets()

    local cx = state.tableLeft + state.tableW * 0.25
    local cy = state.tableTop + state.tableH * 0.5
    state.cueBall = physics.createBall(state, config, cx, cy, "cue")

    createTriangleRack()
end

local M = {}

-- Callback fired when a match ends; set by the caller via M.onMatchEnd
M.onMatchEnd = nil

function M.load()
    computeTableBounds()
    updateScale()
end

function M.start(opponent)
    startMatch(opponent)
end

function M.update(dt)
    updateScale()

    if state.gameResult then return end

    -- Turn transition delay
    if state.gamePhase == "turnOver" then
        state.turnDelayTimer = state.turnDelayTimer - dt
        if state.turnDelayTimer <= 0 then
            if state.currentPlayer == 1 then
                -- Player's turn ended, switch to opponent AI
                state.currentPlayer = 2
                startAIThinking()
            else
                -- Opponent's turn ended, back to player
                state.currentPlayer = 1
                state.gamePhase = "aim"
            end
        end
        return
    end

    -- AI thinking: animate cue stick rotation, then shoot
    if state.gamePhase == "aiThinking" then
        state.aiThinkTimer = state.aiThinkTimer - dt

        -- Lerp cue stick angle during think time
        local elapsed = state.aiThinkDuration - state.aiThinkTimer
        local progress = smoothstep(math.min(1, elapsed / state.aiThinkDuration))
        state.aimAngle = lerpAngle(state.aiStartAngle, state.aiTargetAngle, progress)

        if state.aiThinkTimer <= 0 then
            -- Execute shot
            state.aimAngle = state.aiTargetAngle
            state.powerLevel = state.aiTargetPower
            state.pottedThisTurn = {}
            state.cueScratchedThisTurn = false
            rules.shoot(state, config)
        end
        return
    end

    -- Fixed-timestep sub-stepping for stable physics
    local fixedDt = config.PHYSICS_TIMESTEP
    state.physicsAccumulator = state.physicsAccumulator + dt
    while state.physicsAccumulator >= fixedDt do
        state.world:update(fixedDt)
        rules.applyPocketGravity(state, config, fixedDt)
        rules.checkPocketing(state, config)
        state.physicsAccumulator = state.physicsAccumulator - fixedDt
    end

    local cueBall = state.cueBall
    if state.gamePhase == "aim" and cueBall and not cueBall.pocketed then
        local smx, smy = love.mouse.getPosition()
        local mx, my = screenToDesign(smx, smy)
        local bx, by = cueBall.body:getPosition()
        state.aimAngle = math.atan2(my - by, mx - bx)
    end

    if state.gamePhase == "power" then
        state.powerTimer = state.powerTimer + dt * config.POWER_OSCILLATE_SPEED
        state.powerLevel = (math.sin(state.powerTimer * math.pi) + 1) / 2
    end

    if state.gamePhase == "moving" then
        if rules.allBallsAtRest(state, config) then
            rules.evaluateTurn(state, config)
            -- If evaluateTurn set turnOver, start the delay timer
            if state.gamePhase == "turnOver" then
                state.turnDelayTimer = config.TURN_DELAY
            end
            -- If AI gets another turn, initialize AI thinking
            if state.gamePhase == "aiThinking" then
                startAIThinking()
            end
        end
    end
end

function M.draw()
    render.draw(state, config)
end

function M.mousepressed(_x, _y, button)
    if button ~= 1 then return end

    if state.gameResult then
        if M.onMatchEnd then
            M.onMatchEnd(state.gameResult)
        else
            startMatch(state.opponent)
        end
        return
    end

    if state.gamePhase == "aim" and state.currentPlayer == 1 then
        state.gamePhase = "power"
        state.powerTimer = 0
        state.powerLevel = 0
    elseif state.gamePhase == "power" then
        state.pottedThisTurn = {}
        state.cueScratchedThisTurn = false
        rules.shoot(state, config)
    end
end

function M.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end

    if state.gameResult and key == "space" then
        if M.onMatchEnd then
            M.onMatchEnd(state.gameResult)
        else
            startMatch(state.opponent)
        end
    end
end

return M
