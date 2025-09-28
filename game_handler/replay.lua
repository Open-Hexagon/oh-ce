local msgpack = require("extlibs.msgpack.msgpack")
local old_replay = require("compat.game21.replay")
local log = require("log")(...)

---@class Replay
---@field data table
---@field input_data table
---@field game_version number
---@field first_play boolean
---@field player_name string
---@field score number
---@field pack_id string
---@field level_id string
---@field key_index_map table
---@field input_tick_length number
local replay = {}
replay.__index = replay

---creates or loads a replay if path is given
---@param path string?
---@return Replay
function replay:new(path)
    local obj = setmetatable({
        data = {
            seeds = {},
            keys = {},
            input_times = {},
        },
        input_data = {},
        key_index_map = {},
        score = 0,
        input_tick_length = 0,
    }, replay)
    if path then
        local file, errstr = love.filesystem.openNativeFile(path, "r")
        if file == nil then
            file, errstr = love.filesystem.openFile(path, "r")
            if file == nil then
                error("could not read replay file: " .. errstr)
            end
        end
        obj:_read(file:read("data"))
        file:close()
    end
    return obj
end

---loads a replay from zlib compressed data
---@param data string|love.CompressedData
---@return Replay
function replay:new_from_data(data)
    local obj = replay:new()
    obj:_read(data)
    return obj
end

---gets the key state changes (not the key state) for a specified tick
---the return value is an iterator over: key, state
---@param time number
---@return function?
function replay:get_key_state_changes(time)
    local state_changes = self.input_data[time]
    if state_changes == nil then
        return function()
            return nil
        end
    end
    local index = -1
    return function()
        index = index + 2
        return self.data.keys[state_changes[index]], state_changes[index + 1]
    end
end

---set the level and the settings the game was started with
---@param game_version number
---@param config table global game settings (containing settings such as black and white mode)
---@param first_play boolean
---@param player_name string
---@param pack_id string
---@param level_id string
---@param level_settings table level specific settings (e.g. the difficulty mult in 21)
function replay:set_game_data(game_version, config, first_play, player_name, pack_id, level_id, level_settings)
    self.game_version = game_version
    self.pack_id = pack_id
    self.level_id = level_id
    self.first_play = first_play
    self.player_name = player_name
    self.data.config = config
    self.data.level_settings = level_settings
end

---saves an input into the replay file
---@param key love.KeyConstant
---@param state boolean
---@param time number timestamp (in ticks)
function replay:record_input(key, state, time)
    if self.key_index_map[key] == nil then
        local len = #self.data.keys + 1
        self.data.keys[len] = key
        self.key_index_map[key] = len
    end
    self.input_data[time] = self.input_data[time] or {}
    local state_changes = self.input_data[time]
    state_changes[#state_changes + 1] = self.key_index_map[key]
    state_changes[#state_changes + 1] = state
end

---saves the seed a math.randomseed call was given (this way they can be the same when the replay is replayed even if the level is settings its own random seeds)
function replay:record_seed(seed)
    self.data.seeds[#self.data.seeds + 1] = seed
end

function replay:_get_compressed()
    local header =
        love.data.pack("string", ">I4BBI4", 2, self.game_version, self.first_play and 1 or 0, self.input_tick_length)
    local function write_str(str)
        header = header .. love.data.pack("string", ">I4c" .. #str, #str, str)
    end
    write_str(self.player_name)
    write_str(self.pack_id)
    write_str(self.level_id)
    for time, _ in pairs(self.input_data) do
        self.data.input_times[#self.data.input_times + 1] = time
    end
    table.sort(self.data.input_times)
    local data = msgpack.pack(self.data)
    local input_data = ""
    for i = 1, #self.data.input_times do
        local time = self.data.input_times[i]
        local state_changes = self.input_data[time]
        input_data = input_data .. love.data.pack("string", ">B", #state_changes / 2)
        for j = 1, #state_changes, 2 do
            local key, state = state_changes[j], state_changes[j + 1]
            input_data = input_data .. love.data.pack("string", ">BB", key, state and 1 or 0)
        end
    end
    return love.data.compress(
        "data",
        "zlib",
        header .. data .. input_data .. love.data.pack("string", ">d", self.score),
        9
    )
end

---gets the hash of the replay and also returns the compressed data as it needs to be computed to get the hash already
---@return string
---@return love.CompressedData
function replay:get_hash()
    local data = self:_get_compressed()
    return love.data.encode("string", "hex", love.data.hash("string", "sha256", data)), data
end

---saves the replay into a file the data to write can optionally be specified if already gotten
---@param path string
---@param data string|love.CompressedData|nil
function replay:save(path, data)
    local file = assert(love.filesystem.openFile(path, "w"))
    file:write(data or self:_get_compressed())
    file:close()
end

function replay:_read(compressed_data)
    local data = love.data.decompress("string", "zlib", compressed_data)
    local version, offset = love.data.unpack(">I4", data)
    if version == 0 then
        old_replay.read(self, data, offset)
    elseif version == 1 or version == 2 then
        if version == 1 then
            self.game_version, self.first_play, offset = love.data.unpack(">BB", data, offset)
        else
            self.game_version, self.first_play, self.input_tick_length, offset = love.data.unpack(">BBI4", data, offset)
        end
        local function read_str()
            local len, str
            len, offset = love.data.unpack(">I4", data, offset)
            str, offset = love.data.unpack(">c" .. len, data, offset)
            return str
        end
        self.player_name = read_str()
        self.pack_id = read_str()
        self.level_id = read_str()
        self.first_play = self.first_play == 1
        offset, self.data = msgpack.unpack(data, offset - 1)
        offset = offset + 1
        for i = 1, #self.data.input_times do
            local time = self.data.input_times[i]
            self.input_data[time] = {}
            local changes
            changes, offset = love.data.unpack(">B", data, offset)
            for j = 1, changes * 2, 2 do
                local key, state
                key, state, offset = love.data.unpack(">BB", data, offset)
                self.input_data[time][j] = key
                self.input_data[time][j + 1] = state == 1
            end
        end
        self.score = love.data.unpack(">d", data, offset)
    else
        error("Unsupported replay format version '" .. version .. "'.")
    end
end

return replay
