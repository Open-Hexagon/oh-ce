require("platform")
local log = require("logging").get_logger("threadify")
local modname, is_thread = ...

---@alias CallId integer
---@alias ThreadCommand [ThreadId, CallId, string, ...]
---@alias ThreadResult [CallId, boolean, unknown]
---@alias ThreadClient {
---  require_string: string,
---  resolvers: table<integer, fun(...: unknown)>,
---  rejecters: table<integer, fun(...: unknown)>,
---  out_channel: love.Channel,
---  __index: fun(_: table, key: string):(fun(...: unknown):Promise?),
---}
---@alias ThreadAPI {
---  _threadify_calling_thread_id:integer?,
---  _threadify_update_loop:fun()?,
---}

if is_thread then
    -- Threadified module thread.
    -- There can only be one of these per threadified module.

    local send_responses = not select(3, ...) -- this was once no_responses passed in by threadify.require
    ---@type ThreadAPI
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
                    log:error(("Error calling '%s.%s' with:"):format(modname, cmd[3]), unpack(cmd, 4))
                else
                    log:error(("Error resuming coroutine in %s"):format(modname))
                end
                log:error(debug.traceback(co, ret))
            end
        end
        return is_dead
    end

    local run = true
    local running_coroutines = {}

    -- this runs forever currently
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
                    table.insert(running_coroutines, { thread_id, call_id, co })
                end
            else
                if send_responses then
                    out_channels[thread_id]:push({
                        call_id,
                        false,
                        ("'%s.%s' is not a function"):format(modname, cmd[3]),
                    } --[[@as ThreadResult]])
                end
            end
        -- process pending commands
        else
            local last_i = #running_coroutines
            for i = last_i, 1, -1 do
                local thread_id, call_id, co = unpack(running_coroutines[i])
                if run_coroutine(co, thread_id, call_id) then
                    -- remove with swap and pop
                    running_coroutines[i], running_coroutines[last_i] =
                        running_coroutines[last_i], running_coroutines[i]
                    running_coroutines[last_i] = nil
                    last_i = last_i - 1
                end
            end
        end
    end
else
    -- Threadify module
    -- There can be many of these across different threads
    -- Each has a unique id

    local async = require("async")

    local threadify = {}

    ---list of thread clients
    ---@type ThreadClient[]
    local thread_client_list = {}

    ---Table of already loaded threadified modules
    ---@type table<string, table>
    threadify.loaded = {}

    ---Contains a single global list of love.Thread
    ---Used to enforce one thread per required module
    local threads_channel = love.thread.getChannel("threads")

    local thread_id = require("thread_id")

    ---Run a module in a different thread but allow calling its functions from here.
    ---All valid calls to that module will return promises (unless no_responses is set).
    ---Limitations:
    ---1. Functions in the threadified module can only return 1 value. Other values are lost.
    ---2. The no_responses property is per thread and cannot be changed after a thread is created.
    ---@param require_string string Module name. Same format as normal require.
    ---@param no_responses boolean? Set this to true if you don't want promises when calling this module's functions.
    ---@return table<string, fun(...): Promise>
    function threadify.require(require_string, no_responses)
        local new_module = threadify.loaded[require_string]
        if new_module then
            return new_module
        end

        -- module has not been loaded before

        -- get thread if already running, start it if not
        -- this must be done atomically so multiple threads can't create multiple child threads of the same module
        local thread
        threads_channel:performAtomic(function(channel)
            local all_threads = channel:pop() or {}

            thread = all_threads[require_string]
            if not thread then
                thread = love.thread.newThread("threadify.lua")
                all_threads[require_string] = thread
            end

            if not thread:isRunning() then
                thread:start(require_string, true, no_responses)
            end

            channel:push(all_threads)
        end)

        -- get the command channel for this thread
        local cmd_channel = love.thread.getChannel(require_string .. "_cmd")
        -- create module
        new_module = {}

        ---Create new ThreadClient
        ---@type ThreadClient
        local thread_client = {
            require_string = require_string,
            resolvers = {},
            rejecters = {},
            out_channel = love.thread.getChannel(("%s_%d_out"):format(require_string, thread_id)),
        }

        -- behavior of module functions depends on no_responses
        if no_responses then
            thread_client.__index = function(t, key)
                t[key] = function(...)
                    ---@type ThreadCommand
                    local msg = { thread_id, -1, key, ... }
                    cmd_channel:push(msg)
                end
                return t[key]
            end
        else
            thread_client.__index = function(t, key)
                t[key] = function(...)
                    ---@type ThreadCommand
                    local msg = { thread_id, -1, key, ... }
                    return async.new_promise(function(resolve, reject)
                        local request_id = 1
                        while thread_client.resolvers[request_id] do
                            request_id = request_id + 1
                        end
                        msg[2] = request_id
                        thread_client.resolvers[request_id] = resolve
                        thread_client.rejecters[request_id] = reject
                        cmd_channel:push(msg)
                    end)
                end
                return t[key]
            end
        end

        -- we can use the thread client as the metatable to save making a new one
        setmetatable(new_module, thread_client)
        table.insert(thread_client_list, thread_client)
        threadify.loaded[require_string] = new_module

        return new_module
    end

    ---Process any new results from thread clients
    function threadify.update()
        for i = 1, #thread_client_list do
            local thread_client = thread_client_list[i]
            ---@type ThreadResult?
            local result = thread_client.out_channel:pop()
            if result then
                if result[2] then
                    thread_client.resolvers[result[1]](result[3])
                else
                    log:info(result[3])
                    thread_client.rejecters[result[1]](result[3])
                end
                thread_client.resolvers[result[1]] = nil
                thread_client.rejecters[result[1]] = nil
            end
        end
    end

    return threadify
end
