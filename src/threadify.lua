require("platform")
local log = require("log")("threadify")
local modname, is_thread = ...

---@alias ThreadId integer
---@alias CallId integer
---@alias ThreadCommand [ThreadId, CallId, string, ...]
---@alias ThreadResult [CallId, boolean, unknown]

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
        api._threadify_calling_thread_id = thread_id -- expose thread id in case a function needs it
        local success, ret = coroutine.resume(co, unpack(cmd or {}, 4))
        if not success then
            ret = (ret or "") .. "\n" .. debug.traceback(co)
        end
        local is_dead = coroutine.status(co) == "dead"
        if is_dead then
            if send_responses then
                out_channels[thread_id]:push({ call_id, success, ret } --[[@as ThreadResult]])
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
    while run do
        -- get command and update if necessary
        ---@type ThreadCommand?
        local cmd
        if #running_coroutines > 0 or api._threadify_update_loop then
            cmd = in_channel:demand(0.01)
            if api._threadify_update_loop then
                api._threadify_update_loop()
            end
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
                } --[[@as ThreadResult]])
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

    ---@alias ThreadClient {
    ---  require_string: string,
    ---  resolvers: table<integer, fun(...: unknown)>,
    ---  rejecters: table<integer, fun(...: unknown)>,
    ---  out_channel: love.Channel,
    ---  thread: love.Thread,
    ---}

    ---@type table<string, ThreadClient>
    local thread_map = {}
    ---@type ThreadClient[]
    local thread_list = {}

    local threadify = {}
    local threads_channel = love.thread.getChannel("threads")

    -- get a unique id for this thread using a counter from a channel
    ---@type ThreadId
    threadify.thread_id = love.thread.getChannel("thread_ids"):performAtomic(function(channel)
        local counter = (channel:pop() or 0) + 1
        channel:push(counter)
        return counter
    end)

    ---run a module in a different thread but allow calling its functions from here
    ---@param require_string string
    ---@param no_responses boolean?
    ---@return table<string, fun(...): promise>
    function threadify.require(require_string, no_responses)
        if not thread_map[require_string] then
            -- get thread if already running, start it if not
            local thread
            threads_channel:performAtomic(function(channel)
                local all_threads = channel:pop() or {}
                if all_threads and all_threads[require_string] then
                    thread = all_threads[require_string]
                else
                    thread = love.thread.newThread("threadify.lua")
                end
                if not thread:isRunning() then
                    thread:start(require_string, true, no_responses)
                end
                all_threads[require_string] = thread
                channel:push(all_threads)
            end)

            -- add data to tables
            local data = {
                require_string = require_string,
                resolvers = {},
                rejecters = {},
                out_channel = love.thread.getChannel(("%s_%d_out"):format(require_string, threadify.thread_id)),
            }
            thread_list[#thread_list + 1] = data
            thread_map[require_string] = data
        end

        local thread = thread_map[require_string]
        local cmd_channel = love.thread.getChannel(require_string .. "_cmd")
        return setmetatable({}, {
            __index = function(_, key)
                return function(...)
                    ---@type ThreadCommand
                    local msg = { threadify.thread_id, -1, key, ... }
                    if no_responses then
                        cmd_channel:push(msg)
                        return
                    end
                    return async.promise:new(function(resolve, reject)
                        local request_id = 1
                        while thread.resolvers[request_id] do
                            request_id = request_id + 1
                        end
                        msg[2] = request_id
                        thread.resolvers[request_id] = resolve
                        thread.rejecters[request_id] = reject
                        cmd_channel:push(msg)
                    end)
                end
            end,
        })
    end

    ---update thread clients for the modules
    function threadify.update()
        for i = 1, #thread_list do
            local thread = thread_list[i]
            ---@type ThreadResult?
            local result = thread.out_channel:pop()
            if result then
                if result[2] then
                    thread.resolvers[result[1]](unpack(result, 3))
                else
                    log(result[3])
                    thread.rejecters[result[1]](result[3])
                end
                thread.resolvers[result[1]] = nil
                thread.rejecters[result[1]] = nil
            end
        end
    end

    return threadify
end
