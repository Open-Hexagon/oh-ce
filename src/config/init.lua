local modname = ...
local json = require("extlibs.json.json-beautify")
local profile = require("game_handler.profile")
local logging = require("logging")
local config_logger = logging.get_logger(modname)

---Saves a table into a json file
---@param path string
---@param what table
local function save_to_json(path, what)
    local file, msg = love.filesystem.openFile(path, "w")
    if not file then
        error(msg)
    end
    file:write(json.beautify(what))
    file:close()
end

local config = {}

local global = {}
do
    local global_logger = logging.get_logger(modname .. ".global")

    local GLOBAL_SETTINGS_PATH = "config.json"
    local global_settings = {}
    local dirty = false

    ---Sets a global setting. Also sets the dirty flag.
    ---@param name string
    ---@param value any
    function global.set(name, value)
        if global_settings[name] ~= value then
            global_settings[name] = value
            dirty = true
            global_logger:debug("set '", name, "' to '", value, "'")
        end
    end

    ---Gets a global setting.
    ---@param name string
    ---@return any
    function global.get(name)
        return global_settings[name]
    end

    ---Saves global settings if they're dirty. Raises an error if it can't save.
    ---Clears the dirty flag.
    function global.save()
        if not dirty then
            return
        end
        save_to_json(GLOBAL_SETTINGS_PATH, global_settings)
        dirty = false
        global_logger:info("saved '", GLOBAL_SETTINGS_PATH, "'")
    end

    ---Loads global settings from disk. Raises an error if file isn't found.
    ---Clears the dirty flag.
    function global.load()
        local file, msg = love.filesystem.openFile(GLOBAL_SETTINGS_PATH, "r")
        if not file then
            error(msg)
        end
        global_settings = json.decode(file:read())
        file:close()
        dirty = false
        global_logger:info("loaded '", GLOBAL_SETTINGS_PATH, "'")
    end
end
config.global = global

local settings = {}
do
    -- profiles here refer to setting profiles which should not be confused with game profiles!

    local settings_logger = logging.get_logger(modname .. ".settings")

    local PROFILE_PATH = "settings/"
    if not love.filesystem.getInfo(PROFILE_PATH) then
        if not love.filesystem.createDirectory(PROFILE_PATH) then
        end
    end

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

    local profile_registry = {}
    settings.profile_registry = profile_registry

    local function refresh_profile_registry()
        local filenames = love.filesystem.getDirectoryItems(PROFILE_PATH)
        local profile_name
        local num_filenames = #filenames
        for i = 1, math.max(#profile_registry, num_filenames) do
            if i <= num_filenames then
                profile_name = string.match(filenames[i], "^(.+)%.json$")
                if profile_name then
                    profile_registry[i] = profile_name
                end
            else
                profile_registry[i] = nil
            end
        end
        table.sort(profile_registry)
    end

    refresh_profile_registry()

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

    ---gets the current profile name
    ---@return string
    function settings.get_current_profile()
        return global.get("settings_profile")
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
        current_settings[name] = value
        dirty = true
        settings_logger:debug("set '", name, "' to '", value, "'")
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

    ---Creates a new profile (raises an error if one with the same name already exists).
    ---Settings all start at defaults.
    ---@param name string
    function settings.create_profile(name)
        create_profile(name)
        refresh_profile_registry()
        settings_logger:info("created new settings profile '", name, "'")
    end

    ---Deletes a profile (raises an error if it doesn't exist).
    ---Deleting the current profile is allowed, but if current_profile isn't changed
    ---to something else, the file will come back if a new profile is opened.
    ---@param name string
    function settings.delete_profile(name)
        delete_profile(name)
        refresh_profile_registry()
        settings_logger:info("deleted settings profile '", name, "'")
    end

    ---@param old_name string
    ---@param new_name string
    function settings.copy_profile(old_name, new_name)
        copy_profile(old_name, new_name)
        refresh_profile_registry()
        settings_logger:info("copied settings profile '", old_name, "' to '", new_name, "'")
    end

    ---@param old_name string
    ---@param new_name string
    function settings.rename_profile(old_name, new_name)
        copy_profile(old_name, new_name)
        delete_profile(old_name)
        if old_name == config.global.get("settings_profile") then
            config.global.set("settings_profile", new_name)
        end
        refresh_profile_registry()
        settings_logger:info("renamed settings profile '", old_name, "' to '", new_name, "'")
    end

    ---@param name string
    function settings.reset_profile(name)
        if name == config.global.get("settings_profile") then
            set_defaults(current_settings)
        else
            reset_profile(name)
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
        config.global.set("settings_profile", name)
        settings_logger:info("opened settings profile '", path, "'")
    end

    ---Saves the current profile if it's dirty.
    ---Clears the dirty flag.
    function settings.save_current_profile()
        if not dirty then
            return
        end
        local path = PROFILE_PATH .. settings.get_current_profile() .. ".json"
        save_to_json(path, current_settings)
        dirty = false
        settings_logger:info("saved settings profile '", path, "'")
    end
end
config.settings = settings

local function try_global_save()
    local success, msg = pcall(global.save)
    if not success then
        -- if you somehow got here your disk is probably failing or something
        config_logger:warning("failed to save global config: '", msg, "'")
    end
end

---Open the config file and initialize profiles.
---If files are damaged, will repair them.
function config.init()
    local success, msg, sp_name, gp_name

    success, msg = pcall(global.load)
    if not success then
        config_logger:info(msg, " Recreating using defaults.")
        global.set("settings_profile", "default")
        global.set("game_profile", "default")
        try_global_save()
    end

    sp_name = global.get("settings_profile")
    gp_name = global.get("game_profile")
    config_logger:debug("settings_profile: '", sp_name, "'")
    config_logger:debug("game_profile: '", gp_name, "'")

    success, msg = pcall(settings.open_profile, sp_name)
    if not success then
        config_logger:info(msg, "; recreating using defaults.")
        settings.create_profile(sp_name)
        settings.open_profile(sp_name)
    end

    profile.open_or_new(gp_name)
end

---TODO: this might become obsolete in the future.
---sets the current game profile (creates it if it doesn't exist)
---@param name string
function config.set_game_profile(name)
    profile.close()
    profile.open_or_new(name)
    config.global.set("game_profile", name)
end

function config.save_all()
    try_global_save()
    settings.save_current_profile()
end

return config
