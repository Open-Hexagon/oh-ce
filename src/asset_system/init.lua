local threadify = require("threadify")
local index = threadify.require("asset_system.index")
local mirror_client = require("asset_system.mirror_client")
local watcher = threadify.require("asset_system.file_monitor", true)

local asset_system = {
    mirror_client = mirror_client,
    mirror = mirror_client.mirror,
    index = index,
    is_hot_reloading = false,
}

local main_thread_tasks_cmd = love.thread.getChannel("asset_loading_main_thread_tasks_cmd")
local main_thread_tasks_out = love.thread.getChannel("asset_loading_main_thread_tasks_out")

---runs functions that only work on the main thread on behalf of the asset loaders
---(usually runs only 1 task at a time to not slow down main thread too much, if all is set to true it will always run all available tasks)
---@param all boolean?
function asset_system.run_main_thread_task(all)
    repeat
        local task = main_thread_tasks_cmd:demand(all and 0.1 or 0)
        if task then
            local ret = { loadstring(task[1])(unpack(task, 2)) }
            main_thread_tasks_out:supply(ret, all and 0.1 or 0)
        end
    until task == nil or not all
end

---automatically call index.reload on the correct assets based on file changes
---(note that in case luv is not available this will fall back to polling)
---the filter can specify a starting path under which all files are monitored
---without one all files that were used are monitored, which with polling could be quite inefficient
---@param filter string?
function asset_system.start_hot_reloading(filter)
    watcher.start(filter)
    asset_system.is_hot_reloading = true
end

---don't automatically call index.reload on the correct assets based on file changes
function asset_system.stop_hot_reloading()
    asset_system.is_hot_reloading = false
    watcher.stop()
end

return asset_system
