local set_color = require("compat.game21.color_transform")
local sound = require("compat.sound")
local utils = require("compat.game192.utils")
local extra_math = require("compat.game21.math")
local timer = require("compat.game21.timer")
local config = require("config")
local walls = require("compat.game20.walls")
local style = require("compat.game20.style")
local level_status = require("compat.game20.level_status")
local status = require("compat.game20.status")
local player = {}

local base_thickness = 5
local swap_timer
local swap_blink_timer
local dead_effect_timer
local angle = 0
local hue = 0
local dead = false
local size, speed, focus_speed
local black_and_white
local color_main = {}
local pos
local last_pos
local start_pos = { 0, 0 }
local game
local cap_vertices = {}

function player.reset(pass_game)
    game = pass_game
    swap_timer = timer:new(36)
    swap_blink_timer = timer:new(5)
    dead_effect_timer = timer:new(80, false)
    angle = 0
    hue = 0
    dead = false
    size = config.get("player_size")
    speed = config.get("player_speed")
    focus_speed = config.get("player_focus_speed")
    black_and_white = config.get("black_and_white")
    pos = { 0, 0 }
    last_pos = { 0, 0 }
end

local function update_main_color()
    color_main[1], color_main[2], color_main[3], color_main[4] = style.get_main_color()
    if black_and_white then
        color_main[1], color_main[2], color_main[3] = 255, 255, 255
    end
end

function player.draw_pivot(main_quads)
    local sides = level_status.sides
    local div = math.pi / sides
    local radius = status.radius * 0.75
    update_main_color()
    local cap_vertex_count = 0
    for i = 0, sides - 1 do
        local s_angle = div * 2 * i
        local p1_x, p1_y = extra_math.get_orbit(start_pos, s_angle - div, radius)
        local p2_x, p2_y = extra_math.get_orbit(start_pos, s_angle + div, radius)
        local p3_x, p3_y = extra_math.get_orbit(start_pos, s_angle + div, radius + base_thickness)
        local p4_x, p4_y = extra_math.get_orbit(start_pos, s_angle - div, radius + base_thickness)
        main_quads:add_quad(p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, unpack(color_main))
        cap_vertices[i * 2 + 1] = p1_x
        cap_vertices[i * 2 + 2] = p1_y
        cap_vertex_count = cap_vertex_count + 2
    end
    while #cap_vertices > cap_vertex_count do
        cap_vertices[#cap_vertices] = nil
    end
    -- can't have polygon with less than 3 vertices, so just put some extra at 0 0 so the game doesn't crash
    while #cap_vertices < 6 do
        cap_vertices[#cap_vertices + 1] = 0
    end
end

local function draw_death_effect()
    local sides = level_status.sides
    local div = math.pi / sides
    local radius = hue / 8
    local thickness = hue / 20
    utils.get_color_from_hue((360 - hue) / 255, color_main)
    set_color(unpack(color_main))
    hue = hue + 1
    if hue > 360 then
        hue = 0
    end
    for i = 0, sides - 1 do
        local s_angle = div * 2 * i
        local p1_x, p1_y = extra_math.get_orbit(pos, s_angle - div, radius)
        local p2_x, p2_y = extra_math.get_orbit(pos, s_angle + div, radius)
        local p3_x, p3_y = extra_math.get_orbit(pos, s_angle + div, radius + thickness)
        local p4_x, p4_y = extra_math.get_orbit(pos, s_angle - div, radius + thickness)
        love.graphics.polygon("fill", p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y)
    end
end

function player.draw(main_quads)
    player.draw_pivot(main_quads)
    if dead then
        utils.get_color_from_hue(hue / 255, color_main)
    else
        update_main_color()
    end
    local rad100 = math.rad(100)
    local distance = size + 3
    local p_left_x, p_left_y = extra_math.get_orbit(pos, angle - rad100, distance)
    local p_right_x, p_right_y = extra_math.get_orbit(pos, angle + rad100, distance)
    local p_top_x, p_top_y = extra_math.get_orbit(pos, angle, size)
    if not swap_timer.running then
        utils.get_color_from_hue(swap_blink_timer.current * 15 / 255, color_main)
    end
    main_quads:add_quad(
        p_top_x,
        p_top_y,
        p_top_x,
        p_top_y,
        p_left_x,
        p_left_y,
        p_right_x,
        p_right_y,
        unpack(color_main)
    )
end

function player.draw_cap()
    -- draw death effect here to be on top of everything else apart from cap
    if dead_effect_timer.running then
        draw_death_effect()
    end
    local r, g, b, a = style.get_color(2)
    if black_and_white then
        r, g, b, a = 0, 0, 0, 255
    end
    set_color(r, g, b, a)
    love.graphics.polygon("fill", cap_vertices)
    -- reset so the next drawn stuff still looks correct
    love.graphics.setColor(1, 1, 1, 1)
end

function player.update(frametime, movement, focus, swap)
    swap_blink_timer:update(frametime)
    if dead_effect_timer:update(frametime) and level_status.tutorial_mode then
        dead_effect_timer:stop()
    end
    if level_status.swap_enabled and swap_timer:update(frametime) then
        swap_timer:stop()
    end
    local current_speed = speed
    local last_angle = angle
    local radius = status.radius
    if focus then
        current_speed = focus_speed
    end
    angle = angle + math.rad(current_speed * movement * frametime)
    if level_status.swap_enabled and swap and not swap_timer.running then
        sound.play_game("swap.ogg")
        swap_timer:restart()
        angle = angle + math.pi
    end
    extra_math.get_orbit(start_pos, angle, radius, pos)
    extra_math.get_orbit(start_pos, last_angle, radius, last_pos)
    for i = 1, #walls.entities do
        if extra_math.point_in_polygon(walls.entities[i].vertices, unpack(pos)) then
            if extra_math.point_in_polygon(walls.entities[i].vertices, unpack(last_pos)) then
                dead_effect_timer:restart()
                if not config.get("invincible") then
                    dead = true
                end
                extra_math.get_orbit(last_pos, angle, -5 * game.get_speed_mult_dm(), pos)
                game.death()
                return
            else
                angle = last_angle
                pos[1], pos[2] = last_pos[1], last_pos[2]
            end
        end
    end
end

return player
