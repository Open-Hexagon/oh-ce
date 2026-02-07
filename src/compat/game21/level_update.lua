local sound = require("compat.sound")
local utils = require("compat.game192.utils")
local level_status = require("compat.game21.level_status")
local lua_runtime = require("compat.game21.lua_runtime")
local status = require("compat.game21.status")
local walls = require("compat.game21.walls")
local rng = require("compat.game21.random")

return function(game, frametime)
    -- update time/score
    status.accumulate_frametime(frametime)
    if level_status.score_overwritten then
        status.update_custom_score(lua_runtime.env[level_status.score_overwrite])
    end

    -- update timeline events
    if game.event_timeline:update(status.get_time_tp()) then
        game.event_timeline:clear()
    end
    if game.message_timeline:update(status.get_current_tp()) then
        game.message_timeline:clear()
    end

    -- increment after a while
    if level_status.inc_enabled and status.get_increment_time_seconds() >= level_status.inc_time then
        level_status.current_increments = level_status.current_increments + 1
        game.increment_difficulty()
        status.reset_increment_time()
        game.must_change_sides = true
    end

    -- change sides after increment
    if game.must_change_sides and walls.empty() then
        local side_number = rng.get_int(level_status.sides_min, level_status.sides_max)
        level_status.speed_mult = utils.float_round(level_status.speed_mult + level_status.speed_inc)
        level_status.delay_mult = utils.float_round(level_status.delay_mult + level_status.delay_inc)
        if level_status.rnd_side_changes_enabled then
            game.set_sides(side_number)
        end
        game.must_change_sides = false
        sound.play_pack(game.pack_data, level_status.level_up_sound)
        lua_runtime.run_fn_if_exists("onIncrement")
    end

    -- onUpdate, main timeline and onStep
    if not status.is_time_paused() then
        lua_runtime.run_fn_if_exists("onUpdate", frametime)
        if game.main_timeline:update(status.get_time_tp()) and not game.must_change_sides then
            game.main_timeline:clear()
            lua_runtime.run_fn_if_exists("onStep")
        end
    end
end
