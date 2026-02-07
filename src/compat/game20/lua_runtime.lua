local log = require("log")(...)
local sound = require("compat.sound")
local utils = require("compat.game192.utils")
local speed_data = require("compat.game20.speed_data")
local config = require("config")
local input = require("input")
local status = require("compat.game20.status")
local level_status = require("compat.game20.level_status")
local vfs = require("compat.game192.virtual_filesystem")
local style = require("compat.game20.style")
local walls = require("compat.game20.walls")
local lua_runtime = {
    env = {},
}

local keycode_conversion = {
    [0] = "a",
    [1] = "b",
    [2] = "c",
    [3] = "d",
    [4] = "e",
    [5] = "f",
    [6] = "g",
    [7] = "h",
    [8] = "i",
    [9] = "j",
    [10] = "k",
    [11] = "l",
    [12] = "m",
    [13] = "n",
    [14] = "o",
    [15] = "p",
    [16] = "q",
    [17] = "r",
    [18] = "s",
    [19] = "t",
    [20] = "u",
    [21] = "v",
    [22] = "w",
    [23] = "x",
    [24] = "y",
    [25] = "z",
    [26] = "0",
    [27] = "1",
    [28] = "2",
    [29] = "3",
    [30] = "4",
    [31] = "5",
    [32] = "6",
    [33] = "7",
    [34] = "8",
    [35] = "9",
    [36] = "escape",
    [37] = "lctrl",
    [38] = "lshift",
    [39] = "lalt",
    [40] = "lgui",
    [41] = "rctrl",
    [42] = "rshift",
    [43] = "ralt",
    [44] = "rgui",
    [45] = "menu",
    [46] = "(",
    [47] = ")",
    [48] = ";",
    [49] = ",",
    [50] = ".",
    [51] = "'",
    [52] = "/",
    [53] = "\\",
    [54] = "~",
    [55] = "=",
    [56] = "-",
    [57] = "space",
    [58] = "return",
    [59] = "backspace",
    [60] = "tab",
    [61] = "pageup",
    [62] = "pagedown",
    [63] = "end",
    [64] = "home",
    [65] = "insert",
    [66] = "delete",
    [67] = "+",
    [68] = "-",
    [69] = "*",
    [70] = "/",
    [71] = "left",
    [72] = "right",
    [73] = "up",
    [74] = "down",
    [75] = "kp0",
    [76] = "kp1",
    [77] = "kp2",
    [78] = "kp3",
    [79] = "kp4",
    [80] = "kp5",
    [81] = "kp6",
    [82] = "kp7",
    [83] = "kp8",
    [84] = "kp9",
    [85] = "f1",
    [86] = "f2",
    [87] = "f3",
    [88] = "f4",
    [89] = "f5",
    [90] = "f6",
    [91] = "f7",
    [92] = "f8",
    [93] = "f9",
    [94] = "f10",
    [95] = "f11",
    [96] = "f12",
    [97] = "f13",
    [98] = "f14",
    [99] = "f15",
    [100] = "pause",
}
local file_cache = {}
local env = lua_runtime.env

function lua_runtime.error(msg)
    log(debug.traceback("Error: " .. msg))
end

function lua_runtime.init_env(game, public)
    file_cache = {} -- in case lua files changed since last execution
    lua_runtime.env = {
        os = {
            time = function(...)
                return os.time(...)
            end,
            clock = function()
                return game.real_time
            end,
            execute = function(command)
                log("Level attempted to execute potentially malicious command: '" .. command .. "'")
            end,
            remove = vfs.remove,
        },
        next = next,
        error = error,
        assert = assert,
        pcall = pcall,
        xpcall = xpcall,
        tonumber = tonumber,
        coroutine = coroutine,
        unpack = unpack,
        table = table,
        getmetatable = getmetatable,
        setmetatable = setmetatable,
        type = type,
        string = string,
        ipairs = ipairs,
        pairs = pairs,
        print = print,
        io = vfs.io,
        math = {
            randomseed = function(seed)
                math.randomseed(input.next_seed(seed))
            end,
        },
        tostring = tostring,
        load = function(...)
            local f = load(...)
            if f then
                setfenv(f, lua_runtime.env)
            end
            return f
        end,
    }
    env = lua_runtime.env
    env._G = env
    env.math = setmetatable(env.math, { __index = math })
    env.dofile = function(path)
        local file = vfs.io.open(path, "r")
        if file then
            local code = file:read("*a")
            file:close()
            local func = loadstring(code)
            if func == nil then
                error("Failed executing virtual file '" .. path .. "'")
            end
            setfenv(func, env)
            return func()
        end
    end

    -- utils
    env.u_log = function(message)
        log("Lua: " .. message)
    end
    env.u_execScript = function(script)
        lua_runtime.run_lua_file(game.pack.info.path .. "Scripts/" .. script)
    end
    env.u_playSound = function(name)
        sound.play_pack(game.pack, name)
    end
    env.u_isKeyPressed = function(key_code)
        local key = keycode_conversion[key_code]
        if key == nil then
            lua_runtime.error("Could not find key with sfml keycode '" .. key_code .. "'!")
            return false
        end
        return input.get(key)
    end
    env.u_isFastSpinning = function()
        return status.fast_spin > 0
    end
    env.u_forceIncrement = function()
        game.increment_difficulty()
    end
    env.u_kill = function()
        game.main_timeline:append_do(function()
            game.death(true)
        end)
    end
    env.u_eventKill = function()
        game.event_timeline:append_do(function()
            game.death(true)
        end)
    end
    env.u_getDifficultyMult = function()
        return game.difficulty_mult
    end
    env.u_getSpeedMultDM = function()
        return game.get_speed_mult_dm()
    end
    env.u_getDelayMultDM = function()
        return game.get_delay_mult_dm()
    end

    -- messages
    local function add_message(msg, duration)
        game.message_timeline:append_do(function()
            sound.play_game("beep.ogg")
            game.message_text = msg
        end)
        game.message_timeline:append_wait(duration)
        game.message_timeline:append_do(function()
            game.message_text = ""
        end)
    end
    env.m_messageAdd = function(msg, duration)
        game.event_timeline:append_do(function()
            if public.first_play and config.get("messages") then
                add_message(msg, duration)
            end
        end)
    end
    env.m_messageAddImportant = function(msg, duration)
        game.event_timeline:append_do(function()
            if config.get("messages") then
                add_message(msg, duration)
            end
        end)
    end

    -- main timeline control
    env.t_wait = function(duration)
        game.main_timeline:append_wait(duration)
    end
    env.t_waitS = function(duration)
        game.main_timeline:append_wait(duration * 60)
    end
    env.t_waitUntilS = function(time)
        game.main_timeline:append_wait(10)
        game.main_timeline:append_do(function()
            if status.current_time < time then
                game.main_timeline:jump_to(game.main_timeline:get_current_index() - 2)
            end
        end)
    end

    -- event timeline control
    env.e_eventStopTime = function(duration)
        game.event_timeline:append_do(function()
            status.time_stop = duration
        end)
    end
    env.e_eventStopTimeS = function(duration)
        game.event_timeline:append_do(function()
            status.time_stop = duration * 60
        end)
    end
    env.e_eventWait = function(duration)
        game.event_timeline:append_wait(duration)
    end
    env.e_eventWaitS = function(duration)
        game.event_timeline:append_wait(duration * 60)
    end
    env.e_eventWaitUntilS = function(time)
        game.event_timeline:append_wait(10)
        game.event_timeline:append_do(function()
            if status.current_time < time then
                game.event_timeline:jump_to(game.event_timeline:get_current_index() - 2)
            end
        end)
    end

    -- level control
    env.l_setSpeedMult = function(value)
        level_status.speed_mult = value
    end
    env.l_setSpeedInc = function(value)
        level_status.speed_inc = value
    end
    env.l_setRotationSpeed = function(value)
        level_status.rotation_speed = value
    end
    env.l_setRotationSpeedMax = function(value)
        level_status.rotation_speed_max = value
    end
    env.l_setRotationSpeedInc = function(value)
        level_status.rotation_speed_inc = value
    end
    env.l_setDelayMult = function(value)
        level_status.delay_mult = value
    end
    env.l_setDelayInc = function(value)
        level_status.delay_inc = value
    end
    env.l_setFastSpin = function(value)
        level_status.fast_spin = value
    end
    env.l_setSides = function(value)
        level_status.sides = utils.round_to_even(value)
    end
    env.l_setSidesMin = function(value)
        level_status.sides_min = utils.round_to_even(value)
    end
    env.l_setSidesMax = function(value)
        level_status.sides_max = utils.round_to_even(value)
    end
    env.l_setIncTime = function(value)
        level_status.inc_time = value
    end
    env.l_setPulseMin = function(value)
        level_status.pulse_min = value
    end
    env.l_setPulseMax = function(value)
        level_status.pulse_max = value
    end
    env.l_setPulseSpeed = function(value)
        level_status.pulse_speed = value
    end
    env.l_setPulseSpeedR = function(value)
        level_status.pulse_speed_r = value
    end
    env.l_setPulseDelayMax = function(value)
        level_status.pulse_delay_max = value
    end
    env.l_setBeatPulseMax = function(value)
        level_status.beat_pulse_max = value
    end
    env.l_setBeatPulseDelayMax = function(value)
        level_status.beat_pulse_delay_max = value
    end
    env.l_setWallSkewLeft = function(value)
        level_status.wall_skew_left = value
    end
    env.l_setWallSkewRight = function(value)
        level_status.wall_skew_right = value
    end
    env.l_setWallAngleLeft = function(value)
        level_status.wall_angle_left = value
    end
    env.l_setWallAngleRight = function(value)
        level_status.wall_angle_right = value
    end
    env.l_setRadiusMin = function(value)
        level_status.radius_min = value
    end
    env.l_setSwapEnabled = function(value)
        level_status.swap_enabled = value
    end
    env.l_setTutorialMode = function(value)
        level_status.tutorial_mode = value
    end
    env.l_setIncEnabled = function(value)
        level_status.inc_enabled = value
    end
    env.l_addTracked = function(var, name)
        level_status.tracked_variables[var] = name
    end
    env.l_enableRndSideChanges = function(value)
        level_status.rnd_side_changes_enabled = value
    end
    env.l_getRotationSpeed = function()
        return level_status.rotation_speed
    end
    env.l_getSides = function()
        return level_status.sides
    end
    env.l_getSpeedMult = function()
        return level_status.speed_mult
    end
    env.l_getDelayMult = function()
        return level_status.delay_mult
    end

    -- style control
    env.s_setPulseInc = function(value)
        style.pulse_increment = value
    end
    env.s_setHueInc = function(value)
        style.hue_increment = value
    end
    env.s_getHueInc = function()
        return style.hue_increment
    end

    -- wall creation
    env.w_wall = function(side, thickness)
        game.main_timeline:append_do(function()
            walls.create(0, side, thickness, speed_data:new(game.get_speed_mult_dm()))
        end)
    end
    env.w_wallAdj = function(side, thickness, speed_adj)
        game.main_timeline:append_do(function()
            walls.create(0, side, thickness, speed_data:new(speed_adj * game.get_speed_mult_dm()))
        end)
    end
    env.w_wallAcc = function(side, thickness, speed_adj, acceleration, min_speed, max_speed)
        game.main_timeline:append_do(function()
            local speed_mult_dm = game.get_speed_mult_dm()
            walls.create(
                0,
                side,
                thickness,
                speed_data:new(
                    speed_adj * speed_mult_dm,
                    acceleration,
                    min_speed * speed_mult_dm,
                    max_speed * speed_mult_dm
                )
            )
        end)
    end
    env.w_wallHModSpeedData = function(hmod, side, thickness, sadj, sacc, smin, smax, sping_pong)
        game.main_timeline:append_do(function()
            walls.create(
                hmod,
                side,
                thickness,
                speed_data:new(sadj * game.get_speed_mult_dm(), sacc, smin, smax, sping_pong)
            )
        end)
    end
    env.w_wallHModCurveData = function(hmod, side, thickness, cadj, cacc, cmin, cmax, cping_pong)
        game.main_timeline:append_do(function()
            walls.create(
                hmod,
                side,
                thickness,
                speed_data:new(game.get_speed_mult_dm()),
                speed_data:new(cadj, cacc, cmin, cmax, cping_pong)
            )
        end)
    end
    log("initialized environment")
end

local function run_fn(name, ...)
    return env[name](...)
end

function lua_runtime.run_fn_if_exists(name, ...)
    if env[name] ~= nil then
        local _, ret = xpcall(run_fn, lua_runtime.error, name, ...)
        return ret
    end
end

function lua_runtime.run_lua_file(path)
    if env == nil then
        error("attempted to load a lua file without initializing the environment")
    else
        path = utils.get_real_path(path)
        if file_cache[path] == nil then
            local error_msg
            _, file_cache[path], error_msg = xpcall(love.filesystem.load, log, path)
            if file_cache[path] == nil then
                if error_msg then
                    lua_runtime.error("Failed to load '" .. path .. "': " .. error_msg)
                else
                    lua_runtime.error("Failed to load '" .. path .. "'")
                end
                return
            end
        end
        local lua_file = file_cache[path]
        setfenv(lua_file, env)
        xpcall(lua_file, log)
    end
end

return lua_runtime
