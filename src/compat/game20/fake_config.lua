return function(config)
    local config_str = [[{
        "3D_enabled" : <3D_enabled>,
        "3D_max_depth" : <3D_max_depth>,
        "3D_multiplier" : <3D_multiplier>,
        "antialiasing_level" : 3,
        "auto_restart" : false,
        "auto_zoom_factor" : true,
        "beatpulse_enabled" : <beatpulse_enabled>,
        "black_and_white" : <black_and_white>,
        "debug" : false,
        "flash_enabled" : <flash_enabled>,
        "fullscreen" : true,
        "fullscreen_auto_resolution" : false,
        "fullscreen_height" : 1080,
        "fullscreen_width" : 1920,
        "invincible" : <invincible>,
        "limit_fps" : true,
        "max_fps" : 200,
        "music_speed_dm_sync" : true,
        "music_volume" : 100.0,
        "no_background" : <no_background>,
        "no_music" : false,
        "no_rotation" : <no_rotation>,
        "no_sound" : false,
        "official" : <official>,
        "online" : true,
        "pixel_multiplier" : 1,
        "player_focus_speed" : <player_focus_speed>,
        "player_size" : <player_size>,
        "player_speed" : <player_speed>,
        "pulse_enabled" : <pulse_enabled>,
        "server_local" : false,
        "server_verbose" : false,
        "show_fps" : true,
        "show_messages" : <show_messages>,
        "show_tracked_variables" : true,
        "sound_volume" : 100.0,
        "t_exit" :
        [
            [ "kEscape" ]
        ],
        "t_focus" :
        [
            [ "kLShift" ],
        ],
        "t_force_restart" :
        [
            [ "kR" ],
            [ "kUp" ],
        ],
        "t_restart" :
        [
            [ "kReturn" ],
        ],
        "t_rotate_ccw" :
        [
            [ "kLeft" ],
        ],
        "t_rotate_cw" :
        [
            [ "kRight" ],
        ],
        "t_screenshot" :
        [
            [ "kF12" ]
        ],
        "t_swap" :
        [
            [ "kSpace" ],
        ],
        "timer_static" : true,
        "vsync" : false,
        "windowed_auto_resolution" : false,
        "windowed_height" : 1080,
        "windowed_width" : 1920,
        "zoom_factor" : 1.600000023841858
    }]]
    local function setv(fake_name, value)
        local n
        config_str, n = config_str:gsub("<" .. fake_name .. ">", tostring(value))
        if n == 0 then
            error(fake_name .. " not found in config string.")
        end
    end
    local function set(fake_name, name)
        setv(fake_name, config.get(name))
    end
    set("official", "official_mode")
    setv("no_rotation", not config.get("rotation"))
    setv("no_background", not config.get("background"))
    set("black_and_white", "black_and_white")
    set("pulse_enabled", "pulse")
    set("beatpulse_enabled", "beatpulse")
    set("3D_enabled", "3D_enabled")
    set("3D_multiplier", "3D_multiplier")
    set("3D_max_depth", "3D_max_depth")
    set("flash_enabled", "flash")
    set("player_speed", "player_speed")
    set("player_focus_speed", "player_focus_speed")
    set("player_size", "player_size")
    set("show_messages", "messages")
    set("invincible", "invincible")
    return config_str
end
