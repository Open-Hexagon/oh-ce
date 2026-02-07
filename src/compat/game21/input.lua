local config = require("config")
local game_input = require("input")
local lua_runtime = require("compat.game21.lua_runtime")
local level_status = require("compat.game21.level_status")
local status = require("compat.game21.status")
local player = require("compat.game21.player")
local sound = require("compat.sound")
local input = {
    move = 0,
}
local game, swap_particles, has_swap

function input.init(pass_game, particles)
    game = pass_game
    swap_particles = particles
    if lua_runtime.env.onInput then
        local nparams = debug.getinfo(lua_runtime.env.onInput).nparams
        has_swap = nparams > 3
    end
end

function input.update(frametime)
    local focus = game_input.get("focus")
    local swap
    if has_swap or level_status.swap_enabled then
        swap = game_input.get("swap")
    end
    local cw = game_input.get("right")
    local ccw = game_input.get("left")
    if cw and not ccw then
        input.move = 1
        game.last_move = 1
    elseif not cw and ccw then
        input.move = -1
        game.last_move = -1
    elseif cw and ccw then
        input.move = -game.last_move
    else
        input.move = 0
    end
    -- TODO: update key icons and level info (needs ui)
    player.update(focus, level_status.swap_enabled, frametime)
    if not status.has_died then
        local prevent_player_input = lua_runtime.run_fn_if_exists("onInput", frametime, input.move, focus, swap)
        if not prevent_player_input then
            player.update_input_movement(input.move, level_status.player_speed_mult, focus, frametime)
            if not game.player_now_ready_to_swap and player.is_ready_to_swap() then
                swap_particles.ready()
                game.player_now_ready_to_swap = true
                if config.get("play_swap_sound") then
                    sound.play_game("swap_blip.ogg")
                end
            end
            if level_status.swap_enabled and swap and player.is_ready_to_swap() then
                swap_particles.swap()
                game.perform_player_swap(true)
                player.reset_swap(game.get_swap_cooldown())
                player.set_just_swapped(true)
                game.player_now_ready_to_swap = false
            else
                player.set_just_swapped(false)
            end
        end
    end
end

return input
