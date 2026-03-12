local json = require("extlibs.json.json-beautify")
local profile = require("game_handler.profile")

local config = {}
local global_settings = {}
local GLOBAL_SETTINGS_PATH = "config.json"

---saves the config into a json file
---@param path string
---@param what table what to save
local function save_to_json(path, what)
    local file = love.filesystem.openFile(path, "w")
    file:write(json.beautify(what))
    file:close()
end

---Saves config.json
function config.save_global()
    save_to_json(GLOBAL_SETTINGS_PATH, global_settings)
end

---Open the config file and initialize profiles.
---If files are damaged, will repair them.
function config.init()
    if not love.filesystem.getInfo(GLOBAL_SETTINGS_PATH) then
        -- config.json is missing, use default values
        global_settings.settings_profile = "default"
        global_settings.game_profile = "default"
        config.save_global()
    else
        local file = love.filesystem.openFile(GLOBAL_SETTINGS_PATH, "r")
        global_settings = json.decode(file:read())
        file:close()
    end
    if not pcall(config.settings.open_profile, global_settings.settings_profile) then
        -- create a new profile if the one in config for some reason doesn't exist
        config.settings.create_profile(global_settings.settings_profile)
        config.settings.open_profile(global_settings.settings_profile)
    end
    profile.open_or_new(global_settings.game_profile)
end

---TODO: this might become obsolete in the future.
---sets the current game profile (creates it if it doesn't exist)
---@param name string
function config.set_game_profile(name)
    profile.close()
    profile.open_or_new(name)
    global_settings.game_profile = name
end

do
    local PROFILE_PATH = "settings/"
    if not love.filesystem.getInfo(PROFILE_PATH) then
        love.filesystem.createDirectory(PROFILE_PATH)
    end

    local settings = {}

    -- setting definitions
    local properties = {}
    local categories = {}
    categories.hidden = { name = "hidden" }
    settings.categories = categories
    settings.properties = properties

    -- load setting definitions
    loadfile("src/config/setting_definitions.lua")(categories, properties)

    -- current profile setting values
    local current_settings = {}

    ---@param what table
    local function set_defaults(what)
        for name, values in pairs(properties) do
            what[name] = values.default
        end
    end

    ---resets all settings
    function settings.set_defaults()
        set_defaults(current_settings)
    end

    ---sets a setting to a value
    ---@param name string internal setting name
    ---@param value any
    function settings.set(name, value)
        current_settings[name] = value
    end

    ---Gets a setting (returns the default for settings that cannot be changed in official mode if official mode is on).
    ---Returns nil if setting doesn't exist.
    ---@param name string internal setting name
    ---@return any
    function settings.get(name)
        local value = current_settings[name]
        local property = properties[name]
        if not property then
            return
        end
        if current_settings.official_mode and not property.can_change_in_offical and value ~= property.default then
            return properties[name].default
        else
            return value
        end
    end

    ---gets a table of all settings or all settings for a certain game version
    ---@param game_version number|nil
    ---@return table
    function settings.get_all(game_version)
        if game_version == nil then
            return current_settings
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
                        game_settings[name] = settings.get(name)
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
    ---@param where table where to put settings
    local function load_from_json(path, where)
        -- reset the settings before loading in case some settings didn't exist yet in the config file
        set_defaults(where)
        local file = love.filesystem.openFile(path, "r")
        local contents = file:read()
        file:close()
        for name, value in pairs(json.decode(contents)) do
            where[name] = value
        end
    end

    -- profiles here refer to setting profiles which should not be confused with game profiles!

    ---Creates a new profile (raises an error if one with the same name already exists).
    ---Settings all start at defaults.
    ---@param name string
    function settings.create_profile(name)
        local path = PROFILE_PATH .. name .. ".json"
        if love.filesystem.getInfo(path) then
            error("profile with name '" .. name .. "' already exists!")
        end
        local new_profile = {}
        set_defaults(new_profile)
        save_to_json(path, new_profile)
    end

    ---Deletes a profile (raises an error if it doesn't exist).
    ---Deleting the current profile is allowed, but if current_profile isn't changed
    ---to something else, the file will come back if a new profile is opened.
    ---@param name string
    function settings.delete_profile(name)
        local path = PROFILE_PATH .. name .. ".json"
        if not love.filesystem.getInfo(path) then
            error("profile with name '" .. name .. "' doesn't exist!")
        end
        love.filesystem.remove(path)
    end

    function settings.copy_profile(old_name, new_name)
        if old_name == new_name then
            error("old name and new name are the same")
        end
        local old_path = PROFILE_PATH .. old_name .. ".json"
        local new_path = PROFILE_PATH .. new_name .. ".json"
        if love.filesystem.getInfo(new_path) then
            error("profile with name '" .. new_name .. "' already exists!")
        end
        if not love.filesystem.getInfo(old_path) then
            error("profile with name '" .. old_name .. "' doesn't exist!")
        end
        local buffer = {}
        load_from_json(old_path, buffer)
        save_to_json(new_path, buffer)
    end

    function settings.rename_profile(old_name, new_name)
        settings.copy_profile(old_name, new_name)
        settings.delete_profile(old_name)
        if old_name == global_settings.settings_profile then
            global_settings.settings_profile = new_name
        end
    end

    ---opens a profile (raises an error if it doesn't exist)
    ---@param name string
    function settings.open_profile(name)
        local path = PROFILE_PATH .. name .. ".json"
        if not love.filesystem.getInfo(path) then
            error("profile with name '" .. name .. "' doesn't exist!")
        end
        if global_settings.settings_profile then
            settings.save_current_profile()
        end
        load_from_json(path, current_settings)
        global_settings.settings_profile = name
    end

    ---gets the current profile name
    ---@return string?
    function settings.get_current_profile()
        return global_settings.settings_profile
    end

    ---returns a table containing the names of all existing profiles
    ---@return table
    function settings.list_profiles()
        local filenames = love.filesystem.getDirectoryItems(PROFILE_PATH)
        local names = {}
        for i = 1, #filenames do
            names[i] = filenames[i]:sub(1, -6)
        end
        return names
    end

    ---saves the current profile
    function settings.save_current_profile()
        save_to_json(PROFILE_PATH .. global_settings.settings_profile .. ".json", current_settings)
    end

    -- no profile loaded yet so use defaults for now
    settings.set_defaults()

    config.settings = settings
end

function config.save_all()
    config.save_global()
    config.settings.save_current_profile()
end

return config
