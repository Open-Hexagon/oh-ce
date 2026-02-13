-- small async implementation using coroutines to suspend a function awaiting a callback

---@class Promise
---@field done_callbacks table
---@field error_callbacks table
---@field executed boolean True if the promise is done executing, with or without error.
---@field result any[]? The list of arguments given to resolve or reject. Irrelevant if executed is false.
---@field resolved boolean True if the promise finished without errors. Irrelevant if executed is false.
local Promise = {}
Promise.__index = Promise

---Creates a new promise that gets a resolve and a reject function passed.
---The executor function gets called immediately.
---When done, it should either call `resolve` with the result or `reject` with the error.
---(These functions are provided by the promise class.) Values returned by the executor are ignored.
---If resolve or reject never get called, the promise remains NOT executed forever.
---If an error happens in the executor, reject is called automatically with the error string.
---@param fn fun(resolve:(fun(...):nil), reject:(fun(...):nil)) the executor function
---@return Promise
local function new_promise(fn)
    local obj = setmetatable({
        done_callbacks = {},
        error_callbacks = {},
        executed = false,
        result = nil,
        resolved = false,
    }, Promise)

    local function resolve(...)
        -- extra calls are ignored
        if obj.executed then
            return
        end
        obj.resolved = true
        obj.result = { ... }
        obj.executed = true
        for i = 1, #obj.done_callbacks do
            obj.done_callbacks[i](...)
        end
    end

    local function reject(...)
        -- extra calls are ignored
        if obj.executed then
            return
        end
        obj.result = { ... }
        obj.executed = true
        for i = 1, #obj.error_callbacks do
            obj.error_callbacks[i](...)
        end
        if #obj.error_callbacks == 0 then
            -- only the first argument of ... gets printed here
            io.stderr:write("Error:\t", ..., "\t", debug.traceback())
            error("Uncaught error in promise")
        end
    end

    local success, err = pcall(fn, resolve, reject)
    if not success then
        reject(err)
    end

    return obj
end

---Adds a done (resolve) callback to the promise.
---The callback is called immediately if the promise is already resolved.
---@param callback function
---@return Promise
function Promise:done(callback)
    if self.executed then
        if self.resolved then
            callback(unpack(self.result))
        end
    else
        table.insert(self.done_callbacks, callback)
    end
    return self
end

---Adds an error (reject) callback to the promise.
---The callback is called immediately if the promise is already resolved.
---@param callback function
---@return table
function Promise:err(callback)
    if self.executed then
        if not self.resolved then
            callback(unpack(self.result))
        end
    else
        table.insert(self.error_callbacks, callback)
    end
    return self
end

---Converts a function to an async function
---@param _ any ignore this
---@param fn function any function
---@return fun(...):Promise
local function make_async_function(_, fn)
    return function(...)
        local args = { ... }

        local prom = new_promise(function(resolve, reject)
            local co = coroutine.create(function()
                resolve(fn(unpack(args)))
            end)

            local success, err = coroutine.resume(co)

            if not success then
                reject(err .. "\n" .. debug.traceback(co))
            end
        end)

        if prom.executed and not prom.resolved and #prom.error_callbacks == 0 then
            error("Uncaught error in promise: " .. prom.result[1])
        end

        return prom
    end
end

local async = setmetatable({}, {
    __call = make_async_function,
})

---Waits for a promise to resolve. Can only be used inside async functions
---@param prom Promise
---@return any ...
function async.await(prom)
    if prom.executed then
        return unpack(prom.result)
    end

    -- gets the coroutine of caller
    local co = coroutine.running()
    if not co then
        error("cannot await outide of an async function")
    end

    -- this callback resumes the caller once the promise is done
    prom:done(function(...)
        local success, err = coroutine.resume(co, ...) -- (1)
        if not success then
            error(err .. "\n" .. debug.traceback(co))
        end
    end)

    -- Wait
    -- Yield will returned any values from the promise, which will be passed as arguments to the corresponding resume
    return coroutine.yield() -- (1)
end

---Blocks the current thread until a promise resolves.
---@param prom Promise
---@param in_coroutine_loop boolean?
---@return any ...
function async.busy_await(prom, in_coroutine_loop)
    -- this function is the only implementation specific one (assumes love and the asset system are used)
    local assets = package.loaded.asset_system
    local threadify = package.loaded.threadify
    local is_main = arg ~= nil
    local exit
    while not prom.executed do
        -- main thread is the only one that needs to do this
        if is_main then
            love.event.pump()
            for name, a, b in love.event.poll() do
                if name == "quit" then
                    -- the actual exiting happens outside of this loop
                    -- the event is pushed again below so that a loop
                    -- that is actually handled by love can handle it
                    exit = a or 0
                elseif name == "threaderror" then
                    error("Error in thread: " .. b)
                end
            end
            if assets then
                assets.run_main_thread_task()
            end
        end
        if threadify then
            threadify.update()
        end
        if assets then
            assets.mirror_client.update()
        end
        if in_coroutine_loop then
            coroutine.yield()
        else
            love.timer.sleep(0.01)
        end
    end
    if exit then
        love.event.quit(exit)
    end
    return unpack(prom.result)
end

async.new_promise = new_promise

return async
