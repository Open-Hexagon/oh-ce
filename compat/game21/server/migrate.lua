local msgpack = require("extlibs.msgpack.msgpack")
local database = require("server.database_thread")
local utils = require("compat.game192.utils")
local sqlite = require("extlibs.sqlite")
local game_handler = require("game_handler")
local config = require("config")
local async = require("async")

async.busy_await(game_handler.init(config))
local packs = game_handler.get_packs()
local level_validator_to_id = {}
for j = 1, #packs do
    local pack = packs[j]
    if pack.game_version == 21 then
        for k = 1, pack.level_count do
            local level = pack.levels[k]
            for i = 1, #level.options.difficulty_mult do
                local validator = pack.id .. "_" .. level.id .. "_m_" .. level.options.difficulty_mult[i]
                level_validator_to_id[validator] = {
                    pack = pack.id,
                    level = level.id,
                    difficulty_mult = level.options.difficulty_mult[i],
                }
            end
        end
    end
end

return function(old_db_path)
    local old_database = sqlite({
        uri = old_db_path,
    })
    database.open()
    old_database:open()
    local users = old_database:eval("SELECT cast(steamId as text), name, hex(passwordHash) FROM users")
    for i = 1, #users do
        local user = users[i]
        local hash = love.data.decode("string", "hex", user["hex(passwordHash)"])
        if not database.user_exists_by_steam_id(user["cast(steamId as text)"]) then
            database.register(user.name, user["cast(steamId as text)"], hash)
        end
    end
    local scores = old_database:eval("SELECT cast(userSteamId as text), levelValidator, value, timestamp FROM scores")
    for i = 1, #scores do
        local score = scores[i]
        local actual_level = level_validator_to_id[score.levelValidator]
        if
            actual_level == nil
            or actual_level.pack == nil
            or actual_level.level == nil
            or actual_level.difficulty_mult == nil
        then
            print("Missing '" .. score.levelValidator .. "' for migration")
        else
            print(
                actual_level.pack,
                actual_level.level,
                actual_level.difficulty_mult,
                score.value,
                score["cast(userSteamId as text)"],
                score.timestamp
            )
            local opts = { difficulty_mult = utils.float_round(actual_level.difficulty_mult) }
            database.save_score(
                score.value,
                score["cast(userSteamId as text)"],
                actual_level.pack,
                actual_level.level,
                msgpack.pack(opts),
                score.value,
                nil,
                score.timestamp
            )
        end
    end
    old_database:close()
    database.close()
end
