local channel_cb = {}
local functions = {}

function channel_cb.register(channel_name, fn)
    functions[channel_name] = fn
end

function channel_cb.unregister(channel_name)
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
