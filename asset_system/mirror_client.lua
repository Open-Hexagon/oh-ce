local ltdiff = require("extlibs.ltdiff")
local threadify = require("threadify")

local client = {}

local update_channel = love.thread.getChannel("asset_index_updates_" .. threadify.thread_id)

---@type table<MirrorKey, unknown>
client.mirror = {}

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
    local msg = update_channel:pop()
    if msg then
        local key, data = unpack(msg)
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
