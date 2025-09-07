local ltdiff = require("extlibs.ltdiff")
local log = require("log")(...)

local mirror_server = {}

-- required to know how many acks to wait for when sending notifications for mirroring
local mirror_count = 0

---register a mirror (to wait for when sending notifications) returns currently loaded assets
---@param mirrored_assets table<MirrorKey, Asset>
---@return table<MirrorKey, unknown>
---@nodiscard
function mirror_server.register_mirror(mirrored_assets)
    mirror_count = mirror_count + 1
    local new_mirror = {}
    for key, asset in pairs(mirrored_assets) do
        if asset.value then
            new_mirror[key] = asset.value
        end
    end
    return new_mirror
end

---unregister a mirror so the asset thread doesn't wait for it to confirm notifications
---the mirror still has to confirm notifications until the promise is fulfilled (otherwise the asset thread may get stuck)
function mirror_server.unregister_mirror()
    mirror_count = mirror_count - 1
end

-- channels to communicate with mirrors
local update_channel = love.thread.getChannel("asset_index_updates")
local update_ack_channel = love.thread.getChannel("asset_index_update_acks")

-- keep track of assets which need to have notifications sent once loading stack is empty
---@type table<Asset, boolean>
local pending_assets = {}
local notification_id_offset = 0

function mirror_server.schedule_sync(asset)
    -- use as map to prevent double entry
    pending_assets[asset] = true
end

---@alias MirrorNotification [integer, MirrorKey, unknown]

local function send_notification(id, asset)
    ---@type MirrorNotification
    local notification = { id, asset.key, asset.value }
    -- send a table diff instead of whole table when last mirrored value is a table
    local send_diff = type(asset.last_mirrored_value) == "table" and type(asset.value) == "table"
    if send_diff then
        notification[3] = ltdiff.diff(asset.last_mirrored_value, asset.value)
    end
    update_channel:push(notification)
    if send_diff then
        -- apply sent table diff to prevent having to send whole value for copying again
        ltdiff.patch(asset.last_mirrored_value, notification[3])
    else
        -- copy the value sent to the channel
        asset.last_mirrored_value = update_channel:peek()[3]
    end
end

---syncs all pending assets to all registered mirror clients
function mirror_server.sync_pending_assets()
    local notification_count = 0
    for asset in pairs(pending_assets) do
        notification_count = notification_count + 1
        local id = notification_count + notification_id_offset
        send_notification(id, asset)
        local acked = 0
        local timer = 0
        while acked < mirror_count do
            local ack_id = update_ack_channel:peek()
            if ack_id and ack_id == id then
                update_ack_channel:pop()
                acked = acked + 1
            end
            love.timer.sleep(0.01)
            timer = timer + 0.01
            if timer > 1 then
                log(string.format("Asset %s is taking an unusual amount of time being mirrored", asset.key))
                timer = 0
            end
        end
        update_channel:pop()
        pending_assets[asset] = nil
    end
    -- prevent sending the same id twice in succession
    if notification_count > 0 then
        notification_id_offset = notification_count + notification_id_offset > 1 and 0 or 1
    end
end

return mirror_server
