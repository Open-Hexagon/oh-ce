local config = require("config")
local level_status = require("compat.game21.level_status")
local rng = require("compat.game21.random")
local status = require("compat.game21.status")
local shake = {}
local death_shake_translate = { 0, 0 }

function shake.start()
    status.camera_shake = 45 * config.get("camera_shake_mult")
end

function shake.update(frametime)
    if status.camera_shake <= 0 then
        death_shake_translate[1] = 0
        death_shake_translate[2] = 0
    else
        status.camera_shake = status.camera_shake - frametime
        local i = status.camera_shake
        death_shake_translate[1] = rng.get_real(-i, i)
        death_shake_translate[2] = rng.get_real(-i, i)
    end
end

function shake.apply()
    -- normal death shake
    love.graphics.translate(unpack(death_shake_translate))

    if not status.has_died then
        -- custom shake from level
        if level_status.camera_shake > 0 then
            love.graphics.translate(
                -- use love.math.random instead of math.random to not break replay rng
                (love.math.random() * 2 - 1) * level_status.camera_shake,
                (love.math.random() * 2 - 1) * level_status.camera_shake
            )
        end
    end
end

return shake
