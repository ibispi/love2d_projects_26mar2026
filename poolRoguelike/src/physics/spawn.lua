local M = {}

function M.findValidPosition(state, config, occupied, margin)
    local padding = 40
    local tableLeft, tableTop = state.tableLeft, state.tableTop
    local tableW, tableH = state.tableW, state.tableH
    for _ = 1, 500 do
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
    return tableLeft + tableW * 0.5, tableTop + tableH * 0.5
end

return M
