local M = {}

local function dist(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- Distance from point (px,py) to the line segment (ax,ay)-(bx,by)
local function pointToSegmentDist(px, py, ax, ay, bx, by)
    local abx = bx - ax
    local aby = by - ay
    local ab2 = abx * abx + aby * aby
    if ab2 < 0.001 then return dist(px, py, ax, ay) end
    local t = ((px - ax) * abx + (py - ay) * aby) / ab2
    t = math.max(0, math.min(1, t))
    local cx = ax + t * abx
    local cy = ay + t * aby
    return dist(px, py, cx, cy)
end

-- Check if any ball (except excludeBall) blocks the path from (ax,ay) to (bx,by)
local function isPathBlocked(ax, ay, bx, by, balls, excludeBall, ballRadius)
    local blockRadius = ballRadius * 2.2
    for _, ball in ipairs(balls) do
        if not ball.pocketed and ball ~= excludeBall then
            local bpx, bpy = ball.body:getPosition()
            local d = pointToSegmentDist(bpx, bpy, ax, ay, bx, by)
            if d < blockRadius then
                return true
            end
        end
    end
    return false
end

function M.calculateShot(state, config, opponent)
    local cueBall = state.cueBall
    if not cueBall or cueBall.pocketed then
        return 0, 0.3
    end

    local cbx, cby = cueBall.body:getPosition()
    local br = config.BALL_RADIUS
    local aiSettings = opponent.ai

    -- Determine which color to target
    local myColor = state.opponentColor

    -- Gather AI's balls
    local myBalls = {}
    for _, ball in ipairs(state.balls) do
        if not ball.pocketed and ball.ballColor == myColor then
            table.insert(myBalls, ball)
        end
    end

    -- If no colored balls left, target the black ball
    if #myBalls == 0 then
        for _, ball in ipairs(state.balls) do
            if not ball.pocketed and ball.ballColor == "black" then
                table.insert(myBalls, ball)
                break
            end
        end
    end

    -- Score each ball-pocket combination
    local shots = {}
    for _, ball in ipairs(myBalls) do
        local bx, by = ball.body:getPosition()
        for _, pocket in ipairs(state.pockets) do
            local tpDist = dist(bx, by, pocket.x, pocket.y)
            if tpDist > 1 then
                -- Ghost ball: where cue ball center must be at contact
                -- to send target ball toward pocket
                local nx = (bx - pocket.x) / tpDist
                local ny = (by - pocket.y) / tpDist
                local ghostX = bx + nx * br * 2
                local ghostY = by + ny * br * 2

                local cueToDist = dist(cbx, cby, ghostX, ghostY)

                -- Alignment: angle between cue->target and target->pocket
                local ctAngle = math.atan2(by - cby, bx - cbx)
                local tpAngle = math.atan2(pocket.y - by, pocket.x - bx)
                local angleDiff = math.abs(ctAngle - tpAngle)
                if angleDiff > math.pi then angleDiff = 2 * math.pi - angleDiff end

                -- Only consider shots with reasonable alignment (< 108 degrees)
                if angleDiff < math.pi * 0.6 then
                    -- Score components
                    local maxDist = 1500
                    local distScore = math.max(0, 1 - cueToDist / maxDist)
                    local pocketScore = math.max(0, 1 - tpDist / maxDist)
                    local alignScore = math.max(0, 1 - angleDiff / (math.pi * 0.5))

                    local score = distScore * 0.25 + pocketScore * 0.30 + alignScore * 0.45

                    -- Path obstruction penalties
                    local cueBlocked = isPathBlocked(cbx, cby, ghostX, ghostY, state.balls, ball, br)
                    local pocketBlocked = isPathBlocked(bx, by, pocket.x, pocket.y, state.balls, ball, br)
                    if cueBlocked then score = score * 0.1 end
                    if pocketBlocked then score = score * 0.15 end

                    table.insert(shots, {
                        ball = ball,
                        pocket = pocket,
                        ghostX = ghostX,
                        ghostY = ghostY,
                        score = score,
                        distance = cueToDist,
                    })
                end
            end
        end
    end

    -- Sort by score (best first)
    table.sort(shots, function(a, b) return a.score > b.score end)

    -- Pick shot based on aggression
    local pick
    if #shots > 0 then
        -- High aggression: wider pool (may pick suboptimal but exciting shots)
        -- Low aggression: picks from the very top
        local poolSize = math.max(1, math.ceil(#shots * aiSettings.aggression * 0.5))
        poolSize = math.min(poolSize, #shots)
        pick = shots[math.random(1, poolSize)]
    end

    if pick then
        -- Calculate angle to ghost ball
        local angle = math.atan2(pick.ghostY - cby, pick.ghostX - cbx)

        -- Apply inaccuracy
        local maxError = math.rad(15)
        local errorAmount = (math.random() * 2 - 1) * maxError * (1 - aiSettings.accuracy)
        angle = angle + errorAmount

        -- Calculate power based on distance
        local idealPower = math.min(0.85, math.max(0.25, pick.distance / 1200))

        -- Apply power control variance
        local powerVariance = 0.4
        local powerError = (math.random() * 2 - 1) * powerVariance * (1 - aiSettings.power_control)
        idealPower = idealPower * (1 + powerError)
        idealPower = math.min(1.0, math.max(0.15, idealPower))

        return angle, idealPower
    else
        -- Safety shot: aim at nearest own ball with low power
        if #myBalls > 0 then
            local nearest = myBalls[1]
            local nearDist = math.huge
            for _, ball in ipairs(myBalls) do
                local bx, by = ball.body:getPosition()
                local d = dist(cbx, cby, bx, by)
                if d < nearDist then
                    nearDist = d
                    nearest = ball
                end
            end
            local bx, by = nearest.body:getPosition()
            local angle = math.atan2(by - cby, bx - cbx)
            angle = angle + (math.random() * 2 - 1) * math.rad(10)
            return angle, 0.3
        end

        -- Complete fallback: random direction, medium power
        return math.random() * math.pi * 2, 0.3
    end
end

return M
