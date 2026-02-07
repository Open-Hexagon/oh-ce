local input = require("input")
local key_repeat = {}
local keys = { "ui_up", "ui_down", "ui_left", "ui_right", "ui_click", "ui_backspace", "ui_delete", "exit", "restart" }
local modules = { "ui", "game_handler" }
local states = {}
local press_timers = {}
local press_timer_repeat = {}

function key_repeat.update(dt)
    for i = 1, #keys do
        local state = input.get(keys[i], false)
        if state then
            press_timers[i] = (press_timers[i] or 0) + dt
            if press_timers[i] > (press_timer_repeat[i] or 0.4) then
                press_timers[i] = 0
                press_timer_repeat[i] = math.max((press_timer_repeat[i] or 0.4) - 0.05, 0.1)
                require("ui").process_event("customkeyrepeat", keys[i])
            end
        else
            press_timers[i] = 0
            press_timer_repeat[i] = 0.4
        end
        if state ~= states[i] then
            for j = 1, #modules do
                local module = require(modules[j])
                if state then
                    module.process_event("customkeydown", keys[i])
                else
                    module.process_event("customkeyup", keys[i])
                end
            end
        end
        states[i] = state
    end
end

return key_repeat
