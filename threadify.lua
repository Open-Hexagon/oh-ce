require("platform")
local log = require("log")("threadify")
local modname, is_thread = ...

if is_thread then
    local send_responses = not select(3, ...)
    local api = require(modname)

    local in_channel = love.thread.getChannel(modname .. "_cmd")
    -- make a different out channel for each thread that sends a request
    local out_channels = setmetatable({}, {
        __index = function(t, thread_id)
            t[thread_id] = love.thread.getChannel(("%s_%d_out"):format(modname, thread_id))
            return t[thread_id]
        end,
    })

    local function run_coroutine(co, thread_id, call_id, cmd)
        local success, ret = coroutine.resume(co, unpack(cmd or {}, 4))
        if not success then
            ret = (ret or "") .. "\n" .. debug.traceback(co)
        end
        local is_dead = coroutine.status(co) == "dead"
        if is_dead then
            if send_responses then
                out_channels[thread_id]:push({ call_id, success, ret })
            end
            if not success then
                if cmd then
                    log(("Error calling '%s.%s' with:"):format(modname, cmd[3]), unpack(cmd, 4))
                else
                    log(("Error resuming coroutine in %s"):format(modname))
                end
                log(debug.traceback(co, ret))
            end
        end
        return is_dead
    end

    local run = true
    local running_coroutines = {}
    local update_fun, updater_count = require("update_functions")()
    while run do
        -- get command and update if necessary
        local cmd
        if #running_coroutines > 0 or updater_count > 0 then
            cmd = in_channel:demand(0.01)
            update_fun()
        else
            cmd = in_channel:demand()
        end

        -- process command
        if cmd then
            local thread_id = cmd[1]
            local call_id = cmd[2]
            local fn = api[cmd[3]]
            if type(fn) == "function" then
                local co = coroutine.create(fn)
                if not run_coroutine(co, thread_id, call_id, cmd) then
                    running_coroutines[#running_coroutines + 1] = { thread_id, call_id, co }
                end
            elseif send_responses then
                out_channels[thread_id]:push({
                    call_id,
                    false,
                    ("'%s.%s' is not a function"):format(modname, cmd[3]),
                })
            end
        -- process pending commands
        else
            for i = #running_coroutines, 1, -1 do
                local thread_id, call_id, co = unpack(running_coroutines[i])
                if run_coroutine(co, thread_id, call_id) then
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
    local thread_id = love.thread.getChannel("thread_ids"):performAtomic(function(channel)
        local counter = (channel:pop() or 0) + 1
        channel:push(counter)
        return counter
    end)

    ---run a module in a different thread but allow calling its functions from here
    ---@param require_string string
    ---@param no_responses boolean?
    ---@return table<string, fun(...): promise>
    function threadify.require(require_string, no_responses)
        if not threads[require_string] then
            local thread_table = {
                resolvers = {},
                rejecters = {},
                out_channel = love.thread.getChannel(("%s_%d_out"):format(require_string, thread_id)),
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
        local cmd_channel = love.thread.getChannel(require_string .. "_cmd")
        local request_id = 0
        return setmetatable(interface, {
            __index = function(_, key)
                return function(...)
                    local msg = { thread_id, -1, key, ... }
                    if no_responses then
                        cmd_channel:push(msg)
                        return
                    end
                    return async.promise:new(function(resolve, reject)
                        repeat
                            request_id = (request_id + 1) % 256
                        until thread.resolvers[request_id] == nil
                        msg[2] = request_id
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
            local result = thread.out_channel:pop()
            if result then
                if result[2] then
                    thread.resolvers[result[1]](unpack(result, 3))
                else
                    log(result[3])
                    thread.rejecters[result[1]]()
                end
                thread.resolvers[result[1]] = nil
                thread.rejecters[result[1]] = nil
            end
        end
    end

    return threadify
end
