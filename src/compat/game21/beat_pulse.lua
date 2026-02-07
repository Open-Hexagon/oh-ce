local config = require("config")
local level_status = require("compat.game21.level_status")
local status = require("compat.game21.status")
local beat_pulse = {}

function beat_pulse.init()
    status.beat_pulse_delay = status.beat_pulse_delay + level_status.beat_pulse_initial_delay
end

function beat_pulse.update(frametime, dm_factor)
    if config.get("beatpulse") then
        if not level_status.manual_beat_pulse_control then
            if status.beat_pulse_delay <= 0 then
                status.beat_pulse = level_status.beat_pulse_max
                status.beat_pulse_delay = level_status.beat_pulse_delay_max
            else
                status.beat_pulse_delay = status.beat_pulse_delay - frametime * dm_factor
            end
            if status.beat_pulse > 0 then
                status.beat_pulse = status.beat_pulse - 2 * frametime * dm_factor * level_status.beat_pulse_speed_mult
            end
        end
    end
    local radius_min = config.get("beatpulse") and level_status.radius_min or 75
    status.radius = radius_min * (status.pulse / level_status.pulse_min) + status.beat_pulse
end

return beat_pulse
