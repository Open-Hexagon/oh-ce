local ui = require("ohui")
local cursor = ui.cursor
local theme = ui.theme
local loading_spinner = require("ui2.element.loading_spinner")

---@type layer
local loading = {}

local separation = 30

loading.on_push = loading_spinner.start
loading.on_pop = loading_spinner.stop

function loading.main()
    local x, y = cursor.width, cursor.height
    cursor.change_anchor(0.5)
    cursor.y = cursor.y - separation
    ui.draw.by_cursor.label("LOADING", 50, "center", false, theme.text_color)

    loading_spinner.element(x * 0.5, y * 0.5 + separation, 20, 4)
end

return loading
