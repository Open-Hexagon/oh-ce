local log = require("log")(...)
local async = require("async")
local args = require("args")
local threadify = require("threadify")
local channel_callbacks = require("channel_callbacks")
local audio = require("audio")
local assets = require("asset_system")

local function add_require_path(path)
    love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. ";" .. path)
end

local function add_c_require_path(path)
    love.filesystem.setCRequirePath(love.filesystem.getCRequirePath() .. ";" .. path)
end

local render_replay = async(function(game_handler, replay, out_file, final_score)
    local video_encoder = require("game_handler.video")
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
        love.event.pump()
        for name, a in love.event.poll() do
            if name == "quit" then
                log("Aborting video rendering.")
                video_encoder.stop()
                return a or 0
            end
        end
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
        require("server")
        return function()
            return 0
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
        async.busy_await(game_handler.init(), true)
        local Replay = require("game_handler.replay")
        return function()
            local replay_file = love.thread.getChannel("replays_to_render"):demand(10)

            -- exit if another thread has an error
            love.event.pump()
            for name, _, b in love.event.poll() do
                if name == "threaderror" then
                    log("Error in thread: " .. b, 10)
                    return 0
                end
            end

            -- no replay, continue
            if not replay_file then
                return
            end

            -- replay may no longer exist if player got new pb
            if love.filesystem.getInfo(replay_file) then
                local replay = Replay:new(replay_file)
                local out_file_path = love.filesystem.getSaveDirectory() .. "/" .. replay_file .. ".part.mp4"
                log("Got new #1 on '" .. replay.level_id .. "' from '" .. replay.pack_id .. "', rendering...")
                local fn = async.busy_await(render_replay(game_handler, replay, out_file_path, replay.score), true)
                local aborted = false
                while fn() ~= 0 do
                    local abort_hash = love.thread.getChannel("abort_replay_render"):pop()
                    if abort_hash and abort_hash == replay_file:match(".*/(.*)") then
                        aborted = true
                        require("game_handler.video").stop()
                        game_handler.stop()
                        break
                    end
                end
                if aborted then
                    log("aborted rendering.")
                    love.filesystem.remove(replay_file .. ".part.mp4")
                else
                    os.rename(out_file_path, out_file_path:gsub("%.part%.mp4", "%.mp4"))
                    log("done.")
                end
            end
        end
    end

    if args.headless then
        if args.replay_file == nil then
            error("Started headless mode without replay")
        end
        global_config.init()
        async.busy_await(game_handler.init(), true)
        async.busy_await(game_handler.replay_start(args.replay_file), true)
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
        async.busy_await(game_handler.init(), true)
        return async.busy_await(render_replay(game_handler, args.replay_file, "output.mp4"), true)
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
            async.busy_await(game_handler.replay_start(args.replay_file), true)
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

        -- process events
        love.event.pump()
        for name, a, b, c, d, e, f in love.event.poll() do
            if name == "quit" then
                config.save()
                return a or 0
            elseif name == "threaderror" then
                config.save()
                error("Error in thread: " .. b)
            end
            game_handler.process_event(name, a, b, c, d, e, f)
            ui.process_event(name, a, b, c, d, e, f)
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
    end
end
