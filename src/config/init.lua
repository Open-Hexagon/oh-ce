local modname = ...
local json = require("extlibs.json.json-beautify")
local profile = require("game_handler.profile")
local logging = require("logging")
local global_logger = logging.get_logger(modname)

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
    global_logger:info("saved global config '", GLOBAL_SETTINGS_PATH, "'")
end

---Open the config file and initialize profiles.
---If files are damaged, will repair them.
function config.init()
    if not love.filesystem.getInfo(GLOBAL_SETTINGS_PATH) then
        global_logger:info("global config '", GLOBAL_SETTINGS_PATH, "' is missing; recreating using defaults.")
        global_settings.settings_profile = "default"
        global_settings.game_profile = "default"
        config.save_global()
    else
        local file = love.filesystem.openFile(GLOBAL_SETTINGS_PATH, "r")
        global_settings = json.decode(file:read())
        file:close()
    end
    global_logger:debug("settings_profile: ", global_settings.settings_profile)
    global_logger:debug("game_profile: ", global_settings.game_profile)
    if not pcall(config.settings.open_profile, global_settings.settings_profile) then
        global_logger:info(
            "settings profile '",
            global_settings.settings_profile,
            "' is missing; recreating using defaults."
        )
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
    -- profiles here refer to setting profiles which should not be confused with game profiles!

    local settings_logger = logging.get_logger(modname .. ".settings")

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
    local dirty = false

    local profile_registry_list = {}
    settings.profile_registry_list = profile_registry_list

    local function refresh_profile_registry_list()
        local filenames = love.filesystem.getDirectoryItems(PROFILE_PATH)
        local profile_name
        local num_filenames = #filenames
        for i = 1, math.max(#profile_registry_list, num_filenames) do
            if i <= num_filenames then
                profile_name = string.match(filenames[i], "^(.+)%.json$")
                if profile_name then
                    profile_registry_list[i] = profile_name
                end
            else
                profile_registry_list[i] = nil
            end
        end
        table.sort(profile_registry_list)
    end

    refresh_profile_registry_list()

    ---@param what table
    local function set_defaults(what)
        for name, values in pairs(properties) do
            what[name] = values.default
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

    ---Resets all settings. Sets the dirty flag
    function settings.set_defaults()
        set_defaults(current_settings)
        dirty = true
    end

    ---Sets a setting to a value. Sets the dirty flag
    ---@param name string internal setting name
    ---@param value any
    function settings.set(name, value)
        settings_logger:debug("set '", name, "' to '", value, "'")
        current_settings[name] = value
        dirty = true
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

    local function create_profile(name)
        local path = PROFILE_PATH .. name .. ".json"
        if love.filesystem.getInfo(path) then
            error("profile with name '" .. name .. "' already exists!")
        end
        local new_profile = {}
        set_defaults(new_profile)
        save_to_json(path, new_profile)
    end

    local function delete_profile(name)
        local path = PROFILE_PATH .. name .. ".json"
        if not love.filesystem.getInfo(path) then
            error("profile with name '" .. name .. "' doesn't exist!")
        end
        love.filesystem.remove(path)
    end

    local function copy_profile(old_name, new_name)
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

    local function reset_profile(name)
        local path = PROFILE_PATH .. name .. ".json"
        if not love.filesystem.getInfo(path) then
            error("profile with name '" .. name .. "' doesn't exist!")
        end
        local buffer = {}
        set_defaults(buffer)
        save_to_json(path, buffer)
    end

    ---Creates a new profile (raises an error if one with the same name already exists).
    ---Settings all start at defaults.
    ---@param name string
    function settings.create_profile(name)
        create_profile(name)
        refresh_profile_registry_list()
        settings_logger:info("created new settings profile '", name, "'")
    end

    ---Deletes a profile (raises an error if it doesn't exist).
    ---Deleting the current profile is allowed, but if current_profile isn't changed
    ---to something else, the file will come back if a new profile is opened.
    ---@param name string
    function settings.delete_profile(name)
        delete_profile(name)
        refresh_profile_registry_list()
        settings_logger:info("deleted settings profile '", name, "'")
    end

    ---@param old_name string
    ---@param new_name string
    function settings.copy_profile(old_name, new_name)
        copy_profile(old_name, new_name)
        refresh_profile_registry_list()
        settings_logger:info("copied settings profile '", old_name, "' to '", new_name, "'")
    end

    ---@param old_name string
    ---@param new_name string
    function settings.rename_profile(old_name, new_name)
        copy_profile(old_name, new_name)
        delete_profile(old_name)
        if old_name == global_settings.settings_profile then
            global_settings.settings_profile = new_name
        end
        refresh_profile_registry_list()
        settings_logger:info("renamed settings profile '", old_name, "' to '", new_name, "'")
    end

    ---@param name string
    function settings.reset_profile(name)
        reset_profile(name)
        if name == global_settings.settings_profile then
            set_defaults(current_settings)
        end
        settings_logger:info("reset settings profile '", name, "'")
    end

    ---Opens a profile (raises an error if it doesn't exist). Saves the previous profile.
    ---@param name string
    function settings.open_profile(name)
        local path = PROFILE_PATH .. name .. ".json"
        if not love.filesystem.getInfo(path) then
            error("profile with name '" .. name .. "' doesn't exist!")
        end
        settings.save_current_profile()
        load_from_json(path, current_settings)
        global_settings.settings_profile = name
        settings_logger:info("opened settings profile '", path, "'")
    end

    ---gets the current profile name
    ---@return string
    function settings.get_current_profile()
        return global_settings.settings_profile
    end

    ---Saves the current profile if it's dirty.
    ---Clears the dirty flag.
    function settings.save_current_profile()
        if not dirty then
            return
        end
        local path = PROFILE_PATH .. global_settings.settings_profile .. ".json"
        save_to_json(path, current_settings)
        dirty = false
        settings_logger:info("saved settings profile '", path, "'")
    end

    config.settings = settings
end

function config.save_all()
    config.save_global()
    config.settings.save_current_profile()
end

return config
