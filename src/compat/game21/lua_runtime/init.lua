local log = require("log")(...)
local sound = require("compat.sound")
local add_timeline_functions = require("compat.game21.lua_runtime.timelines")
local add_audio_functions = require("compat.game21.lua_runtime.audio")
local add_utility_functions = require("compat.game21.lua_runtime.utility")
local add_wall_functions = require("compat.game21.lua_runtime.walls")
local add_level_functions = require("compat.game21.lua_runtime.level")
local add_style_functions = require("compat.game21.lua_runtime.style")
local shader_functions = require("compat.game21.lua_runtime.shaders")
local custom_timelines = require("compat.game21.custom_timelines")
local custom_walls = require("compat.game21.custom_walls")
local lua_runtime = {
    env = {},
}

local file_cache = {}
local env = lua_runtime.env

function lua_runtime.error(msg)
    sound.play_game("error.ogg")
    log(debug.traceback("Error: " .. msg))
end

function lua_runtime.init_env(game, public)
    file_cache = {} -- in case lua files changed since last execution
    lua_runtime.env = {
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
        math = {},
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

    for k, v in pairs(math) do
        if k ~= "randomseed" then
            env.math[k] = v
        end
    end

    add_level_functions(game)
    add_style_functions(game)
    add_audio_functions(game)
    add_timeline_functions(public, game)
    add_utility_functions(public, game)
    add_wall_functions(game)
    custom_timelines.add_lua_functions(game)

    -- Custom wall functions
    for name, fn in pairs(custom_walls) do
        if name:sub(1, 3) == "cw_" then
            env[name] = fn
        end
    end

    shader_functions.use(game)

    -- Miscellaneous functions
    env.steam_unlockAchievement = function(achievement)
        lua_runtime.error("Attempt to unlock steam achievement '" .. achievement .. "' in compat mode")
    end

    -- make sure no malicious code is required in
    local safe_modules = {
        ["bit"] = true,
    }
    env.require = function(modname)
        if safe_modules[modname] then
            return require(modname)
        else
            lua_runtime.error("Script attempted to require potentially dangerous module: '" .. modname .. "'")
        end
    end

    -- restrict io operations
    env.io = {
        open = function(filename, mode)
            return io.open(filename, mode == "rb" and mode or "r")
        end,
    }

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
