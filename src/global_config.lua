local json = require("extlibs.json.json-beautify")
local profile = require("game_handler.profile")
local config = require("config")

local global_config = {}
local settings = {}
local path = "config.json"

local function save()
    local file = love.filesystem.openFile(path, "w")
    file:write(json.beautify(settings))
    file:close()
end

---open the config file
function global_config.init()
    if not love.filesystem.getInfo(path) then
        global_config.set_game_profile("default")
        global_config.set_settings_profile("default")
        save()
    else
        local file = love.filesystem.openFile(path, "r")
        settings = json.decode(file:read())
        file:close()
        config.open_profile(settings.settings_profile)
        profile.open_or_new(settings.game_profile)
    end
end

---set the current settings profile (creates it if it doesn't exist)
---@param name string
function global_config.set_settings_profile(name)
    local profiles = config.list_profiles()
    local has_profile = false
    for i = 1, #profiles do
        if profiles[i] == name then
            has_profile = true
            break
        end
    end
    if not has_profile then
        config.create_profile(name)
    end
    config.open_profile(name)
    settings.settings_profile = name
    save()
end

---sets the current game profile (creates it if it doesn't exist)
---@param name string
function global_config.set_game_profile(name)
    profile.close()
    profile.open_or_new(name)
    settings.game_profile = name
    save()
end

return global_config
