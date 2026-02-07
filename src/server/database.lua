local log = require("log")(...)
local db = {}
local thread
local calling_thread

function db.init()
    thread = love.thread.newThread("server/database_thread.lua")
    thread:start("server.database_thread", true)
end

function db.set_identity(thread_id)
    calling_thread = thread_id
end

function db.execute(cmd)
    love.thread.getChannel("db_cmd"):push({ calling_thread, unpack(cmd) })
    local result = love.thread.getChannel("db_out" .. calling_thread):demand()
    if result[1] == "error" then
        error("Error while calling 'database." .. cmd[1] .. "':\n" .. result[2])
    end
    return unpack(result)
end

function db.stop()
    if thread:isRunning() then
        love.thread.getChannel("db_cmd"):push({ calling_thread, "stop" })
        thread:wait()
    else
        log("error in db thread:\n", thread:getError())
    end
end

return setmetatable(db, {
    __index = function(_, key)
        return function(...)
            return db.execute({ key, ... })
        end
    end,
})
