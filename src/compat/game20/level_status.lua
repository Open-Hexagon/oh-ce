local level_status = {}

function level_status.reset()
    level_status.tracked_variables = {}
    level_status.speed_mult = 1
    level_status.speed_inc = 0
    level_status.rotation_speed = 0
    level_status.rotation_speed_inc = 0
    level_status.rotation_speed_max = 0
    level_status.delay_mult = 1
    level_status.delay_inc = 0
    level_status.fast_spin = 0
    level_status.inc_time = 15
    level_status.pulse_min = 75
    level_status.pulse_max = 80
    level_status.pulse_speed = 0
    level_status.pulse_speed_r = 0
    level_status.pulse_delay_max = 0
    level_status.pulse_delay_half_max = 0
    level_status.beat_pulse_max = 0
    level_status.beat_pulse_delay_max = 0
    level_status.radius_min = 72
    level_status.wall_skew_left = 0
    level_status.wall_skew_right = 0
    level_status.wall_angle_left = 0
    level_status.wall_angle_right = 0
    level_status._3D_effect_multiplier = 1
    level_status.sides = 6
    level_status.sides_max = 6
    level_status.sides_min = 6
    level_status.swap_enabled = false
    level_status.tutorial_mode = false
    level_status.inc_enabled = true
    level_status.rnd_side_changes_enabled = true
end

return level_status
