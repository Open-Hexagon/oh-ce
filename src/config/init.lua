local json = require("extlibs.json.json-beautify")

local PROFILE_PATH = "config/"
if not love.filesystem.getInfo(PROFILE_PATH) then
    love.filesystem.createDirectory(PROFILE_PATH)
end

local config = {}

local settings = {}
local properties = {}
local categories = {}
categories.hidden = { name = "hidden" }

config.categories = categories
config.properties = properties

local current_profile = nil

-- load setting definitions
loadfile("src/config/setting_definitions.lua")(categories, properties)

---resets all settings
function config.set_defaults()
    for name, values in pairs(properties) do
        settings[name] = values.default
    end
end

---sets a setting to a value
---@param name string internal setting name
---@param value any
function config.set(name, value)
    settings[name] = value
end

---gets a setting (returns the default for settings that cannot be changed in official mode if official mode is on)
---@param name string internal setting name
---@return any
function config.get(name)
    local value = settings[name]
    local property = properties[name]
    if not property then
        return
    end
    if settings.official_mode and not property.can_change_in_offical and value ~= property.default then
        return properties[name].default
    else
        return value
    end
end

---gets a table of all settings or all settings for a certain game version
---@param game_version number|nil
---@return table
function config.get_all(game_version)
    if game_version == nil then
        return settings
    elseif type(game_version) == "number" then
        local game_settings = {}
        for name, property in pairs(properties) do
            if property.game ~= nil then
                local has_version = false
                if type(property.game) == "table" then
                    for i = 1, #property.game do
                        if property.game[i] == game_version then
                            has_version = true
                            break
                        end
                    end
                elseif type(property.game) == "number" then
                    if property.game == game_version then
                        has_version = true
                    end
                end
                if has_version then
                    game_settings[name] = config.get(name)
                end
            end
        end
        return game_settings
    else
        error("game_version should be a number")
    end
end

---loads the config from a json file
---@param path string
local function load_from_json(path)
    -- reset the settings before loading in case some settings didn't exist yet in the config file
    config.set_defaults()
    local file = love.filesystem.openFile(path, "r")
    local contents = file:read()
    file:close()
    for name, value in pairs(json.decode(contents)) do
        config.set(name, value)
    end
end

---saves the config into a json file
---@param path string
local function save_to_json(path)
    local file = love.filesystem.openFile(path, "w")
    file:write(json.beautify(config.get_all()))
    file:close()
end

-- profiles here refer to setting profiles which should not be confused with game profiles!

---creates a new profile (raises an error if one with the same name already exists)
---@param name string
function config.create_profile(name)
    local path = PROFILE_PATH .. name .. ".json"
    if not love.filesystem.getInfo(path) then
        save_to_json(path)
    else
        error("profile with name '" .. name .. "' already exists!")
    end
    current_profile = name
end

---opens a profile (raises an error if it doesn't exist)
---@param name string
function config.open_profile(name)
    local path = PROFILE_PATH .. name .. ".json"
    if love.filesystem.getInfo(path) then
        load_from_json(path)
    else
        error("profile with name '" .. name .. "' doesn't exist!")
    end
    current_profile = name
end

---gets the current profile name
---@return string?
function config.get_profile()
    return current_profile
end

---deletes a profile
---@param name string
function config.delete_profile(name)
    local path = PROFILE_PATH .. name .. ".json"
    if love.filesystem.getInfo(path) then
        love.filesystem.remove(path)
    end
    current_profile = nil
    config.set_defaults()
end

---returns a table containing the names of all existing profiles
---@return table
function config.list_profiles()
    local filenames = love.filesystem.getDirectoryItems(PROFILE_PATH)
    local names = {}
    for i = 1, #filenames do
        names[i] = filenames[i]:sub(1, -6)
    end
    return names
end

---saves the current profile
function config.save()
    save_to_json(PROFILE_PATH .. current_profile .. ".json")
end

-- no profile loaded yet so use defaults for now
config.set_defaults()

return config
