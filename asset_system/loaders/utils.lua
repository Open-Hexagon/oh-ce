local utils = {}
local main_thread_tasks_cmd = love.thread.getChannel("asset_loading_main_thread_tasks_cmd")
local main_thread_tasks_out = love.thread.getChannel("asset_loading_main_thread_tasks_out")

---run a task on the main thread
---@param code string
---@param ... unknown
---@return unknown
function utils.run_on_main(code, ...)
    main_thread_tasks_cmd:supply({ code, ... })
    return unpack(main_thread_tasks_out:demand())
end

return utils
