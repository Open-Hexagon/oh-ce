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
---@type table<MirrorKey|table, table<MirrorCallback, number>>
local asset_callbacks = {}

---call the callbacks for an asset
---@param key MirrorKey|table
---@param value unknown
local function call_calbacks(key, value)
    local call_count_map = asset_callbacks[key]
    if call_count_map then
        local calls = {}
        for callback, available_calls in pairs(call_count_map) do
            if available_calls > 0 then
                call_count_map[callback] = available_calls - 1
                calls[#calls + 1] = callback
            end
        end
        -- defer the actual calls because some may call listen in the callback which would
        -- cause the call_count_map to be edited while iteration is ongoing
        for i = 1, #calls do
            calls[i](value)
        end
    end
end

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
                    call_calbacks(t, t)
                end)
            else
                client.mirror[key] = data
            end
            call_calbacks(key, client.mirror[key])
        end
    end
end

---get a function to set the amount of times a callback can be called
---@param number integer
---@return fun(key: MirrorKey|table, callback: MirrorCallback)
local function get_listen_count_setter(number)
    return function(key, callback)
        asset_callbacks[key] = asset_callbacks[key] or {}
        asset_callbacks[key][callback] = number
    end
end

---listen to one asset change, the callback is turned off afterwards
---call listen again in the callback to keep the listener
---it is possible to have multiple callbacks per asset
client.listen_once = get_listen_count_setter(1)

---permanently listen to changes of an asset
client.listen = get_listen_count_setter(math.huge)

---disable a registered listener
client.disable_listener = get_listen_count_setter(0)

---@type table<MirrorCallback, MirrorKey|table>
local callback_asset_map = {}

---register an asset to call a listener on changes, calling this again with a different asset (or nil) will overwrite the previous assignement
---@param callback MirrorCallback
---@param key MirrorKey|table|nil
function client.assign_asset_to_listener(callback, key)
    if callback_asset_map[callback] ~= key then
        callback_asset_map[callback] = key
        if key then
            local function wrapped_callback(value)
                callback(value)
                if callback_asset_map[callback] then
                    client.listen_once(callback_asset_map[callback], wrapped_callback)
                end
            end
            client.listen_once(key, wrapped_callback)
        end
    end
end

return client
