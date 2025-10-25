-- small async implementation using coroutines to suspend a function awaiting a callback

---@class promise
---@field done_callbacks table
---@field error_callbacks table
---@field executed boolean
---@field result any
---@field resolved boolean
---@private done_callbacks table
local promise = {}
promise.__index = promise

---creates a new promise that gets a resolve and a reject function passed
---@param fn function
---@return promise
function promise:new(fn)
    local obj = setmetatable({
        done_callbacks = {},
        error_callbacks = {},
        executed = false,
        result = nil,
        resolved = false,
    }, promise)
    fn(function(...)
        obj.resolved = true
        obj.result = { ... }
        obj.executed = true
        for i = 1, #obj.done_callbacks do
            obj.done_callbacks[i](...)
        end
    end, function(...)
        obj.result = { ... }
        obj.executed = true
        for i = 1, #obj.error_callbacks do
            obj.error_callbacks[i](...)
        end
        if #obj.error_callbacks == 0 then
            print("Error: ", ..., debug.traceback())
            error("Uncaught error in promise")
        end
    end)
    return obj
end

---adds a done (resolve) callback to the promise
---@param callback function
---@return promise
function promise:done(callback)
    if self.executed then
        if self.resolved then
            callback(unpack(self.result))
        end
        return self
    end
    self.done_callbacks[#self.done_callbacks + 1] = callback
    return self
end

---adds an error (reject) callback to the promise
---@param callback any
---@return table
function promise:err(callback)
    if self.executed then
        if not self.resolved then
            callback(unpack(self.result))
        end
        return self
    end
    self.error_callbacks[#self.error_callbacks + 1] = callback
    return self
end

local async = setmetatable({}, {
    __call = function(_, fn)
        return function(...)
            local args = { ... }
            local prom = promise:new(function(resolve, reject)
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
    end,
})

function async.await(prom)
    if prom.executed then
        return unpack(prom.result)
    end
    local co = coroutine.running()
    if not co then
        error("cannot await outide of an async function")
    end
    prom:done(function(...)
        local success, err = coroutine.resume(co, ...)
        if not success then
            error(err .. "\n" .. debug.traceback(co))
        end
    end)
    return coroutine.yield()
end

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

async.promise = promise

return async
