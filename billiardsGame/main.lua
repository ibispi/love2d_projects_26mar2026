-- Billiards — entry point (logic in src/)

local game = require("src.app")

function love.load()
    game.load()
end

function love.update(dt)
    game.update(dt)
end

function love.draw()
    game.draw()
end

function love.mousepressed(x, y, button)
    game.mousepressed(x, y, button)
end

function love.keypressed(key)
    game.keypressed(key)
end
