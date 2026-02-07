local data = {}
local packs = {}
local pack_id_map = {}
local pack_count = 0

function data.register_pack(id, name, folder_name, game_version, dependency_ids)
    pack_count = pack_count + 1
    packs[pack_count] = {
        id = id,
        name = name,
        folder_name = folder_name,
        game_version = game_version,
        levels = {},
        level_count = 0,
        dependency_ids = dependency_ids or {},
    }
    pack_id_map[id] = packs[pack_count]
end

function data.register_level(pack_id, id, name, author, description, options)
    local pack = pack_id_map[pack_id]
    if pack == nil then
        error("Attempted to register level for non-existing pack")
    end
    pack.level_count = pack.level_count + 1
    pack.levels[pack.level_count] = {
        id = id,
        name = name or "[No name]",
        author = author or "[No author]",
        description = description or "[No Description]",
        options = options or {},
    }
end

function data.get_packs()
    return packs
end

function data.import_packs(new_packs)
    for i = 1, #new_packs do
        local pack = new_packs[i]
        data.register_pack(pack.id, pack.name, pack.folder_name, pack.game_version, pack.dependency_ids)
        for j = 1, pack.level_count do
            local level = pack.levels[j]
            data.register_level(pack.id, level.id, level.name, level.author, level.description, level.options)
        end
    end
end

function data.clear()
    packs = {}
    pack_id_map = {}
    pack_count = 0
end

return data
