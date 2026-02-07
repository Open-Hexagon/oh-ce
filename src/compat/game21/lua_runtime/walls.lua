local walls = require("compat.game21.walls")

return function(game)
    local env = require("compat.game21.lua_runtime").env
    local function wall(
        hue_modifier,
        side,
        thickness,
        speed_mult,
        acceleration,
        min_speed,
        max_speed,
        ping_pong,
        curving,
        speed_data_wall_thing
    )
        game.main_timeline:append_do(function()
            walls.wall(
                game.get_speed_mult_dm(),
                game.difficulty_mult,
                hue_modifier,
                side,
                thickness,
                speed_mult,
                acceleration,
                min_speed,
                max_speed,
                ping_pong,
                curving,
                speed_data_wall_thing
            )
        end)
    end
    env.w_wall = function(side, thickness)
        wall(0, side, thickness)
    end
    env.w_wallAdj = function(side, thickness, speed_mult)
        wall(0, side, thickness, speed_mult)
    end
    env.w_wallAcc = function(side, thickness, speed_mult, acceleration, min_speed, max_speed)
        wall(0, side, thickness, speed_mult, acceleration, min_speed, max_speed)
    end
    env.w_wallHModSpeedData = function(
        hue_modifier,
        side,
        thickness,
        speed_mult,
        acceleration,
        min_speed,
        max_speed,
        ping_pong
    )
        wall(hue_modifier, side, thickness, speed_mult, acceleration, min_speed, max_speed, ping_pong, false, true)
    end
    env.w_wallHModCurveData = function(
        hue_modifier,
        side,
        thickness,
        speed_mult,
        acceleration,
        min_speed,
        max_speed,
        ping_pong
    )
        wall(hue_modifier, side, thickness, speed_mult, acceleration, min_speed, max_speed, ping_pong, true)
    end
end
