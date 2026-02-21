local ohui = require("ohui")
local cursor = ohui.cursor
local theme = ohui.theme

local debug = {}
local text_color = {0, 0, 0, 0.5}
function debug.main()
    local text = string.format("%d fps", love.timer.getFPS())
    ohui.draw.by_cursor.label(text, 12, "left", false, text_color)
end

return debug
