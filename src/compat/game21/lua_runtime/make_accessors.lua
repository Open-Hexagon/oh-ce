local utils = require("compat.game192.utils")
return function()
    local env = require("compat.game21.lua_runtime").env
    return function(prefix, name, t, f)
        if type(t[f]) == "number" then
            env[prefix .. "_set" .. name] = function(value)
                if type(value) ~= "number" then
                    value = 0
                end
                t[f] = utils.float_round(value)
            end
            env[prefix .. "_get" .. name] = function()
                return utils.float_round(t[f])
            end
        else
            env[prefix .. "_set" .. name] = function(value)
                t[f] = value
            end
            env[prefix .. "_get" .. name] = function()
                return t[f]
            end
        end
    end
end
