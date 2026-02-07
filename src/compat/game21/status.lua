local status = {}

local _total_frametime_accumulator = 0
local _played_frametime_accumulator = 0
local _paused_frametime_accumulator = 0
local _current_pause = 6
local _current_increment_time = 0
local _custom_score = 0

function status.reset_all_data()
    _total_frametime_accumulator = 0
    _played_frametime_accumulator = 0
    _paused_frametime_accumulator = 0
    _current_pause = 6
    _current_increment_time = 0
    _custom_score = 0
    status.flash_color = { 0, 0, 0 }
    status.pulse = 75
    status.pulse_direction = 1
    status.pulse_delay = 0
    status.beat_pulse = 0
    status.beat_pulse_delay = 0
    status.pulse3D = 1
    status.pulse3D_direction = 1
    status.flash_effect = 0
    status.radius = 75
    status.fast_spin = 0
    status.camera_shake = 0
    status.has_died = false
    status.score_invalid = false
    status.invalid_reason = ""
    status.started = false
    status.show_player_trail = true
    status.fragment_shaders = {}
end

function status.start()
    status.reset_time()
    _custom_score = 0
    status.started = true
end

function status.get_increment_time_seconds()
    return _current_increment_time / 60
end

function status.get_time_seconds()
    return status.get_played_accumulated_frametime_in_seconds()
end

function status.get_current_tp()
    return math.floor(status.get_total_accumulated_frametime_in_seconds() * 1000)
end

function status.get_time_tp()
    return math.floor(status.get_played_accumulated_frametime_in_seconds() * 1000)
end

function status.get_level_start_tp()
    return 0
end

function status.is_time_paused()
    return _current_pause > 0
end

function status.pause_time(time)
    _current_pause = _current_pause + time * 60
end

function status.reset_increment_time()
    _current_increment_time = 0
end

function status.reset_time()
    _total_frametime_accumulator = 0
    _played_frametime_accumulator = 0
    _paused_frametime_accumulator = 0
    _current_pause = 6
    _current_increment_time = 0
end

function status.accumulate_frametime(ft)
    _total_frametime_accumulator = _total_frametime_accumulator + ft
    if _current_pause > 0 then
        _current_pause = _current_pause - ft
    else
        _played_frametime_accumulator = _played_frametime_accumulator + ft
        _current_increment_time = _current_increment_time + ft
    end
end

function status.update_custom_score(score)
    _custom_score = score
end

function status.get_total_accumulated_frametime()
    return _total_frametime_accumulator
end

function status.get_total_accumulated_frametime_in_seconds()
    return status.get_total_accumulated_frametime() / 60
end

function status.get_played_accumulated_frametime()
    return _played_frametime_accumulator
end

function status.get_played_accumulated_frametime_in_seconds()
    return status.get_played_accumulated_frametime() / 60
end

function status.get_paused_accumulated_frametime()
    return _paused_frametime_accumulator
end

function status.get_paused_accumulated_frametime_in_seconds()
    return status.get_paused_accumulated_frametime() / 60
end

function status.get_custom_score()
    return _custom_score
end

status.reset_all_data()

return status
