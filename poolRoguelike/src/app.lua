local config = require("src.config")
local physics = require("src.physics.table")
local spawn = require("src.physics.spawn")
local rules = require("src.game.rules")
local render = require("src.render.draw")

local state = {
    world = nil,
    cueBall = nil,
    redBalls = {},
    holes = {},
    rails = {},
    score = 0,
    targetScore = config.TARGET_SCORE,
    gamePhase = "aim",
    aimAngle = 0,
    powerLevel = 0,
    powerTimer = 0,
    tableLeft = 0,
    tableTop = 0,
    tableRight = 0,
    tableBottom = 0,
    tableW = 0,
    tableH = 0,
}

local function computeTableBounds()
    local pad = config.TABLE_PADDING
    local rt = config.RAIL_THICKNESS
    state.tableLeft = pad + rt
    state.tableTop = pad + rt
    state.tableRight = config.WINDOW_W - pad - rt
    state.tableBottom = config.WINDOW_H - pad - rt
    state.tableW = state.tableRight - state.tableLeft
    state.tableH = state.tableBottom - state.tableTop
end

local function initRandomSeed()
    love.math.setRandomSeed(os.time())
end

local function startRound()
    initRandomSeed()

    state.score = 0
    state.gamePhase = "aim"
    state.redBalls = {}
    state.holes = {}
    state.rails = {}

    state.world = love.physics.newWorld(0, 0, true)
    physics.setWorldCallbacks(state.world)

    physics.createRails(state, config)

    local occupied = {}

    local hx, hy = spawn.findValidPosition(state, config, occupied, config.HOLE_RADIUS + 30)
    table.insert(occupied, {x = hx, y = hy, r = config.HOLE_RADIUS + config.BALL_RADIUS + 5})
    table.insert(state.holes, physics.createHole(state, config, hx, hy))

    local cx, cy = spawn.findValidPosition(state, config, occupied, config.BALL_RADIUS + 10)
    table.insert(occupied, {x = cx, y = cy, r = config.BALL_RADIUS * 3})
    state.cueBall = physics.createBall(state, config, cx, cy, "cue")

    for _ = 1, config.NUM_RED_BALLS do
        local rx, ry = spawn.findValidPosition(state, config, occupied, config.BALL_RADIUS + 5)
        table.insert(occupied, {x = rx, y = ry, r = config.BALL_RADIUS * 3})
        table.insert(state.redBalls, physics.createBall(state, config, rx, ry, "red"))
    end
end

local M = {}

function M.load()
    love.window.setTitle("Billiards Roguelike")
    love.window.setMode(config.WINDOW_W, config.WINDOW_H, {resizable = false})
    love.graphics.setBackgroundColor(config.COLOR_BG)

    computeTableBounds()
    startRound()
end

function M.update(dt)
    if state.gamePhase == "roundComplete" then return end

    state.world:update(dt)

    local cueBall = state.cueBall
    if state.gamePhase == "aim" and cueBall and not cueBall.pocketed then
        local mx, my = love.mouse.getPosition()
        local bx, by = cueBall.body:getPosition()
        state.aimAngle = math.atan2(my - by, mx - bx)
    end

    if state.gamePhase == "power" then
        state.powerTimer = state.powerTimer + dt * config.POWER_OSCILLATE_SPEED
        state.powerLevel = (math.sin(state.powerTimer * math.pi) + 1) / 2
    end

    rules.checkPocketing(state, config)

    if state.gamePhase == "moving" then
        if rules.allBallsAtRest(state, config) then
            if state.score >= state.targetScore or rules.countRedBalls(state) == 0 then
                state.gamePhase = "roundComplete"
            else
                state.gamePhase = "aim"
            end
        end
    end
end

function M.draw()
    render.draw(state, config)
end

function M.mousepressed(_x, _y, button)
    if button ~= 1 then return end

    if state.gamePhase == "aim" then
        state.gamePhase = "power"
        state.powerTimer = 0
        state.powerLevel = 0
    elseif state.gamePhase == "power" then
        rules.shoot(state, config)
    elseif state.gamePhase == "roundComplete" then
        startRound()
    end
end

function M.keypressed(key)
    if key == "space" and state.gamePhase == "roundComplete" then
        startRound()
    end
    if key == "escape" then
        love.event.quit()
    end
end

return M
