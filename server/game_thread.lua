require("platform")
local log = require("log")(...)
local msgpack = require("extlibs.msgpack.msgpack")
local replay = require("game_handler.replay")
local game_handler = require("game_handler")
local assets = require("asset_system")
local async = require("async")
require("love.timer")

async.busy_await(game_handler.init())

local database, replay_path
database = require("server.database")
database.set_identity(1)
replay_path = database.get_replay_path()

local api = {}

local time_tolerance = 3
local score_tolerance = 0.2
local render_top_scores = false

local function get_replay_save_path(hash)
    local dir = replay_path .. hash:sub(1, 2) .. "/"
    if not love.filesystem.getInfo(dir) then
        love.filesystem.createDirectory(dir)
    end
    local n
    local path = dir .. hash
    -- in case a replay actually has a duplicate hash (which is almost impossible) add some random numbers to it
    if love.filesystem.getInfo(path) then
        path = path .. 0
        n = 0
        while love.filesystem.getInfo(path) do
            n = n + 1
            path = path:sub(1, -2) .. n
        end
        hash = hash .. n
    end
    return path, hash
end

function api.verify_replay(compressed_replay, time, steam_id)
    local start = love.timer.getTime()
    local decoded_replay = replay:new_from_data(compressed_replay)
    local around_time = 0
    local last_around_time = 0
    local replay_was_done = false
    local replay_end_compare_score, replay_end_timed_score, exceeded_max_processing_time
    async.busy_await(game_handler.replay_start(decoded_replay))
    game_handler.run_until_death(function()
        local now = love.timer.getTime()
        around_time = math.floor((now - start) % 10)
        if math.abs(around_time - last_around_time) > 2 then
            -- print progress every 10s
            log(
                "Verifying replay of '"
                    .. decoded_replay.level_id
                    .. "' progress: "
                    .. (100 * game_handler.get_score() / decoded_replay.score)
                    .. "%"
            )
        end
        last_around_time = around_time
        if game_handler.is_replay_done() then
            if not replay_was_done then
                replay_was_done = true
                local score, is_custom_score = game_handler.get_score()
                replay_end_timed_score = game_handler.get_timed_score()
                replay_end_compare_score = score
                if is_custom_score and decoded_replay.game_version == 21 then
                    replay_end_compare_score = game_handler.get_compat_custom_score()
                end
            end
            -- still check 60s in game time more after input data ended
            if game_handler.get_timed_score() - replay_end_timed_score > 60 then
                log("exceeded max processing time")
                exceeded_max_processing_time = true
                return true
            end
        end
        return false
    end)
    if exceeded_max_processing_time then
        log("no player death 60s after end of input data. discarding replay.")
        return
    end
    local score, is_custom_score = game_handler.get_score()
    local compare_score = replay_end_compare_score
    if not compare_score then
        compare_score = score
        if is_custom_score and decoded_replay.game_version == 21 then
            compare_score = game_handler.get_compat_custom_score()
        end
    end
    local timed_score = replay_end_timed_score or game_handler.get_timed_score()
    -- the old game divides custom scores by 60
    if is_custom_score and decoded_replay.game_version == 21 then
        decoded_replay.score = decoded_replay.score * 60
    end
    log(
        "Finished running replay. compare score: "
            .. compare_score
            .. " timed score: "
            .. timed_score
            .. "s replay score: "
            .. decoded_replay.score
            .. " save score: "
            .. score
            .. " real time: "
            .. time
            .. "s"
    )
    if
        compare_score + score_tolerance > decoded_replay.score
        and compare_score - score_tolerance < decoded_replay.score
    then
        if time + time_tolerance > timed_score and time - time_tolerance < timed_score then
            log("replay verified, score: " .. score)
            local hash, data = decoded_replay:get_hash()
            local packed_level_settings = msgpack.pack(decoded_replay.data.level_settings)
            local replay_save_path, replay_hash = get_replay_save_path(hash)
            if
                database.save_score(
                    time,
                    steam_id,
                    decoded_replay.pack_id,
                    decoded_replay.level_id,
                    packed_level_settings,
                    score,
                    replay_hash
                )
            then
                decoded_replay:save(replay_save_path, data)
                log("Saved new score")
                local position = database.get_score_position(
                    decoded_replay.pack_id,
                    decoded_replay.level_id,
                    packed_level_settings,
                    steam_id
                )
                love.thread.getChannel("new_scores"):push({
                    position = position,
                    value = score,
                    replay_hash = replay_hash,
                    user_name = (database.get_user_by_steam_id(steam_id) or { username = "deleted user" }).username,
                    timestamp = os.time(),
                    level_options = decoded_replay.data.level_settings,
                    level = decoded_replay.level_id,
                    pack = decoded_replay.pack_id,
                })
                if render_top_scores and position == 1 then
                    local channel = love.thread.getChannel("replays_to_render")
                    channel:push(replay_save_path)
                    log(channel:getCount() .. " replays queued for rendering.")
                end
            end
        else
            log("time between packets of " .. time .. " does not match score of " .. timed_score)
        end
    else
        log("The replay's score of " .. decoded_replay.score .. " does not match the actual score of " .. compare_score)
    end
end

function api.get_levels21()
    local level_validators = {}
    local levels = {}
    local packs = game_handler.get_packs()
    for j = 1, #packs do
        local pack = packs[j]
        if pack.game_version == 21 then
            for k = 1, pack.level_count do
                local level = pack.levels[k]
                for i = 1, #level.options.difficulty_mult do
                    level_validators[#level_validators + 1] = pack.id
                        .. "_"
                        .. level.id
                        .. "_m_"
                        .. level.options.difficulty_mult[i]
                    levels[#levels + 1] = pack.id
                    levels[#levels + 1] = level.id
                    levels[#levels + 1] = level.options.difficulty_mult[i]
                end
            end
        end
    end
    love.thread.getChannel("ranked_levels"):push(level_validators)
    love.thread.getChannel("ranked_levels"):push(levels)
end

function api.set_render_top_scores(bool)
    render_top_scores = bool
end

local run = true
while run do
    local cmd = love.thread.getChannel("game_commands"):demand(1)
    -- TODO: this causes all asset loading to have up to 1s delay
    assets.mirror_client.update()
    if cmd then
        if cmd[1] == "stop" then
            run = false
        else
            xpcall(function()
                local fn = api[cmd[1]]
                table.remove(cmd, 1)
                fn(unpack(cmd))
            end, function(err)
                log("Error while verifying replay:\n", err)
            end)
        end
    end
end
