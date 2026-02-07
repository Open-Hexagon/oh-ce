require("love.sound")
local index = require("asset_system.index")
local utils = require("asset_system.loaders.utils")
local loaders = {}

function loaders.text_file(path)
    index.watch_file(path)
    return love.filesystem.read(path)
end

function loaders.image(path)
    index.watch_file(path)
    return utils.run_on_main("return love.graphics.newImage(...)", path)
end

function loaders.font(path, size)
    index.watch_file(path)
    return utils.run_on_main("return love.graphics.newFont(...)", path, size)
end

function loaders.json(path)
    local json = require("extlibs.json.json")
    local text = index.local_request("text_file", path)
    return json.decode(text)
end

function loaders.sound_data(path)
    index.watch_file(path)
    return love.sound.newSoundData(path)
end

function loaders.icon_font(name, size)
    local path = "assets/font/" .. name
    return {
        font = index.local_request("font", path .. ".ttf", size),
        id_map = index.local_request("json", path .. ".json"),
    }
end

return loaders
