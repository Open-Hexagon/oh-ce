local ui = require("ohui")
local cursor = ui.cursor
local theme = ui.theme
local draw = ui.draw
local draw_by_cursor = draw.by_cursor

local debug = {}
local text_color = { 0, 0, 0, 0.5 }
local error_message
local error_message_time = 0

function debug.main()
    local text = string.format("%d fps", love.timer.getFPS())
    ui.draw.by_cursor.label(text, 12, "left", false, text_color)

    if error_message_time > 0 then
        cursor.reset()
        cursor.change_anchor(0, 1)
        local r = draw.allocate_reservation(1)
        draw_by_cursor.label(error_message, 12, "left", true)
        draw.next_takes_reservation(r)
        draw_by_cursor.rectangle(theme.black, "fill")
        error_message_time = error_message_time - love.timer.getDelta()
    end
end

function debug.set_error_message(str, time)
    local trimmed = string.match(str, ":%d+: (.*)")
    str = trimmed or str
    error_message = str
    error_message_time = time or 5
end

return debug
