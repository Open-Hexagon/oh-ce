-- Enables calling functions by sending messages via channels

local channel_cb = {}
local functions = {}

---Register a channel
---@param channel_name string Channel name
---@param fn fun(msg: any) Callback function. Can only accept 1 argument. Return values are ignored.
function channel_cb.register(channel_name, fn)
    functions[channel_name] = fn
end

---Unregister a channel
---@param channel_name string Channel name
function channel_cb.unregister(channel_name)
    -- clear the channel so it can be freed by the gc
    -- TODO: this doesn't prevent other threads from continuing to send messages
    love.thread.getChannel(channel_name):clear()
    functions[channel_name] = nil
end

function channel_cb.update()
    for channel_name, fn in pairs(functions) do
        local msg = love.thread.getChannel(channel_name):pop()
        if msg then
            fn(msg)
        end
    end
end

return channel_cb
