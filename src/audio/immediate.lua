local audio = {}
-- Expose only a subset of the love audio api so we can use the same api when exporting a video as well
local property_func_map = {
    looping = { "setLooping", "getLooping" },
    volume = { "setVolume", "getVolume" },
    playing = "isPlaying",
    pitch = "getPitch",
    play = "play",
    stop = "stop",
    set_pitch = "setPitch",
    seek = "seek",
    release = "release",
}
audio.__index = function(t, k)
    if rawget(t, k) then
        return t[k]
    elseif audio[k] then
        return audio[k]
    elseif property_func_map[k] then
        local source = rawget(t, "source")
        if type(property_func_map[k]) == "table" then
            return function(_, ...)
                source[property_func_map[k][2]](source, ...)
            end
        end
        return function(_, ...)
            source[property_func_map[k]](source, ...)
        end
    end
end
audio.__newindex = function(t, k, v)
    if property_func_map[k] and type(property_func_map[k]) == "table" then
        local source = rawget(t, "source")
        source[property_func_map[k][1]](source, v)
    else
        rawset(t, k, v)
    end
end

function audio.update() end

local function new(filename, read_type)
    return setmetatable({
        source = love.audio.newSource(filename, read_type),
        filename = filename,
        playing = false,
    }, audio)
end

function audio.new_stream(filename)
    return new(filename, "stream")
end

function audio.new_static(filename)
    return new(filename, "static")
end

return audio
