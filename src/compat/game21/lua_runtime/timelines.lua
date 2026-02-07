local sound = require("compat.sound")
local config = require("config")
local level_status = require("compat.game21.level_status")
local status = require("compat.game21.status")

return function(public, game)
    local env = require("compat.game21.lua_runtime").env

    -- Main timeline functions
    env.t_eval = function(code)
        local fn = loadstring(code)
        if fn then
            setfenv(fn, env)
            game.main_timeline:append_do(fn)
        end
    end
    env.t_clear = function()
        game.main_timeline:clear(true)
    end
    env.t_kill = function()
        game.main_timeline:append_do(function()
            game.death(true)
        end)
    end
    env.t_wait = function(duration)
        game.main_timeline:append_wait_for_sixths(duration)
    end
    env.t_waitS = function(duration)
        game.main_timeline:append_wait_for_seconds(duration)
    end
    env.t_waitUntilS = function(time)
        game.main_timeline:append_wait_until_fn(function()
            return status.get_level_start_tp() + math.floor(time * 1000)
        end)
    end

    -- Event timeline functions
    env.e_eval = function(code)
        local fn = loadstring(code)
        if fn then
            setfenv(fn, env)
            game.event_timeline:append_do(fn)
        end
    end
    env.e_kill = function()
        game.event_timeline:append_do(function()
            game.death(true)
        end)
    end

    env.e_stopTime = function(duration)
        game.event_timeline:append_do(function()
            status.pause_time(duration / 60)
        end)
    end
    env.e_stopTimeS = function(duration)
        game.event_timeline:append_do(function()
            status.pause_time(duration)
        end)
    end
    env.e_wait = function(duration)
        game.event_timeline:append_wait_for_sixths(duration)
    end
    env.e_waitS = function(duration)
        game.event_timeline:append_wait_for_seconds(duration)
    end
    env.e_waitUntilS = function(time)
        game.event_timeline:append_wait_until_fn(function()
            return status.get_level_start_tp() + math.floor(time * 1000)
        end)
    end
    local function add_message(message, duration, sound_toggle)
        if config.get("messages") then
            game.message_timeline:append_do(function()
                if sound_toggle then
                    sound.play_pack(game.pack_data, level_status.beep_sound)
                end
                game.message_text = message:upper()
            end)
            game.message_timeline:append_wait_for_sixths(duration)
            game.message_timeline:append_do(function()
                game.message_text = ""
            end)
        end
    end
    env.e_messageAdd = function(message, duration)
        game.event_timeline:append_do(function()
            if public.first_play then
                add_message(message, duration, true)
            end
        end)
    end
    env.e_messageAddImportant = function(message, duration)
        game.event_timeline:append_do(function()
            add_message(message, duration, true)
        end)
    end
    env.e_messageAddImportantSilent = function(message, duration)
        game.event_timeline:append_do(function()
            add_message(message, duration, false)
        end)
    end
    env.e_clearMessages = function()
        -- yes the game really does not do this with the event timeline like all the other e_ functions
        game.message_timeline:clear()
    end

    -- deprecated
    env.m_messageAdd = env.e_messageAdd
    env.m_messageAddImportant = env.e_messageAddImportant
    env.m_messageAddImportantSilent = env.e_messageAddImportantSilent
    env.m_clearMessages = env.e_clearMessages
    env.e_eventWaitS = env.e_waitS
    env.u_eventKill = env.e_kill
    env.u_kill = env.t_kill
end
