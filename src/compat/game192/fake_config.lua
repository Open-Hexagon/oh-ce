return function(config)
    local config_str = [[{
        // Online capabilities
        "online": true,

        // Official mode - if set to false, you won't be eligible for online scores - this setting ignores some of the customizable options
        "official": <official>,

        // Window options
        "fullscreen": true,
        "fullscreen_auto_resolution": true,
        "fullscreen_width": 1024,
        "fullscreen_height": 768,
        "windowed_auto_resolution": true,
        "windowed_width": 1024,
        "windowed_height": 768,
        "auto_zoom_factor": true, // Ignored in official mode
        "zoom_factor": 1,
        "pixel_multiplier": 1,
        
        // FPS options
        "static_frametime": false, // Ignored in official mode
        "static_frametime_value": 1,
        "limit_fps": false,
        "vsync": false,
        
        // Graphical options
        "no_rotation": <no_rotation>, // Ignored in official mode
        "no_background": <no_background>, // Ignored in official mode
        "black_and_white": <black_and_white>, // Ignored in official mode
        "pulse_enabled": <pulse_enabled>, // Ignored in official mode
        "beatpulse_enabled": <beatpulse_enabled>, // Ignored in official mode
        "3D_enabled": <3D_enabled>,
        "3D_multiplier": <3D_multiplier>,
        "3D_max_depth": <3D_max_depth>,
        "flash_enabled": <flash_enabled>,
        
        // Audio options
        "no_sound": false,
        "no_music": false,
        "sound_volume": 100,
        "music_volume": 100,	
        
        // Player options
        "player_speed": <player_speed>, // Ignored in official mode
        "player_focus_speed": <player_focus_speed>, // Ignored in official mode
        "player_size": <player_size>, // Ignored in official mode
        "auto_restart": false,
        
        // Scripting options
        "debug": false,
        "show_messages": <show_messages>,
        "change_styles": true,
        "change_music": true,
        
        // Cheats
        "invincible": <invincible>, // Ignored in official mode

        // Inputs
        "t_rotate_ccw":		[ ["kLeft"] ],
        "t_rotate_cw":		[ ["kRight"] ],
        "t_focus":			[ ["kLShift"] ],
        "t_exit": 			[ ["kEscape"] ],
        "t_force_restart": 	[ ["kR"], ["kUp"] ],
        "t_restart":		[ ["kReturn"], ["kSpace"] ],
        "t_screenshot":		[ ["kF12"] ]
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
