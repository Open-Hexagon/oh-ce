local flex = require("ui.layout.flex")
local quad = require("ui.elements.quad")
local label = require("ui.elements.label")
local theme = require("ui.theme")
local buttons = {}

local list = flex:new({}, { align_items = "end", justify_content = "end" })
buttons.layout = list
buttons.name_map = {}
buttons.holding = 0

---add a visual button for incomplete input schemes to use (e.g. touch)
---@param name string
---@return table
function buttons.add(name)
    local button = quad:new({
        child_element = label:new(name),
        hold_handler = function(self, state)
            self.ui_pressing = state
            if state then
                buttons.holding = buttons.holding + 1
            else
                buttons.holding = buttons.holding - 1
            end
        end,
    })
    table.insert(list.elements, 1, button)
    list.changed = true
    buttons.layout:mutated()
    buttons.name_map[name] = button
    return button
end

---get an existing button from its name
---@param name string
---@return table
function buttons.get(name)
    return buttons.name_map[name]
end

---set the real input state e.g. from a key press to display it on the button
---@param name string
---@param state boolean
function buttons.set_state(name, state)
    buttons.name_map[name].real_input_state = state
end

---check if a point is in one of the buttons
---@param x any
---@param y any
function buttons.is_in(x, y)
    for i = 1, #list.elements do
        local btn = list.elements[i]
        if x >= btn.x and y >= btn.y and x - btn.x <= btn.width and y - btn.y <= btn.height then
            return true
        end
    end
end

---update all buttons
function buttons.update()
    for i = #list.elements, 1, -1 do
        local btn = list.elements[i]
        if btn.updated then
            btn.pressing = btn.ui_pressing or btn.real_input_state
            if btn.pressing then
                btn.border_color = theme.get("selection_color")
                btn.border_thickness = theme.get("selection_border_thickness")
            else
                btn.border_color = theme.get("border_color")
                btn.border_thickness = theme.get("border_thickness")
            end
            btn.updated = false
        else
            table.remove(list.elements, i)
            list.changed = true
            buttons.name_map[btn.element.raw_text] = nil
            buttons.layout:mutated()
        end
    end
end

---remove all visual buttons
function buttons.clear()
    list.elements = {}
    list.changed = true
    buttons.layout:mutated()
    buttons.name_map = {}
end

return buttons
