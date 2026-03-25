local modname = ...
local json = require("extlibs.json.json-beautify")
local profile = require("game_handler.profile")
local logging = require("logging")
local config_logger = logging.get_logger(modname)
local buffer = require("string.buffer")
table.clear = require("table.clear")

---Saves a table into a json file. Might throw an error.
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

--#region GLOBAL SETTINGS

local global_logger = logging.get_logger(modname .. ".global")
local GLOBAL_SETTINGS_PATH = "config.json"
local global_settings = {}
config.global_settings = global_settings

---Saves global settings to disk. Might throw an error.
local function global_save()
    save_to_json(GLOBAL_SETTINGS_PATH, global_settings)
    global_logger:info("saved '", GLOBAL_SETTINGS_PATH, "'")
end

---Loads global settings from disk. Might throw an error.
local function global_load()
    local file, msg = love.filesystem.openFile(GLOBAL_SETTINGS_PATH, "r")
    if not file then
        error(msg)
    end
    global_settings = json.decode(file:read())
    file:close()
    global_logger:info("loaded '", GLOBAL_SETTINGS_PATH, "'")
end

--#endregion

--#region SETTINGS PROFILES
-- profiles here refer to setting profiles which should not be confused with game profiles!

local settings_logger = logging.get_logger(modname .. ".settings")

-- check for this folder's existence
local SETTINGS_PROFILE_PATH = "settings/"
if not love.filesystem.exists(SETTINGS_PROFILE_PATH) then
    if not love.filesystem.createDirectory(SETTINGS_PROFILE_PATH) then
        -- set this flag if we for some reason can't make the directory
        settings_logger:warning("Settings directory is unavailable. Expect errors.")
    end
end

local function to_settings_path(ident)
    return SETTINGS_PROFILE_PATH .. ident .. ".json"
end

local settings = {}
config.settings = settings

-- setting definitions
local properties = {}
local categories = {}
categories.hidden = { name = "hidden" }
settings.categories = categories
settings.properties = properties

-- load setting definitions
---@type fun(width:number, height:number): number
settings.auto_gui_scale = loadfile("src/config/setting_definitions.lua")(categories, properties)

-- current profile setting values
local current_settings = {}
local cs_dirty = false

-- ! User generated filenames are inherently unsafe.

---This is a shortcut to the settings_profile_registry in the global settings table
local sp_registry

local function sync_sp_registry()
    local lost_and_found, spurious = 0, 0
    -- find any unlisted json files
    local filenames = love.filesystem.getDirectoryItems(SETTINGS_PROFILE_PATH)
    for i = 1, #filenames do
        local dir_ident = string.match(filenames[i], "(.+)%.json")
        for _, ident in pairs(sp_registry) do
            if dir_ident == ident then
                goto found
            end
        end
        sp_registry[dir_ident] = dir_ident
        lost_and_found = lost_and_found + 1
        ::found::
    end
    if lost_and_found > 0 then
        settings_logger:info("recovered ", lost_and_found, " settings profiles")
    end

    -- delete any spurious registry entries
    for name, ident in pairs(sp_registry) do
        if not love.filesystem.exists(to_settings_path(ident)) then
            sp_registry[name] = nil
            spurious = spurious + 1
        end
    end
    if spurious > 0 then
        settings_logger:info("removed ", spurious, " spurious settings profile registry entries")
    end
end

--#region sp_display_list

-- A list of profile names for displaying profiles
local sp_display_list = {}
settings.profile_display_list = sp_display_list

local function sp_display_list_add(name)
    table.insert(sp_display_list, name)
end

local function sp_display_list_remove(name)
    for i = 1, #sp_display_list do
        if sp_display_list[i] == name then
            table.remove(sp_display_list, i)
            return
        end
    end
end

local function sp_display_list_replace(old_name, new_name)
    for i = 1, #sp_display_list do
        if sp_display_list[i] == old_name then
            sp_display_list[i] = new_name
            return
        end
    end
end

local function sort_sp_display_list(reverse_order)
    if reverse_order then
        table.sort(sp_display_list, function(a, b)
            return a > b
        end)
    else
        table.sort(sp_display_list)
    end
end
settings.sort_profile_display_list = sort_sp_display_list

local function load_sp_display_list_from_registry()
    table.clear(sp_display_list)
    for profile_name, _ in pairs(sp_registry) do
        table.insert(sp_display_list, profile_name)
    end
    sort_sp_display_list()
    settings_logger:info("loaded ", #sp_display_list, " names into the display list")
end

--#endregion

--#region current settings setters/getters

---Sets a setting to a value. Sets the dirty flag.
---@param name string internal setting name
---@param value any
function settings.set(name, value)
    current_settings[name] = value
    cs_dirty = true
    settings_logger:debug("set '", name, "' to '", value, "'")
end

function settings.reset_setting(name)
    local property = properties[name]
    if property.default_serialized then
        current_settings[name] = buffer.decode(property.default_serialized)
    else
        current_settings[name] = property.default
    end
    cs_dirty = true
end

function settings.set_dirty_flag()
    cs_dirty = true
end

function settings.is_default(name)
    local property = properties[name]
    if property.default_serialized then
        return false -- we can't know (serializing isn't reliable)
    end
    return current_settings[name] == property.default
end

---Gets a setting (returns the default for settings that cannot be changed in official mode if official mode is on).
---Returns nil if setting doesn't exist.
---@param name string internal setting name
---@return any
---@nodiscard
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
---@nodiscard
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

--#endregion

---Puts all default settings into a table.
---@param what table
local function set_defaults(what)
    for name, prop_def in pairs(properties) do
        if prop_def.default_serialized then
            what[name] = buffer.decode(prop_def.default_serialized)
        else
            what[name] = prop_def.default
        end
    end
end

--#region profile management
-- all of these functions may throw errors for various reasons.
-- these functions only operate on the filesystem, they don't care about what's going on in the current_settings table.

local RANDSTR = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
local RANDLEN = 8
local function get_random_identifier()
    local buf, c, path, ident
    buf = buffer.new(RANDLEN)
    ::again::
    for _ = 1, RANDLEN do
        c = math.random(1, #RANDSTR)
        buf:put(RANDSTR:sub(c, c))
    end
    ident = buf:tostring()
    path = to_settings_path(ident)
    if love.filesystem.exists(path) then
        buf:reset()
        goto again
    end
    return ident
end

---Loads the config from a json file. Might throw an error.
---@param path string
---@param where table
local function load_from_json(path, where)
    local file, msg = love.filesystem.openFile(path, "r")
    if not file then
        error(msg)
    end
    local contents = file:read()
    file:close()
    -- reset the settings before loading in case some settings didn't exist yet in the config file
    set_defaults(where)
    for name, value in pairs(json.decode(contents)) do
        where[name] = value
    end
end

---Tries to save settings to a file. May replace the identifier if something goes wrong.
---Will trow an error if unable to save.
local function try_save_settings_to_json(ident, what)
    -- check for special characters
    -- ident must have 1 alphanumeric character
    local needs_new_ident = (not not string.match(ident, "[^%w _-]")) or (not string.match(ident, "%w"))
    ::again::
    if needs_new_ident then
        ident = get_random_identifier()
    end
    local path = to_settings_path(ident)
    local success, msg = pcall(save_to_json, path, what)
    if not success then
        if needs_new_ident then
            -- identifier has already been replaced, something else has caused this failure.
            error(msg)
        end
        -- try again but replace the identifier
        needs_new_ident = true
        goto again
    end
    return ident
end

local function create_profile(name)
    if #name == 0 then
        error("new name can't be empty")
    end
    if sp_registry[name] then
        error("profile with name '" .. name .. "' already exists")
    end
    local new_profile = {}
    set_defaults(new_profile)
    local ident = try_save_settings_to_json(name, new_profile)
    sp_registry[name] = ident
    sp_display_list_add(name)
    settings_logger:info("created new settings profile '", name, "' at '", to_settings_path(ident), "'")
end

local function delete_profile(name)
    if #sp_display_list <= 1 then
        error("cannot delete the last profile")
    end
    local ident = sp_registry[name]
    if not ident then
        error("profile with name '" .. name .. "' doesn't exist")
    end
    -- if file removal fails for some reason it doesn't really cause any harm
    love.filesystem.remove(to_settings_path(ident))
    sp_registry[name] = nil
    sp_display_list_remove(name)
    settings_logger:info("deleted settings profile '", name, "' at '", to_settings_path(ident), "'")
end

local function copy_profile(target_name, new_name)
    if #new_name == 0 then
        error("new name can't be empty")
    end
    if target_name == new_name then
        error("old name and new name are the same")
    end
    local target_ident = sp_registry[target_name]
    if not target_ident then
        error("profile with name '" .. target_name .. "' doesn't exist")
    end
    if sp_registry[new_name] then
        error("profile with name '" .. new_name .. "' already exists")
    end
    local new_ident = get_random_identifier()
    local buf = {}
    load_from_json(to_settings_path(target_ident), buf)
    new_ident = try_save_settings_to_json(new_name, buf)
    sp_registry[new_name] = new_ident
    sp_display_list_add(new_name)
    settings_logger:info(
        "copied settings profile '",
        target_name,
        "' to '",
        new_name,
        "' at '",
        to_settings_path(new_ident),
        "'"
    )
end

local function rename_profile(old_name, new_name)
    if #new_name == 0 then
        error("new name can't be empty")
    end
    if old_name == new_name then
        error("old name and new name are the same")
    end
    local ident = sp_registry[old_name]
    if not ident then
        error("profile with name '" .. old_name .. "' doesn't exist")
    end
    if sp_registry[new_name] then
        error("profile with name '" .. new_name .. "' already exists")
    end
    sp_registry[new_name] = ident
    sp_registry[old_name] = nil
    sp_display_list_replace(old_name, new_name)
    settings_logger:info(
        "renamed settings profile '",
        old_name,
        "' to '",
        new_name,
        "' at '",
        to_settings_path(ident),
        "'"
    )
end

local function reset_profile(name)
    local ident = sp_registry[name]
    if not ident then
        error("profile with name '" .. name .. "' doesn't exist")
    end
    local buf = {}
    set_defaults(buf)
    ident = try_save_settings_to_json(ident, buf)
    sp_registry[name] = ident
    settings_logger:info("reset settings profile '", name, "' at '", to_settings_path(ident), "'")
end

---Saves the currently opened profile if it's dirty.
---Clears the dirty flag.
local function save_current_profile()
    if not cs_dirty then
        return
    end
    local name = global_settings.settings_profile
    local ident = sp_registry[name]
    assert(ident, "global_settings.settings_profile has an invalid value")
    ident = try_save_settings_to_json(ident, current_settings)
    sp_registry[name] = ident
    cs_dirty = false
    settings_logger:info("saved settings profile '", name, "' to '", to_settings_path(ident), "'")
end

local function open_profile(name)
    local ident = sp_registry[name]
    if not ident then
        error("profile with name '" .. name .. "' doesn't exist")
    end
    save_current_profile()
    local path = to_settings_path(ident)
    load_from_json(path, current_settings)
    global_settings.settings_profile = name
    settings_logger:info("opened settings profile '", name, "' from '", path, "'")
end

--#endregion

--#region user-facing profile management
-- the functions must handle all errors

---Creates a new profile. Settings all start at defaults.
---@param name string
---@return boolean success
---@return string? msg
---@nodiscard
function settings.create_profile(name)
    local success, msg = pcall(create_profile, name)
    if not success then
        settings_logger:info("failed to create new settings profile '", name, "': ", msg)
    end
    return success, msg
end

---Deletes a profile. Throws an error if there's only 1 profile left.
---Switches to the first profile in the display list if the current profile gets deleted.
---@param name string
---@return boolean success
---@return string? msg
---@nodiscard
function settings.delete_profile(name)
    local success, msg = pcall(delete_profile, name)
    if not success then
        settings_logger:info("failed to delete settings profile '", name, "': ", msg)
    else
        if name == global_settings.settings_profile then
            global_settings.settings_profile = sp_display_list[1]
        end
    end
    return success, msg
end

---Copies a profile.
---@param target_name string
---@param new_name string
---@return boolean success
---@return string? msg
---@nodiscard
function settings.copy_profile(target_name, new_name)
    local success, msg = pcall(copy_profile, target_name, new_name)
    if not success then
        settings_logger:info("failed to copy settings profile '", target_name, "' to '", new_name, "': ", msg)
    end
    return success, msg
end

---Renames a profile.
---@param old_name string
---@param new_name string
---@return boolean success
---@return string? msg
---@nodiscard
function settings.rename_profile(old_name, new_name)
    local success, msg = pcall(rename_profile, old_name, new_name)
    if not success then
        settings_logger:info("failed to rename settings profile '", old_name, "' to '", new_name, "': ", msg)
    else
        if old_name == global_settings.settings_profile then
            global_settings.settings_profile = new_name
        end
    end
    return success, msg
end

---Sets a profile to defaults.
---@param name string
---@return boolean success
---@return string? msg
---@nodiscard
function settings.reset_profile(name)
    if name == global_settings.settings_profile then
        set_defaults(current_settings)
        cs_dirty = true
        return true
    else
        local success, msg = pcall(reset_profile, name)
        if not success then
            settings_logger:info("failed to reset settings profile '", name, "': ", msg)
        end
        return success, msg
    end
end

---Opens a profile. Saves the previous profile.
---@param name string
---@return boolean success
---@return string? msg
---@nodiscard
function settings.open_profile(name)
    local success, msg = pcall(open_profile, name)
    if not success then
        settings_logger:info("failed to open settings profile '", name, "': ", msg)
    end
    return success, msg
end

---gets the current settings profile
---@return string
---@nodiscard
function settings.get_current_profile()
    return global_settings.settings_profile
end

--#endregion

--#endregion SETTINGS PROFILES

local function try_global_save()
    local success, msg = pcall(global_save)
    if not success then
        -- if you somehow got here your disk is probably failing or something
        config_logger:warning("failed to save global config: '", msg, "'")
    end
end

local function try_current_settings_save()
    local success, msg = pcall(save_current_profile)
    if not success then
        config_logger:warning("failed to save current settings profile: '", msg, "'")
    end
end

---Open the config file and initialize profiles.
---If files are damaged, will repair them.
---All onchange functions are run once.
do
    local global_load_success, success, msg, sp_name, gp_name

    -- try to load (can only fail because of filesystem errors)
    global_load_success, msg = pcall(global_load)
    if not global_load_success then
        config_logger:info("failed to load global config: ", msg)
    end

    -- set up global config or try to restore values if missing
    if type(global_settings.settings_profile_registry) ~= "table" then
        config_logger:info("restoring settings_profile_registry")
        sp_registry = {}
        global_settings.settings_profile_registry = sp_registry
    else
        sp_registry = global_settings.settings_profile_registry
    end

    sync_sp_registry()
    load_sp_display_list_from_registry()

    if type(global_settings.settings_profile) ~= "string" then
        local profile_name = sp_display_list[1]
        if profile_name then
            config_logger:info("restoring settings_profile value to '", profile_name, "' (from registry)")
            global_settings.settings_profile = profile_name
        else
            config_logger:info("restoring settings_profile value to 'default'")
            global_settings.settings_profile = "default"
        end
    end

    if type(global_settings.game_profile) ~= "string" then
        config_logger:info("restoring game_profile value to 'default'")
        global_settings.game_profile = "default"
    end

    sp_name = global_settings.settings_profile
    config_logger:debug("settings_profile: '", sp_name, "'")

    gp_name = global_settings.game_profile
    config_logger:debug("game_profile: '", gp_name, "'")

    -- try to open the settings profile
    success, msg = settings.open_profile(sp_name)
    if not success then
        config_logger:info("couldn't load profile '", sp_name, "': ", msg)
        success, msg = pcall(function()
            create_profile(sp_name)
            open_profile(sp_name)
        end)
        if not success then
            config_logger:info("couldn't restore profile: ", msg)
            set_defaults(current_settings)
        end
    end

    for name, prop_def in pairs(properties) do
        if prop_def.onchange then
            prop_def.onchange(current_settings[name])
        end
    end

    ---TODO: this might become obsolete in the future.
    profile.open_or_new(gp_name)

    -- recreate the config file if needed
    if not global_load_success then
        try_global_save()
    end
end

---TODO: this might become obsolete in the future.
---sets the current game profile (creates it if it doesn't exist)
---@param name string
function config.set_game_profile(name)
    profile.close()
    profile.open_or_new(name)
    global_settings.game_profile = name
end

function config.save_all()
    try_current_settings_save()
    try_global_save()
end

return config
