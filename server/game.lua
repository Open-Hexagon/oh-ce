local log = require("log")(...)
local game = {}
local thread = love.thread.newThread("server/game_thread.lua")

-- this whole module is technically obsolete and could be replaced with
-- the asset system and threadify, but I have not gotten around to it

function game.init(render_top_scores)
    thread:start("server.game_thread", true)
    love.thread.getChannel("game_commands"):push({ "set_render_top_scores", render_top_scores })
end

function game.verify_replay_and_save_score(compressed_replay, time, steam_id)
    love.thread.getChannel("game_commands"):push({ "verify_replay", compressed_replay, time, steam_id })
end

function game.stop()
    if thread:isRunning() then
        love.thread.getChannel("game_commands"):push({ "stop" })
        thread:wait()
    else
        log("Got error in game thread:\n", thread:getError())
    end
end

return game
