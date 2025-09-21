local args = require("args")
local Tris = require("compat.game21.dynamic_tris")
local utils = require("compat.game192.utils")
local style = {}

local function set_default_color(color)
    for i = 1, 4 do
        color[i] = (color[i] or 0) % 256
    end
end

local function set_color_data_defaults(data)
    data.main = data.main or false
    data.dynamic = data.dynamic or false
    data.dynamic_offset = data.dynamic_offset or false
    data.dynamic_darkness = data.dynamic_darkness or 0
    data.hue_shift = data.hue_shift or 0
    data.offset = data.offset or 0
    data.value = data.value or { 0, 0, 0, 0 }
    data.pulse = data.pulse or { 0, 0, 0, 0 }
    data.result = { 0, 0, 0, 0 }
    set_default_color(data.value)
    set_default_color(data.pulse)
end

local root
local real_style_table = {}
local default_values = {
    max_swap_time = 100,
    ["3D_depth"] = 15,
    ["3D_skew"] = 0.18,
    ["3D_spacing"] = 1,
    ["3D_darken_multiplier"] = 1.5,
    ["3D_alpha_multiplier"] = 0.5,
    ["3D_alpha_falloff"] = 3,
    ["3D_pulse_max"] = 3.2,
    ["3D_pulse_min"] = 0,
    ["3D_pulse_speed"] = 0.01,
    ["3D_perspective_multiplier"] = 1,
    colors = {},
    main = {},
}
local current_hue = 0
local current_hue_color = { 0, 0, 0, 0 }
local pulse_factor = 0
local current_swap_time = 0
local current_3D_override_color
local color_start_index = 0
local background_tris
if not args.headless then
    background_tris = Tris:new()
end

function style.select(style_data, no_listen)
    -- the no_listen parameter is required because this module may be used during asset loading
    -- requiring the mirror_client would cause problems in that case
    if not no_listen then
        require("asset_system.mirror_client").assign_asset_to_listener(style.select, style_data)
    end
    -- reset other values
    current_hue = 0
    pulse_factor = 0
    current_swap_time = 0
    color_start_index = 0
    -- reset values
    for k, _ in pairs(real_style_table) do
        real_style_table[k] = nil
    end
    -- use default values as fallback
    root = setmetatable(real_style_table, {
        __index = function(_, k)
            return style_data[k] or (default_values[k] or 0)
        end,
    })
    current_hue = root.hue_min
    set_color_data_defaults(root.main)
    for i = 1, #root.colors do
        set_color_data_defaults(root.colors[i])
    end
end

function style.get_table()
    return root
end

function style.calculate_color(color_data)
    if color_data.dynamic then
        utils.get_color_from_hue((current_hue + color_data.hue_shift) / 360, current_hue_color)
        if color_data.main then
            for i = 1, 4 do
                color_data.result[i] = current_hue_color[i]
            end
        else
            if color_data.dynamic_offset then
                for i = 1, 3 do
                    color_data.result[i] = (color_data.value[i] + current_hue_color[i] / color_data.offset) % 256
                end
                -- hue color alpha is always 255
                color_data.result[4] = (color_data.value[4] + 255) % 256
            else
                for i = 1, 3 do
                    color_data.result[i] = (current_hue_color[i] / color_data.dynamic_darkness) % 256
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
        local value = color_data.result[i]
        if value ~= value or value == math.huge then
            -- nan or inf
            value = 0
        end
        value = value + color_data.pulse[i] * pulse_factor
        if value > 255 then
            value = 255
        elseif value < 0 then
            value = 0
        end
        color_data.result[i] = value
    end
end

function style.update(frametime)
    current_swap_time = current_swap_time + frametime
    if current_swap_time >= root.max_swap_time then
        current_swap_time = 0
    end
    current_hue = current_hue + root.hue_increment * frametime
    if current_hue < root.hue_min then
        if root.hue_ping_pong then
            current_hue = root.hue_min
            root.hue_increment = -root.hue_increment
        else
            current_hue = root.hue_max
        end
    elseif current_hue > root.hue_max then
        if root.hue_ping_pong then
            current_hue = root.hue_max
            root.hue_increment = -root.hue_increment
        else
            current_hue = root.hue_min
        end
    end
    pulse_factor = pulse_factor + root.pulse_increment * frametime
    if pulse_factor < root.pulse_min then
        root.pulse_increment = -root.pulse_increment
        pulse_factor = root.pulse_min
    elseif pulse_factor > root.pulse_max then
        root.pulse_increment = -root.pulse_increment
        pulse_factor = root.pulse_max
    end
end

function style.compute_colors()
    style.calculate_color(root.main)
    current_3D_override_color = root["3D_override_color"] == 0 and root.main.result or root["3D_override_color"]
    for i = 1, #root.colors do
        style.calculate_color(root.colors[i])
    end
    if root.max_swap_time == 0 then
        color_start_index = 0
    else
        color_start_index = math.floor(2 * current_swap_time / root.max_swap_time)
    end
end

function style.draw_background(sides, black_and_white)
    background_tris:clear()
    if #root.colors ~= 0 then
        local sin, cos = math.sin, math.cos
        local div = 2 * math.pi / sides
        local half_div = div * 0.5
        local distance = 4500
        for i = 0, sides - 1 do
            local angle = div * i
            local r, g, b, a = style.get_color(i)
            local must_darken = i % 2 == 0 and i == sides - 1
            if black_and_white then
                r, g, b, a = 0, 0, 0, 0
            elseif must_darken then
                r = r / 1.4
                g = g / 1.4
                b = b / 1.4
            end
            local angle0, angle1 = angle + half_div, angle - half_div
            background_tris:add_tris(
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
        background_tris:draw()
    end
end

function style.set_value(name, value)
    root[name] = value
end

function style.get_value(name)
    return root[name]
end

function style.get_color(index)
    local color_object = root.colors[(color_start_index + index) % #root.colors + 1]
    if color_object == nil then
        return 0, 0, 0, 0
    else
        return unpack(color_object.result)
    end
end

function style.get_second_color()
    local i
    if #root.colors == 2 then
        i = 2 - color_start_index
    else
        i = 2 + color_start_index
    end
    local color_object = root.colors[i]
    if color_object == nil then
        return 0, 0, 0, 0
    else
        return unpack(color_object.result)
    end
end

function style.get_main_color()
    return unpack(root.main.result)
end

function style.get_current_hue()
    return current_hue
end

function style.get_current_swap_time()
    return current_swap_time
end

function style.get_3D_override_color()
    return unpack(current_3D_override_color)
end

return style
