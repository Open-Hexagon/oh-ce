local args = require("args")
local Tris = require("compat.game21.dynamic_tris")
local get_color_from_hue = require("compat.game21.hue").get_color
local utils = require("compat.game192.utils")
local style = {}

local function set_color_data_defaults(data)
    data.main = data.main or false
    data.dynamic = data.dynamic or false
    data.dynamic_offset = data.dynamic_offset or false
    data.dynamic_darkness = data.dynamic_darkness or 1
    data.hue_shift = data.hue_shift or 0
    data.offset = data.offset or 0
    data.value = data.value or { 0, 0, 0, 255 }
    data.pulse = data.pulse or { 0, 0, 0, 255 }
    data.result = { 0, 0, 0, 0 }

    -- removes a runtime check
    if data.dynamic and not data.dynamic_offset and data.dynamic_darkness == 0 then
        data.main = true
    end
end

local function parse_cap_color(obj)
    if obj == nil then
        return 4
    end
    if type(obj) == "string" then
        if obj == "main" then
            return 1 -- just use main color
        elseif obj == "main_darkened" then
            return 2 -- use main color but divide rgb by 1.4
        else
            -- invalid string, return default
            return 4
        end
    else
        local legacy = obj.legacy
        if legacy == nil then
            legacy = true
        end
        if legacy then
            -- use the color of the 1st background panel or the one of the index
            return 4 + (obj.index or 0)
        else
            set_color_data_defaults(obj)
            return 3 -- custom color
        end
    end
end

local _current_hue
local _current_swap_time
local _pulse_factor
local _current_3D_override_color
local _main_color_data
local _player_color_data
local _text_color
local _wall_color
local _cap_color
local _cap_color_obj
local _color_datas
local _colors
local _color_start_index
local _current_hue_color
local _background_tris
if not args.headless then
    _background_tris = Tris:new()
end

function style.select(style_data)
    style_data = style_data or {}
    _current_hue = style_data.hue_min or 0
    _current_swap_time = 0
    _pulse_factor = 0
    _current_3D_override_color = { 0, 0, 0, 0 }
    _main_color_data = style_data.main or {}
    _player_color_data = style_data.player_color or _main_color_data
    _text_color = style_data.text_color or _main_color_data
    _wall_color = style_data.wall_color or _main_color_data
    _cap_color = parse_cap_color(style_data.cap_color)
    _cap_color_obj = style_data.cap_color
    _color_datas = {}
    _colors = {}
    _color_start_index = 0
    _current_hue_color = { 0, 0, 0, 0 }
    style.id = style_data.id or "nullId"
    style.hue_min = style_data.hue_min or 0
    style.hue_max = style_data.hue_max or 360
    style.hue_increment = style_data.hue_increment or 0
    style.hue_ping_pong = style_data.hue_ping_pong
    style.pulse_min = style_data.pulse_min or 0
    style.pulse_max = style_data.pulse_max or 0
    style.pulse_increment = style_data.pulse_increment or 0
    style.max_swap_time = style_data.max_swap_time or 100
    style.pseudo_3D_depth = style_data["3D_depth"] or 15
    style.pseudo_3D_skew = style_data["3D_skew"] or 0.18
    style.pseudo_3D_spacing = style_data["3D_spacing"] or 1
    style.pseudo_3D_darken_mult = style_data["3D_darken_multiplier"] or 1.5
    style.pseudo_3D_alpha_mult = style_data["3D_alpha_multiplier"] or 0.5
    style.pseudo_3D_alpha_falloff = style_data["3D_alpha_falloff"] or 3
    style.pseudo_3D_pulse_max = style_data["3D_pulse_max"] or 3.2
    style.pseudo_3D_pulse_min = style_data["3D_pulse_min"] or 0
    style.pseudo_3D_pulse_speed = style_data["3D_pulse_speed"] or 0.01
    style.pseudo_3D_perspective_mult = style_data["3D_perspective_multiplier"] or 1
    style.bg_tile_radius = 10000
    style.bg_color_offset = 0
    style.bg_rot_off = 0
    style.pseudo_3D_override_color = style_data["3D_override_color"] or { 0, 0, 0, 0 }
    style.pseudo_3D_override_is_main = true
    set_color_data_defaults(_main_color_data)
    set_color_data_defaults(_player_color_data)
    set_color_data_defaults(_text_color)
    set_color_data_defaults(_wall_color)
    local colors = style_data.colors or {}
    for i = 1, #colors do
        set_color_data_defaults(colors[i])
        _color_datas[i] = colors[i]
        _colors[i] = colors[i].result
    end
    for key, value in pairs(style) do
        if type(value) == "number" then
            style[key] = utils.float_round(value)
        end
    end
end

function style.calculate_color(color_data)
    if color_data.dynamic then
        get_color_from_hue(math.fmod(_current_hue + color_data.hue_shift, 360) / 360, _current_hue_color)
        if color_data.main then
            for i = 1, 4 do
                color_data.result[i] = _current_hue_color[i]
            end
        else
            if color_data.dynamic_offset then
                if color_data.offset == 0 then
                    for i = 1, 3 do
                        color_data.result[i] = color_data.value[i]
                    end
                else
                    for i = 1, 3 do
                        color_data.result[i] = color_data.value[i] + _current_hue_color[i] / color_data.offset
                    end
                end
                -- hue color alpha is always 255
                color_data.result[4] = color_data.value[4] + 255
            else
                -- usually wouldn't divide if color_data.dynamic_darkness == 0 but we already checked for that while setting defaults
                for i = 1, 3 do
                    color_data.result[i] = (_current_hue_color[i] / color_data.dynamic_darkness) % 256
                end
                -- hue color alpha is always 255
                color_data.result[4] = 255
            end
        end
    else
        for i = 1, 4 do
            color_data.result[i] = color_data.value[i]
        end
    end
    for i = 1, 4 do
        local value = (color_data.result[i] % 256) + (color_data.pulse[i] or 0) * _pulse_factor
        if value > 255 then
            value = 255
        elseif value < 0 then
            value = 0
        end
        color_data.result[i] = value
    end
end

function style.update(frametime, mult)
    _current_swap_time = _current_swap_time + frametime * mult
    if _current_swap_time > style.max_swap_time then
        _current_swap_time = 0
    end
    _current_hue = _current_hue + style.hue_increment * frametime * mult
    if _current_hue < style.hue_min then
        if style.hue_ping_pong then
            _current_hue = style.hue_min
            style.hue_increment = -style.hue_increment
        else
            _current_hue = style.hue_max
        end
    elseif _current_hue > style.hue_max then
        if style.hue_ping_pong then
            _current_hue = style.hue_max
            style.hue_increment = -style.hue_increment
        else
            _current_hue = style.hue_min
        end
    end
    _pulse_factor = _pulse_factor + style.pulse_increment * frametime
    if _pulse_factor < style.pulse_min then
        style.pulse_increment = -style.pulse_increment
        _pulse_factor = style.pulse_min
    elseif _pulse_factor > style.pulse_max then
        style.pulse_increment = -style.pulse_increment
        _pulse_factor = style.pulse_max
    end
end

function style.compute_colors()
    style.calculate_color(_main_color_data)
    style.calculate_color(_player_color_data)
    style.calculate_color(_text_color)
    style.calculate_color(_wall_color)
    _current_3D_override_color = style.pseudo_3D_override_color[4] == 0 and _main_color_data.result
        or style.pseudo_3D_override_color
    for i = 1, 4 do
        if _current_3D_override_color[i] ~= _main_color_data.result[i] then
            style.pseudo_3D_override_is_main = false
            break
        end
    end
    for i = 1, #_color_datas do
        style.calculate_color(_color_datas[i])
    end
    if style.max_swap_time == 0 then
        _color_start_index = style.bg_color_offset
    else
        local rotation = 2 * _current_swap_time / style.max_swap_time
        _color_start_index = math.floor(rotation + style.bg_color_offset)
    end
end

function style.draw_background(sides, darken_uneven_background_chunk, black_and_white)
    _background_tris:clear()
    if #_color_datas ~= 0 then
        local sin, cos = math.sin, math.cos
        local div = 2 * math.pi / sides
        local half_div = div * 0.5
        local distance = style.bg_tile_radius
        for i = 0, sides - 1 do
            local angle = math.rad(style.bg_rot_off) + div * i
            local r, g, b, a = style.get_color(i)
            local must_darken = (i % 2 == 0 and i == sides - 1) and darken_uneven_background_chunk
            if black_and_white then
                r, g, b, a = 0, 0, 0, 255
            elseif must_darken then
                r = r / 1.4
                g = g / 1.4
                b = b / 1.4
            end
            local angle0, angle1 = angle + half_div, angle - half_div
            _background_tris:add_tris(
                cos(angle0) * distance,
                sin(angle0) * distance,
                cos(angle1) * distance,
                sin(angle1) * distance,
                0,
                0,
                r,
                g,
                b,
                a
            )
        end
        _background_tris:draw()
    end
end

function style._get_color(index)
    return _colors[(_color_start_index + index) % #_colors + 1]
end

function style.set_cap_color(mode)
    _cap_color = mode
end

function style.get_main_color()
    return unpack(_main_color_data.result)
end

function style.get_player_color()
    return unpack(_player_color_data.result)
end

function style.get_text_color()
    return unpack(_text_color.result)
end

function style.get_wall_color()
    return unpack(_wall_color.result)
end

function style.get_color(index)
    return unpack(style._get_color(index) or { 0, 0, 0, 255 })
end

function style.get_current_hue()
    return _current_hue
end

function style.get_current_swap_time()
    return _current_swap_time
end

function style.get_3D_override_color()
    return unpack(_current_3D_override_color)
end

function style.get_cap_color_result()
    if _cap_color == 1 then
        return style.get_main_color()
    elseif _cap_color == 2 then
        local r, g, b, a = style.get_main_color()
        return r / 1.4, g / 1.4, b / 1.4, a
    elseif _cap_color == 3 then
        style.calculate_color(_cap_color_obj)
        return unpack(_cap_color_obj.result)
    else
        return style.get_color(_cap_color - 4)
    end
end

return style
