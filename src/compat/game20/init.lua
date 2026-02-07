local args = require("args")
local sound = require("compat.sound")
local assets = require("asset_system")
local make_fake_config = require("compat.game20.fake_config")
local lua_runtime = require("compat.game20.lua_runtime")
local dynamic_quads = require("compat.game21.dynamic_quads")
local set_color = require("compat.game21.color_transform")
local timeline = require("compat.game20.timeline")
local async = require("async")
local music = require("compat.music")
local config = require("config")
local input = require("input")
local status = require("compat.game20.status")
local level = require("compat.game20.level")
local level_status = require("compat.game20.level_status")
local vfs = require("compat.game192.virtual_filesystem")
local style = require("compat.game20.style")
local player = require("compat.game20.player")
local walls = require("compat.game20.walls")
local public = {
    running = false,
    first_play = true,
    tickrate = 120,
}
local game = {
    main_timeline = timeline:new(),
    event_timeline = timeline:new(),
    message_timeline = timeline:new(),
    effect_timeline = timeline:new(),
    message_text = "",
    real_time = 0,
}
local shake_move = { 0, 0 }
local main_quads
local must_change_sides = false
local last_move, move = 0, 0
local depth = 0
local layer_shader
local instance_offsets = {}
local instance_colors = {}

local function set_3D_depth(style_data)
    depth = math.min(style_data["3D_depth"] or 15, config.get("3D_max_depth"))
end

---starts a new game
---@param pack_id string
---@param level_id string
---@param level_options table
public.start = async(function(pack_id, level_id, level_options)
    level_options.difficulty_mult = level_options.difficulty_mult or 1
    game.difficulty_mult = level_options.difficulty_mult
    local seed = math.floor(love.timer.getTime() * 1000000000)
    math.randomseed(input.next_seed(seed))

    local key = "20_" .. pack_id
    if not assets.mirror[key] then
        async.await(assets.index.request(key, "pack.compat.full_load", 20, pack_id))
    end
    game.pack = assets.mirror[key]
    level.set(game.pack.levels[level_id])
    level_status.reset()
    local style_data = game.pack.styles[level.style_id]
    style.set(style_data)
    music.stop()
    local pitch = config.get("sync_music_to_dm") and math.pow(game.difficulty_mult, 0.12) or 1
    music.play(game.pack.music[level.music_id], not public.first_play, nil, pitch)
    sound.play_game("go.ogg")

    -- virtual filesystem init
    vfs.clear()
    vfs.pack_path = game.pack.info.path
    vfs.pack_folder_name = game.pack.folder
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
    game.event_timeline:clear()
    game.event_timeline:reset()
    game.message_timeline:clear()
    game.message_timeline:reset()
    walls.init()
    player.reset(game)
    game.main_timeline:clear()
    game.main_timeline:reset()
    game.effect_timeline:clear()
    game.effect_timeline:reset()
    must_change_sides = false
    status.reset()
    game.real_time = 0
    if not public.first_play then
        lua_runtime.run_fn_if_exists("onUnload")
    end
    lua_runtime.init_env(game, public)
    lua_runtime.run_lua_file(game.pack.info.path .. level.lua_file)
    lua_runtime.run_fn_if_exists("onInit")
    lua_runtime.run_fn_if_exists("onLoad")
    game.set_sides(level_status.sides)
    game.current_rotation = 0
    style._3D_depth = math.min(style._3D_depth, config.get("3D_max_depth"))
    set_3D_depth(style_data)
    assets.mirror_client.assign_asset_to_listener(set_3D_depth, style_data)
    public.running = true
end)

function game.increment_difficulty()
    sound.play_game("level_up.ogg")
    level_status.rotation_speed = level_status.rotation_speed
        + level_status.rotation_speed_inc * (level_status.rotation_speed > 0 and 1 or -1)
    level_status.rotation_speed = -level_status.rotation_speed
    local rotation_speed_max = level_status.rotation_speed_max
    if status.fast_spin < 0 and math.abs(level_status.rotation_speed) > rotation_speed_max then
        level_status.rotation_speed = rotation_speed_max * (level_status.rotation_speed > 0 and 1 or -1)
    end
    status.fast_spin = level_status.fast_spin
end

function game.get_speed_mult_dm()
    return level_status.speed_mult * math.pow(game.difficulty_mult, 0.65)
end

function game.get_delay_mult_dm()
    return level_status.delay_mult / math.pow(game.difficulty_mult, 0.10)
end

function game.death(force)
    sound.play_game("death.ogg")
    if not force and (config.get("invincible") or level_status.tutorial_mode) then
        return
    end
    sound.play_game("game_over.ogg")
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
    if public.death_callback then
        public.death_callback()
    end
end

function game.set_sides(sides)
    sound.play_game("beep.ogg")
    if sides < 3 then
        sides = 3
    end
    level_status.sides = sides
end

local function get_smoother_step(edge0, edge1, x)
    x = math.max(0, math.min(1, (x - edge0) / (edge1 - edge0)))
    return x * x * x * (x * (x * 6 - 15) + 10)
end

---update the game
---@param frametime number
function public.update(frametime)
    game.real_time = game.real_time + frametime
    frametime = frametime * 60
    input.update()
    local focus = input.get("focus")
    local swap = input.get("swap")
    local cw = input.get("right")
    local ccw = input.get("left")
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
    if status.flash_effect > 0 then
        status.flash_effect = status.flash_effect - 3 * frametime
    end
    if status.flash_effect > 255 then
        status.flash_effect = 255
    elseif status.flash_effect < 0 then
        status.flash_effect = 0
    end
    if not status.has_died then
        walls.update(frametime)
        if not public.preview_mode then
            player.update(frametime, move, focus, swap)
        end
        game.event_timeline:update(frametime)
        if game.event_timeline.finished then
            game.event_timeline:clear()
            game.event_timeline:reset()
        end
        game.message_timeline:update(frametime)
        if game.message_timeline.finished then
            game.message_timeline:clear()
            game.message_timeline:reset()
        end
        if status.time_stop <= 0 then
            status.current_time = status.current_time + frametime / 60
            status.increment_time = status.increment_time + frametime / 60
        else
            status.time_stop = status.time_stop - frametime
        end
        if level_status.inc_enabled and status.increment_time >= level_status.inc_time then
            status.increment_time = 0
            game.increment_difficulty()
            must_change_sides = true
        end
        if must_change_sides and #walls.entities == 0 then
            local sides = math.random(level_status.sides_min, level_status.sides_max)
            lua_runtime.run_fn_if_exists("onIncrement")
            level_status.speed_mult = level_status.speed_mult + level_status.speed_inc
            level_status.delay_mult = level_status.delay_mult + level_status.delay_inc
            if level_status.rnd_side_changes_enabled then
                game.set_sides(sides)
            end
            must_change_sides = false
        end
        if status.time_stop <= 0 then
            lua_runtime.run_fn_if_exists("onUpdate", frametime)
            game.main_timeline:update(frametime)
            if game.main_timeline.finished and not must_change_sides then
                game.main_timeline:clear()
                lua_runtime.run_fn_if_exists("onStep")
                game.main_timeline:reset()
            end
        end
        local music_dm_sync_factor = config.get("sync_music_to_dm") and math.pow(game.difficulty_mult, 0.12) or 1
        if config.get("beatpulse") then
            if status.beatpulse_delay <= 0 then
                status.beatpulse = level_status.beat_pulse_max
                status.beatpulse_delay = level_status.beat_pulse_delay_max
            else
                status.beatpulse_delay = status.beatpulse_delay - frametime * music_dm_sync_factor
            end
            if status.beatpulse > 0 then
                status.beatpulse = status.beatpulse - 2 * frametime * music_dm_sync_factor
            end
            local radius_min = config.get("beatpulse") and level_status.radius_min or 75
            status.radius = radius_min * (status.pulse / level_status.pulse_min) + status.beatpulse
        end
        if config.get("pulse") then
            if status.pulse_delay <= 0 and status.pulse_delay_half <= 0 then
                local pulse_add = status.pulse_direction > 0 and level_status.pulse_speed or -level_status.pulse_speed_r
                local pulse_limit = status.pulse_direction > 0 and level_status.pulse_max or level_status.pulse_min
                status.pulse = status.pulse + pulse_add * frametime * music_dm_sync_factor
                if
                    (status.pulse_direction > 0 and status.pulse >= pulse_limit)
                    or (status.pulse_direction < 0 and status.pulse <= pulse_limit)
                then
                    status.pulse = pulse_limit
                    status.pulse_direction = -status.pulse_direction
                    status.pulse_delay_half = level_status.pulse_delay_half_max
                    if status.pulse_direction < 0 then
                        status.pulse_delay = level_status.pulse_delay_max
                    end
                end
            end
            status.pulse_delay = status.pulse_delay - frametime
            status.pulse_delay_half = status.pulse_delay_half - frametime
        end
        if not config.get("black_and_white") then
            style.update(frametime, math.pow(game.difficulty_mult, 0.8))
        end
    else
        game.effect_timeline:update(frametime)
        if game.effect_timeline.finished then
            game.effect_timeline:clear()
            game.effect_timeline:reset()
        end
        level_status.rotation_speed = level_status.rotation_speed * 0.99
    end
    if config.get("3D_enabled") then
        status.pulse_3D = status.pulse_3D + style._3D_pulse_speed * status.pulse_3D_direction * frametime
        if status.pulse_3D > style._3D_pulse_max then
            status.pulse_3D_direction = -1
        elseif status.pulse_3D < style._3D_pulse_min then
            status.pulse_3D_direction = 1
        end
    end
    if config.get("rotation") then
        local next_rotation = level_status.rotation_speed * 10
        if status.fast_spin > 0 then
            next_rotation = next_rotation
                + math.abs(get_smoother_step(0, level_status.fast_spin, status.fast_spin) / 3.5 * 17)
                    * (next_rotation > 0 and 1 or -1)
            status.fast_spin = status.fast_spin - frametime
        end
        game.current_rotation = (game.current_rotation + next_rotation * frametime) % 360
    end
end

---draw the game to the current canvas
---@param screen love.Canvas
function public.draw(screen)
    local width, height = screen:getDimensions()
    -- do the resize adjustment the old game did after already enforcing our aspect ratio
    local zoom_factor = 1 / math.max(1024 / width, 768 / height)
    -- apply pulse as well
    local p = status.pulse / level_status.pulse_min
    love.graphics.scale(zoom_factor / p, zoom_factor / p)
    love.graphics.translate(unpack(shake_move))
    local effect
    if config.get("3D_enabled") then
        effect = style._3D_skew * status.pulse_3D * config.get("3D_multiplier")
        love.graphics.scale(1, 1 / (1 + effect))
    end
    love.graphics.rotate(math.rad(game.current_rotation))
    style.compute_colors()
    local black_and_white = config.get("black_and_white")
    if config.get("background") then
        style.draw_background(level_status.sides, black_and_white)
    end
    main_quads:clear()
    walls.draw(main_quads)
    if public.preview_mode then
        player.draw_pivot(main_quads)
    else
        player.draw(main_quads)
    end
    if config.get("3D_enabled") and depth > 0 then
        local per_layer_offset = style._3D_spacing * style._3D_perspective_mult * effect * 3.6
        local rad_rot = math.rad(game.current_rotation)
        local sin_rot = math.sin(rad_rot)
        local cos_rot = math.cos(rad_rot)
        local darken_mult = style._3D_darken_mult
        local r, g, b, a = style.get_3D_override_color()
        if darken_mult == 0 then
            r, g, b = 0, 0, 0
        else
            r = r / darken_mult
            g = g / darken_mult
            b = b / darken_mult
        end
        local alpha_mult = style._3D_alpha_mult
        if alpha_mult == 0 then
            a = 0
        else
            a = a / alpha_mult
        end
        local alpha_falloff = style._3D_alpha_falloff
        for i = 1, depth do
            local offset = per_layer_offset * i
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
    player.draw_cap()

    -- message and flash shouldn't be affected by skew/rotation
    love.graphics.origin()
    love.graphics.scale(zoom_factor, zoom_factor)
    if game.message_text ~= nil and (not public.preview_mode or config.get("background_preview_has_text")) then
        local function draw_text(ox, oy)
            love.graphics.print(
                game.message_text,
                assets.mirror.imagine_font_38,
                width / zoom_factor / 2 - assets.mirror.imagine_font_38:getWidth(game.message_text) / 2 + ox,
                height / zoom_factor / 6 + oy
            )
        end
        local r, g, b, a = style.get_color(2)
        if black_and_white then
            r, g, b, a = 0, 0, 0, 0
        end
        set_color(r, g, b, a)
        -- 2.0-rc2 unlike the steam version actually does outlines like this so it's probably fine to do the same here
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

---get the current score
---@return number
function public.get_score()
    return status.current_time
end

---get the timed current score
---@return number
function public.get_timed_score()
    return game.real_time
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

---initialize the game
---@async
public.init = async(function()
    if not args.headless then
        main_quads = dynamic_quads:new()
        async.await(assets.index.request("imagine_font_38", "font", "assets/font/imagine.ttf", 38))
        async.await(sound.init())
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
    end
end)

return public
