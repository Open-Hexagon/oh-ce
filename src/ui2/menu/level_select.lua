local ui = require("ohui")
local cursor = ui.cursor
local theme = ui.theme
local draw_by_cursor = ui.draw.by_cursor
local icon_button = ui.element.icon_button
local mnav = ui.control.mouse_navigation
local settings_menu = require("ui2.menu.settings")

local level_select = {}

function level_select.main()
    draw_by_cursor.rectangle(theme.get_xterm_color(75))
    cursor.change_anchor(0.5)
    draw_by_cursor.label("level_select", 50, "center", false, theme.text_color)

    cursor.x = 100
    cursor.y = 100

    icon_button(54, "gear")
    if mnav.get_clicked() then
        ui.layer.push(settings_menu)
    end
end

return level_select
