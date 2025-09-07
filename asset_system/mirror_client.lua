local ltdiff = require("extlibs.ltdiff")
local threadify = require("threadify")
local async = require("async")
local index = threadify.require("asset_system.index")
require("love.timer")

local client = {}

local update_channel = love.thread.getChannel("asset_index_updates")
local update_ack_channel = love.thread.getChannel("asset_index_update_acks")

-- thanks to require caching modules this will only be called once per thread
-- in case the mirror was created after some assets are already
-- loaded the promise results in the initial mirror state
---@type table<MirrorKey, unknown>
client.mirror = async.busy_await(index.register_mirror())

local last_id
---@alias MirrorCallback fun(value: unknown)
---@type table<MirrorKey|table, MirrorCallback>
local asset_callbacks = {}

---updates the contents of the mirror using the asset notifications
function client.update()
    ---@type MirrorNotification?
    local notification = update_channel:peek()
    if notification then
        local id = notification[1]
        -- notifications are only removed from the channel once all mirrors
        -- acked them, so only process it again once the id changes
        if id ~= last_id then
            update_ack_channel:push(id)
            last_id = id
            local key = notification[2]
            local data = notification[3]
            -- if currently mirrored value is a table and new value is one, assume it's a diff
            if type(client.mirror[key]) == "table" and type(data) == "table" then
                ltdiff.patch(client.mirror[key], data, function(t)
                    if asset_callbacks[t] then
                        asset_callbacks[t](t)
                    end
                end)
            else
                client.mirror[key] = data
            end
            if asset_callbacks[key] then
                asset_callbacks[key](client.mirror[key])
            end
        end
    end
end

---listen to asset changes, to unregister listener set callback to nil
---@param key MirrorKey|table
---@param callback MirrorCallback?
function client.listen(key, callback)
    asset_callbacks[key] = callback
end

return client
