local assets = require("asset_system")
local audio = require("audio")
local args = require("args")
local log = require("log")(...)
local sound = {}

-- TODO: make this less jank or don't support it at all (less jank as in not polluting asset mirrors and preventing unloads)
-- the only level I know that does this is "ace in the hole" from "Exschwasion" (it plays "test.ogg" from "VeeEndurance")
local function play_external_pack_sound(game_version, pack_id, actual_name)
    local pack_folder = pack_id
    if game_version == 21 then
        local game_handler = require("game_handler")
        local packs = game_handler.get_packs()
        for i = 1, #packs do
            if packs[i].id == pack_id then
                pack_folder = packs[i].folder_name
            end
        end
    end
    local key = ("sound_datas_%d_%s"):format(game_version, pack_folder)
    assets.index
        .request(
            key,
            "pack.compat.load_file_list",
            "Sounds",
            ".ogg",
            "pack.compat.sound_data",
            "filename",
            game_version,
            pack_folder
        )
        :done(function()
            audio.play_sound(assets.mirror[key][actual_name])
        end)
end

local function get_game_sound(name)
    if assets.mirror.game_sounds then
        return assets.mirror.game_sounds[name]
    else
        log("sound module used without initializing first")
    end
end

function sound.play_game(name)
    if not args.headless then
        audio.play_sound(get_game_sound(name))
    end
end

function sound.play_pack(pack, name)
    if not args.headless then
        local game_sound = get_game_sound(name)
        if game_sound then
            audio.play_sound(game_sound)
        else
            local pack_id, actual_name = name:match("(.*)_(.*)")
            if pack_id ~= pack.info.id then
                play_external_pack_sound(pack.info.game_version, pack_id, actual_name)
            elseif pack.sounds[actual_name] then
                audio.play_sound(pack.sounds[actual_name])
            else
                log("Sound not found:", name)
            end
        end
    end
end

function sound.init()
    return assets.index.request("game_sounds", "compat.all_game_sounds")
end

return sound
