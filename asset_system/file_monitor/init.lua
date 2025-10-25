local log = require("log")(...)

-- sorted by priority
local implementations = {
    "asset_system.file_monitor.luv_watcher",
    "asset_system.file_monitor.poll_watcher",
}
log("Checking hot reloading backends...")
local impl
for i = 1, #implementations do
    impl = require(implementations[i])
    if impl then
        log(("'%s' is available."):format(implementations[i]))
        break
    else
        log(("'%s' is not available. Checking other backends..."):format(implementations[i]))
    end
end
local threadify = require("threadify")
local index = threadify.require("asset_system.index")

local watcher = {}

function watcher._threadify_update_loop()
    threadify.update()
end

local watching = false
local path_filter = nil
---@type string[]
local filtered_list = {}
---@type string[]
local file_list = {}

---start watching files while optionally filtering for the beginning of the path
---@param filter string?
function watcher.start(filter)
    log("Start.")
    if filter then
        log("Filter:", filter)
    end
    path_filter = filter
    if filter then
        filtered_list = {}
        for i = 1, #file_list do
            local name = file_list[i]
            if name:find(filter) == 1 then
                filtered_list[#filtered_list + 1] = name
            end
        end
    else
        filtered_list = file_list
    end
    watching = true
    ---@type string[]
    local paths = {}
    while watching do
        local co = coroutine.wrap(impl)
        local i = 0
        repeat
            i = i + 1
            paths[i] = co(filtered_list)
        until not paths[i]
        if i > 1 then
            log("Files changed: " .. table.concat(paths, ", ", 1, i - 1))
            index.changed(unpack(paths, 1, i - 1))
        end
        -- has to be non-blocking so new files can be added while watching
        coroutine.yield()
    end
end

---stop watching
function watcher.stop()
    log("Stop.")
    watching = false
end

---add a file to watch
---@param path string
function watcher.add(path)
    file_list[#file_list + 1] = path
    if path_filter and path:find(path_filter) == 1 then
        filtered_list[#filtered_list + 1] = path
    end
end

local function remove(t, e)
    for i = 1, #t do
        if t[i] == e then
            table.remove(t, i)
            return
        end
    end
end

---remove a file from watcher
---@param path string
function watcher.remove(path)
    remove(file_list, path)
    if path_filter and path:find(path_filter) == 1 then
        remove(filtered_list, path)
    end
end

return watcher
