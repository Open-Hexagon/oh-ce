local level_status = require("compat.game21.level_status")
local utils = require("compat.game192.utils")
local config = require("config")
local status = require("compat.game21.status")
local pulse = {}

function pulse.init()
    status.pulse_delay = status.pulse_delay + level_status.pulse_initial_delay
end

function pulse.update(frametime, dm_factor)
    if not level_status.manual_pulse_control then
        status.pulse_delay = status.pulse_delay
        if status.pulse_delay <= 0 then
            local pulse_add = status.pulse_direction > 0 and level_status.pulse_speed or -level_status.pulse_speed_r
            local pulse_limit = status.pulse_direction > 0 and level_status.pulse_max or level_status.pulse_min
            status.pulse = utils.float_round(status.pulse + pulse_add * frametime * dm_factor)
            if
                (status.pulse_direction > 0 and status.pulse >= pulse_limit)
                or (status.pulse_direction < 0 and status.pulse <= pulse_limit)
            then
                status.pulse = pulse_limit
                status.pulse_direction = -status.pulse_direction
                if status.pulse_direction < 0 then
                    status.pulse_delay = level_status.pulse_delay_max
                end
            end
        end
        status.pulse_delay = status.pulse_delay - frametime * dm_factor
    end
end

function pulse.get_zoom(zoom_factor)
    local p = config.get("pulse") and status.pulse / level_status.pulse_min or 1
    return zoom_factor / p
end

return pulse
