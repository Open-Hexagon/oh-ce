local ltdiff = require("extlibs.ltdiff")
local log = require("log")(...)

local mirror_server = {}

-- keep track of assets which need to have notifications sent once loading stack is empty
---@type table<Asset, boolean>
local pending_assets = {}
---@type table<Asset, ThreadId>
local target_thread_overwrite = {}

---schedule a sync of an asset, it is possible to sync to a specific thread
---@param asset Asset
---@param target_thread ThreadId?
function mirror_server.schedule_sync(asset, target_thread)
    -- use as map to prevent double entry
    pending_assets[asset] = true
    target_thread_overwrite[asset] = target_thread
end

---@alias MirrorNotification [MirrorKey, unknown]

---sends a notification to asset mirrors
---@param asset Asset
---@return table<love.Channel, integer>
local function send_notification(asset)
    local can_diff = true

    -- get map of target threads
    local targets = asset.mirror_targets
    if target_thread_overwrite[asset] then
        targets = { [target_thread_overwrite[asset]] = true }
    end

    -- count targets and check if there is a new target
    local target_count = 0
    asset.last_mirror_targets = asset.last_mirror_targets or {}
    for thread, should_mirror in pairs(targets) do
        if should_mirror then
            target_count = target_count + 1
        end
        if asset.last_mirror_targets[thread] ~= should_mirror then
            asset.last_mirror_targets[thread] = should_mirror
            can_diff = false -- sending for the first time
        end
    end
    -- if we sent a non-diff value to a thread that already has the value, it would try to interpret the value as diff
    assert(can_diff or target_count == 1, "initial sync has to be triggered by request")

    ---@type MirrorNotification
    local notification = { asset.key, asset.value }

    -- send a table diff instead of whole table when last mirrored value is a table
    local send_diff = type(asset.last_mirrored_value) == "table" and type(asset.value) == "table" and can_diff
    local copied_value
    if send_diff then
        notification[2] = ltdiff.diff(asset.last_mirrored_value, asset.value)
    end
    local wait_for = {}
    for thread, should_mirror in pairs(targets) do
        if should_mirror then
            local channel = love.thread.getChannel("asset_index_updates_" .. thread)
            if not send_diff and copied_value == nil then
                -- need to make a copy, so performAtomic is required to get copy before client pops
                channel:performAtomic(function()
                    wait_for[channel] = channel:push(notification)
                    copied_value = channel:peek()[2]
                end)
            else
                wait_for[channel] = channel:push(notification)
            end
        end
    end
    if send_diff then
        -- apply sent table diff to prevent having to send whole value for copying again
        ltdiff.patch(asset.last_mirrored_value, notification[2])
    else
        -- copy the value sent to the channel
        asset.last_mirrored_value = copied_value
    end
    return wait_for
end

---syncs all pending assets to all registered mirror clients
function mirror_server.sync_pending_assets()
    for asset in pairs(pending_assets) do
        local wait_for = send_notification(asset)

        -- wait until mirrors processed the notification
        local timer = 0
        repeat
            local done = true
            for channel, id in pairs(wait_for) do
                done = done and channel:hasRead(id)
            end
            if not done then
                love.timer.sleep(0.01)
                timer = timer + 0.01
                if timer > 1 then
                    log(string.format("Asset %s is taking an unusual amount of time being mirrored", asset.key))
                    timer = 0
                end
            end
        until done

        -- mark assets as no longer pending
        pending_assets[asset] = nil
        target_thread_overwrite[asset] = nil
    end
end

return mirror_server
