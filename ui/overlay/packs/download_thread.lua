local log = require("log")("ui.overlay.packs.download_thread")
local json = require("extlibs.json.json")
local assets = require("asset_system")
local async = require("async")
local url = require("socket.url")
require("love.timer")

-- don't import https when running in the browser
-- TODO: find an alternative?
require("love.system")
local https
if love.system.getOS() ~= "Web" then
    https = require("https")
end

local server_http_url, server_https_url
local tmp_folder = "download_cache/"
if not love.filesystem.getInfo(tmp_folder) then
    love.filesystem.createDirectory(tmp_folder)
end

local pack_map = {}
local download = {}

local function api(suffix)
    local code, json_data = https.request(server_https_url .. url.escape(suffix))
    if code ~= 200 then
        log("'" .. server_https_url .. url.escape(suffix) .. "' api request failed")
        return
    end
    if not json_data or (json_data:sub(1, 1) ~= "{" and json_data:sub(1, 1) ~= "[") then
        -- something went wrong
        return
    end
    return json.decode(json_data)
end

function download.set_server(serv_url, http_port, https_port)
    server_http_url = "http://" .. serv_url .. ":" .. http_port .. "/"
    server_https_url = "https://" .. serv_url .. ":" .. https_port .. "/"
end

local preview_data = {}

---get preview data
---@param game_version number
---@param pack string
---@return table
function download.get_preview_data(game_version, pack)
    preview_data[game_version] = preview_data[game_version] or {}
    preview_data[game_version][pack] = preview_data[game_version][pack]
        or api(("get_pack_preview_data/%d/%s"):format(game_version, pack))
    return preview_data[game_version][pack]
end

---gets a list of packs
---@param start number
---@param stop number
---@return table|boolean|nil
function download.get_pack_list(start, stop)
    async.busy_await(assets.index.request("pack_level_data", "pack.load_register"))
    local pack_list = assets.mirror.pack_level_data
    local pack_data_list = api(("get_packs/%d/%d"):format(start, stop))
    if not pack_data_list then
        return
    end
    if #pack_data_list == 0 then
        return true
    end
    -- remove packs the player already has
    local map = {}
    for i = 1, #pack_list do
        local pack = pack_list[i]
        map[pack.game_version] = map[pack.game_version] or {}
        map[pack.game_version][pack.id] = true
    end
    for i = #pack_data_list, 1, -1 do
        local pack = pack_data_list[i]
        pack_map[pack.game_version] = pack_map[pack.game_version] or {}
        pack_map[pack.game_version][pack.folder_name] = pack
        if map[pack.game_version] and map[pack.game_version][pack.id] then
            table.remove(pack_data_list, i)
        end
    end
    return pack_data_list
end

---downloads and extracts a pack in the right location
---@param version number
---@param pack_name string
---@return string?
function download.get(version, pack_name)
    local thread = love.thread.newThread("ui/overlay/packs/download.lua")
    thread:start(version, pack_name, tmp_folder, server_http_url, pack_map[version][pack_name].file_size)
    while thread:isRunning() do
        coroutine.yield()
    end
    local err = thread:getError()
        or love.thread.getChannel(string.format("pack_download_error_%d_%s", version, pack_name)):pop()
    if err then
        return err
    end
    log("Done")
end

return download
