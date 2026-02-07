return function(modname)
    return function(...)
        -- don't print stuff when testing
        if love.filesystem.getIdentity() ~= "ohtest" then
            print("[" .. os.date() .. "] [" .. modname .. "]", ...)
        end
    end
end
