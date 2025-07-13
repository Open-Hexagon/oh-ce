require("love.system")
if love.system.getOS() == "Web" then
    -- just fake it for now
    return setmetatable({}, {
        __index = function()
            return function()
                return {}
            end
        end
    })
end
local sqlite = require("extlibs.sqlite")
local strfun = require("extlibs.sqlite.strfun")

local profile = {}

local profile_path = "profiles/"
if not love.filesystem.getInfo(profile_path) then
    love.filesystem.createDirectory(profile_path)
end
local replay_path = "replays/"
if not love.filesystem.getInfo(replay_path) then
    love.filesystem.createDirectory(replay_path)
end
local database
local current_profile

---get the current profile name
---@return string
function profile.get_current_profile()
    return current_profile
end

---get a list of all available game profiles
---@return table
function profile.list()
    local profiles = love.filesystem.getDirectoryItems(profile_path)
    for i = 1, #profiles do
        profiles[i] = profiles[i]:sub(1, -4)
    end
    return profiles
end

---open or create a new profile
---@param name string
function profile.open_or_new(name)
    local path = profile_path .. name .. ".db"
    database = sqlite({
        uri = path,
        scores = {
            pack = "text",
            level = "text",
            level_options = "luatable",
            created = { "timestamp", default = strfun.strftime("%s", "now") },
            time = "real",
            score = "real",
            replay_hash = "text",
        },
        custom_data = {
            pack = { "text", unique = true, primary = true },
            data = "luatable",
        },
    })
    current_profile = name
end

local function escape(str)
    if str:match("%(") or str:match("%)") then
        str = string.format("'%s'", str)
    end
    if str:match("'") then
        str = str:gsub("'", "''")
    end
    return str
end

local function unescape(str)
    if str:match("%(") or str:match("%)") then
        str = str:sub(2, -2)
    end
    if str:match("''") then
        str = str:gsub("''", "'")
    end
    return str
end

---get all persistent data stored in the database for a pack
---@param pack_id string
---@return table?
function profile.get_data(pack_id)
    local matches = database.custom_data:get({ where = { pack = escape(pack_id) } })
    if #matches == 0 then
        return nil
    elseif #matches == 1 then
        return matches[1].data
    else
        error("Found " .. #matches .. " matches for primary key value '" .. pack_id .. "' which should be impossible!")
    end
end

---get all persistent data from the profile (pack_id/data as key/value pairs)
---@return table
function profile.get_all_data()
    local rows = database.custom_data:get()
    local result = {}
    for i = 1, #rows do
        local row = rows[i]
        result[unescape(row.pack)] = row.data
    end
    return result
end

---store any persistent data for a pack in the database (overwrites data for the pack if it already has some)
---@param pack_id string
---@param data table
function profile.store_data(pack_id, data)
    database:open()
    database:update("custom_data", {
        where = { pack = escape(pack_id) },
        set = { data = data },
    })
    database:close()
end

---save a score into the profile's database and save the replay as well
---@param time number
---@param replay Replay
function profile.save_score(time, replay)
    local hash, data = replay:get_hash()
    local dir = replay_path .. hash:sub(1, 2) .. "/"
    if not love.filesystem.getInfo(dir) then
        love.filesystem.createDirectory(dir)
    end
    local n
    local path = dir .. hash
    -- in case a replay actually has a duplicate hash (which is almost impossible) add some random numbers to it
    if love.filesystem.getInfo(path) then
        path = path .. 0
        n = 0
        while love.filesystem.getInfo(path) do
            n = n + 1
            path = path:sub(1, -2) .. n
        end
        hash = hash .. n
    end
    database:open()
    database:insert("scores", {
        pack = escape(replay.pack_id),
        level = escape(replay.level_id),
        level_options = replay.data.level_settings,
        time = time,
        score = replay.score,
        replay_hash = hash,
    })
    database:close()
    replay:save(path, data)
end

---get all scores on a level with certain level options
---@param pack string
---@param level string
---@param level_options table
---@return table
function profile.get_scores(pack, level, level_options)
    database:open()
    local results = database:select("scores", {
        where = {
            pack = escape(pack),
            level = level,
        },
    })
    database:close()
    for i = #results, 1, -1 do
        for k, v in pairs(results[i].level_options) do
            if level_options[k] ~= v then
                table.remove(results, i)
                break
            end
        end
    end
    return results
end

---delete the currently selected profile with all its replays
function profile.delete()
    database:open()
    local scores = database:select("scores")
    for i = 1, #scores do
        local score = scores[i]
        local folder = replay_path .. score.replay_hash:sub(1, 2) .. "/"
        local path = folder .. score.replay_hash
        love.filesystem.remove(path)
        if #love.filesystem.getDirectoryItems(folder) == 0 then
            love.filesystem.remove(folder)
        end
    end
    database:close()
    local path = profile_path .. current_profile .. ".db"
    love.filesystem.remove(path)
    database = nil
    current_profile = nil
end

return profile
