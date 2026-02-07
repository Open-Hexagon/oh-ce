local log = require("log")(...)
local args = require("args")
local sound = require("compat.sound")
local utils = require("compat.game192.utils")
local style = require("compat.game192.style")
local level = require("compat.game192.level")
local status = require("compat.game192.status")
local events = require("compat.game192.events")
local walls = require("compat.game192.walls")
local vfs = require("compat.game192.virtual_filesystem")
local config = require("config")
local input = require("input")
local lua_runtime = {
    env = {},
    reset_timings = false,
}

local file_cache = {}
local env = lua_runtime.env
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
    -- love doesn't have this one
    --[54] = "~",
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

function lua_runtime.error(msg)
    log("Error: " .. (msg or "error() was called"))
end

local clock_count = 0
local key_count = 0
local block_threshold = 1000

function lua_runtime.init_env(game, public)
    file_cache = {} -- in case lua files changed since last execution
    local pack = game.pack
    lua_runtime.env = {
        os = {
            time = function(...)
                -- TODO: may break replays?
                return os.time(...)
            end,
            date = function(...)
                -- TODO: may break replays?
                return os.date(...)
            end,
            clock = function()
                clock_count = clock_count + 1
                if clock_count > block_threshold then
                    -- remove debug hook for handled blocking call (if not in menu)
                    if not public.preview_mode then
                        debug.sethook()
                    end
                    -- blocking call (something like: `while os.clock() < x do ...`)
                    game.real_time = game.real_time + game.current_frametime / 60
                    game.blocked_updates = game.blocked_updates + 1
                end
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
        tostring = tostring,
        loadstring = function(...)
            local f = loadstring(...)
            if f then
                setfenv(f, lua_runtime.env)
            end
            return f
        end,
        io = vfs.io,
        -- allowing manual random seed setting, the randomseed calls will be recorded in the replay in order (with their seed)
        math = {
            randomseed = function(seed)
                math.randomseed(input.next_seed(seed))
            end,
        },
    }
    env = lua_runtime.env
    env._G = env
    env.math = setmetatable(env.math, { __index = math })
    env.dofile = function(path)
        local file = vfs.io.open(path, "r")
        assert(file, "file doesn't exist")
        local code = file:read("*a")
        file:close()
        local func = loadstring(code)
        if func == nil then
            error("Failed executing virtual file '" .. path .. "'")
        end
        setfenv(func, env)
        return func()
    end
    local function make_get_set_functions(get, set, name)
        env["get" .. name .. "ValueInt"] = function(field)
            return utils.round_to_even(tonumber(get(field)))
        end
        env["get" .. name .. "ValueFloat"] = function(field)
            return tonumber(get(field) or 0)
        end
        env["get" .. name .. "ValueString"] = function(field)
            local value = get(field) or ""
            local str = tostring(value)
            -- fix float to string conversion expecting 0 after dot
            if type(value) == "number" and str:match("[.]") then
                return str .. "0"
            else
                return str
            end
        end
        env["get" .. name .. "ValueBool"] = function(field)
            return get(field) or false
        end
        env["set" .. name .. "ValueInt"] = function(field, value)
            set(field, utils.round_to_even(value))
        end
        env["set" .. name .. "ValueFloat"] = function(field, value)
            set(field, value)
        end
        env["set" .. name .. "ValueString"] = function(field, value)
            set(field, value)
        end
        env["set" .. name .. "ValueBool"] = function(field, value)
            set(field, value)
        end
    end
    make_get_set_functions(level.get_value, level.set_value, "Level")
    make_get_set_functions(style.get_value, style.set_value, "Style")
    env.log = function(text)
        log("Lua: " .. text)
    end
    env.wall = function(side, thickness)
        game.main_timeline:append_do(function()
            walls.wall(side, thickness)
        end)
    end
    env.getSides = function()
        return game.level_data.sides
    end
    env.getSpeedMult = function()
        return game.level_data.speed_multiplier * math.pow(game.difficulty_mult, 0.65)
    end
    env.getDelayMult = function()
        return game.level_data.delay_multiplier * math.pow(game.difficulty_mult, 0.1)
    end
    env.getDifficultyMult = function()
        return game.difficulty_mult
    end
    env.execScript = function(script)
        lua_runtime.run_lua_file(pack.info.path .. "Scripts/" .. script)
    end
    env.execEvent = function(id)
        events.exec(game.pack.events[id])
    end
    env.enqueueEvent = function(id)
        events.queue(game.pack.events[id])
    end
    env.wait = function(duration)
        game.main_timeline:append_wait(duration)
    end
    env.playSound = function(id)
        sound.play_pack(game.pack, id)
    end
    env.forceIncrement = function()
        game.increment_difficulty()
    end
    local function add_message(message, duration)
        if not args.headless then
            game.message_timeline:append_do(function()
                sound.play_game("beep.ogg")
                game.message_text = message
            end)
            game.message_timeline:append_wait(duration)
            game.message_timeline:append_do(function()
                game.message_text = nil
            end)
        end
    end
    env.messageAdd = function(message, duration)
        if config.get("messages") and public.first_play then
            add_message(message, duration)
        end
    end
    env.messageImportantAdd = function(message, duration)
        if config.get("messages") then
            add_message(message, duration)
        end
    end
    env.isKeyPressed = function(key_code)
        local key = keycode_conversion[key_code]
        if key == nil then
            --lua_runtime.error("No suitable keycode conversion found for '" .. key_code .. "'")
            return false
        end
        key_count = key_count + 1
        if key_count > block_threshold then
            -- remove debug hook for handled blocking call (if not in menu)
            if not public.preview_mode then
                debug.sethook()
            end
            -- blocking loop like `while not isKeyPressed("left") do ...`
            if not args.headless then
                love.event.pump()
            end
            input.update()
        end
        return input.get(key)
    end
    env.isFastSpinning = function()
        return status.fast_spin > 0
    end
    env.wallAdj = function(side, thickness, speed)
        game.main_timeline:append_do(function()
            walls.wallAdj(side, thickness, speed)
        end)
    end
    env.wallAcc = function(side, thickness, speed, accel, min, max)
        game.main_timeline:append_do(function()
            walls.wallAcc(side, thickness, speed, accel, min, max)
        end)
    end
    log("initialized environment")
end

local function limit_function_calls(fn, ...)
    local count = 0
    debug.sethook(function()
        count = count + 1
        if count > 1000000 then
            debug.sethook()
            lua_runtime.reset_timings = true
            -- not ideal as this can stop preview music
            -- but it is required to not hang on some previews
            if require("compat.game192").preview_mode then
                require("game_handler").stop()
            end
            error("too many function calls without returning to the game")
        end
    end, "c")
    local ret = { fn(...) }
    debug.sethook()
    return unpack(ret)
end

local function run_fn(name, ...)
    return limit_function_calls(env[name], ...)
end

function lua_runtime.run_fn_if_exists(name, ...)
    clock_count = 0
    key_count = 0
    if env[name] ~= nil then
        xpcall(run_fn, lua_runtime.error, name, ...)
        debug.sethook()
    end
    if key_count > block_threshold then
        lua_runtime.reset_timings = true
    end
end

function lua_runtime.run_lua_file(path)
    if env == nil then
        error("attempted to load a lua file without initializing the environment")
    else
        if file_cache[path] == nil then
            local error_msg
            _, file_cache[path], error_msg = xpcall(love.filesystem.load, log, utils.get_real_path(path))
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
        xpcall(limit_function_calls, log, lua_file)
    end
end

return lua_runtime
