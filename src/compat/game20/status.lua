local status = {}

function status.reset()
    status.current_time = 0
    status.increment_time = 0
    status.time_stop = 50
    status.pulse = 75
    status.pulse_direction = 1
    status.pulse_delay = 0
    status.pulse_delay_half = 0
    status.beatpulse = 0
    status.beatpulse_delay = 0
    status.pulse_3D = 1
    status.pulse_3D_direction = 1
    status.flash_effect = 0
    status.radius = 75
    status.fast_spin = 0
    status.has_died = false
    status.must_restart = false
    status.score_invalid = false
    status.override_color = { 0, 0, 0, 0 }
    status.lost_frames = 0
end

return status
