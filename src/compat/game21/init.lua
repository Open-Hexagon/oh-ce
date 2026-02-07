-- 2.1.X compatibility mode
local args = require("args")
local log = require("log")(...)
local assets = require("asset_system")
local sound = require("compat.sound")
local Timeline = require("compat.game21.timeline")
local Quads = require("compat.game21.dynamic_quads")
local Tris = require("compat.game21.dynamic_tris")
local set_color = require("compat.game21.color_transform")
local utils = require("compat.game192.utils")
local pulse = require("compat.game21.pulse")
local beat_pulse = require("compat.game21.beat_pulse")
local pseudo3d = require("compat.game21.pseudo3d")
local swap_particles = require("compat.game21.swap_particles")
local trail_particles = require("compat.game21.trail_particles")
local flash = require("compat.game21.flash")
local input = require("compat.game21.input")
local level_update = require("compat.game21.level_update")
local camera_shake = require("compat.game21.camera_shake")
local rotation = require("compat.game21.rotation")
local async = require("async")
local music = require("compat.music")
local config = require("config")
local game_input = require("input")
local lua_runtime = require("compat.game21.lua_runtime")
local shader_functions = require("compat.game21.lua_runtime.shaders")
local level_status = require("compat.game21.level_status")
local status = require("compat.game21.status")
local style = require("compat.game21.style")
local player = require("compat.game21.player")
local custom_timelines = require("compat.game21.custom_timelines")
local walls = require("compat.game21.walls")
local custom_walls = require("compat.game21.custom_walls")
local rng = require("compat.game21.random")
local public = {
    running = false,
    first_play = true,
    tickrate = 240,
}
local game = {
    level_data = nil,
    pack_data = nil,
    difficulty_mult = nil,
    music = nil,
    seed = nil,
    message_text = "",
    last_move = 0,
    must_change_sides = false,
    current_rotation = 0,
    player_now_ready_to_swap = false,
    event_timeline = Timeline:new(),
    message_timeline = Timeline:new(),
    main_timeline = Timeline:new(),
    flash_color = { 0, 0, 0, 0 },
}
local wall_quads, pivot_quads, player_tris, cap_tris
if args.headless then
    -- should be fine as long as no level uses initial values here to make rng
    game.width, game.height = 1024, 768
else
    game.width = love.graphics.getWidth()
    game.height = love.graphics.getHeight()
    wall_quads = Quads:new()
    pivot_quads = Quads:new()
    player_tris = Tris:new()
    cap_tris = Tris:new()
end
local current_trail_color = { 0, 0, 0, 0 }

---starts a new game
---@param pack_id string
---@param level_id string
---@param level_options table
public.start = async(function(pack_id, level_id, level_options)
    -- update inital window dimensions when starting as well (for onInit/onLoad)
    if not args.headless then
        local game_handler = require("game_handler")
        game.width, game.height = game_handler.get_game_dimensions()
    end
    level_options.difficulty_mult = level_options.difficulty_mult or 1
    local difficulty_mult = level_options.difficulty_mult
    local seed = math.floor(love.timer.getTime() * 1000000000)
    math.randomseed(game_input.next_seed(seed))
    math.random()

    local key = "21_" .. pack_id
    if not assets.mirror[key] then
        async.await(assets.index.request(key, "pack.compat.full_load", 21, pack_id))
    end
    game.pack_data = assets.mirror[key]
    game.level_data = game.pack_data.levels[level_id]
    if game.level_data == nil then
        error("Error: level with id '" .. level_id .. "' not found")
    end
    level_status.reset(config.get("sync_music_to_dm"))
    local style_data = game.pack_data.styles[game.level_data.style_id]
    if style_data == nil then
        log("Warn: style with id '" .. game.level_data.style_id .. "' not found")
        -- still continue with default style values
    end
    style.select(style_data or {})
    style.compute_colors()
    game.difficulty_mult = difficulty_mult
    status.reset_all_data()
    music.stop()
    local new_music = game.pack_data.music[game.level_data.music_id]
    if new_music == nil then
        error("Music with id '" .. game.level_data.music_id .. "' doesn't exist!")
    end
    music.play(new_music, not public.first_play, nil, public.refresh_music_pitch())
    status.beat_pulse_delay = status.beat_pulse_delay + (music.segment.beat_pulse_delay_offset or 0)

    rng.set_seed(game_input.next_seed(seed))

    game.main_timeline:clear()
    game.event_timeline:clear()
    game.message_timeline:clear()
    custom_timelines:reset()
    walls.reset(level_status)
    custom_walls.cw_clear()
    player.reset(
        game.get_swap_cooldown(),
        config.get("player_size"),
        config.get("player_speed"),
        config.get("player_focus_speed")
    )
    flash.init(game)
    game.current_rotation = 0
    game.must_change_sides = false
    if not public.first_play then
        lua_runtime.run_fn_if_exists("onPreUnload")
    end
    lua_runtime.init_env(game, public)
    lua_runtime.run_lua_file(game.pack_data.info.path .. game.level_data.lua_file)
    if public.first_play then
        sound.play_game("select.ogg")
    else
        lua_runtime.run_fn_if_exists("onUnload")
        sound.play_game("restart.ogg")
    end
    lua_runtime.run_fn_if_exists("onInit")
    game.set_sides(level_status.sides)
    pulse.init()
    beat_pulse.init()
    status.start()
    game.message_text = ""
    sound.play_game("go.ogg")
    lua_runtime.run_fn_if_exists("onLoad")

    if not args.headless then
        swap_particles.init()
        trail_particles.init()
    end
    input.init(game, swap_particles)
    public.running = true
end)

function game.set_sides(sides)
    sound.play_pack(game.pack_data, level_status.beep_sound)
    if sides < 3 then
        sides = 3
    end
    level_status.sides = sides
end

function game.get_swap_cooldown()
    return math.max(36 * level_status.swap_cooldown_mult, 8)
end

function game.get_speed_mult_dm()
    local result = level_status.speed_mult * math.pow(game.difficulty_mult, 0.65)
    if not level_status.has_speed_max_limit() then
        return result
    end
    return result < level_status.speed_max and result or level_status.speed_max
end

function game.death(force)
    if not status.has_died then
        lua_runtime.run_fn_if_exists("onPreDeath")
        sound.play_pack(game.pack_data, level_status.death_sound)
        if force or not (level_status.tutorial_mode or config.get("invincible")) then
            lua_runtime.run_fn_if_exists("onDeath")
            camera_shake.start()
            music.stop()
            flash.start_white()
            status.has_died = true
            if public.death_callback ~= nil then
                public.death_callback()
            end
        end
    end
end

function game.perform_player_swap(play_sound)
    player.player_swap()
    lua_runtime.run_fn_if_exists("onCursorSwap")
    if play_sound then
        sound.play_pack(game.pack_data, level_status.swap_sound)
    end
end

local function get_music_dm_sync_factor()
    return math.pow(game.difficulty_mult, 0.12)
end

function public.refresh_music_pitch()
    if not level_status.music_pitch then
        return
    end
    local pitch = level_status.music_pitch
        * config.get("music_speed_mult")
        * (level_status.sync_music_to_dm and get_music_dm_sync_factor() or 1)
    if pitch ~= pitch then
        -- pitch is NaN, happens with negative difficulty mults
        pitch = 1
    end
    if pitch < 0 then
        -- pitch can't be 0, setting it to almost 0, not sure if this could cause issues
        pitch = 0.001
    end
    music.set_pitch(pitch)
    return pitch
end

function game.increment_difficulty()
    sound.play_game("level_up.ogg")
    local sign_mult = level_status.rotation_speed > 0 and 1 or -1
    level_status.rotation_speed =
        utils.float_round(level_status.rotation_speed + level_status.rotation_speed_inc * sign_mult)
    if math.abs(level_status.rotation_speed) > level_status.rotation_speed_max then
        level_status.rotation_speed = level_status.rotation_speed_max * sign_mult
    end
    level_status.rotation_speed = -level_status.rotation_speed
    status.fast_spin = level_status.fast_spin
end

---update the game
---@param frametime number (in seconds)
function public.update(frametime)
    game_input.update()
    frametime = frametime * 60
    -- TODO: don't update if debug pause

    flash.update(frametime)

    if public.running then
        style.compute_colors()
        input.update(frametime)
        if not status.has_died then
            -- TODO: draw tracked vars (needs ui)
            -- small snippet to print them:
            --[[for var, name in pairs(level_status.tracked_variables) do
                print(name, lua_runtime.env[var])
            end]]
            level_update(game, frametime)
            custom_timelines.update(status.get_current_tp())

            local dm_factor = get_music_dm_sync_factor()
            beat_pulse.update(frametime, dm_factor)
            pulse.update(frametime, dm_factor)

            if not config.get("black_and_white") then
                style.update(frametime, math.pow(game.difficulty_mult, 0.8))
            end

            player.update_position(status.radius)
            walls.update(frametime, status.radius)
            if not public.preview_mode then
                if
                    walls.handle_collision(input.move, frametime, player, status.radius)
                    or custom_walls.handle_collision(input.move, status.radius, player, frametime)
                then
                    local fatal = not config.get("invincible") and not level_status.tutorial_mode
                    player.kill(fatal)
                    game.death()
                end
                custom_walls.update_old_vertices()
            end
        else
            level_status.rotation_speed = level_status.rotation_speed * 0.99
        end

        pseudo3d.update(frametime)

        -- update rotation
        if config.get("rotation") then
            rotation.update(game, frametime)
        end
        camera_shake.update(frametime)
        if not status.has_died then
            rng.advance(math.abs(status.pulse))
            rng.advance(math.abs(status.pulse3D))
            rng.advance(math.abs(status.fast_spin))
            rng.advance(math.abs(status.flash_effect))
            rng.advance(math.abs(level_status.rotation_speed))
        end

        -- update trail color (also used for swap particles)
        current_trail_color[1], current_trail_color[2], current_trail_color[3] = style.get_player_color()
        if config.get("black_and_white") then
            current_trail_color[1], current_trail_color[2], current_trail_color[3] = 255, 255, 255
        else
            if config.get("player_trail_has_swap_color") then
                player.get_color_adjusted_for_swap(current_trail_color)
            else
                player.get_color(current_trail_color)
            end
        end
        current_trail_color[4] = config.get("player_trail_alpha")

        if config.get("show_player_trail") and status.show_player_trail and not args.headless then
            trail_particles.update(frametime, current_trail_color)
        end
        if config.get("show_swap_particles") and not args.headless then
            swap_particles.update(frametime, current_trail_color)
        end

        -- supress empty block warning for now
        --- @diagnostic disable
        if level_status.pseudo_3D_required and not config.get("3D_enabled") then
            -- TODO: invalidate score
        end
        if level_status.shaders_required and not config.get("shaders") then
            -- TODO: invalidate score
        end
        --- @diagnostic enable
    end
end

---draw the game to the current canvas
---@param screen love.Canvas
---@param frametime number
function public.draw(screen, frametime)
    -- for lua access
    game.width, game.height = screen:getDimensions()

    -- do the resize adjustment the old game did after already enforcing our aspect ratio
    local zoom_factor = 1 / math.max(1024 / game.width, 768 / game.height)
    -- apply pulse as well
    local zoom = pulse.get_zoom(zoom_factor)
    love.graphics.scale(zoom, zoom)
    camera_shake.apply()
    pseudo3d.apply_skew()
    rotation.apply(game)
    shader_functions.check()

    local function set_render_stage(render_stage, no_shader, instanced)
        if config.get("shaders") then
            local shader = status.fragment_shaders[render_stage]
            if shader ~= nil then
                lua_runtime.run_fn_if_exists("onRenderStage", render_stage, frametime * 60)
                if instanced then
                    love.graphics.setShader(shader.instance_shader)
                else
                    if render_stage ~= 8 then
                        love.graphics.setShader(shader.shader)
                    else
                        love.graphics.setShader(shader.text_shader)
                    end
                end
            else
                love.graphics.setShader(no_shader)
            end
        end
    end

    local black_and_white = config.get("black_and_white")
    if config.get("background") then
        set_render_stage(0)
        style.draw_background(level_status.sides, level_status.darken_uneven_background_chunk, black_and_white)
    end

    wall_quads:clear()
    walls.draw(style, wall_quads, black_and_white)
    custom_walls.draw(wall_quads)

    player_tris:clear()
    pivot_quads:clear()
    cap_tris:clear()
    if public.preview_mode then
        player.draw_pivot(pivot_quads, cap_tris, black_and_white)
    elseif status.started then
        player.draw(
            pivot_quads,
            player_tris,
            cap_tris,
            config.get("player_tilt_intensity"),
            config.get("swap_blinking_effect"),
            black_and_white
        )
    end
    love.graphics.setColor(1, 1, 1, 1)
    pseudo3d.draw(set_render_stage, wall_quads, pivot_quads, player_tris, black_and_white)

    if not public.preview_mode then
        if config.get("show_player_trail") and status.show_player_trail then
            love.graphics.setShader()
            trail_particles.draw()
        end

        if config.get("show_swap_particles") then
            love.graphics.setShader()
            swap_particles.draw()
        end
    end

    set_render_stage(4)
    wall_quads:draw()
    set_render_stage(5)
    cap_tris:draw()
    set_render_stage(6)
    pivot_quads:draw()
    set_render_stage(7)
    player_tris:draw()

    -- text shouldn't be affected by rotation/pulse
    love.graphics.origin()
    love.graphics.scale(zoom_factor, zoom_factor)
    camera_shake.apply()
    set_render_stage(8)
    if game.message_text ~= "" and (not public.preview_mode or config.get("background_preview_has_text")) then
        -- text
        -- TODO: offset_color = style.get_color(0)  -- black in bw mode
        -- TODO: draw outlines (if not disabled in config)
        local r, g, b, a = style.get_text_color()
        if black_and_white then
            r, g, b = 255, 255, 255
        end
        set_color(r, g, b, a)
        love.graphics.print(
            game.message_text,
            assets.mirror.opensquare_font,
            game.width / zoom_factor / 2 - assets.mirror.opensquare_font:getWidth(game.message_text) / 2,
            game.height / zoom_factor / 5.5
        )
    end

    -- reset render stage shaders
    love.graphics.setShader()

    -- flash shouldnt be affected by rotation/pulse/camera_shake
    love.graphics.origin()
    love.graphics.scale(zoom_factor, zoom_factor)
    flash.draw(config.get("flash"), zoom_factor)
end

---get the current score
---@return number the score
---@return boolean is custom score
function public.get_score()
    if level_status.score_overwritten then
        -- custom score may change after death, get it again
        return tonumber(lua_runtime.env[level_status.score_overwrite]) or 0, true
    end
    return status.get_played_accumulated_frametime_in_seconds(), false
end

---gets time based score even if there is a custom score
function public.get_timed_score()
    return status.get_total_accumulated_frametime_in_seconds()
end

---21 specific function that gets the custom score right before death (which is used for replay verification instead of the actual one)
---@return number?
function public.get_compat_custom_score()
    return tonumber(status.get_custom_score())
end

---returns true if the player has died
---@return boolean
function public.is_dead()
    return status.has_died
end

---stop the game
function public.stop()
    public.running = false
    music.stop()
end

---initialize the game
---@async
public.init = async(function()
    pseudo3d.init(game)
    if not args.headless then
        async.await(assets.index.request(
            "opensquare_font",
            "font",
            "assets/font/OpenSquare-Regular.ttf",
            32 * config.get("text_scale") -- TODO: respond to changes
        ))
        async.await(sound.init())
    end
end)

return public
