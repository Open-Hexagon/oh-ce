local log = require("log")(...)
local async = require("async")
local args = require("args")
local threadify = require("threadify")
local channel_callbacks = require("channel_callbacks")
local audio = require("audio")
local assets = require("asset_system")
local video_encoder = require("game_handler.video")
local player_tracker = require("server.player_tracker")

local function add_require_path(path)
    love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. ";" .. path)
end

local function add_c_require_path(path)
    love.filesystem.setCRequirePath(love.filesystem.getCRequirePath() .. ";" .. path)
end

local exit_channel = love.thread.getChannel("scheduled_exit")

local function server_exit()
    -- exit once nothing is happening if exit was scheduled
    local scheduled_exit = exit_channel:peek()
    if scheduled_exit then
        local exit = scheduled_exit
        if next(player_tracker.get()) ~= nil then
            exit = nil -- players are still online
        elseif love.thread.getChannel("game_thread_running"):peek() then
            exit = nil -- game thread is still processing a replay
        end
        if exit ~= nil then
            love.event.quit(exit)
        end
    end
end

local function event_loop(config, game_handler, ui)
    love.event.pump()
    for name, a, b, c, d, e, f in love.event.poll() do
        -- check exit conditions
        local exit
        if name == "quit" then
            exit = a or 0
        elseif name == "threaderror" then
            log("Error in thread: " .. b)
            exit = 1
        end

        -- cleanup and exit
        if exit then
            if video_encoder.running then
                video_encoder.stop()
            end
            if config then
                config.save()
            end
            return exit
        end

        -- pass events to other modules
        if game_handler then
            game_handler.process_event(name, a, b, c, d, e, f)
        end
        if ui then
            ui.process_event(name, a, b, c, d, e, f)
        end
    end
end

local render_replay = async(function(game_handler, replay, out_file, final_score)
    game_handler.set_game_dimensions(1920, 1080)
    local ui = require("ui")
    ui.open_screen("game")
    local fps = 60
    local ticks_to_frame = 0
    video_encoder.start(out_file, 1920, 1080, fps, audio.sample_rate)
    audio.set_encoder(video_encoder)
    local after_death_frames = 3 * fps
    async.await(game_handler.replay_start(replay))
    local frames = 0
    local last_print = love.timer.getTime()
    local canvas = love.graphics.newCanvas(1920, 1080, { msaa = 4 })
    return function()
        if final_score then
            local now = love.timer.getTime()
            if now - last_print > 10 then
                log("Rendering progress: " .. (100 * game_handler.get_timed_score() / final_score) .. "%")
                last_print = now
            end
        end
        if love.graphics.isActive() then
            frames = frames + 1
            ticks_to_frame = ticks_to_frame + game_handler.get_tickrate() / fps
            for _ = 1, ticks_to_frame do
                ticks_to_frame = ticks_to_frame - 1
                game_handler.update(false)
            end
            audio.update(1 / fps)
            love.timer.step()
            love.graphics.setCanvas(canvas)
            love.graphics.origin()
            love.graphics.clear(0, 0, 0, 1)
            game_handler.draw(1 / fps)
            ui.update(1 / fps)
            ui.draw()
            love.graphics.setCanvas()
            video_encoder.supply_video_data(canvas)
            if game_handler.is_dead() then
                after_death_frames = after_death_frames - 1
                if after_death_frames <= 0 then
                    video_encoder.stop()
                    game_handler.stop()
                    return 0
                end
            end
        end
        return event_loop()
    end
end)

function love.run()
    -- make sure no level accesses malicious files via symlinks
    love.filesystem.setSymlinksEnabled(false)

    -- find libs
    add_require_path("extlibs/?.lua")
    add_c_require_path("lib/??")

    if args.migrate then
        -- migrate a ranking database from the old game to the new format
        require("compat.game21.server.migrate")(args.migrate)
        return function()
            return 0
        end
    end

    -- mount pack folders
    for i = 1, #args.mount_pack_folder do
        local pack_folder = args.mount_pack_folder[i]
        local version = pack_folder[1]
        local path = pack_folder[2]
        log("mounting " .. path .. " to packs" .. version)
        love.filesystem.mountFullPath(path, "packs" .. version)
    end

    if args.server and not args.render then
        -- game21 compat server (made for old clients)
        local run = require("server")
        return function()
            run()
            assets.mirror_client.update()
            assets.run_main_thread_task()
            server_exit()
            return event_loop()
        end
    end

    local config = require("config")
    local global_config = require("global_config")
    local game_handler = require("game_handler")

    if args.server and args.render then
        -- render top scores sent to the server
        local server_thread = love.thread.newThread("server/init.lua")
        server_thread:start("server", true, args.web)
        global_config.init()
        async.busy_await(game_handler.init())
        local Replay = require("game_handler.replay")
        return function()
            local replay_file = love.thread.getChannel("replays_to_render"):demand(1)

            assets.mirror_client.update()
            assets.run_main_thread_task(true)

            if replay_file then
                -- replay may no longer exist if player got new pb
                if love.filesystem.getInfo(replay_file) then
                    local replay = Replay:new(replay_file)
                    local out_file_path = love.filesystem.getSaveDirectory() .. "/" .. replay_file .. ".part.mp4"
                    log("Got new #1 on '" .. replay.level_id .. "' from '" .. replay.pack_id .. "', rendering...")
                    local aborted = false
                    local success, error = pcall(function()
                        local fn = async.busy_await(render_replay(game_handler, replay, out_file_path, replay.score))
                        while fn() ~= 0 do
                            local abort_hash = love.thread.getChannel("abort_replay_render"):pop()
                            if abort_hash and abort_hash == replay_file:match(".*/(.*)") then
                                aborted = true
                                require("game_handler.video").stop()
                                game_handler.stop()
                                break
                            end
                        end
                    end)
                    if aborted or not success then
                        if error then
                            log("Got error:", error)
                        end
                        log("aborted rendering.")
                        love.filesystem.remove(replay_file .. ".part.mp4")
                    else
                        os.rename(out_file_path, out_file_path:gsub("%.part%.mp4", "%.mp4"))
                        log("done.")
                    end
                end
            end
            server_exit()
            return event_loop()
        end
    end

    if args.extract_working_replays then
        local database = require("server.database")
        local Replay = require("game_handler.replay")

        love.filesystem.createDirectory("server/working_replays")
        database.set_identity(0)
        database.init()
        local threads = {}
        local workers = 12
        for i = 1, workers do
            local thread = love.thread.newThread("server/game_thread.lua")
            thread:start("server.game_thread." .. i, true)
            threads[i] = thread
        end
        local worked = 0
        local pending = {}
        local replay_path = database.get_replay_path()
        local scores = database.get_all_scores()
        for i = 1, #scores do
            log(("checking %d / %d scores"):format(i, #scores))
            local score = scores[i]
            local hash = score.replay_hash
            if hash then
                if love.filesystem.exists("server/working_replays/" .. hash) then
                    log("skipping, replay already in working replays folder.")
                    worked = worked + 1
                else
                    local path = replay_path .. hash:sub(1, 2) .. "/" .. hash
                    if love.filesystem.exists(path) then
                        local replay = Replay:new(path)
                        love.thread
                            .getChannel("game_commands")
                            :push({ "verify_replay", replay:_get_compressed(), score.time, 0, i })
                        pending[#pending + 1] = i
                    end
                end
            end
            assets.run_main_thread_task()
        end
        local last_time = love.timer.getTime()
        return function()
            assets.run_main_thread_task()
            love.event.pump()
            for event, t, err in love.event.poll() do
                if event == "threaderror" then
                    error("Thread error (" .. tostring(t) .. ")\n\n" .. err, 0)
                end
            end
            local should_stop = #pending == 0
            if love.timer.getTime() - last_time > 60 then
                log("got nothing for a minute, aborting")
                should_stop = true
            else
                for j = #pending, 1, -1 do
                    local i = pending[j]
                    local result = love.thread.getChannel("verification_results_" .. i):peek()
                    if result ~= nil then
                        last_time = love.timer.getTime()
                        table.remove(pending, j)
                        log(("got result for %d, %d / %d to go."):format(i, #pending, #scores))
                        if result then
                            log("worked, copying...")
                            local hash = scores[i].replay_hash
                            local path = replay_path .. hash:sub(1, 2) .. "/" .. hash
                            Replay:new(path):save("server/working_replays/" .. hash)
                            worked = worked + 1
                        end
                    end
                end
            end
            love.timer.sleep(0.01)
            if should_stop then
                log(("Done verifying. %d / %d scores worked."):format(worked, #scores))
                for _ = 1, workers do
                    love.thread.getChannel("game_commands"):push({ "stop" })
                end
                love.timer.sleep(0.1)
                local is_running = false
                for i = 1, workers do
                    is_running = is_running or threads[i]:isRunning()
                end
                if is_running then
                    love.timer.sleep(10) -- give them a bit of time to exit
                    -- otherwise kill with force
                    for i = 1, workers do
                        threads[i]:release()
                    end
                end
                database.stop()
                return 0
            end
        end
    end

    if args.headless then
        if args.replay_file == nil then
            error("Started headless mode without replay")
        end
        global_config.init()
        async.busy_await(game_handler.init())
        async.busy_await(game_handler.replay_start(args.replay_file))
        game_handler.run_until_death()
        log("Score: " .. game_handler.get_score())
        return function()
            return 0
        end
    end

    if args.render then
        if args.replay_file == nil then
            error("trying to render replay without replay")
        end
        global_config.init()
        async.busy_await(game_handler.init())
        return async.busy_await(render_replay(game_handler, args.replay_file, "output.mp4"))
    end

    local ui = require("ui")
    ui.open_screen("loading")
    global_config.init()
    -- apply fullscreen setting initially
    config.get_definitions().fullscreen.onchange(config.get("fullscreen"))

    local fps_limit = config.get("fps_limit")
    local delta_target = 1 / fps_limit
    local last_time = love.timer.getTime()

    game_handler.init():done(function()
        if args.replay_file then
            async.busy_await(game_handler.replay_start(args.replay_file))
            ui.open_screen("game")
        else
            ui.open_screen("levelselect")
        end
    end)
    local level = require("ui.screens.levelselect.level")

    -- function is called every frame by love
    return function()
        local new_fps_limit = config.get("fps_limit")
        if fps_limit ~= new_fps_limit then
            fps_limit = new_fps_limit
            delta_target = 1 / fps_limit
        end
        if fps_limit ~= 0 then
            love.timer.sleep(delta_target - (love.timer.getTime() - last_time))
            last_time = last_time + delta_target
        end

        threadify.update()
        channel_callbacks.update()
        ui.update(love.timer.getDelta())
        audio.update()
        assets.run_main_thread_task()
        assets.mirror_client.update()

        -- ensures tickrate on its own
        game_handler.update(true)

        if love.graphics.isActive() then
            -- reset any transformations and make the screen black
            love.graphics.origin()
            love.graphics.clear(0, 0, 0, 1)
            game_handler.draw()
            if level.current_preview_active and not game_handler.is_running() then
                level.current_preview:draw(true)
            end
            ui.draw()
            love.graphics.present()
        end
        love.timer.step()
        return event_loop(config, game_handler, ui)
    end
end
