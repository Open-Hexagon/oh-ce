local extra_math = require("compat.game21.math")
local set_color = require("compat.game21.color_transform")
local utils = require("compat.game192.utils")

local player = {}

local hue
local angle
local size
local speed
local focus_speed
local pos
local last_pos
local dead
local color
local hue_color = { 0, 0, 0, 0 }
local cap_vertices
local conf

function player.reset(config)
    conf = config
    hue = 0
    angle = 0

    size = config.get("player_size")
    speed = config.get("player_speed")
    focus_speed = config.get("player_focus_speed")

    pos = { 0, 0 }
    last_pos = { 0, 0 }
    dead = false
    color = { 0, 0, 0, 0 }
    cap_vertices = {}
end

function player.update(frametime, radius, movement, focus, walls)
    local current_speed = speed
    local last_angle = angle
    if focus then
        current_speed = focus_speed
    end
    local rad_angle = math.rad(angle)
    last_pos[1], last_pos[2] = math.cos(rad_angle) * radius, math.sin(rad_angle) * radius
    angle = angle + current_speed * movement * frametime
    rad_angle = math.rad(angle)
    pos[1], pos[2] = math.cos(rad_angle) * radius, math.sin(rad_angle) * radius
    for wall in walls.iter() do
        if extra_math.point_in_polygon(wall.vertices, unpack(pos)) then
            if extra_math.point_in_polygon(wall.vertices, unpack(last_pos)) then
                if not conf.get("invincible") then
                    dead = true
                end
                local mag = math.sqrt(last_pos[1] ^ 2 + last_pos[2] ^ 2)
                last_pos[1] = last_pos[1] - last_pos[1] / mag * 5
                last_pos[2] = last_pos[2] - last_pos[2] / mag * 5
                pos[1], pos[2] = last_pos[1], last_pos[2]
                return true
            else
                angle = last_angle
                pos[1], pos[2] = last_pos[1], last_pos[2]
            end
        end
    end
    return false
end

function player.draw_pivot(sides, radius, main_quads, r, g, b, a)
    local div = 360 / sides
    local p_radius = radius * 0.75
    local distance2 = 5 + p_radius
    if math.abs(p_radius) > math.abs(distance2) then
        local dist = p_radius
        p_radius = distance2
        distance2 = dist
    end
    local cos, sin = math.cos, math.sin
    for i = 0, sides - 1 do
        local p_angle = div * i
        local angle0 = math.rad(p_angle - div * 0.5)
        local angle1 = math.rad(p_angle + div * 0.5)
        local p1_x, p1_y = cos(angle0) * p_radius, sin(angle0) * p_radius
        local p2_x, p2_y = cos(angle1) * p_radius, sin(angle1) * p_radius
        local p3_x, p3_y = cos(angle1) * distance2, sin(angle1) * distance2
        local p4_x, p4_y = cos(angle0) * distance2, sin(angle0) * distance2
        main_quads:add_quad(p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, r, g, b, a)
        cap_vertices[i * 2 + 1] = p1_x
        cap_vertices[i * 2 + 2] = p1_y
    end
end

local function draw_death_effect(sides, main_quads)
    local div = math.pi / sides
    local radius = hue / 8
    local thickness = hue / 20
    utils.get_color_from_hue((360 - hue) / 255, hue_color)
    hue = hue + 1
    if hue > 360 then
        hue = 0
    end
    for i = 0, sides - 1 do
        local d_angle = 2 * div * i
        local p1_x, p1_y = extra_math.get_orbit(pos, d_angle - div, radius)
        local p2_x, p2_y = extra_math.get_orbit(pos, d_angle + div, radius)
        local p3_x, p3_y = extra_math.get_orbit(pos, d_angle + div, radius + thickness)
        local p4_x, p4_y = extra_math.get_orbit(pos, d_angle - div, radius + thickness)
        main_quads:add_quad(p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, unpack(hue_color))
    end
end

function player.draw(style, sides, radius, main_quads, black_and_white, r, g, b, a)
    player.draw_pivot(sides, radius, main_quads, r, g, b, a)
    if dead then
        draw_death_effect(sides, main_quads)
    end
    color[1], color[2], color[3], color[4] = style.get_main_color()
    if black_and_white then
        color[1], color[2], color[3] = 255, 255, 255
    end
    if dead then
        utils.get_color_from_hue(hue / 255, color)
    end
    local rad = math.rad
    local p_left_x, p_left_y = extra_math.get_orbit(pos, rad(angle - 100), size + 3)
    local p_right_x, p_right_y = extra_math.get_orbit(pos, rad(angle + 100), size + 3)
    local x, y = extra_math.get_orbit(pos, rad(angle), size)
    -- TODO: possibly make some kind of dynamic mix mesh so this can be cleaner?
    main_quads:add_quad(x, y, x, y, p_left_x, p_left_y, p_right_x, p_right_y, unpack(color))
end

-- have to actually draw later because of 3d
function player.draw_cap(sides, style, black_and_white)
    if sides > 2 then
        local r, g, b, a = style.get_second_color()
        if black_and_white then
            r, g, b, a = 0, 0, 0, 0
        end
        set_color(r, g, b, a)
        love.graphics.polygon("fill", unpack(cap_vertices, 1, sides * 2))
    end
end

return player
