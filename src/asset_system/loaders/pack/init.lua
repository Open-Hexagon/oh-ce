local log = require("log")(...)
local index = require("asset_system.index")
local compat = require("asset_system.loaders.pack.compat")

local pack_loaders = {}

function pack_loaders.preload_packs(version)
    log("Loading pack information for game" .. version)
    index.watch_file("packs" .. version)
    local pack_folders = love.filesystem.getDirectoryItems("packs" .. version)
    local packs = {}
    for j = 1, #pack_folders do
        packs[#packs + 1] = index.local_request("pack.compat.preload_pack", pack_folders[j], version)
    end
    return packs
end

function pack_loaders.level_register(pack_folder_name, version)
    local level_list = index.local_request("pack.compat.level_datas", pack_folder_name, version)
    local result = {}
    for i = 1, #level_list do
        local level = level_list[i]
        if version ~= 192 or level.selectable then
            result[#result + 1] = {
                id = level.id,
                name = level.name,
                author = level.author,
                description = level.description,
                options = { difficulty_mult = level.difficulty_mults },
            }
        end
    end
    return result
end

function pack_loaders.pack_register(pack_folder_name, version)
    local pack = index.local_request("pack.compat.info", pack_folder_name, version)

    -- check dependencies and add ids to list
    local has_all_deps = true
    local dependency_ids = {}
    if version == 21 and type(pack.dependencies) == "table" and #pack.dependencies > 0 then
        local dependency_pack_map21 = index.local_request("pack.compat.load_dependency_map21")
        for i = 1, #pack.dependencies do
            local dependency = pack.dependencies[i]
            local index_pack_id = compat.build_pack_id21(dependency)
            local dependency_pack = dependency_pack_map21[index_pack_id]
            if dependency_pack == nil then
                has_all_deps = false
            else
                dependency_ids[#dependency_ids + 1] = dependency_pack.id
            end
        end
    end

    if has_all_deps then
        local levels = index.local_request("pack.level_register", pack.folder_name, version)
        return {
            id = pack.id,
            name = pack.name,
            folder_name = pack.folder_name,
            game_version = version,
            dependency_ids = dependency_ids,
            levels = levels,
            level_count = #levels,
        }
    else
        log("Pack with id '" .. pack.id .. "' has unsatisfied dependencies!")
    end
end

function pack_loaders.load_register()
    local result = {}
    -- check all folders in save directory
    -- don't watch here as adding a new game version will never happen without restarting
    local folders = love.filesystem.getDirectoryItems("")
    for i = 1, #folders do
        -- check if the name matches "packs<version>"
        local version = tonumber(folders[i]:match("packs(.*)"))
        if version then
            -- folder is a pack folder
            local pack_list = index.local_request("pack.preload_packs", version)
            for k = 1, #pack_list do
                local pack = pack_list[k]
                result[#result + 1] = index.local_request("pack.pack_register", pack.info.folder_name, version)
            end
        end
    end
    return result
end

function pack_loaders.load_id_map()
    local reg = index.local_request("pack.load_register")
    local packs = {}
    for i = 1, #reg do
        local pack = reg[i]
        packs[pack.game_version] = packs[pack.game_version] or {}
        packs[pack.game_version][pack.id] =
            index.local_request("pack.compat.preload_pack", pack.folder_name, pack.game_version)
    end
    return packs
end

return pack_loaders
