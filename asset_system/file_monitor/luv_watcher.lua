local log = require("log")(...)
local uv = require("luv")

local event_handles = {}
local stopped = {}
local save_dir = love.filesystem.getSaveDirectory()

---watch files (called on loop), calls yields path on file changes
---@param file_list table
return function(file_list)
    for i = 1, #file_list do
        local path = file_list[i]
        local is_first_time = event_handles[path] == nil
        event_handles[path] = event_handles[path] or uv.new_fs_event()
        -- the file path of a handle is nil if it has been stopped or not started yet
        if event_handles[path]:getpath() == nil then
            -- add save directory to path as luv uses native ones
            local prefix = love.filesystem.getRealDirectory(path) == save_dir and save_dir .. "/" or ""
            event_handles[path]:start(prefix .. path, {}, function(err, filename)
                if err then
                    -- I have never seen that happen, so not sure what could go wrong here
                    log("Error watching", filename, err)
                end
                -- since some editors move the file when saving (idk why)
                -- the handle has to be recreated every time in case the inode of the file changed
                -- (not sure about backends other than inotify)
                event_handles[path]:stop()
                stopped[path] = true
            end)
            if not is_first_time and event_handles[path]:getpath() ~= nil or stopped[path] then
                -- started handle successfully for not the first time
                -- didn't start but stopped in the callback earlier (required for deleting files)
                coroutine.yield(path)
                stopped[path] = false
            end
        end
    end
    uv.sleep(100)
    uv.run("nowait")
end
