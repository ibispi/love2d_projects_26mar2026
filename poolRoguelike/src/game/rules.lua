local M = {}

function M.countRedBalls(state)
    return #state.redBalls
end

function M.pocketBall(state, config, ball, index)
    ball.pocketed = true
    ball.body:destroy()
    table.remove(state.redBalls, index)
    state.score = state.score + config.POINTS_PER_BALL
end

function M.respawnCueBall(state)
    local cueBall = state.cueBall
    if not cueBall then return end
    local cx = state.tableLeft + state.tableW * 0.25
    local cy = state.tableTop + state.tableH * 0.5
    cueBall.body:setPosition(cx, cy)
    cueBall.body:setLinearVelocity(0, 0)
    cueBall.body:setAngularVelocity(0)
end

function M.checkPocketing(state, config)
    local holeR = config.HOLE_RADIUS
    local threshold = holeR * 0.6
    for _, hole in ipairs(state.holes) do
        local cueBall = state.cueBall
        if cueBall and not cueBall.pocketed then
            local bx, by = cueBall.body:getPosition()
            local dx = bx - hole.x
            local dy = by - hole.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < threshold then
                state.score = math.max(0, state.score - config.SCRATCH_PENALTY)
                M.respawnCueBall(state)
            end
        end

        for i = #state.redBalls, 1, -1 do
            local ball = state.redBalls[i]
            if not ball.pocketed then
                local bx, by = ball.body:getPosition()
                local dx = bx - hole.x
                local dy = by - hole.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < threshold then
                    M.pocketBall(state, config, ball, i)
                end
            end
        end
    end
end

function M.allBallsAtRest(state, config)
    local threshold = config.REST_THRESHOLD
    local cueBall = state.cueBall
    if cueBall and not cueBall.pocketed then
        local vx, vy = cueBall.body:getLinearVelocity()
        if math.sqrt(vx * vx + vy * vy) > threshold then return false end
    end
    for _, ball in ipairs(state.redBalls) do
        if not ball.pocketed then
            local vx, vy = ball.body:getLinearVelocity()
            if math.sqrt(vx * vx + vy * vy) > threshold then return false end
        end
    end
    if cueBall and not cueBall.pocketed then
        cueBall.body:setLinearVelocity(0, 0)
        cueBall.body:setAngularVelocity(0)
    end
    for _, ball in ipairs(state.redBalls) do
        if not ball.pocketed then
            ball.body:setLinearVelocity(0, 0)
            ball.body:setAngularVelocity(0)
        end
    end
    return true
end

function M.shoot(state, config)
    local cueBall = state.cueBall
    if not cueBall or cueBall.pocketed then
        state.gamePhase = "aim"
        return
    end

    local force = state.powerLevel * config.MAX_SHOT_IMPULSE
    local fx = math.cos(state.aimAngle) * force
    local fy = math.sin(state.aimAngle) * force

    cueBall.body:applyLinearImpulse(fx, fy)
    state.gamePhase = "moving"
end

return M
