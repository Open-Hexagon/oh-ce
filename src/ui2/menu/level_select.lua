local ui = require("ohui")
local cursor = ui.cursor
local theme = ui.theme

local level_select = {}

function level_select.main()
    cursor.change_anchor(0.5)
    ui.draw.by_cursor.label("level_select", 50, "center", false, theme.text_color)
end

return level_select
