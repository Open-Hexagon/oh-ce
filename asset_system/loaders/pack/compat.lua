local log = require("log")(...)
local index = require("asset_system.index")
local json = require("extlibs.json.jsonc")
local vfs = require("compat.game192.virtual_filesystem")
local shader_compat = require("compat.game21.shader_compat")
local utils = require("asset_system.loaders.utils")
local platform = require("platform")
local args = require("args")
if not args.is_main_headless then
    require("love.graphics")
end

local compat_loaders = {}

---steam version has special unique pack identifiers other than the folder name
---@param info table
---@param include_version boolean?
---@return string
function compat_loaders.build_pack_id21(info, include_version)
    local pack_id = info.disambiguator .. "_" .. info.author .. "_" .. info.name
    if info.version ~= nil and include_version then
        pack_id = pack_id .. "_" .. math.floor(info.version)
    end
    pack_id = pack_id:gsub(" ", "_")
    return pack_id
end

function compat_loaders.sound_data(path_or_content, use_vfs)
    if use_vfs then
        error("loading sounds from virtual filesystem is not supported.")
    end
    index.watch_file(path_or_content)
    return love.sound.newSoundData(path_or_content)
end

function compat_loaders.text_file(path_or_content, use_vfs)
    if use_vfs then
        return path_or_content
    else
        index.watch_file(path_or_content)
        local contents, err = love.filesystem.read(path_or_content)
        if not contents then
            log(("Error reading file '%s': %s"):format(path_or_content, err))
            contents = ""
        end
        return contents
    end
end

function compat_loaders.json_file(path_or_content, use_vfs, filename)
    local str = index.local_request("pack.compat.text_file", path_or_content, use_vfs)
    -- not a good way but hardcoding some known cases
    str = str:gsub(": 00 }", ": 0 }")
    str = str:gsub(", 00", ", 0")
    str = str:gsub("%[00,", "%[0,")
    str = str:gsub("055%]", "55%]")
    -- remove multiline comments
    while str:find("/*", 0, true) and str:find("*/", 0, true) do
        local cstart = str:find("/*", 0, true)
        local cend = str:find("*/", 0, true)
        str = str:sub(1, cstart - 1) .. str:sub(cend + 2)
    end
    -- catch decode errors
    local _, result = xpcall(json.decode_jsonc, function(msg)
        log("Error: can't decode '" .. (filename or path_or_content) .. "': " .. msg)
    end, str)
    if type(result) == "userdata" then
        return {} -- jsonc does this when the string is empty for some reason
    end
    return result or {}
end

function compat_loaders.virtual_folder(pack_folder_name)
    index.watch("persistent_data:" .. pack_folder_name)
    local persistent_data = love.thread.getChannel("persistent_data:" .. pack_folder_name):peek()
    vfs.clear()
    local virtual_pack_folder
    if persistent_data then
        vfs.load_files(json.decode(persistent_data))
        virtual_pack_folder = vfs.dump_real_files_recurse()[pack_folder_name]
    end
    return virtual_pack_folder or {}
end

---iterate over the contents of all files with a certain ending in a certain folder
---@param dir string
---@param ending string
---@param info table
---@return function
local function file_iter(dir, ending, loader, info)
    index.watch_file(info.path .. dir)
    local files = love.filesystem.getDirectoryItems(info.path .. dir)
    local virt_folder = index.local_request("pack.compat.virtual_folder", info.folder_name)
    virt_folder = virt_folder[dir] or {}
    -- add virtual files to list
    for file in pairs(virt_folder) do
        files[#files + 1] = file
    end
    return coroutine.wrap(function()
        for i = 1, #files do
            local name = files[i]
            if name:sub(-#ending) == ending then
                -- virtual files take precedence over real ones (overwriting)
                if virt_folder[name] then
                    coroutine.yield(
                        index.local_request(loader, virt_folder[name], true, name, info.game_version, info.folder_name),
                        name
                    )
                else
                    coroutine.yield(
                        index.local_request(
                            loader,
                            info.path .. dir .. "/" .. name,
                            false,
                            name,
                            info.game_version,
                            info.folder_name
                        ),
                        name
                    )
                end
            end
        end
    end)
end

local function set_event_defaults(events)
    for i = 1, #events do
        local event = events[i]
        if type(event) == "userdata" then
            -- null in end of list (parsing error)
            events[i] = nil
            break
        end
        event.type = event.type or ""
        event.duration = event.duration or 0
        event.value_name = event.value_name or ""
        event.value = event.value or 0
        event.message = event.message or ""
        event.id = event.id or ""
    end
end

function compat_loaders.level_data(path_or_content, is_content)
    local level_json = index.local_request("pack.compat.json_file", path_or_content, is_content)
    -- make keys have the same name for all versions
    -- get key names
    local key_names = {}
    for key in pairs(level_json) do
        key_names[#key_names + 1] = key
    end
    -- and then translate them to avoid modifying the table while iterating (which may skip some keys)
    for k = 1, #key_names do
        local key = key_names[k]
        local value = level_json[key]
        local snake_case_key = key:gsub("([a-z])([A-Z])", "%1_%2"):lower()
        snake_case_key = snake_case_key:gsub("multipliers", "mults")
        level_json[snake_case_key] = value
    end

    -- set defaults
    level_json.id = level_json.id or "nullId"
    level_json.name = level_json.name or "nullName"
    level_json.description = level_json.description or ""
    level_json.author = level_json.author or ""
    level_json.menu_priority = level_json.menu_priority or 0
    if level_json.selectable == nil then
        level_json.selectable = true
    end
    level_json.music_id = level_json.music_id or "nullMusicId"
    level_json.sound_id = level_json.sound_id or "nullSoundId"
    level_json.style_id = level_json.style_id or "nullStyleId"
    level_json.lua_file = level_json.lua_file or "nullLuaPath"
    if level_json.events ~= nil then
        set_event_defaults(level_json.events)
    end
    level_json.difficulty_mults = level_json.difficulty_mults or {}
    -- add 1x difficulty mult if it doesn't exist
    local has1 = false
    for k = 1, #level_json.difficulty_mults do
        if level_json.difficulty_mults[k] == 1 then
            has1 = true
            break
        end
    end
    if not has1 then
        level_json.difficulty_mults[#level_json.difficulty_mults + 1] = 1
    end
    -- sort difficulties
    table.sort(level_json.difficulty_mults)
    return level_json
end

function compat_loaders.level_datas(pack_folder_name, version)
    local info = index.local_request("pack.compat.info", pack_folder_name, version)
    local levels = {}
    for level_data in file_iter("Levels", ".json", "pack.compat.level_data", info) do
        levels[#levels + 1] = level_data
        level_data.sort_index = #levels
    end
    -- make sure levels are in menu priority order
    table.sort(levels, function(a, b)
        if a.menu_priority == b.menu_priority then
            return a.sort_index > b.sort_index
        end
        return a.menu_priority < b.menu_priority
    end)
    for i = 1, #levels do
        levels[i].sort_index = nil
    end
    return levels
end

function compat_loaders.info(pack_folder_name, version)
    local folder = "packs" .. version .. "/" .. pack_folder_name .. "/"
    local info = {}
    index.watch_file(folder .. "pack.json")
    if not love.filesystem.exists(folder .. "pack.json") then
        log("Invalid pack at " .. folder .. " missing pack.json")
    else
        info = index.local_request("pack.compat.json_file", folder .. "pack.json")
    end
    info.game_version = version
    info.path = folder
    info.folder_name = pack_folder_name
    if version == 21 then
        -- steam version defaults
        info.name = info.name or "unkown name"
        info.author = info.author or "unkown author"
        info.description = info.description or "no description"
        info.version = info.version or 0
        info.priority = info.priority or 100
        info.disambiguator = info.disambiguator or "no disambiguator"

        info.id = compat_loaders.build_pack_id21(info, true)
    else
        info.name = info.name or ""
        info.id = pack_folder_name
    end
    return info
end

function compat_loaders.preload_pack(pack_folder_name, version)
    local pack = {}
    pack.info = index.local_request("pack.compat.info", pack_folder_name, version)
    local level_list = index.local_request("pack.compat.level_datas", pack_folder_name, version)
    pack.levels = {}
    for i = 1, #level_list do
        local level = level_list[i]
        pack.levels[level.id] = level
    end
    return pack
end

function compat_loaders.load_dependency_map21()
    local packs21 = index.local_request("pack.preload_packs", 21)
    local map = {}
    for i = 1, #packs21 do
        local pack = packs21[i]
        map[compat_loaders.build_pack_id21(pack.info)] = pack
    end
    return map
end

function compat_loaders.load_file_list(dir, ending, loader, list_key, version, name, res_key)
    local info = index.local_request("pack.compat.info", name, version)
    local list = {}
    for result, filename in file_iter(dir, ending, loader, info) do
        local key = #list + 1
        if list_key == "filename" then
            key = filename
        elseif list_key then
            key = result[list_key]
        end
        if not key then
            log("Failed loading " .. filename)
        else
            if res_key then
                list[key] = result[res_key]
            else
                list[key] = result
            end
        end
    end
    return list
end

function compat_loaders.music(path_or_content, is_content, filename, version, pack_folder_name)
    local pack_info = index.local_request("pack.compat.info", pack_folder_name, version)
    local music = index.local_request("pack.compat.json_file", path_or_content, is_content, filename)
    if not args.is_main_headless then
        local fallback_path = filename:gsub("%.json$", ".ogg")
        music.file_name = music.file_name or fallback_path
        local path = pack_info.path .. "Music/" .. music.file_name
        index.watch_file(path)
        if music.file_name:sub(-4) ~= ".ogg" or not love.filesystem.exists(path) then
            music.file_name = fallback_path
            path = pack_info.path .. "Music/" .. music.file_name
        end
        if love.filesystem.exists(path) then
            -- don't load music here yet, load it when required and unload it again to save memory usage (otherwise the game may use 5+ gb just for music assets after clicking through the menu)
            music.file_path = path
        end
    end
    music.segments = music.segments or {}
    if version ~= 21 then
        for i = 1, #music.segments do
            if type(music.segments[i]) == "table" then
                music.segments[i].time = math.floor(music.segments[i].time)
            else
                -- happens with the last element of not properly closed segment list
                music.segments[i] = nil
            end
        end
    end
    return music
end

function compat_loaders.shader(path_or_content, is_content, filename)
    local code = index.local_request("pack.compat.text_file", path_or_content, is_content)
    local translated_shader = shader_compat.translate(code, filename)
    local compiled_shader
    if platform.supports_threaded_shader_compilation then
        compiled_shader = shader_compat.compile(translated_shader.new_code, code, filename)
    else
        compiled_shader = utils.run_on_main(
            'return require("compat.game21.shader_compat").compile(...)',
            translated_shader.new_code,
            translated_shader.code,
            translated_shader.filename
        )
    end
    return compiled_shader
end

function compat_loaders.event_list(path_or_content, is_content, filename)
    local value = index.local_request("pack.compat.json_file", path_or_content, is_content, filename)
    set_event_defaults(value.events)
    return value
end

function compat_loaders.preview_data(version, name)
    local info = index.local_request("pack.compat.info", name, version)
    local levels = index.local_request("pack.compat.level_datas", name, version)
    local styles = index.local_request(
        "pack.compat.load_file_list",
        "Styles",
        ".json",
        "pack.compat.json_file",
        "id",
        version,
        name
    )
    local style_module = require("compat.game" .. version .. ".style")
    local set_function = style_module.select or style_module.set
    local preview_data = {}
    for i = 1, #levels do
        local level = levels[i]

        -- get side count and rotation speed
        local side_count = 6
        local rotation_speed = 0
        if version == 192 then
            side_count = level.sides or side_count
            rotation_speed = level.rotation_speed or rotation_speed
        else
            local lua_path = info.path .. "/" .. level.lua_file
            index.watch_file(lua_path)
            if love.filesystem.exists(lua_path) then
                local code = love.filesystem.read(lua_path)
                for match in code:gmatch("function%s*onInit.-l_setSides%((.-)%).-end") do
                    side_count = tonumber(match) or side_count
                end
                for match in code:gmatch("function%s*onInit.-l_setRotationSpeed%((.-)%).-end") do
                    rotation_speed = tonumber(match) or rotation_speed
                end
            end
        end
        side_count = math.max(side_count, 3)
        -- convert to rad/s
        rotation_speed = rotation_speed * math.pi * 10 / 3

        -- get colors
        set_function(styles[level.style_id] or {}, true)
        style_module.compute_colors()
        local main_color = { style_module.get_main_color() }
        for j = 1, 4 do
            main_color[j] = main_color[j] / 255
        end
        local colors = {}
        for j = 1, side_count do
            local r, g, b, a = style_module.get_color(j - (version == 20 and 0 or 1))
            local must_darken = j % 2 == 0 and j == side_count - 1
            if must_darken then
                r = r / 1.4
                g = g / 1.4
                b = b / 1.4
            end
            colors[j] = { r, g, b, 1 }
            for k = 1, 3 do
                colors[j][k] = colors[j][k] / 255 * a / 255
            end
        end
        local r, g, b, a
        if version == 21 then
            r, g, b, a = style_module.get_cap_color_result()
        elseif version == 20 then
            r, g, b, a = style_module.get_color(2)
        elseif version == 192 then
            r, g, b, a = style_module.get_second_color()
        end
        preview_data[level.id] = {
            rotation_speed = rotation_speed,
            sides = side_count,
            background_colors = colors,
            pivot_color = main_color,
            cap_color = { r / 255, g / 255, b / 255, a / 255 },
        }
    end
    return preview_data
end

function compat_loaders.full_load(version, id)
    local id_map = index.local_request("pack.load_id_map")
    local pack = (id_map[version] or {})[id]
    if not pack then
        error("pack with id '" .. id .. "' does not exist.")
    end
    local name = pack.info.folder_name

    if version == 21 then
        pack.dependencies = {}
        local dependency_map = index.local_request("pack.compat.load_dependency_map21")
        if type(pack.info.dependencies) == "table" then
            for i = 1, #pack.info.dependencies do
                local pack_id = compat_loaders.build_pack_id21(pack.info.dependencies[i])
                local full_pack_id = dependency_map[pack_id].info.id
                if pack.info.id ~= full_pack_id then
                    pack.dependencies[pack_id] = index.local_request("pack.compat.full_load", 21, full_pack_id)
                end
            end
        end
    end

    log("Loading '" .. pack.info.id .. "' assets")

    pack.music =
        index.local_request("pack.compat.load_file_list", "Music", ".json", "pack.compat.music", "id", version, name)
    pack.sounds =
        index.local_request("pack.compat.load_file_list", "Sounds", ".ogg", "sound_data", "filename", version, name)

    -- shaders in compat mode are only required for 21
    if not args.is_main_headless and version == 21 then
        pack.shaders = index.local_request(
            "pack.compat.load_file_list",
            "Shaders",
            ".frag",
            "pack.compat.shader",
            "filename",
            version,
            name
        )
    end

    -- styles
    pack.styles = index.local_request(
        "pack.compat.load_file_list",
        "Styles",
        ".json",
        "pack.compat.json_file",
        "id",
        version,
        name
    )

    -- only 1.92 has event files
    if version == 192 then
        pack.events = index.local_request(
            "pack.compat.load_file_list",
            "Events",
            ".json",
            "pack.compat.event_list",
            "id",
            version,
            name,
            "events"
        )
    end

    -- sounds
    pack.sounds = index.local_request(
        "pack.compat.load_file_list",
        "Sounds",
        ".ogg",
        "pack.compat.sound_data",
        "filename",
        version,
        name
    )

    return pack
end

return compat_loaders
