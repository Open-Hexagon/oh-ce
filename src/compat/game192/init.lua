local log = require("log")
local args = require("args")
local sound = require("compat.sound")
local assets = require("asset_system")
local DynamicQuads = require("compat.game21.dynamic_quads")
local Timeline = require("compat.game192.timeline")
local set_color = require("compat.game21.color_transform")
local make_fake_config = require("compat.game192.fake_config")
local music = require("compat.music")
local async = require("async")
local style = require("compat.game192.style")
local status = require("compat.game192.status")
local level = require("compat.game192.level")
local player = require("compat.game192.player")
local lua_runtime = require("compat.game192.lua_runtime")
local events = require("compat.game192.events")
local walls = require("compat.game192.walls")
local vfs = require("compat.game192.virtual_filesystem")
local utils = require("compat.game192.utils")
local config = require("config")
local input = require("input")
local public = {
    running = false,
    first_play = true,
    tickrate = 960,
}
local game = {
    difficulty_mult = 1,
    restart_id = "",
    restart_first_time = false,
    main_timeline = Timeline:new(),
    message_timeline = Timeline:new(),
    effect_timeline = Timeline:new(),
    real_time = 0,
    blocked_updates = 0,
    current_frametime = 0.25 / 60,
}

local shake_move = { 0, 0 }
local layer_shader, main_quads
if not args.headless then
    layer_shader = love.graphics.newShader(
        [[
            layout(location = 3) in vec2 instance_offset;
            layout(location = 4) in vec4 instance_color;
            out vec4 instance_color_out;

            vec4 position(mat4 transform_projection, vec4 vertex_position)
            {
                instance_color_out = instance_color / 255.0;
                vertex_position.xy += instance_offset;
                return transform_projection * vertex_position;
            }
        ]],
        [[
            in vec4 instance_color_out;

            vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
            {
                return instance_color_out;
            }
        ]]
    )
    main_quads = DynamicQuads:new()
end
local instance_offsets = {}
local instance_colors = {}
local depth = 0
local last_move = 0
local last_real_time = 0
local current_rotation = 0

function game.increment_difficulty()
    sound.play_game("level_up.ogg")
    game.level_data.rotation_speed = game.level_data.rotation_speed
        + game.level_data.rotation_increment * (game.level_data.rotation_speed > 0 and 1 or -1)
    game.level_data.rotation_speed = -game.level_data.rotation_speed
    if status.fast_spin < 0 and math.abs(game.level_data.rotation_speed) > game.level_data.rotation_speed_max then
        game.level_data.rotation_speed = game.level_data.rotation_speed_max
            * (game.level_data.rotation_speed > 0 and 1 or -1)
    end
    status.fast_spin = game.level_data.fast_spin
    game.main_timeline:at_start_do(function()
        game.side_change(math.random(game.level_data.sides_min, game.level_data.sides_max))
    end)
end

function game.side_change(side_count)
    if walls.size() > 0 then
        game.main_timeline:at_start_do(function()
            game.main_timeline:clear()
            game.main_timeline:reset()
        end)
        game.main_timeline:at_start_do(function()
            game.side_change(side_count)
        end)
        game.main_timeline:at_start_wait(1)
    else
        lua_runtime.run_fn_if_exists("onIncrement")
        game.level_data.speed_multiplier = game.level_data.speed_multiplier + game.level_data.speed_increment
        -- This is wrong, ask vee what he thought while doing that in 1.92 lol
        game.level_data.delay_increment = game.level_data.delay_multiplier + game.level_data.delay_increment
        if status.random_side_changes_enabled then
            game.set_sides(side_count)
        end
    end
end

function game.set_sides(side_count)
    side_count = utils.round_to_even(side_count) % 2 ^ 32
    sound.play_game("beep.ogg")
    if side_count < 3 then
        side_count = 3
    end
    game.level_data.sides = side_count
end

function game.get_main_color(black_and_white)
    local r, g, b, a = style.get_main_color()
    if black_and_white then
        r, g, b = 255, 255, 255
    end
    return r, g, b, a
end

local function set_3D_depth(style_data)
    depth = math.floor(style_data["3D_depth"] or 15)
    if depth > 100 then
        depth = 100
    end
end

public.start = async(function(pack_folder, level_id, level_options)
    public.tickrate = 960
    level_options.difficulty_mult = level_options.difficulty_mult or 1
    local difficulty_mult = level_options.difficulty_mult
    local seed = math.floor(love.timer.getTime() * 1000000000)
    math.randomseed(input.next_seed(seed))

    game.real_time = 0
    last_real_time = 0
    local key = "192_" .. pack_folder
    if not assets.mirror[key] then
        async.await(assets.index.request(key, "pack.compat.full_load", 192, pack_folder))
    end
    game.pack = assets.mirror[key]
    local level_data = game.pack.levels[level_id]
    if level_data == nil then
        error("Level with id '" .. level_id .. "' not found")
    end
    game.level_data = level.set(level_data)
    if level_data.style_id == nil then
        error("Style id cannot be 'nil'!")
    end
    local style_data = game.pack.styles[level_data.style_id]
    if style_data == nil then
        error("Style with id '" .. level_data.style_id .. "' does not exist.")
    end
    style.select(style_data)
    game.difficulty_mult = difficulty_mult
    music.stop()
    local new_music = game.pack.music[level_data.music_id]
    if new_music == nil then
        log("Music with id '" .. level_data.music_id .. "' not found")
    else
        music.play(new_music, not public.first_play)
    end
    sound.play_game("go.ogg")

    -- virtual filesystem init
    vfs.clear()
    vfs.pack_path = game.pack.info.path
    vfs.pack_folder_name = game.pack.info.id
    local files = {
        ["config.json"] = make_fake_config(config),
    }
    if public.persistent_data ~= nil then
        for path, contents in pairs(public.persistent_data) do
            files[path] = contents
        end
    end
    vfs.load_files(files)

    game.message_text = ""
    events.init(game, public)
    status.reset()
    game.restart_id = level_id
    game.restart_first_time = false
    game.set_sides(game.level_data.sides)
    walls.clear()
    walls.set_level_data(game.level_data, game.difficulty_mult)
    player.reset(config)
    game.main_timeline:clear()
    game.main_timeline:reset()
    game.message_timeline:clear()
    game.message_timeline:reset()
    game.effect_timeline:clear()
    game.effect_timeline:reset()
    if not public.first_play then
        lua_runtime.run_fn_if_exists("onUnload")
    end
    lua_runtime.init_env(game, public)
    lua_runtime.run_lua_file(game.pack.info.path .. "Scripts/" .. level_data.lua_file)
    lua_runtime.run_fn_if_exists("onLoad")
    if math.random(0, 1) == 0 then
        game.level_data.rotation_speed = -game.level_data.rotation_speed
    end
    current_rotation = 0
    set_3D_depth(style_data)
    assets.mirror_client.assign_asset_to_listener(set_3D_depth, style_data)
    shake_move[1], shake_move[2] = 0, 0
    public.running = true
end)

local function get_sign(num)
    return (num > 0 and 1 or (num == 0 and 0 or -1))
end

local function get_smoother_step(edge0, edge1, x)
    x = math.max(0, math.min(1, (x - edge0) / (edge1 - edge0)))
    return x * x * x * (x * (x * 6 - 15) + 10)
end

function public.update(frametime)
    if game.blocked_updates > 0 then
        game.blocked_updates = game.blocked_updates - 1
        return
    end
    game.real_time = game.real_time + frametime
    frametime = (game.real_time - last_real_time) * 60
    last_real_time = game.real_time
    if frametime > 4 then
        frametime = 4
    end
    input.update()
    if status.flash_effect > 0 then
        status.flash_effect = status.flash_effect - 3 * frametime
    end
    if status.flash_effect > 255 then
        status.flash_effect = 255
    elseif status.flash_effect < 0 then
        status.flash_effect = 0
    end
    if status.has_died then
        game.effect_timeline:update(frametime)
        if game.effect_timeline.finished then
            game.effect_timeline:clear()
            game.effect_timeline:reset()
        end
    end
    if not status.has_died then
        local focus = input.get("focus")
        local cw = input.get("right")
        local ccw = input.get("left")
        local move
        if cw and not ccw then
            move = 1
            last_move = 1
        elseif not cw and ccw then
            move = -1
            last_move = -1
        elseif cw and ccw then
            move = -last_move
        else
            move = 0
        end
        walls.update(frametime, status.radius)
        if player.update(frametime, status.radius, move, focus, walls) and not public.preview_mode then
            sound.play_game("death.ogg")
            sound.play_game("game_over.ogg")
            if not config.get("invincible") then
                status.flash_effect = 255
                -- camera shake
                local s = 7
                for i = s, 0, -1 do
                    local j = s - i + 1
                    for _ = 1, j * 3 do
                        game.effect_timeline:append_do(function()
                            shake_move[1] = (1 - math.random() * 2) * i
                            shake_move[2] = (1 - math.random() * 2) * i
                        end)
                        game.effect_timeline:append_wait(1)
                    end
                end
                game.effect_timeline:append_do(function()
                    shake_move[1], shake_move[2] = 0, 0
                end)
                status.has_died = true
                music.stop()
                if public.death_callback ~= nil then
                    public.death_callback()
                end
            end
        end
        events.update(frametime, status.current_time, game.message_timeline)
        if status.time_stop <= 0 then
            status.current_time = status.current_time + frametime / 60
            status.increment_time = status.increment_time + frametime / 60
        else
            status.time_stop = status.time_stop - frametime
        end
        if status.increment_enabled then
            if status.increment_time >= game.level_data.increment_time then
                status.increment_time = 0
                game.increment_difficulty()
            end
        end
        lua_runtime.run_fn_if_exists("onUpdate", frametime)
        game.main_timeline:update(frametime)
        if game.main_timeline.finished then
            game.main_timeline:clear()
            lua_runtime.run_fn_if_exists("onStep")
            game.main_timeline:reset()
        end
        if config.get("beatpulse") then
            if status.beatpulse_delay <= 0 then
                status.beatpulse = game.level_data.beatpulse_max
                status.beatpulse_delay = game.level_data.beatpulse_delay_max
            else
                status.beatpulse_delay = status.beatpulse_delay - frametime
            end
            if status.beatpulse > 0 then
                status.beatpulse = status.beatpulse - 2 * frametime
            end
            status.radius = game.level_data.radius_min * (status.pulse / game.level_data.pulse_min) + status.beatpulse
        end
        if config.get("pulse") then
            if status.pulse_delay <= 0 and status.pulse_delay_half <= 0 then
                local pulse_add = status.pulse_direction > 0 and game.level_data.pulse_speed
                    or -game.level_data.pulse_speed_r
                local pulse_limit = status.pulse_direction > 0 and game.level_data.pulse_max
                    or game.level_data.pulse_min
                status.pulse = status.pulse + pulse_add * frametime
                if
                    (status.pulse_direction > 0 and status.pulse >= pulse_limit)
                    or (status.pulse_direction < 0 and status.pulse <= pulse_limit)
                then
                    status.pulse = pulse_limit
                    status.pulse_direction = -status.pulse_direction
                    status.pulse_delay_half = game.level_data.pulse_delay_half_max
                    if status.pulse_direction < 0 then
                        status.pulse_delay = game.level_data.pulse_delay_max
                    end
                end
            end
            status.pulse_delay = status.pulse_delay - frametime
            status.pulse_delay_half = status.pulse_delay_half - frametime
        end
        if not config.get("black_and_white") then
            style.update(frametime)
        end
    else
        game.level_data.rotation_speed = game.level_data.rotation_speed * 0.99
    end
    if config.get("3D_enabled") then
        status.pulse_3D = status.pulse_3D + style.get_value("3D_pulse_speed") * status.pulse_3D_direction * frametime
        if status.pulse_3D > style.get_value("3D_pulse_max") then
            status.pulse_3D_direction = -1
        elseif status.pulse_3D < style.get_value("3D_pulse_min") then
            status.pulse_3D_direction = 1
        end
    end
    if config.get("rotation") then
        local next_rotation = math.abs(game.level_data.rotation_speed) * 10 * frametime
        if status.fast_spin > 0 then
            next_rotation = next_rotation
                + math.abs((get_smoother_step(0, game.level_data.fast_spin, status.fast_spin) / 3.5) * frametime * 17)
            status.fast_spin = status.fast_spin - frametime
        end
        current_rotation = current_rotation + next_rotation * get_sign(game.level_data.rotation_speed)
    end
    -- only for level change, real restarts happen externally
    if status.must_restart then
        public.running = false
        public.first_play = game.restart_first_time
        public.start(game.pack.info.id, game.restart_id, { difficulty_mult = game.difficulty_mult })
        return
    end
    -- TODO: invalidate score if not official status invalid set or fps limit maybe?

    if public.reset_timings then
        lua_runtime.reset_timings = false
    end
    public.reset_timings = lua_runtime.reset_timings

    -- TODO: make adjustable on a per level basis
    local performance = 0.04
    local target_frametime = (
        (0.785 * depth + 1) * (0.000461074 * performance + 0.000155698) * walls.size()
        + performance * (0.025 * depth + 1)
    )
    if target_frametime < 0.0625 then
        target_frametime = 0.0625
    elseif target_frametime > 0.25 then
        target_frametime = 0.25
    end
    game.current_frametime = target_frametime
    public.tickrate = 60 / target_frametime
end

function public.draw(screen)
    local width, height = screen:getDimensions()
    -- do the resize adjustment the old game did after already enforcing our aspect ratio
    local zoom_factor = 1 / math.max(1024 / width, 768 / height)
    -- apply pulse as well
    local p = status.pulse / game.level_data.pulse_min
    love.graphics.scale(zoom_factor / p, zoom_factor / p)
    love.graphics.translate(unpack(shake_move))
    local effect
    if config.get("3D_enabled") then
        effect = style.get_value("3D_skew") * status.pulse_3D
        love.graphics.scale(1, 1 / (1 + effect))
    end
    love.graphics.rotate(math.rad(current_rotation))
    style.compute_colors()
    local black_and_white = config.get("black_and_white")
    if config.get("background") then
        style.draw_background(game.level_data.sides % 2 ^ 32, black_and_white)
    end
    main_quads:clear()
    walls.draw(main_quads, game.get_main_color(black_and_white))
    if public.preview_mode then
        player.draw_pivot(
            game.level_data.sides % 2 ^ 32,
            status.radius,
            main_quads,
            game.get_main_color(black_and_white)
        )
    else
        player.draw(
            style,
            game.level_data.sides,
            status.radius,
            main_quads,
            black_and_white,
            game.get_main_color(black_and_white)
        )
    end
    if config.get("3D_enabled") and depth ~= 0 then
        local per_layer_offset = style.get_value("3D_spacing")
            * style.get_value("3D_perspective_multiplier")
            * config.get("3D_multiplier")
            * effect
            * 3.6
        local rad_rot = math.rad(current_rotation)
        local sin_rot = math.sin(rad_rot)
        local cos_rot = math.cos(rad_rot)
        local darken_mult = style.get_value("3D_darken_multiplier")
        local r, g, b, a = style.get_3D_override_color()
        if darken_mult == 0 then
            r, g, b = 0, 0, 0
        else
            r = r / darken_mult
            g = g / darken_mult
            b = b / darken_mult
        end
        local alpha_mult = style.get_value("3D_alpha_multiplier")
        if alpha_mult == 0 then
            a = 0
        else
            a = a / alpha_mult
        end
        local alpha_falloff = style.get_value("3D_alpha_falloff")
        for i = 1, depth do
            local offset = per_layer_offset * (i - 1)
            instance_offsets[i] = instance_offsets[i] or {}
            instance_offsets[i][1] = offset * sin_rot
            instance_offsets[i][2] = offset * cos_rot
            instance_colors[i] = instance_colors[i] or {}
            instance_colors[i][1] = r
            instance_colors[i][2] = g
            instance_colors[i][3] = b
            instance_colors[i][4] = a
            a = (a - alpha_falloff) % 256
        end
        main_quads:set_instance_attribute_array("instance_offset", "floatvec2", 3, instance_offsets)
        main_quads:set_instance_attribute_array("instance_color", "floatvec4", 4, instance_colors)
        love.graphics.setShader(layer_shader)
        main_quads:draw_instanced(depth)
        love.graphics.setShader()
    end
    main_quads:draw()
    player.draw_cap(game.level_data.sides % 2 ^ 32, style, false)
    -- message and flash shouldn't be affected by skew/rotation
    love.graphics.origin()
    love.graphics.scale(zoom_factor, zoom_factor)
    if game.message_text ~= nil and (not public.preview_mode or config.get("background_preview_has_text")) then
        local function draw_text(ox, oy)
            love.graphics.print(
                game.message_text,
                assets.mirror.imagine_font_40,
                width / zoom_factor / 2 - assets.mirror.imagine_font_40:getWidth(game.message_text) / 2 + ox,
                height / zoom_factor / 6 + oy
            )
        end
        local r, g, b, a = style.get_second_color()
        if black_and_white then
            r, g, b, a = 0, 0, 0, 0
        end
        set_color(r, g, b, a)
        -- 1.92 unlike the steam version actually does outlines like this so it's probably fine to do the same here
        draw_text(-1, -1)
        draw_text(-1, 1)
        draw_text(1, -1)
        draw_text(1, 1)
        r, g, b, a = style.get_main_color()
        if black_and_white then
            r, g, b = 255, 255, 255
        end
        set_color(r, g, b, a)
        draw_text(0, 0)
    end
    if status.flash_effect ~= 0 and config.get("flash") then
        set_color(255, 255, 255, status.flash_effect)
        love.graphics.rectangle("fill", 0, 0, width / zoom_factor, height / zoom_factor)
    end
end

---get the current score (gets the custom score if one exists)
---@return number
function public.get_score()
    return status.current_time
end

---get the current time
---@return number
function public.get_timed_score()
    return game.real_time
end

---returns true if the player has died
---@return boolean
function public.is_dead()
    return status.has_died
end

---stop the game (works during gameplay and gets out of blocking calls)
function public.stop()
    public.running = false
    music.stop()
end

---initialize the game
---@async
public.init = async(function()
    if not args.headless then
        async.await(assets.index.request("imagine_font_40", "font", "assets/font/imagine.ttf", 40))
        async.await(sound.init())
    end
end)

---updates the persistent data
function public.update_save_data()
    local files = vfs.dump_files()
    files["config.json"] = nil
    local has_files = false
    for _, _ in pairs(files) do
        has_files = true
        break
    end
    if has_files then
        public.persistent_data = files
    end
end

return public
