local ohui = require("ohui")
local cursor = ohui.cursor
local theme = ohui.theme

local debug = {}

function debug.main()
    local text = string.format("%d fps", love.timer.getFPS())
    ohui.draw.by_cursor.label(text, 12, "left", false, theme.text_color)
end

return debug
