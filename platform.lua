-- platform specific adjustments and features

local args = require("args")

local features = {}

-- thanks to fake dlfcn functions, the library is actually just statically compiled in
-- dlsym just uses a table with symbol names and pointers to the actual symbols
package.preload.ffi = package.preload.ffi or package.loadlib("cffi.a", "luaopen_cffi")
local ffi = require("ffi")

-- cffi-lua has its own ffi.tonumber
-- luajit's ffi combines both in the default tonumber
---@diagnostic disable-next-line: inject-field
ffi.tonumber = ffi.tonumber or tonumber

-- PUC lua 5.1 does not allow extra arguments in xpcall, 5.2+ and luajit do
local xpcall_takes_arguments
xpcall(function(a)
    xpcall_takes_arguments = a == "test"
end, error, "test")
if not xpcall_takes_arguments then
    local old_xpcall = xpcall
    xpcall = function(fun, errfun, ...)
        local varargs = { ... }
        return old_xpcall(function()
            return fun(unpack(varargs))
        end, errfun)
    end
end

-- PUC lua 5.1 does not return nparams or isvararg from debug.getinfo
-- instead the data is encoded in string.dump(function).
if debug.getinfo(function(_, _) end).nparams ~= 2 then
    local old_getinfo = debug.getinfo
    ---@diagnostic disable-next-line: duplicate-set-field
    debug.getinfo = function(f, what)
        local res = old_getinfo(f, what)
        local s = string.dump(f --[[@as function]])
        assert(s:sub(1, 6) == "\27LuaQ\0", "This code works only in Lua 5.1")
        local int_size = s:byte(8)
        local ptr_size = s:byte(9)
        local pos = 14 + ptr_size + (s:byte(7) > 0 and s:byte(13) or s:byte(12 + ptr_size)) + 2 * int_size
        res.nparams = s:byte(pos)
        res.isvararg = s:byte(pos + 1) > 0
        return res
    end
end

-- PUC lua 5.1 does not allow yielding across pcall/xpcall
if coroutine.wrap(function()
    pcall(coroutine.yield, "test")
end)() ~= "test" then
    function pcall(f, ...)
        local co = coroutine.create(f)
        local result
        repeat
            result = { coroutine.resume(co, ...) }
            coroutine.yield(unpack(result, 2))
        until coroutine.status(co) ~= "suspended"
        return unpack(result)
    end
    function xpcall(f, errf, ...)
        local result = { pcall(f, ...) }
        if result[1] then
            return unpack(result)
        else
            errf(result[2])
            return result[1]
        end
    end
end

if not args.headless then
    love.thread
        .newThread([[
    require("love.graphics")
    local code = "vec4 effect(vec4,Image,vec2,vec2){return vec4(1.0);}"
    local success = pcall(love.graphics.newShader, code)
    love.thread.getChannel("_shader_test_result"):push(success)
]])
        :start()
    features.supports_threaded_shader_compilation = love.thread.getChannel("_shader_test_result"):demand()
end

return features
