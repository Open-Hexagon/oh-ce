local log = require("log")(...)
local json = require("extlibs.json.jsonc")
local data = require("game_handler.data")
local utils = require("compat.game192.utils")
local vfs = require("compat.game192.virtual_filesystem")
local shader_compat = require("compat.game21.shader_compat")
local assets = {}
local packs = {}
local is_headless = false
local dependency_pack_mapping21 = {}
local asset_loading_text_channel = love.thread.getChannel("asset_loading_text")
local asset_loading_progress_channel = love.thread.getChannel("asset_loading_progress")

---decode a string of json with a filename to be used in a potential non erroring error message
---@param str string
---@param filename string
---@return boolean
---@return table
local function decode_json(str, filename)
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
    return xpcall(json.decode_jsonc, function(msg)
        log("Error: can't decode '" .. filename .. "': " .. msg)
    end, str)
end

local function file_ext_read_iter(dir, ending)
    local files = love.filesystem.getDirectoryItems(dir)
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
        local contents = love.filesystem.read(dir .. "/" .. files[index])
        if contents == nil then
            error("Failed to read " .. dir .. "/" .. files[index])
        else
            return contents, files[index]
        end
    end
end

local function get_file_amount(dir, ending, pack_data)
    local files = love.filesystem.getDirectoryItems(pack_data.path .. dir)
    if pack_data.game_version ~= 21 then
        for file in pairs(pack_data.virtual_pack_folder[dir] or {}) do
            files[#files + 1] = file
        end
    end
    local count = 0
    for i = 1, #files do
        if files[i]:sub(-#ending) == ending then
            count = count + 1
        end
    end
    return count
end

local function file_iter(dir, ending, pack_data)
    if pack_data.game_version ~= 21 then
        return utils.file_ext_read_iter(pack_data.path .. dir, ending, pack_data.virtual_pack_folder[dir])
    else
        return file_ext_read_iter(pack_data.path .. dir, ending)
    end
end

-- steam version has special unique pack identifiers other than the folder name
local function build_pack_id21(disambiguator, author, name, version)
    local pack_id = disambiguator .. "_" .. author .. "_" .. name
    if version ~= nil then
        pack_id = pack_id .. "_" .. math.floor(version)
    end
    pack_id = pack_id:gsub(" ", "_")
    return pack_id
end

local initialized = false

local function preload_pack(pack_folder_name, version, persistent_data)
    local is_compat = version ~= 3
    local folder = "packs" .. version .. "/" .. pack_folder_name .. "/"
    -- check if valid pack
    local files = love.filesystem.getDirectoryItems(folder)
    local function check_file(file)
        local is_in = false
        for k = 1, #files do
            if files[k] == file then
                is_in = true
            end
        end
        if not is_in then
            log("Invalid pack " .. folder .. file .. " does not exist!")
        end
        return is_in
    end
    if is_compat and check_file("pack.json") and check_file("Scripts") then
        local pack_json_contents = love.filesystem.read(folder .. "pack.json")
        if pack_json_contents == nil then
            log("Failed to load pack.json at", folder .. "pack.json")
        else
            local decode_success, pack_data = decode_json(pack_json_contents)
            if decode_success then
                pack_data.name = pack_data.name or ""
                pack_data.game_version = version
                pack_data.path = folder
                pack_data.folder_name = pack_folder_name
                pack_data.loaded = false
                if version == 21 then
                    pack_data.id =
                        build_pack_id21(pack_data.disambiguator, pack_data.author, pack_data.name, pack_data.version)
                    dependency_pack_mapping21[build_pack_id21(pack_data.disambiguator, pack_data.author, pack_data.name)] =
                        pack_data
                else
                    pack_data.id = pack_folder_name
                end
                if version ~= 21 then
                    -- initialize virtual filesystem for reading
                    vfs.clear()
                    local virtual_pack_folder
                    local folder_name = pack_folder_name
                    if persistent_data and persistent_data[folder_name] then
                        vfs.load_files(persistent_data[folder_name])
                        virtual_pack_folder = vfs.dump_real_files_recurse()[folder_name]
                    end
                    pack_data.virtual_pack_folder = virtual_pack_folder or {}
                end

                -- level data has to be loaded immediately for level selection purposes
                pack_data.levels = {}
                pack_data.level_list = {}
                for contents, filename in file_iter("Levels", ".json", pack_data) do
                    local success, level_json = decode_json(contents, filename)
                    if success then
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

                        -- default
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

                        pack_data.levels[level_json.id] = level_json
                        pack_data.level_list[#pack_data.level_list + 1] = level_json
                        -- ensure original order for same priority levels
                        level_json.sort_index = #pack_data.level_list
                    else
                        log("Failed to parse level json:", filename)
                    end
                end

                packs[version] = packs[version] or {}
                if packs[version][pack_data.id] then
                    log("Id conflict: ", pack_data.id)
                end
                packs[version][pack_data.id] = pack_data
                return pack_data
            else
                log("Failed to decode", folder .. "pack.json")
            end
        end
    end
end

local function register_pack(version, pack_data)
    if pack_data.game_version ~= 3 then
        -- only register pack if dependencies are satisfied
        local has_all_deps = true
        local dependency_ids = {}
        if version == 21 and pack_data.dependencies ~= nil then
            for k = 1, #pack_data.dependencies do
                local dependency = pack_data.dependencies[k]
                local index_pack_id = build_pack_id21(dependency.disambiguator, dependency.author, dependency.name)
                local dependency_pack_data = dependency_pack_mapping21[index_pack_id]
                if dependency_pack_data == nil then
                    has_all_deps = false
                else
                    dependency_ids[#dependency_ids + 1] = dependency_pack_data.id
                end
            end
        end
        if has_all_deps then
            data.register_pack(pack_data.id, pack_data.name, pack_data.folder_name, version, dependency_ids)

            -- register levels in menu priority order
            table.sort(pack_data.level_list, function(a, b)
                if a.menu_priority == b.menu_priority then
                    return a.sort_index > b.sort_index
                end
                return a.menu_priority < b.menu_priority
            end)
            for k = 1, #pack_data.level_list do
                local level = pack_data.level_list[k]
                level.sort_index = nil
                local proceed = true
                if pack_data.game_version == 192 then
                    proceed = level.selectable
                end
                if proceed then
                    data.register_level(
                        pack_data.id,
                        level.id,
                        level.name,
                        level.author,
                        level.description,
                        { difficulty_mult = level.difficulty_mults }
                    )
                end
            end
        else
            log("Pack with id '" .. pack_data.id .. "' has unsatisfied dependencies!")
        end
        -- only used for temporary sorting (same priority levels are sorted after file list)
        pack_data.level_list = nil
    end
end

function assets.init(persistent_data, headless)
    if not initialized then
        is_headless = headless
        local folders = love.filesystem.getDirectoryItems("")
        for i = 1, #folders do
            local version = folders[i]:match("packs(.*)")
            version = tonumber(version)
            if version then
                log("Loading pack information for game" .. version)
                asset_loading_text_channel:push("Loading pack information for game" .. version)
                local pack_list = {}
                local pack_folder = "packs" .. version .. "/"
                local pack_folders = love.filesystem.getDirectoryItems(pack_folder)
                for j = 1, #pack_folders do
                    pack_list[#pack_list + 1] = preload_pack(pack_folders[j], version, persistent_data)
                    asset_loading_progress_channel:push(j / #pack_folders)
                end

                -- register pack and levels
                for j = 1, #pack_list do
                    register_pack(version, pack_list[j])
                end
            end
        end
        initialized = true
    end
    return data.get_packs()
end

function assets.preload_pack(pack_folder_name, version, persistent_data)
    local pack_data = preload_pack(pack_folder_name, version, persistent_data)
    register_pack(version, pack_data)
    local pack_datas = data.get_packs()
    return pack_datas[#pack_datas]
end

function assets.get_dependency_pack_mapping21()
    return dependency_pack_mapping21
end

function assets.get_pack(version, id, headless)
    if headless == nil then
        headless = is_headless
    end
    local is_compat = version ~= 3
    local pack_data = (packs[version] or {})[id] or dependency_pack_mapping21[id]
    if not pack_data then
        error("pack with id '" .. id .. "' does not exist.")
    end
    id = pack_data.id
    asset_loading_text_channel:push("Loading pack '" .. id .. "' assets")
    asset_loading_progress_channel:push(0)
    if pack_data.loaded and (pack_data.was_loaded_headlessly == headless or headless) then
        asset_loading_progress_channel:push(1)
        return pack_data
    end
    pack_data.was_loaded_headlessly = headless
    if is_compat then
        if version == 21 then
            -- pack may have dependencies
            if pack_data.dependencies ~= nil then
                for i = 1, #pack_data.dependencies do
                    local dependency = pack_data.dependencies[i]
                    local index_pack_id = build_pack_id21(dependency.disambiguator, dependency.author, dependency.name)
                    local dependency_pack_data = dependency_pack_mapping21[index_pack_id]
                    if dependency_pack_data == nil then
                        error("can't find dependency '" .. index_pack_id .. "' of '" .. pack_data.id .. "'.")
                    end
                    -- fix recursive dependencies
                    if dependency_pack_data.id ~= id then
                        -- no need to keep the pack data, just make sure it's loaded now to avoid having to make loading circles during gameplay to load dependency packs
                        assets.get_pack(version, dependency_pack_data.id)
                    end
                end
            end
            -- reset text and progress to this pack
            asset_loading_text_channel:push("Loading pack '" .. id .. "' assets")
            asset_loading_progress_channel:push(0)
        end
        log("Loading '" .. pack_data.id .. "' assets")

        local loaded_files = 0
        local total_files = get_file_amount("Music", ".json", pack_data) + get_file_amount("Styles", ".json", pack_data)
        if pack_data.game_version == 21 then
            total_files = total_files + get_file_amount("Shaders", ".frag", pack_data)
        elseif pack_data.game_version == 192 then
            total_files = total_files + get_file_amount("Events", ".json", pack_data)
        end

        -- music
        pack_data.music = {}
        for contents, filename in file_iter("Music", ".json", pack_data) do
            local success, music_json = decode_json(contents, filename)
            if success then
                if not headless then
                    local fallback_path = filename:gsub("%.json", ".ogg")
                    music_json.file_name = music_json.file_name or fallback_path
                    if music_json.file_name:sub(-4) ~= ".ogg" then
                        music_json.file_name = fallback_path
                    end
                    if not love.filesystem.getInfo(pack_data.path .. "Music/" .. music_json.file_name) then
                        music_json.file_name = fallback_path
                    end
                    if love.filesystem.getInfo(pack_data.path .. "Music/" .. music_json.file_name) then
                        -- don't load music here yet, load it when required and unload it again to save memory usage (otherwise the game may use 5+ gb just for music assets after clicking through the menu)
                        music_json.file_path = pack_data.path .. "Music/" .. music_json.file_name
                    end
                end
                if pack_data.game_version ~= 21 then
                    music_json.segments = music_json.segments or {}
                    for i = 1, #music_json.segments do
                        if type(music_json.segments[i]) == "table" then
                            music_json.segments[i].time = math.floor(music_json.segments[i].time)
                        else
                            -- happens with the last element of not properly closed segment list
                            music_json.segments[i] = nil
                        end
                    end
                end
                pack_data.music[music_json.id] = music_json
            end
            loaded_files = loaded_files + 1
            asset_loading_progress_channel:push(loaded_files / total_files)
        end

        -- shaders in compat mode are only required for 21
        if not headless and version == 21 then
            pack_data.shaders = {}
            for code, filename in file_iter("Shaders", ".frag", pack_data) do
                -- only translating, can only compile in main thread
                pack_data.shaders[filename] = shader_compat.translate(code, filename)
                loaded_files = loaded_files + 1
                asset_loading_progress_channel:push(loaded_files / total_files)
            end
        end

        -- styles
        pack_data.styles = {}
        for contents, filename in file_iter("Styles", ".json", pack_data) do
            local success, style_json = decode_json(contents, filename)
            if success then
                pack_data.styles[style_json.id] = style_json
            end
            loaded_files = loaded_files + 1
            asset_loading_progress_channel:push(loaded_files / total_files)
        end

        -- only 1.92 has event files
        if version == 192 then
            pack_data.events = {}
            for contents, filename in file_iter("Events", ".json", pack_data) do
                local success, event_json = decode_json(contents, filename)
                if success then
                    pack_data.events[event_json.id] = event_json.events
                end
                loaded_files = loaded_files + 1
                asset_loading_progress_channel:push(loaded_files / total_files)
            end
        end

        -- small preview data
        pack_data.preview_data = {}
        local style_module = require("compat.game" .. pack_data.game_version .. ".style")
        local set_function = style_module.select or style_module.set
        for level_id, level in pairs(pack_data.levels) do
            -- get side count and rotation speed
            local sides = 6
            local rotation_speed = 0
            if version == 192 then
                sides = level.sides or 6
                rotation_speed = level.rotation_speed or 0
            else
                local lua_path = pack_data.path .. "/" .. level.lua_file
                if love.filesystem.getInfo(lua_path) then
                    local code = love.filesystem.read(lua_path)
                    -- match set sides calls in the lua file to get the number of sides
                    for match in code:gmatch("function.-onInit.-l_setSides%((.-)%).-end") do
                        sides = tonumber(match) or sides
                    end
                    -- match set rotation speed calls in the lua file to get the rotation speed
                    for match in code:gmatch("function.-onInit.-l_setRotationSpeed%((.-)%).-end") do
                        rotation_speed = tonumber(match) or rotation_speed
                    end
                end
            end
            sides = math.max(sides, 3)
            -- convert to rad/s
            rotation_speed = rotation_speed * math.pi * 10 / 3

            -- get colors
            set_function(pack_data.styles[level.style_id])
            style_module.compute_colors()
            local main_color = { style_module.get_main_color() }
            for i = 1, 4 do
                main_color[i] = main_color[i] / 255
            end

            -- generate vertex color data
            local colors = {}
            for i = 1, sides do
                local r, g, b, a = style_module.get_color(i - (pack_data.game_version == 20 and 0 or 1))
                local must_darken = i % 2 == 0 and i == sides - 1
                if must_darken then
                    r = r / 1.4
                    g = g / 1.4
                    b = b / 1.4
                end
                r = r / 255
                g = g / 255
                b = b / 255
                a = a / 255
                colors[#colors + 1] = { r * a, g * a, b * a, 1 }
            end
            local r, g, b, a
            if pack_data.game_version == 21 then
                r, g, b, a = style_module.get_cap_color_result()
            elseif pack_data.game_version == 20 then
                r, g, b, a = style_module.get_color(2)
            elseif pack_data.game_version == 192 then
                r, g, b, a = style_module.get_second_color()
            end
            pack_data.preview_data[level_id] = {
                rotation_speed = rotation_speed,
                sides = sides,
                background_colors = colors,
                pivot_color = main_color,
                cap_color = { r / 255, g / 255, b / 255, a / 255 },
            }
        end
    end

    pack_data.loaded = true
    return pack_data
end

return assets
