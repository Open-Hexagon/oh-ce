require("platform")
local log = require("log")("threadify")
local modname, is_thread = ...

if is_thread then
    local send_responses = not select(3, ...)
    local api = require(modname)
    local in_channel = love.thread.getChannel(modname .. "_cmd")
    local out_channel = love.thread.getChannel(modname .. "_out")
    local run = true
    local running_coroutines = {}
    local function run_coroutine(co, call_id, cmd)
        local success, ret = coroutine.resume(co, unpack(cmd or {}, 3))
        if not success then
            ret = (ret or "") .. "\n" .. debug.traceback(co)
        end
        local is_dead = coroutine.status(co) == "dead"
        if is_dead then
            if send_responses then
                out_channel:push({ call_id, success, ret })
            end
            if not success then
                if cmd then
                    log(("Error calling '%s.%s' with:"):format(modname, cmd[2]), unpack(cmd, 3))
                else
                    log(("Error resuming coroutine in %s"):format(modname))
                end
                log(debug.traceback(co, ret))
            end
        end
        return is_dead
    end
    local update_fun, updater_count = require("update_functions")()
    while run do
        local cmd
        if #running_coroutines > 0 or updater_count > 0 then
            cmd = in_channel:demand(0.01)
            update_fun()
        else
            cmd = in_channel:demand()
        end
        if cmd then
            local call_id = cmd[1]
            local fn = api[cmd[2]]
            if type(fn) == "function" then
                local co = coroutine.create(fn)
                if not run_coroutine(co, call_id, cmd) then
                    running_coroutines[#running_coroutines + 1] = { call_id, co }
                end
            elseif send_responses then
                out_channel:push({ call_id, false, "'" .. modname .. "." .. cmd[2] .. "' is not a function" })
            end
        else
            for i = #running_coroutines, 1, -1 do
                local call_id, co = unpack(running_coroutines[i])
                if run_coroutine(co, call_id) then
                    table.remove(running_coroutines, i)
                end
            end
        end
    end
else
    local async = require("async")
    local threads = {}
    local thread_names = {}
    local threadify = {}
    local threads_channel = love.thread.getChannel("threads")

    ---run a module in a different thread but allow calling its functions from here
    ---@param require_string string
    ---@param no_responses boolean?
    ---@return table<string, fun(...): promise>
    function threadify.require(require_string, no_responses)
        if not threads[require_string] then
            local thread_table = {
                resolvers = {},
                rejecters = {},
            }
            threads_channel:performAtomic(function(channel)
                local all_threads = channel:pop() or {}
                if all_threads and all_threads[require_string] then
                    thread_table.thread = all_threads[require_string]
                else
                    thread_table.thread = love.thread.newThread("threadify.lua")
                end
                if not thread_table.thread:isRunning() then
                    thread_table.thread:start(require_string, true, no_responses)
                end
                all_threads[require_string] = thread_table.thread
                channel:push(all_threads)
            end)
            thread_names[#thread_names + 1] = require_string
            threads[require_string] = thread_table
        end
        local thread = threads[require_string]
        local interface = {}
        local id_channel = love.thread.getChannel(require_string .. "_ids")
        local cmd_channel = love.thread.getChannel(require_string .. "_cmd")
        return setmetatable(interface, {
            __index = function(_, key)
                return function(...)
                    local msg = { -1, key, ... }
                    if no_responses then
                        cmd_channel:push(msg)
                        return
                    end
                    return async.promise:new(function(resolve, reject)
                        -- get a request id with no duplicates across any other threads
                        local request_id = 1
                        id_channel:performAtomic(function(channel)
                            local used_ids = channel:pop() or {}
                            request_id = (used_ids.count or 0) + 1
                            while used_ids[request_id] do
                                request_id = request_id + 1
                            end
                            used_ids[request_id] = true
                            used_ids.count = (used_ids.count or 0) + 1
                            channel:push(used_ids)
                        end)
                        msg[1] = request_id
                        thread.resolvers[request_id] = resolve
                        thread.rejecters[request_id] = reject
                        cmd_channel:push(msg)
                    end)
                end
            end,
        })
    end

    ---update threaded modules
    function threadify.update()
        for i = 1, #thread_names do
            local require_string = thread_names[i]
            local thread = threads[require_string]
            local out_channel = love.thread.getChannel(require_string .. "_out")
            local result
            local check_result = out_channel:peek()
            if check_result then
                if thread.resolvers[check_result[1]] and thread.rejecters[check_result[1]] then
                    result = out_channel:pop()
                end
            end
            if result then
                if result[2] then
                    thread.resolvers[result[1]](unpack(result, 3))
                else
                    log(result[3])
                    thread.rejecters[result[1]]()
                end
                thread.resolvers[result[1]] = nil
                thread.rejecters[result[1]] = nil
                -- remove id from used id table for this thread
                local id_channel = love.thread.getChannel(require_string .. "_ids")
                id_channel:performAtomic(function(channel)
                    local used_ids = channel:pop()
                    if used_ids then
                        used_ids[result[1]] = nil
                        used_ids.count = used_ids.count - 1
                        channel:push(used_ids)
                    end
                end)
            end
        end
    end

    return threadify
end
