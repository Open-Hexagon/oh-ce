require("platform")
local version, pack_name, tmp_folder, server_api_url, pack_size = ...
xpcall(function()
    local zip = require("extlibs.zip")
    local log = require("log")("ui.overlay.packs.download")
    local http = require("socket.http")
    local url = require("socket.url")

    local filename = string.format("%s%s_%s.zip", tmp_folder, version, pack_name)
    local file = love.filesystem.openFile(filename, "w")
    local download_size, last_progress = 0, nil
    log("Downloading", pack_name)
    local channel = love.thread.getChannel(string.format("pack_download_progress_%d_%s", version, pack_name))
    channel:clear()
    channel:push(0)
    local success, err = http.request({
        url = server_api_url .. "get_pack/" .. version .. "/" .. url.escape(pack_name),
        sink = function(chunk, err)
            if err then
                log(err)
                file:close()
                love.filesystem.remove(filename)
            elseif chunk then
                file:write(chunk)
                download_size = download_size + #chunk
                local progress = math.floor(download_size / pack_size * 100)
                if progress ~= last_progress then
                    channel:push(progress)
                    last_progress = progress
                end
                return 1
            end
        end,
    })
    file:close()
    if not success then
        love.filesystem.remove(filename)
        error("Failed http request: " .. err)
    end
    if download_size < pack_size then
        error(string.format("Failed download: missing %d bytes", pack_size - download_size))
    end
    log("Extracting", filename)
    local zip_file = zip:new(filename)
    zip_file:unzip("packs" .. version)
    zip_file:close()
    love.filesystem.remove(filename)
end, function(err)
    love.thread.getChannel(string.format("pack_download_error_%d_%s", version, pack_name)):push(err)
end)
