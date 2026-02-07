local tmpfile = {}

if io.tmpfile() then
    tmpfile.create = io.tmpfile
    tmpfile.clear = function() end
else
    -- alternative implementation for platforms that don't support io.tmpfile
    local count = 0
    local opened_files = 0
    local save_dir = love.filesystem.getSaveDirectory()
    if save_dir:sub(-1) ~= "/" then
        save_dir = save_dir .. "/"
    end

    function tmpfile.create()
        if not love.filesystem.getInfo("tmpfiles") then
            love.filesystem.createDirectory("tmpfiles")
        end
        local name = "tmpfiles/" .. string.format("%x", count)
        count = count + 1
        return io.open(save_dir .. name, "w")
    end

    function tmpfile.clear()
        count = 0
    end
end

return tmpfile
