local index = require("asset_system.index")

local sound_mapping = {
    ["beep.ogg"] = "click.ogg",
    ["difficultyMultDown.ogg"] = "difficulty_mult_down.ogg",
    ["difficultyMultUp.ogg"] = "difficulty_mult_up.ogg",
    ["gameOver.ogg"] = "game_over.ogg",
    ["levelUp.ogg"] = "level_up.ogg",
    ["openHexagon.ogg"] = "open_hexagon.ogg",
    ["personalBest.ogg"] = "personal_best.ogg",
    ["swapBlip.ogg"] = "swap_blip.ogg",
}
local audio_path = "assets/audio/"

local loaders = {}

function loaders.sound(name)
    name = sound_mapping[name] or name
    local path = audio_path .. name
    if love.filesystem.exists(path) then
        return index.local_request("sound_data", path)
    end
end

function loaders.all_game_sounds()
    index.watch_file(audio_path)
    local items = love.filesystem.getDirectoryItems(audio_path)
    local result = {}
    for i = 1, #items do
        result[items[i]] = index.local_request("compat.sound", items[i])
    end
    for k, v in pairs(sound_mapping) do
        result[k] = result[v]
    end
    return result
end

function loaders.steam_level_validators()
    local packs = index.local_request("pack.load_register")
    local level_validators = {
        list = {},
        set = {},
        to_id = {},
    }
    for j = 1, #packs do
        local pack = packs[j]
        if pack.game_version == 21 then
            for k = 1, pack.level_count do
                local level = pack.levels[k]
                for i = 1, #level.options.difficulty_mult do
                    local validator = pack.id .. "_" .. level.id .. "_m_" .. level.options.difficulty_mult[i]
                    level_validators.list[#level_validators.list + 1] = validator
                    level_validators.set[validator] = true
                    level_validators.to_id[validator] = {
                        pack = pack.id,
                        level = level.id,
                        difficulty_mult = level.options.difficulty_mult[i],
                    }
                end
            end
        end
    end
    return level_validators
end

return loaders
