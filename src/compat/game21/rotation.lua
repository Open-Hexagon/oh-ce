local level_status = require("compat.game21.level_status")
local status = require("compat.game21.status")
local rotation = {}

local function get_sign(num)
    return (num > 0 and 1 or (num == 0 and 0 or -1))
end
local function get_smoother_step(edge0, edge1, x)
    x = math.max(0, math.min(1, (x - edge0) / (edge1 - edge0)))
    return x * x * x * (x * (x * 6 - 15) + 10)
end

function rotation.update(game, frametime)
    local next_rotation = level_status.rotation_speed * 10
    if status.fast_spin > 0 then
        next_rotation = next_rotation
            + math.abs((get_smoother_step(0, level_status.fast_spin, status.fast_spin) / 3.5) * 17)
                * get_sign(next_rotation)
        status.fast_spin = status.fast_spin - frametime
    end
    game.current_rotation = (game.current_rotation + next_rotation * frametime) % 360
end

function rotation.apply(game)
    love.graphics.rotate(-math.rad(game.current_rotation))
end

return rotation
