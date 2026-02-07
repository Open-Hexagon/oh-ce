local default_sounds = {
    beep_sound = "click.ogg",
    level_up_sound = "increment.ogg",
    swap_sound = "swap.ogg",
    death_sound = "death.ogg",
}
local level_status = {}

-- takes sync music because unless overwritten it is defined by the global config file
function level_status.reset(sync_music_to_dm)
    for sound, name in pairs(default_sounds) do
        level_status[sound] = name
    end
    level_status.tracked_variables = {}
    level_status.score_overwritten = false
    level_status.score_overwrite = ""
    level_status.sync_music_to_dm = sync_music_to_dm
    level_status.music_pitch = 1
    level_status.speed_mult = 1
    level_status.player_speed_mult = 1
    level_status.speed_inc = 0
    level_status.speed_max = 0
    level_status.rotation_speed = 0
    level_status.rotation_speed_inc = 0
    level_status.rotation_speed_max = 0
    level_status.delay_mult = 1
    level_status.delay_inc = 0
    level_status.delay_min = 0
    level_status.delay_max = 0
    level_status.fast_spin = 0
    level_status.inc_time = 15
    level_status.pulse_min = 75
    level_status.pulse_max = 80
    level_status.pulse_speed = 0
    level_status.pulse_speed_r = 0
    level_status.pulse_delay_max = 0
    level_status.pulse_initial_delay = 0
    level_status.swap_cooldown_mult = 1
    level_status.beat_pulse_initial_delay = 0
    level_status.beat_pulse_max = 0
    level_status.beat_pulse_delay_max = 0
    level_status.beat_pulse_speed_mult = 1
    level_status.radius_min = 72
    level_status.wall_skew_left = 0
    level_status.wall_skew_right = 0
    level_status.wall_angle_left = 0
    level_status.wall_angle_right = 0
    level_status.wall_spawn_distance = 1600
    level_status.camera_shake = 0
    level_status.sides = 6
    level_status.sides_max = 6
    level_status.sides_min = 6
    level_status.swap_enabled = false
    level_status.tutorial_mode = false
    level_status.pseudo_3D_required = false
    level_status.shaders_required = false
    level_status.inc_enabled = true
    level_status.rnd_side_changes_enabled = true
    level_status.darken_uneven_background_chunk = true
    level_status.manual_pulse_control = false
    level_status.manual_beat_pulse_control = false
    level_status.current_increments = 0
end

function level_status.has_speed_max_limit()
    return level_status.speed_max > 0
end

function level_status.has_delay_max_limit()
    return level_status.delay_max > 0
end

return level_status
