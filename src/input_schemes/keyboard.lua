local keyboard = {
    defaults = {
        focus = { "lshift", "rshift" },
        right = { "right", "d" },
        left = { "left", "a" },
        swap = { "space" },
        exit = { "escape" },
        restart = { "up" },
        ui_backspace = { "backspace" },
        ui_delete = { "delete" },
        ui_up = { "up" },
        ui_down = { "down" },
        ui_left = { "left" },
        ui_right = { "right" },
        ui_click = { "return", "space" },
    },
}

function keyboard.is_down(key)
    return love.keyboard.isDown(key)
end

return keyboard
