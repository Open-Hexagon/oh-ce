local make_make_accessors = require("compat.game21.lua_runtime.make_accessors")
local level_status = require("compat.game21.level_status")
local config = require("config")
local status = require("compat.game21.status")

return function(game)
    local lua_runtime = require("compat.game21.lua_runtime")
    local env = lua_runtime.env
    local make_accessors = make_make_accessors()
    local function make_accessor(prefix, name, t, f)
        env[prefix .. "_" .. name] = function(value)
            t[f] = value
        end
    end
    make_accessors("l", "SpeedMult", level_status, "speed_mult")
    make_accessors("l", "PlayerSpeedMult", level_status, "player_speed_mult")
    make_accessors("l", "SpeedInc", level_status, "speed_inc")
    make_accessors("l", "SpeedMax", level_status, "speed_max")
    make_accessors("l", "RotationSpeed", level_status, "rotation_speed")
    make_accessors("l", "RotationSpeedInc", level_status, "rotation_speed_inc")
    make_accessors("l", "RotationSpeedMax", level_status, "rotation_speed_max")
    make_accessors("l", "DelayMult", level_status, "delay_mult")
    make_accessors("l", "DelayInc", level_status, "delay_inc")
    make_accessors("l", "DelayMin", level_status, "delay_min")
    make_accessors("l", "DelayMax", level_status, "delay_max")
    make_accessors("l", "FastSpin", level_status, "fast_spin")
    make_accessors("l", "IncTime", level_status, "inc_time")
    make_accessors("l", "PulseMin", level_status, "pulse_min")
    make_accessors("l", "PulseMax", level_status, "pulse_max")
    make_accessors("l", "PulseSpeed", level_status, "pulse_speed")
    make_accessors("l", "PulseSpeedR", level_status, "pulse_speed_r")
    make_accessors("l", "PulseDelayMax", level_status, "pulse_delay_max")
    make_accessors("l", "PulseInitialDelay", level_status, "pulse_initial_delay")
    make_accessors("l", "SwapCooldownMult", level_status, "swap_cooldown_mult")
    make_accessors("l", "BeatPulseMax", level_status, "beat_pulse_max")
    make_accessors("l", "BeatPulseDelayMax", level_status, "beat_pulse_delay_max")
    make_accessors("l", "BeatPulseInitialDelay", level_status, "beat_pulse_initial_delay")
    make_accessors("l", "BeatPulseSpeedMult", level_status, "beat_pulse_speed_mult")
    make_accessors("l", "RadiusMin", level_status, "radius_min")
    make_accessors("l", "WallSkewLeft", level_status, "wall_skew_left")
    make_accessors("l", "WallSkewRight", level_status, "wall_skew_right")
    make_accessors("l", "WallAngleLeft", level_status, "wall_angle_left")
    make_accessors("l", "WallAngleRight", level_status, "wall_angle_right")
    make_accessors("l", "WallSpawnDistance", level_status, "wall_spawn_distance")
    make_accessors("l", "3dRequired", level_status, "pseudo_3D_required")
    make_accessors("l", "ShadersRequired", level_status, "shaders_required")
    make_accessors("l", "CameraShake", level_status, "camera_shake")
    make_accessors("l", "Sides", level_status, "sides")
    make_accessors("l", "SidesMin", level_status, "sides_min")
    make_accessors("l", "SidesMax", level_status, "sides_max")
    make_accessors("l", "SwapEnabled", level_status, "swap_enabled")
    make_accessors("l", "TutorialMode", level_status, "tutorial_mode")
    make_accessors("l", "IncEnabled", level_status, "inc_enabled")
    make_accessors("l", "DarkenUnevenBackgroundChunk", level_status, "darken_uneven_background_chunk")
    make_accessors("l", "ManualPulseControl", level_status, "manual_pulse_control")
    make_accessors("l", "ManualBeatPulseControl", level_status, "manual_beat_pulse_control")
    make_accessors("l", "CurrentIncrements", level_status, "current_increments")
    make_accessor("l", "enableRndSideChanges", level_status, "rnd_side_changes_enabled")
    env.l_addTracked = function(variable, name)
        level_status.tracked_variables[variable] = name
    end
    env.l_removeTracked = function(variable)
        level_status.tracked_variables[variable] = nil
    end
    env.l_clearTracked = function()
        level_status.tracked_variables = {}
    end
    env.l_getLevelTime = function()
        return status.get_time_seconds()
    end
    env.l_resetTime = function()
        status.reset_time()
    end
    make_accessors("l", "Pulse", status, "pulse")
    make_accessors("l", "PulseDirection", status, "pulse_direction")
    make_accessors("l", "PulseDelay", status, "pulse_delay")
    make_accessors("l", "BeatPulse", status, "beat_pulse")
    make_accessors("l", "BeatPulseDelay", status, "beat_pulse_delay")
    make_accessors("l", "ShowPlayerTrail", status, "show_player_trail")
    make_accessors("l", "Rotation", game, "current_rotation")
    env.l_overrideScore = function(variable)
        level_status.score_overwrite = variable
        level_status.score_overwritten = true
        if type(env[variable]) ~= "number" then
            lua_runtime.error("Score override must be a number value")
        end
    end
    env.l_getOfficial = function()
        return config.get("official_mode")
    end
end
