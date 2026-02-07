local bit = require("bit")
local ffi = require("ffi")

local replay = {}

---read the old replay format and convert the data which is then put into the passed replay object
---@param replay_obj Replay
---@param data string
---@param offset number
function replay.read(replay_obj, data, offset)
    replay_obj.game_version = 21
    replay_obj.data.keys = { "keyboard_left", "keyboard_right", "keyboard_space", "keyboard_lshift" }
    replay_obj.data.config = {
        left = { { scheme = "keyboard", ids = { "left" } } },
        right = { { scheme = "keyboard", ids = { "right" } } },
        swap = { { scheme = "keyboard", ids = { "space" } } },
        focus = { { scheme = "keyboard", ids = { "lshift" } } },
    }
    -- the old format is platform specific, so let's make some assumptions to make it more consistent:
    -- sizeof(size_t) = 8
    -- sizeof(unsigned long long) = 8
    local function read_str()
        local len, str
        len, offset = love.data.unpack("<I4", data, offset)
        str, offset = love.data.unpack("<c" .. len, data, offset)
        return str
    end
    local function read_uint64()
        local part1, part2
        part1, offset = love.data.unpack("<I4", data, offset)
        part2, offset = love.data.unpack("<I4", data, offset)
        return bit.lshift(ffi.new("uint64_t", part2), 32) + part1
    end
    replay_obj.player_name = read_str()
    local seed = read_uint64()
    -- even if not correct, the first seed is only used for music segment (which was random in replays from this version)
    replay_obj.data.seeds[1] = ffi.tonumber(seed)
    replay_obj.data.seeds[2] = seed
    local input_len
    -- may cause issues with replays longer than ~9000 years
    input_len = ffi.tonumber(read_uint64())
    replay_obj.input_tick_length = input_len
    local state = { 0, 0, 0, 0 }
    local last_tick = 0
    for tick = 1, input_len do
        last_tick = tick
        local input_bitmask
        input_bitmask, offset = love.data.unpack("<B", data, offset)
        local changed = {}
        for input = 1, 4 do
            local key_state = bit.band(bit.rshift(input_bitmask, input - 1), 1)
            if state[input] ~= key_state then
                state[input] = key_state
                changed[#changed + 1] = input
                changed[#changed + 1] = key_state == 1
            end
        end
        if #changed ~= 0 then
            replay_obj.data.input_times[#replay_obj.data.input_times + 1] = tick
            replay_obj.input_data[tick] = changed
        end
    end
    local need_change = {}
    for i = 1, 4 do
        if state[i] == 1 then
            need_change[#need_change + 1] = i
            need_change[#need_change + 1] = false
        end
    end
    if #need_change ~= 0 then
        replay_obj.input_data[last_tick + 1] = need_change
    end
    replay_obj.pack_id = read_str()
    replay_obj.level_id = read_str()
    -- no need to prefix level id with pack id
    replay_obj.level_id = replay_obj.level_id:sub(#replay_obj.pack_id + 2)

    replay_obj.first_play, offset = love.data.unpack("<B", data, offset)
    replay_obj.first_play = replay_obj.first_play == 1
    local dm
    -- TODO: check if this works on all platforms (float and double are native size)
    dm, offset = love.data.unpack("<f", data, offset)
    replay_obj.data.level_settings = { difficulty_mult = dm }
    replay_obj.score = love.data.unpack("<d", data, offset) / 60
end

---write the old replay format from the passed replay object
---@param replay_obj Replay
---@return string
function replay.write(replay_obj)
    assert(replay_obj.game_version == 21, "the old replay format only works for the steam version")
    local data, offset = love.data.pack("string", ">I4", 0) -- format version
    -- resolve which input binding names correspond to the 4 steam version inputs
    local input_names = { "left", "right", "swap", "focus" }
    local resolved_inputs = {}
    local available_inputs = {}
    for i = 1, #input_names do
        local schemes = replay_obj.data.config[input_names[i]]
        resolved_inputs[i] = {}
        for j = 1, #schemes do
            local scheme = schemes[j]
            for k = 1, #scheme.ids do
                local binding = scheme.scheme .. "_" .. scheme.ids[k]
                resolved_inputs[i][j] = binding
                available_inputs[binding] = true
            end
        end
    end
    -- the old format only stores the 4 default inputs, anything more cannot be saved
    for i = 1, #replay_obj.data.keys do
        if not available_inputs[replay_obj.data.keys[i]] then
            error("Cannot convert replay with u_isKeyPressed data to old format.")
        end
    end
    -- same assumption about native size as in the read function
    local function write_str(str)
        data = data .. love.data.pack("string", "<I4c" .. #str, #str, str)
    end
    local function write_uint64(num)
        num = ffi.new("uint64_t", num)
        data = data
            .. love.data.pack(
                "string",
                "<I4I4",
                ffi.tonumber(bit.band(num, 0xFFFFFFFF)),
                ffi.tonumber(bit.rshift(num, 32))
            )
    end
    write_str(replay_obj.player_name)
    -- the steam version doesn't save the music seed
    write_uint64(replay_obj.data.seeds[2])
    write_uint64(replay_obj.input_tick_length)
    local input_state = {}
    for tick = 1, replay_obj.input_tick_length do
        for key, state in replay_obj:get_key_state_changes(tick) do
            input_state[key] = state
        end
        local input_bitmask = 0
        for input = 1, 4 do
            local state = false
            local bindings = resolved_inputs[input]
            for i = 1, #bindings do
                state = state or input_state[bindings[i]]
            end
            if state then
                input_bitmask = bit.bor(bit.lshift(1, input - 1), input_bitmask)
            end
        end
        data = data .. love.data.pack("string", "<B", input_bitmask)
    end
    write_str(replay_obj.pack_id)
    -- the steam version prefixes the level id with the pack id despite saving the pack id just earlier
    write_str(replay_obj.pack_id .. "_" .. replay_obj.level_id)

    assert(
        next(replay_obj.data.level_settings, "difficulty_mult") == nil,
        "replay has unsupported settings for the steam version"
    )
    -- TODO: check if this works on all platforms (float and double are native size)
    data = data
        .. love.data.pack(
            "string",
            "<Bfd",
            replay_obj.first_play and 1 or 0,
            replay_obj.data.level_settings.difficulty_mult or 1,
            replay_obj.score * 60
        )
    return data
end

return replay
