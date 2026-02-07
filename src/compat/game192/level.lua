local utils = require("compat.game192.utils")
local level = {}

local level_data_types = {
    id = tostring,
    name = tostring,
    description = tostring,
    author = tostring,
    menu_priority = utils.round_to_even,
    selectable = function(v)
        return v or false
    end,
    music_id = tostring,
    style_id = tostring,
    speed_multiplier = utils.float_round,
    speed_increment = utils.float_round,
    rotation_speed = utils.float_round,
    rotation_increment = utils.float_round,
    delay_multiplier = utils.float_round,
    delay_increment = utils.float_round,
    fast_spin = utils.float_round,
    sides = utils.round_to_even,
    sides_max = utils.round_to_even,
    sides_min = utils.round_to_even,
    increment_time = utils.float_round,
    pulse_min = utils.float_round,
    pulse_max = utils.float_round,
    pulse_speed = utils.float_round,
    pulse_speed_r = utils.float_round,
    pulse_delay_max = utils.float_round,
    pulse_delay_half_max = utils.float_round,
    beatpulse_max = utils.float_round,
    beatpulse_delay_max = utils.float_round,
    radius_min = utils.float_round,
    wall_angle_left = utils.float_round,
    wall_angle_right = utils.float_round,
    wall_skew_left = utils.float_round,
    wall_skew_right = utils.float_round,
}
local default_values = {
    pulse_min = 75,
    pulse_max = 80,
    radius_min = 72,
}
local tmp_values = {}
local current_data
local current_raw_data

function level.set(level_data)
    for k, _ in pairs(tmp_values) do
        tmp_values[k] = nil
    end
    current_raw_data = level_data
    current_data = setmetatable({}, {
        __newindex = function(_, k, v)
            tmp_values[k] = v
        end,
        __index = function(_, k)
            if k == "id" then
                -- undo folder prefix when level gets the id
                local v = level_data[k]
                return v:sub(v:find("_") + 1)
            end
            local converter = level_data_types[k]
            local value = tmp_values[k] or (level_data[k] or (default_values[k] or 0))
            if converter then
                return converter(value)
            end
            return value
        end,
    })
    return current_data
end

function level.get_difficulty_multipliers()
    local mults = current_data.difficulty_multipliers or { 1 }
    if #mults == 0 then
        return { 1 }
    else
        return mults
    end
end

function level.set_value(name, value)
    current_data[name] = value
end

function level.get_value(name)
    return tmp_values[name] or current_raw_data[name]
end

return level
