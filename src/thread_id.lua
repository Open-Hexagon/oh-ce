---Get a unique id for this thread using a counter from a channel
---The main thread is always number 1.

---@alias ThreadId integer

---@type ThreadId
local thread_id = love.thread.getChannel("thread_ids"):performAtomic(function(channel)
    local counter = (channel:pop() or 0) + 1
    channel:push(counter)
    return counter
end)

return thread_id
