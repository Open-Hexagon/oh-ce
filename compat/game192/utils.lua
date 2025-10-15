local ffi = require("ffi")
local utils = {}

function utils.file_ext_read_iter(dir, ending, virt_folder)
    virt_folder = virt_folder or {}
    local files = love.filesystem.getDirectoryItems(dir)
    local virt_start_index = #files + 1
    for file in pairs(virt_folder) do
        files[#files + 1] = file
    end
    for i = virt_start_index - 1, 1, -1 do
        for j = virt_start_index, #files do
            if files[j] == files[i] then
                table.remove(files, i)
                virt_start_index = virt_start_index - 1
            end
        end
    end
    local index = 0
    return function()
        index = index + 1
        if index > #files then
            return
        end
        while files[index]:sub(-#ending) ~= ending do
            index = index + 1
            if index > #files then
                return
            end
        end
        if index >= virt_start_index then
            local contents = virt_folder[files[index]]
            return contents, files[index]
        else
            local contents = love.filesystem.read(dir .. "/" .. files[index])
            if contents == nil then
                error("Failed to read '" .. dir .. "/" .. files[index] .. "'")
            else
                return contents, files[index]
            end
        end
    end
end

-- fixes case insensitive paths
function utils.get_real_path(path)
    -- remove trailing spaces
    while path:sub(-1) == " " do
        path = path:sub(1, -2)
    end

    -- fix capitalization
    local real_path = ""
    for segment in path:gmatch("[^/]+") do
        if love.filesystem.getInfo(real_path .. segment) then
            real_path = real_path .. segment .. "/"
        else
            local list = love.filesystem.getDirectoryItems(real_path)
            for i = 1, #list do
                if list[i]:upper() == segment:upper() then
                    real_path = real_path .. list[i] .. "/"
                    break
                end
            end
        end
    end
    real_path = real_path:sub(1, -2)
    return real_path
end

-- insert a path into a recursive table structure
function utils.insert_path(t, keys, value)
    local directory = t
    for i = 1, #keys do
        local key = keys[i]
        if directory[key] == nil then
            if i == #keys then
                directory[key] = value
                return
            end
            directory[key] = {}
        end
        directory = directory[key]
    end
end

-- lookup the item at the end of a path inside a recursive table structure
function utils.lookup_path(t, keys)
    local directory = t
    for _, key in pairs(keys) do
        if directory[key] == nil then
            return
        end
        directory = directory[key]
    end
    return directory
end

function utils.round_to_even(num)
    if num == nil then
        return 0
    end
    -- TODO: return math.floor(num) on some packs depending on target platform?
    local decimal = num % 1
    if decimal ~= 0.5 then
        return math.floor(num + 0.5)
    else
        if num % 2 == 0.5 then
            return num - 0.5
        else
            return num + 0.5
        end
    end
end

function utils.float_round(num)
    return ffi.tonumber(ffi.new("float", num))
end

local max_int = 2 ^ 31 - 1
local min_int = -2 ^ 31

-- replicate platform specific behavior of the abs function
function utils.int_abs(num)
    if num > max_int then
        return min_int
    elseif num <= min_int then
        return min_int
    end
    return math.floor(math.abs(num))
end

-- This is quite messy since it's copied from 1.92
function utils.get_color_from_hue(hue, color)
    hue = utils.float_round(hue)
    local s, v, r, g, b = 1, 1, 0, 0, 0
    local i = math.floor(hue * 6)
    local f = hue * 6 - i
    local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    local im
    if i >= 0 then
        im = i % 6
    else
        im = -(i % 6)
    end
    if im == 0 then
        r, g, b = v, t, p
    elseif im == 1 then
        r, g, b = q, v, p
    elseif im == 2 then
        r, g, b = p, v, t
    elseif im == 3 then
        r, g, b = p, q, v
    elseif im == 4 then
        r, g, b = t, p, v
    elseif im == 5 then
        r, g, b = v, p, q
    end
    color[1] = math.modf(r * 255)
    color[2] = math.modf(g * 255)
    color[3] = math.modf(b * 255)
    color[4] = 255
end

return utils
