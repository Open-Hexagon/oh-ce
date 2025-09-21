local args = require("args")
local dynamic_tris = require("compat.game21.dynamic_tris")
local utils = require("compat.game192.utils")
local style = {}

local function set_color_data_defaults(color_data)
    color_data = color_data or {}
    color_data.main = color_data.main or false
    color_data.dynamic = color_data.dynamic or false
    color_data.dynamic_offset = color_data.dynamic_offset or false
    color_data.dynamic_darkness = color_data.dynamic_darkness or 1
    color_data.hue_shift = color_data.hue_shift or 0
    color_data.offset = color_data.offset or 0
    color_data.value = color_data.value or { 255, 255, 255, 255 }
    color_data.pulse = color_data.pulse or { 255, 255, 255, 255 }
    color_data.result = { unpack(color_data.value) }
    return color_data
end

local current_hue_color = {}

local function calculate_color(color_data)
    if color_data.dynamic then
        utils.get_color_from_hue((style.current_hue + color_data.hue_shift) / 360, current_hue_color)
        if color_data.main then
            for i = 1, 4 do
                color_data.result[i] = current_hue_color[i]
            end
        else
            if color_data.dynamic_offset then
                for i = 1, 3 do
                    color_data.result[i] = color_data.value[i] + current_hue_color[i] / color_data.offset
                end
                color_data.result[4] = color_data.value[4] + current_hue_color[4]
            else
                for i = 1, 3 do
                    color_data.result[i] = current_hue_color[i] / color_data.dynamic_darkness
                end
                color_data.result[4] = current_hue_color[4]
            end
        end
    else
        for i = 1, 4 do
            color_data.result[i] = color_data.value[i]
        end
    end
    for i = 1, 4 do
        local value = color_data.result[i]
        if value ~= value or value == math.huge then
            -- nan or inf
            value = 0
        end
        value = value + color_data.pulse[i] * style.pulse_factor
        if value > 255 then
            value = 255
        elseif value < 0 then
            value = 0
        end
        color_data.result[i] = value
    end
end

local current_colors
local current_3D_override_color
local color_index_offset

function style.set(style_json, no_listen)
    -- the no_listen parameter is required because this module may be used during asset loading
    -- requiring the mirror_client would cause problems in that case
    if not no_listen then
        require("asset_system.mirror_client").assign_asset_to_listener(style.set, style_json)
    end
    style_json = style_json or {}
    style.current_swap_time = 0
    style.pulse_factor = 0
    style.id = style_json.id or "nullId"
    style.hue_min = style_json.hue_min or 0
    style.hue_max = style_json.hue_max or 360
    style.hue_increment = style_json.hue_increment or 0
    style.pulse_min = style_json.pulse_min or 0
    style.pulse_max = style_json.pulse_max or 0
    style.pulse_increment = style_json.pulse_increment or 0
    style.hue_ping_pong = style_json.hue_ping_pong or false
    style.max_swap_time = style_json.max_swap_time or 100
    style._3D_depth = style_json["3D_depth"] or 15
    style._3D_skew = style_json["3D_skew"] or 0.18
    style._3D_spacing = style_json["3D_spacing"] or 1
    style._3D_darken_mult = style_json["3D_darken_multiplier"] or 1.5
    style._3D_alpha_mult = style_json["3D_alpha_multiplier"] or 0.5
    style._3D_alpha_falloff = style_json["3D_alpha_falloff"] or 3
    style._3D_pulse_max = style_json["3D_pulse_max"] or 3.2
    style._3D_pulse_min = style_json["3D_pulse_min"] or 0
    style._3D_pulse_speed = style_json["3D_pulse_speed"] or 0.01
    style._3D_perspective_mult = style_json["3D_perspective_multiplier"] or 1
    style._3D_override_color = style_json["3D_override_color"] or { 0, 0, 0, 0 }
    style.main_color_data = set_color_data_defaults(style_json.main)
    style.current_hue = style.hue_min
    style.color_datas = style_json.colors or {}
    current_colors = {}
    for i = 1, #style.color_datas do
        current_colors[#current_colors + 1] = set_color_data_defaults(style.color_datas[i]).result
    end
    color_index_offset = 0
end

function style.update(frametime, mult)
    mult = mult or 1
    style.current_swap_time = style.current_swap_time + frametime * mult
    if style.current_swap_time > style.max_swap_time then
        style.current_swap_time = 0
    end
    style.current_hue = style.current_hue + style.hue_increment * frametime * mult
    if style.current_hue < style.hue_min then
        if style.hue_ping_pong then
            style.current_hue = style.hue_min
            style.hue_increment = -style.hue_increment
        else
            style.current_hue = style.hue_max
        end
    end
    if style.current_hue > style.hue_max then
        if style.hue_ping_pong then
            style.current_hue = style.hue_max
            style.hue_increment = -style.hue_increment
        else
            style.current_hue = style.hue_min
        end
    end
    style.pulse_factor = style.pulse_factor + style.pulse_increment * frametime
    if style.pulse_factor < style.pulse_min then
        style.pulse_increment = -style.pulse_increment
        style.pulse_factor = style.pulse_min
    end
    if style.pulse_factor > style.pulse_max then
        style.pulse_increment = -style.pulse_increment
        style.pulse_factor = style.pulse_max
    end
end

function style.compute_colors()
    calculate_color(style.main_color_data)
    if style._3D_override_color[4] == 0 then
        current_3D_override_color = style.main_color_data.result
    else
        current_3D_override_color = style._3D_override_color
    end
    for i = 1, #style.color_datas do
        calculate_color(style.color_datas[i])
    end
    if #style.color_datas > 1 then
        color_index_offset = math.floor(2 * style.current_swap_time / style.max_swap_time)
    end
end

function style.get_color(index)
    local color = current_colors[(color_index_offset + index - 1) % #current_colors + 1]
    if color == nil then
        return 0, 0, 0, 0
    else
        return unpack(color)
    end
end

function style.get_3D_override_color()
    return unpack(current_3D_override_color)
end

function style.get_main_color()
    return unpack(style.main_color_data.result)
end

local background_tris
if not args.headless then
    background_tris = dynamic_tris:new()
end

function style.draw_background(sides, black_and_white)
    local div = 2 * math.pi / sides
    local distance = 4500
    local sin, cos = math.sin, math.cos
    background_tris:clear()
    for i = 1, sides do
        local angle = div * (i - 1)
        local r, g, b, a = style.get_color(i)
        if black_and_white then
            r, g, b, a = 0, 0, 0, 255
        elseif (i - 1) % 2 == 0 and i == sides then
            r, g, b = r / 1.4, g / 1.4, b / 1.4
        end
        local angle1, angle2 = angle + div * 0.5, angle - div * 0.5
        local s1, c1 = sin(angle1), cos(angle1)
        local s2, c2 = sin(angle2), cos(angle2)
        background_tris:add_tris(0, 0, c1 * distance, s1 * distance, c2 * distance, s2 * distance, r, g, b, a)
    end
    background_tris:draw()
end

return style
