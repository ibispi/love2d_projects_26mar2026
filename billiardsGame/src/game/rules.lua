local M = {}

function M.countBallsByColor(state, color)
    local count = 0
    for _, ball in ipairs(state.balls) do
        if not ball.pocketed and ball.ballColor == color then
            count = count + 1
        end
    end
    return count
end

function M.respawnCueBall(state)
    local cueBall = state.cueBall
    if not cueBall then return end
    cueBall.pocketed = false
    local cx = state.tableLeft + state.tableW * 0.25
    local cy = state.tableTop + state.tableH * 0.5
    cueBall.body:setPosition(cx, cy)
    cueBall.body:setLinearVelocity(0, 0)
    cueBall.body:setAngularVelocity(0)
end

function M.checkPocketing(state, config)
    local threshold = config.HOLE_RADIUS * 0.7

    for _, pocket in ipairs(state.pockets) do
        -- Check cue ball
        local cueBall = state.cueBall
        if cueBall and not cueBall.pocketed then
            local bx, by = cueBall.body:getPosition()
            local dx = bx - pocket.x
            local dy = by - pocket.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < threshold then
                cueBall.pocketed = true
                cueBall.body:setLinearVelocity(0, 0)
                cueBall.body:setAngularVelocity(0)
                -- Move off-screen
                cueBall.body:setPosition(-100, -100)
                state.cueScratchedThisTurn = true
            end
        end

        -- Check object balls
        for _, ball in ipairs(state.balls) do
            if not ball.pocketed then
                local bx, by = ball.body:getPosition()
                local dx = bx - pocket.x
                local dy = by - pocket.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < threshold then
                    ball.pocketed = true
                    ball.body:setLinearVelocity(0, 0)
                    ball.body:setAngularVelocity(0)
                    ball.body:setPosition(-100, -100)
                    table.insert(state.pottedThisTurn, ball.ballColor)
                end
            end
        end
    end
end

function M.applyPocketGravity(state, config, dt)
    local gravRadius = config.POCKET_GRAVITY_RADIUS
    local gravStrength = config.POCKET_GRAVITY_STRENGTH
    if not gravRadius or gravRadius <= 0 or not gravStrength or gravStrength <= 0 then return end

    local threshold = config.HOLE_RADIUS * 0.7

    local function pullBall(body, radius)
        for _, pocket in ipairs(state.pockets) do
            local bx, by = body:getPosition()
            local dx = pocket.x - bx
            local dy = pocket.y - by
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > threshold and dist < radius then
                -- How deep into the gravity zone (0 at edge, 1 at threshold)
                local t = 1 - (dist - threshold) / (radius - threshold)
                -- Set velocity directly toward pocket, killing any lateral motion
                local speed = gravStrength * t
                body:setLinearVelocity(dx / dist * speed, dy / dist * speed)
                return -- only one pocket can capture at a time
            end
        end
    end

    -- Cue ball uses its own smaller gravity radius
    local cueBall = state.cueBall
    local cueGravRadius = config.CUE_BALL_GRAVITY_RADIUS
    if cueBall and not cueBall.pocketed and cueGravRadius > 0 then
        pullBall(cueBall.body, cueGravRadius)
    end

    for _, ball in ipairs(state.balls) do
        if not ball.pocketed then
            if ball.ballColor == "black" then
                -- Only apply gravity to the black ball when potting it would win
                local myColor
                if state.currentPlayer == 1 then
                    myColor = state.playerColor
                else
                    myColor = state.opponentColor
                end
                if myColor and M.countBallsByColor(state, myColor) == 0 then
                    pullBall(ball.body, gravRadius)
                end
            else
                pullBall(ball.body, gravRadius)
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
    for _, ball in ipairs(state.balls) do
        if not ball.pocketed then
            local vx, vy = ball.body:getLinearVelocity()
            if math.sqrt(vx * vx + vy * vy) > threshold then return false end
        end
    end

    -- Zero out velocities when at rest
    if cueBall and not cueBall.pocketed then
        cueBall.body:setLinearVelocity(0, 0)
        cueBall.body:setAngularVelocity(0)
    end
    for _, ball in ipairs(state.balls) do
        if not ball.pocketed then
            ball.body:setLinearVelocity(0, 0)
            ball.body:setAngularVelocity(0)
        end
    end
    return true
end

function M.evaluateTurn(state, config)
    local potted = state.pottedThisTurn
    local scratched = state.cueScratchedThisTurn

    -- Check if black ball was potted
    local blackPotted = false
    for _, color in ipairs(potted) do
        if color == "black" then
            blackPotted = true
            break
        end
    end

    if blackPotted then
        local myColor = state.playerColor
        if state.currentPlayer == 1 then
            -- Player potted the black ball
            if myColor and M.countBallsByColor(state, myColor) == 0 then
                state.gameResult = "win"
            else
                state.gameResult = "lose"
            end
        else
            -- Opponent potted the black ball
            local oppColor = state.opponentColor
            if oppColor and M.countBallsByColor(state, oppColor) == 0 then
                state.gameResult = "lose" -- opponent wins = player loses
            else
                state.gameResult = "win" -- opponent fouled = player wins
            end
        end
        state.gamePhase = "gameOver"
        return
    end

    -- Handle scratch
    if scratched then
        M.respawnCueBall(state)
        -- Turn passes
        state.gamePhase = "turnOver"
        return
    end

    -- Assign player color on first pot (if not yet assigned)
    if not state.playerColor and #potted > 0 and state.currentPlayer == 1 then
        for _, color in ipairs(potted) do
            if color == "red" or color == "blue" then
                state.playerColor = color
                state.opponentColor = (color == "red") and "blue" or "red"
                break
            end
        end
    elseif not state.playerColor and #potted > 0 and state.currentPlayer == 2 then
        for _, color in ipairs(potted) do
            if color == "red" or color == "blue" then
                state.opponentColor = color
                state.playerColor = (color == "red") and "blue" or "red"
                break
            end
        end
    end

    -- Determine if current player gets another turn
    if #potted > 0 and state.playerColor then
        local myColor
        if state.currentPlayer == 1 then
            myColor = state.playerColor
        else
            myColor = state.opponentColor
        end

        local pottedOwn = false
        for _, color in ipairs(potted) do
            if color == myColor then
                pottedOwn = true
                break
            end
        end

        if pottedOwn then
            -- Another turn for current player
            if state.currentPlayer == 1 then
                state.gamePhase = "aim"
            else
                state.gamePhase = "turnOver"
            end
            return
        end
    end

    -- No pot or potted opponent's ball: turn passes
    state.gamePhase = "turnOver"
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
