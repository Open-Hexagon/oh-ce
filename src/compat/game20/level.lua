local level = {}

local defaults = {
    id = "nullId",
    name = "nullName",
    description = "",
    author = "",
    menu_priority = 0,
    selectable = true,
    music_id = "nullMusicId",
    style_id = "nullStyleId",
    lua_file = "nullLuaPath",
    difficulty_multipliers = {},
}

function level.set(level_json)
    for key, value in pairs(defaults) do
        level[key] = level_json[key] or value
    end
    local has1 = false
    for i = 1, #level.difficulty_multipliers do
        if level.difficulty_multipliers[i] == 1 then
            has1 = true
            break
        end
    end
    if not has1 then
        level.difficulty_multipliers[#level.difficulty_multipliers + 1] = 1
    end
    table.sort(level.difficulty_multipliers)
end

return level
