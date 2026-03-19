local game_input_methods = require("game_input.methods")
local config = require("config").settings

-- wrapper for game inputs to automate replay recording
local input = {
    ---@type Replay?
    replay = nil,
    is_done_replaying = false,
}
local recording = false
local input_state = {}
local time = 0
local replaying = false
local seed_index = 0

---starts recording all new inputs
function input.record_start()
    input.replay_stop()
    recording = true
    time = 0
    input_state = {}
end

---stops recording inputs
function input.record_stop()
    recording = false
end

---start replaying the active replay
function input.replay_start()
    input.record_stop()
    replaying = true
    time = 0
    seed_index = 0
    input_state = {}
    input.is_done_replaying = false
end

function input.is_replaying()
    return replaying
end

---save the next seed when recording or get the next seed when replaying
---@param seed number
---@return number
function input.next_seed(seed)
    if recording then
        input.replay:record_seed(seed)
        return seed
    elseif replaying then
        seed_index = seed_index + 1
        return input.replay.data.seeds[seed_index]
    end
    return seed
end

---stops replaying
function input.replay_stop()
    replaying = false
    input.is_done_replaying = true
end

---increments the timer for the input timestamps when recording and updates the input state when replaying
function input.update()
    if recording then
        time = time + 1
        input.replay.input_tick_length = time
    end
    if replaying then
        time = time + 1
        input.is_done_replaying = time >= input.replay.input_tick_length
        for key, state in input.replay:get_key_state_changes(time) do
            input_state[key] = state
        end
    end
end

-- common keys used to get player actions
local mapping = {
    lshift = "focus",
}

---gets the down state of any input (checks config for bindings, uses key if it doesn't exist)
---records changes if recording
---gets input state from replay if replaying
---@param input_name string
---@return boolean
function input.get(input_name)
    input_name = mapping[input_name] or input_name

    local inputs = config.get(input_name) or { {
        ids = { input_name },
        scheme = "keyboard",
    } }

    local ret = false
    for i = 1, #inputs do
        local scheme = inputs[i]
        for j = 1, #scheme.ids do
            local key = scheme.scheme .. "_" .. scheme.ids[j]
            local state
            if replaying then
                state = input_state[key] or false
            else
                state = game_input_methods[scheme.scheme].is_down(scheme.ids[j])
                if recording then
                    if input.replay == nil then
                        error("attempted to record input without active replay")
                    end
                    if input_state[key] ~= state then
                        input_state[key] = state
                        input.replay:record_input(key, state, time)
                    end
                end
            end
            ret = ret or state
        end
    end
    return ret
end

return input
