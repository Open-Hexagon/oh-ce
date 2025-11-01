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
local failed_replay_path = "server/failed_replays/"
love.filesystem.createDirectory(failed_replay_path)

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

function api.verify_replay(compressed_replay, time, steam_id, test_id)
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
        if test_id then
            love.thread.getChannel("verification_results_" .. test_id):push(false)
        end
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
    local time_string = "compare score: "
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
    log("Finished running replay on", decoded_replay.pack_id, decoded_replay.level_id)
    log("Times: " .. time_string)
    local verified = false
    if
        compare_score + score_tolerance > decoded_replay.score
        and compare_score - score_tolerance < decoded_replay.score
    then
        if time + time_tolerance > timed_score and time - time_tolerance < timed_score then
            verified = true
            if not test_id then
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
            end
        else
            log("time between packets of " .. time .. " does not match score of " .. timed_score)
        end
    else
        log("The replay's score of " .. decoded_replay.score .. " does not match the actual score of " .. compare_score)
    end
    if test_id then
        love.thread.getChannel("verification_results_" .. test_id):push(verified)
    elseif not verified then
        log("Saving failed replay with real time.")
        time_string = time_string:gsub(" ", "_"):gsub(":", "") -- remove special characters
        decoded_replay:save(failed_replay_path .. love.timer.getTime() .. "_steam_" .. steam_id .. "_" .. time_string)
    end
end

function api.set_render_top_scores(bool)
    render_top_scores = bool
end

local status_channel = love.thread.getChannel("game_thread_running")

local function set_status(running)
    status_channel:performAtomic(function()
        status_channel:clear()
        status_channel:push(running)
    end)
end

local run = true
local channel = love.thread.getChannel("game_commands")
while run do
    local cmd = channel:demand(1)
    assets.mirror_client.update()
    if cmd then
        log("processing game command.", channel:getCount(), "left.")
        if cmd[1] == "stop" then
            run = false
        else
            set_status(true)
            xpcall(function()
                local fn = api[cmd[1]]
                table.remove(cmd, 1)
                fn(unpack(cmd))
            end, function(err)
                log("Error while verifying replay:\n", err)
                local test_id = cmd[4]
                if test_id then
                    love.thread.getChannel("verification_results_" .. test_id):push(false)
                end
            end)
            set_status(false)
        end
        log("done.")
    end
end
log("quitting")
