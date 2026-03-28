local config = require("src.config")
local physics = require("src.physics.table")
local rules = require("src.game.rules")
local render = require("src.render.draw")

local state = {
    world = nil,
    cueBall = nil,
    balls = {},       -- all 15 object balls (red, blue, black)
    pockets = {},
    rails = {},
    gamePhase = "aim", -- aim, power, moving, turnOver, gameOver
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
    playerColor = nil,   -- nil until first pot, then "red" or "blue"
    opponentColor = nil,
    gameResult = nil,    -- nil, "win", "lose"
    pottedThisTurn = {}, -- colors of balls potted during current shot
    cueScratchedThisTurn = false,
    turnDelayTimer = 0,
    physicsAccumulator = 0,
    -- Scaling state (computed each frame)
    scale = 1,
    offsetX = 0,
    offsetY = 0,
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

local function createPockets()
    state.pockets = {}
    local tl = state.tableLeft
    local tr = state.tableRight
    local tt = state.tableTop
    local tb = state.tableBottom
    local cx = (tl + tr) / 2

    local inset = config.CENTER_POCKET_INSET
    local positions = {
        {x = tl, y = tt},              -- top-left
        {x = cx, y = tt + inset},      -- top-middle (pushed inward)
        {x = tr, y = tt},              -- top-right
        {x = tl, y = tb},              -- bottom-left
        {x = cx, y = tb - inset},      -- bottom-middle (pushed inward)
        {x = tr, y = tb},              -- bottom-right
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

    -- Row spacing: horizontal distance between rows of tightly packed balls
    local rowDX = br * 2 * math.cos(math.rad(30))  -- = br * sqrt(3)

    -- Layout: each row lists ball colors top-to-bottom
    -- 7 red, 7 blue, 1 black = 15 total
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
            -- Center each row vertically
            local y = rackCenterY + (i - 1) * (br * 2) - (n - 1) * br
            local ball = physics.createBall(state, config, x, y, ballColor)
            table.insert(state.balls, ball)
        end
    end
end

local function startGame()
    state.gamePhase = "aim"
    state.balls = {}
    state.pockets = {}
    state.rails = {}
    state.currentPlayer = 1
    state.playerColor = nil
    state.opponentColor = nil
    state.gameResult = nil
    state.pottedThisTurn = {}
    state.cueScratchedThisTurn = false
    state.turnDelayTimer = 0

    state.world = love.physics.newWorld(0, 0, true)
    physics.setWorldCallbacks(state.world)

    physics.createRails(state, config)
    createPockets()

    -- Cue ball at 1/4 from left, centered vertically
    local cx = state.tableLeft + state.tableW * 0.25
    local cy = state.tableTop + state.tableH * 0.5
    state.cueBall = physics.createBall(state, config, cx, cy, "cue")

    createTriangleRack()
end

local M = {}

function M.load()
    love.window.setTitle("Billiards")
    love.window.setMode(config.DESIGN_W, config.DESIGN_H, {resizable = true})
    love.graphics.setBackgroundColor(0, 0, 0)

    computeTableBounds()
    updateScale()
    startGame()
end

function M.update(dt)
    updateScale()

    if state.gameResult then return end

    if state.gamePhase == "turnOver" then
        state.turnDelayTimer = state.turnDelayTimer - dt
        if state.turnDelayTimer <= 0 then
            if state.currentPlayer == 1 then
                -- Player's turn ended, switch to opponent
                state.currentPlayer = 2
                state.turnDelayTimer = config.TURN_DELAY
                -- Opponent has no AI yet, auto-pass after delay
            else
                -- Opponent's turn ended, back to player
                state.currentPlayer = 1
                state.gamePhase = "aim"
            end
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
        end
    end
end

function M.draw()
    render.draw(state, config)
end

function M.mousepressed(_x, _y, button)
    if button ~= 1 then return end

    if state.gameResult then
        startGame()
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
        startGame()
    end
end

return M
