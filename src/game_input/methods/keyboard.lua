local keyboard = {
    defaults = {
        focus = { "lshift", "rshift" },
        right = { "right", "d" },
        left = { "left", "a" },
        swap = { "space" },
        exit = { "escape" },
        restart = { "up" },
    },
}

function keyboard.is_down(key)
    return love.keyboard.isDown(key)
end

return keyboard
