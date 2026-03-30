local M = {}

local function beginContact(_a, _b, _contact)
    -- Pocketing handled in update via distance check
end

function M.setWorldCallbacks(world)
    world:setCallbacks(beginContact, nil, nil, nil)
end

function M.createRails(state, config)
    local world = state.world
    local rails = state.rails
    local tableLeft, tableRight = state.tableLeft, state.tableRight
    local tableTop, tableBottom = state.tableTop, state.tableBottom
    local tableW, tableH = state.tableW, state.tableH
    local rt = config.RAIL_THICKNESS

    local cx = (tableLeft + tableRight) / 2
    local cy = (tableTop + tableBottom) / 2

    -- Horizontal rails span the table width only (no overlap with vertical rails)
    local top = {}
    top.body = love.physics.newBody(world, cx, tableTop - rt / 2, "static")
    top.shape = love.physics.newRectangleShape(tableW, rt)
    top.fixture = love.physics.newFixture(top.body, top.shape)
    top.fixture:setRestitution(0.85)
    top.fixture:setFriction(0.05)
    table.insert(rails, top)

    local bot = {}
    bot.body = love.physics.newBody(world, cx, tableBottom + rt / 2, "static")
    bot.shape = love.physics.newRectangleShape(tableW, rt)
    bot.fixture = love.physics.newFixture(bot.body, bot.shape)
    bot.fixture:setRestitution(0.85)
    bot.fixture:setFriction(0.05)
    table.insert(rails, bot)

    -- Vertical rails span the full height including corners
    local fullH = tableH + rt * 2
    local left = {}
    left.body = love.physics.newBody(world, tableLeft - rt / 2, cy, "static")
    left.shape = love.physics.newRectangleShape(rt, fullH)
    left.fixture = love.physics.newFixture(left.body, left.shape)
    left.fixture:setRestitution(0.85)
    left.fixture:setFriction(0.05)
    table.insert(rails, left)

    local right = {}
    right.body = love.physics.newBody(world, tableRight + rt / 2, cy, "static")
    right.shape = love.physics.newRectangleShape(rt, fullH)
    right.fixture = love.physics.newFixture(right.body, right.shape)
    right.fixture:setRestitution(0.85)
    right.fixture:setFriction(0.05)
    table.insert(rails, right)
end

function M.createBall(state, config, x, y, ballColor)
    local world = state.world
    local r = config.BALL_RADIUS
    local ball = {}
    ball.ballColor = ballColor
    ball.body = love.physics.newBody(world, x, y, "dynamic")
    ball.body:setBullet(true)
    ball.shape = love.physics.newCircleShape(r)
    ball.fixture = love.physics.newFixture(ball.body, ball.shape, 1)
    ball.fixture:setRestitution(0.92)
    ball.fixture:setFriction(0.15)
    ball.body:setLinearDamping(0.65)
    ball.body:setAngularDamping(0.3)
    ball.fixture:setUserData({type = ballColor, ball = ball})
    ball.pocketed = false
    return ball
end

function M.createHole(state, config, x, y)
    local world = state.world
    local hole = {}
    hole.x = x
    hole.y = y
    hole.body = love.physics.newBody(world, x, y, "static")
    hole.shape = love.physics.newCircleShape(config.HOLE_RADIUS)
    hole.fixture = love.physics.newFixture(hole.body, hole.shape)
    hole.fixture:setSensor(true)
    hole.fixture:setUserData({type = "hole"})
    return hole
end

return M
