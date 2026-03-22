local logger = require("logging").get_logger(...)
local game_input_methods = require("game_input.methods")
local config = require("config").settings

-- wrapper for game inputs to automate replay recording
local game_input = {
    ---@type Replay?
    replay = nil,
    is_done_replaying = false,
}

---@type "idle"|"recording"|"replaying"
local mode = "idle"

---Only used for recording and replaying.
---For recording, this table is used to help record only *changes* to the input state.
---For replaying, previously saved inputs area read from here.
local input_state = {}

local time = 0
local seed_index = 0

---starts recording all new inputs
function game_input.record_start()
    mode = "recording"
    time = 0
    input_state = {}
end

---stops recording inputs
function game_input.record_stop()
    mode = "idle"
end

---start replaying the active replay
function game_input.replay_start()
    mode = "replaying"
    time = 0
    seed_index = 0
    input_state = {}
    game_input.is_done_replaying = false
end

function game_input.is_replaying()
    return mode == "replaying"
end

---save the next seed when recording or get the next seed when replaying
---@param seed number
---@return number
function game_input.next_seed(seed)
    if mode == "recording" then
        game_input.replay:record_seed(seed)
        return seed
    elseif mode == "replaying" then
        seed_index = seed_index + 1
        return game_input.replay.data.seeds[seed_index]
    else
        logger:warning("next_seed called while neither recording nor replaying")
    end
    return seed
end

---stops replaying
function game_input.replay_stop()
    mode = "idle"
    game_input.is_done_replaying = true
end

---increments the timer for the input timestamps when recording and updates the input state when replaying
function game_input.update()
    time = time + 1
    if mode == "recording" then
        game_input.replay.input_tick_length = time
    elseif mode == "replaying" then
        game_input.is_done_replaying = time >= game_input.replay.input_tick_length
        for key, state in game_input.replay:get_key_state_changes(time) do
            input_state[key] = state
        end
    else
        logger:warning("update called while neither recording nor replaying")
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
function game_input.get(input_name)
    input_name = mapping[input_name] or input_name

    local config_methods = config.get(input_name) or {
        keyboard = { input_name },
    }

    local ret = false
    for method_name, bindings in pairs(config_methods) do
        for j = 1, #bindings do
            local key = method_name .. "_" .. bindings[j]
            local state
            if mode == "replaying" then
                -- the input state would have been set up by the update function
                state = input_state[key] or false
            else
                state = game_input_methods[method_name].is_down(bindings[j])
                if mode == "recording" then
                    if game_input.replay == nil then
                        error("attempted to record input without active replay")
                    end
                    if input_state[key] ~= state then
                        input_state[key] = state
                        game_input.replay:record_input(key, state, time)
                    end
                end
            end

            -- input is true if any method is true
            ret = ret or state
        end
    end
    return ret
end

return game_input
