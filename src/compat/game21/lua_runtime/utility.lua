local log = require("log")(...)
local args = require("args")
local input = require("input")
local level_status = require("compat.game21.level_status")
local status = require("compat.game21.status")
local player = require("compat.game21.player")
local walls = require("compat.game21.walls")
local rng = require("compat.game21.random")
local utils = require("compat.game192.utils")

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
return function(public, game)
    local pack = game.pack_data
    local lua_runtime = require("compat.game21.lua_runtime")
    local env = lua_runtime.env
    env.u_isHeadless = function()
        return args.headless or false
    end
    env.u_rndReal = function()
        return rng.get_real(0, 1)
    end
    env.u_rndIntUpper = function(upper)
        return rng.get_int(1, upper)
    end
    env.u_rndInt = function(lower, upper)
        return rng.get_int(lower, upper)
    end
    env.u_rndSwitch = function(mode, lower, upper)
        if mode == 0 then
            return env.u_rndReal()
        elseif mode == 1 then
            return env.u_rndIntUpper(upper)
        elseif mode == 2 then
            return env.u_rndInt(lower, upper)
        end
        return 0
    end
    env.math.random = function(a, b)
        if a == nil and b == nil then
            return env.u_rndSwitch(0, 0, 0)
        elseif b == nil then
            return env.u_rndSwitch(1, 0, a)
        else
            return env.u_rndSwitch(2, a, b)
        end
    end
    env.u_getAttemptRandomSeed = function()
        return rng.get_seed()
    end
    env.u_inMenu = function()
        -- the lua env shouldn't be active in the menu?
        return false
    end
    -- pretend to be the current newest version (2.1.7)
    env.u_getVersionMajor = function()
        return 2
    end
    env.u_getVersionMinor = function()
        return 1
    end
    env.u_getVersionMicro = function()
        return 7
    end
    env.u_getVersionString = function()
        return "2.1.7"
    end
    env.u_execScript = function(path)
        lua_runtime.run_lua_file(pack.info.path .. "Scripts/" .. path)
    end
    env.u_execDependencyScript = function(disambiguator, name, author, script)
        local pack_id = disambiguator .. "_" .. author .. "_" .. name
        pack_id = pack_id:gsub(" ", "_")
        local dependency_pack = pack.dependencies[pack_id] or pack
        local old = env.u_execScript
        env.u_execScript = function(path)
            lua_runtime.run_lua_file(dependency_pack.info.path .. "Scripts/" .. path)
        end
        lua_runtime.run_lua_file(dependency_pack.info.path .. "Scripts/" .. script)
        env.u_execScript = old
    end
    env.u_getWidth = function()
        return game.width
    end
    env.u_getHeight = function()
        return game.height
    end
    env.u_setFlashEffect = function(value)
        status.flash_effect = value
    end
    env.u_setFlashColor = function(r, g, b)
        game.flash_color[1] = r
        game.flash_color[2] = g
        game.flash_color[3] = b
    end
    env.u_log = function(message)
        log("[lua] " .. message)
    end
    env.u_isKeyPressed = function(key_code)
        local key = keycode_conversion[key_code]
        if key == nil then
            lua_runtime.error("Could not find key with sfml keycode '" .. key_code .. "'!")
            return false
        end
        return input.get(key)
    end
    env.u_haltTime = function(duration)
        status.pause_time(duration / 60)
    end
    env.u_clearWalls = function()
        walls.clear()
    end
    env.u_getPlayerAngle = function()
        if public.preview_mode then
            -- return real angle if called from a function named 'getPlayerSide'
            if not debug.traceback():match("in function 'getPlayerSide'") then
                return -(0 / 0)
            end
        end
        return player.get_player_angle()
    end
    env.u_setPlayerAngle = function(angle)
        angle = utils.float_round(angle or 0)
        return player.set_player_angle(angle)
    end
    env.u_isMouseButtonPressed = function(button)
        return input.get(button)
    end
    env.u_isFastSpinning = function()
        return status.fast_spin > 0
    end
    env.u_forceIncrement = function()
        game.increment_difficulty()
    end
    env.u_getDifficultyMult = function()
        return game.difficulty_mult
    end
    env.u_getSpeedMultDM = function()
        return game.get_speed_mult_dm()
    end
    env.u_getDelayMultDM = function()
        local result = level_status.delay_mult / math.pow(game.difficulty_mult, 0.1)
        if not level_status.has_delay_max_limit() then
            return result
        end
        return result < level_status.delay_max and result or level_status.delay_max
    end
    env.u_swapPlayer = function(play_sound)
        game.perform_player_swap(play_sound)
    end
end
