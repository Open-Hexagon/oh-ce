local player_tracker = {}

local channel = love.thread.getChannel("players")
local client_map = {}

function player_tracker.add(client_data, name, steam_id)
    client_map[client_data] = name
    channel:performAtomic(function()
        local players = channel:pop() or {}
        players[name] = steam_id
        channel:push(players)
    end)
end

function player_tracker.get()
    return channel:peek() or {}
end

function player_tracker.remove(client_data)
    local name = client_map[client_data]
    if name ~= nil then
        channel:performAtomic(function()
            local players = channel:pop() or {}
            players[name] = nil
            channel:push(players)
        end)
        client_map[client_data] = nil
    end
end

return player_tracker
