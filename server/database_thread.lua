require("platform")
local log_name, as_thread = ...
local log = require("log")(log_name)
local sqlite = require("extlibs.sqlite")
local strfun = require("extlibs.sqlite.strfun")
local msgpack = require("extlibs.msgpack.msgpack")

local api = {}

local server_path = "server/"
local db_path = server_path .. "server.db"
local replay_path = server_path .. "replays/"
love.filesystem.createDirectory(server_path)
love.filesystem.createDirectory(replay_path)
local database = sqlite({
    uri = db_path,
    users = {
        steam_id = { "text", unique = true, primary = true },
        username = { "text", unique = true },
        password_hash = "text",
    },
    scores = {
        steam_id = "text",
        pack = "text",
        level = "text",
        level_options = "text",
        created = { "timestamp", default = strfun.strftime("%s", "now") },
        time = "real",
        score = "real",
        replay_hash = "text",
    },
    login_tokens = {
        steam_id = { "text", unique = true },
        created = { "timestamp", default = strfun.strftime("%s", "now") },
        token = { "text", unique = true, primary = true },
    },
    rank_1_scores = {
        steam_id = "text",
        pack = "text",
        level = "text",
        level_options = "text",
        created = { "timestamp", default = strfun.strftime("%s", "now") },
        time = "real",
        score = "real",
    },
})

---get the replay path
---@return string
function api.get_replay_path()
    return replay_path
end

---remove all login tokens for a user with the given steam id
---@param steam_id string
function api.remove_login_tokens(steam_id)
    database:delete("login_tokens", { where = { steam_id = steam_id } })
end

---add a login token to the database
---@param steam_id string
---@param token any
function api.add_login_token(steam_id, token)
    token = love.data.encode("string", "base64", token)
    database:insert("login_tokens", { steam_id = steam_id, token = token })
end

---check if a user exists in the database
---@param name string
---@return boolean
function api.user_exists_by_name(name)
    return #database:select("users", { where = { username = name } }) > 0
end

---check if a user exists in the database
---@param steam_id string
---@return boolean
function api.user_exists_by_steam_id(steam_id)
    return #database:select("users", { where = { steam_id = steam_id } }) > 0
end

---get the row of a user in the database
---@param name string
---@param steam_id string
---@return table|nil
function api.get_user(name, steam_id)
    local results = database:select("users", { where = { username = name, steam_id = steam_id } })
    if #results == 0 then
        return
    end
    results[1].password_hash = love.data.decode("string", "base64", results[1].password_hash)
    return results[1]
end

---get the row of a user in the database
---@param steam_id string
---@return table|nil
function api.get_user_by_steam_id(steam_id)
    local results = database:select("users", { where = { steam_id = steam_id } })
    if #results == 0 then
        return
    end
    results[1].password_hash = love.data.decode("string", "base64", results[1].password_hash)
    return results[1]
end

---register a new user in the database (returns true on success)
---@param username string
---@param steam_id integer
---@param password_hash string
---@return boolean
function api.register(username, steam_id, password_hash)
    return database:insert("users", {
        steam_id = steam_id,
        username = username,
        password_hash = love.data.encode("string", "base64", password_hash),
    })
end

local function save_to_db_rank_1_scores(time, steam_id, pack, level, level_options, score, timestamp)
    database:insert("rank_1_scores", {
        steam_id = steam_id,
        pack = pack,
        level = level,
        level_options = level_options,
        time = time,
        score = score,
        replay_hash = hash,
        created = timestamp,
    })
end

---save a score into the database and save the replay
---@param time number
---@param steam_id string
---@param pack string
---@param level string
---@param level_options any
---@param score number
---@param hash string?
---@param timestamp integer?
---@return boolean
function api.save_score(time, steam_id, pack, level, level_options, score, hash, timestamp)
    level_options = love.data.encode("string", "base64", level_options)
    local results = database:select("scores", {
        where = {
            steam_id = steam_id,
            pack = pack,
            level = level,
            level_options = level_options,
        },
    })
    if #results == 0 then
        database:insert("scores", {
            steam_id = steam_id,
            pack = pack,
            level = level,
            level_options = level_options,
            time = time,
            score = score,
            replay_hash = hash,
            created = timestamp,
        })
    else
        if #results > 1 then
            log("Player has more than one score on the same ranking!")
        end
        if results[1].score > score then
            log("Score is worse than pb, discarding")
            return false
        end
        if results[1].replay_hash then
            -- remove old replay
            local folder = replay_path .. results[1].replay_hash:sub(1, 2) .. "/"
            local path = folder .. results[1].replay_hash
            love.thread.getChannel("abort_replay_render"):push(results[1].replay_hash)
            love.filesystem.remove(path)
            local video = path .. ".mp4"
            if love.filesystem.getInfo(video) then
                love.filesystem.remove(video)
            end
            if #love.filesystem.getDirectoryItems(folder) == 0 then
                love.filesystem.remove(folder)
            end
        end
        database:update("scores", {
            where = {
                steam_id = steam_id,
                pack = pack,
                level = level,
                level_options = level_options,
            },
            set = {
                time = time,
                score = score,
                replay_hash = hash,
                created = timestamp or os.time(),
            },
        })
    end

    local position = api.get_score_position(pack, level, level_options, steam_id, true)
    if position == 1 then
        save_to_db_rank_1_scores(time, steam_id, pack, level, level_options, score, timestamp)
    end

    return true
end

---get all scores that were done in the last however many seconds
---@param seconds any
---@return table
function api.get_newest_scores(seconds)
    local min_time = os.time() - seconds
    local results = database:eval("SELECT * FROM scores WHERE created >= ?", min_time)
    if type(results) == "table" then
        local ret = {}
        for i = 1, #results do
            local score = results[i]
            local _, level_options = msgpack.unpack(love.data.decode("string", "base64", score.level_options))
            ret[#ret + 1] = {
                position = api.get_score_position(score.pack, score.level, score.level_options, score.steam_id, true),
                user_name = (api.get_user_by_steam_id(score.steam_id) or { username = "deleted user" }).username,
                timestamp = score.created,
                value = score.score,
                replay_hash = score.replay_hash,
                level_options = level_options,
                level = score.level,
                pack = score.pack,
            }
        end
        return ret
    end
    return {}
end

function api.get_score_position(pack, level, level_options, steam_id, is_base64)
    if not is_base64 then
        level_options = love.data.encode("string", "base64", level_options)
    end
    local results = database:select("scores", {
        where = {
            pack = pack,
            level = level,
            level_options = level_options,
        },
    })
    local user_score
    for i = 1, #results do
        if results[i].steam_id == steam_id then
            user_score = results[i]
        end
    end
    local position = 1
    for i = #results, 1, -1 do
        if results[i].score >= user_score.score and results[i] ~= user_score then
            position = position + 1
        end
    end
    return position
end

---get the score for a certain replay
---@param hash any
---@return table
function api.get_score_from_hash(hash)
    local results = database:select("scores", { where = { replay_hash = hash } })
    if #results > 1 then
        log("Two scores with same replay hash?")
    end
    return results[1]
end

---get the top scores on a level and the score for the steam id
---@param pack any
---@param level any
---@param level_options any
---@param steam_id any
---@return table
---@return table?
function api.get_leaderboard(pack, level, level_options, steam_id)
    level_options = love.data.encode("string", "base64", level_options)
    local results = database:select("scores", {
        where = {
            pack = pack,
            level = level,
            level_options = level_options,
        },
    })
    local times = {}
    local scores_by_time = {}
    for i = 1, #results do
        local score = results[i]
        times[#times + 1] = score.score
        if scores_by_time[score.score] == nil then
            scores_by_time[score.score] = { score }
        else
            scores_by_time[score.score][#scores_by_time[score.score] + 1] = score
        end
    end
    table.sort(times)
    local ret = {}
    local user_score
    local time_count = 1
    local last_time
    for i = #times, 1, -1 do
        if times[i] ~= last_time then
            time_count = 1
        end
        local scores_for_time = scores_by_time[times[i]]
        local score = scores_for_time[time_count]
        time_count = time_count + 1
        last_time = times[i]
        local user = api.get_user_by_steam_id(score.steam_id)
        local name = user and user.username or "deleted user"
        ret[#ret + 1] = {
            position = #times - i + 1,
            user_name = name,
            timestamp = score.created,
            value = times[i],
            replay_hash = score.replay_hash,
        }
        if score.steam_id == steam_id then
            user_score = {}
            for k, v in pairs(ret[#ret]) do
                user_score[k] = v
            end
            user_score.position = user_score.position - 1
        end
    end
    return ret, user_score
end

---delete a user with all their scores and replays
---@param steam_id any
function api.delete(steam_id)
    local scores = database:select("scores", { where = { steam_id = steam_id } })
    for i = 1, #scores do
        local score = scores[i]
        if score.replay_hash then
            local folder = replay_path .. score.replay_hash:sub(1, 2) .. "/"
            local path = folder .. score.replay_hash
            love.filesystem.remove(path)
            if #love.filesystem.getDirectoryItems(folder) == 0 then
                love.filesystem.remove(folder)
            end
        end
    end
    database:delete("scores", { where = { steam_id = steam_id } })
    database:delete("users", { where = { steam_id = steam_id } })
end

function api.get_all_scores()
    return database:select("scores")
end

if as_thread then
    database:open()
    local run = true
    while run do
        local cmd = love.thread.getChannel("db_cmd"):demand()
        local thread_id = cmd[1]
        table.remove(cmd, 1)
        if cmd[1] == "stop" then
            run = false
        else
            xpcall(function()
                local fn = api[cmd[1]]
                table.remove(cmd, 1)
                local ret = { fn(unpack(cmd)) }
                love.thread.getChannel("db_out" .. thread_id):push(ret)
            end, function(err)
                love.thread.getChannel("db_out" .. thread_id):push({ "error", err })
            end)
        end
    end
    database:close()
else
    function api.open()
        database:open()
    end
    function api.close()
        database:close()
    end
    return api
end
