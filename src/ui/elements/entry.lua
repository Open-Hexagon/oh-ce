local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local scroll = require("ui.layout.scroll")
local theme = require("ui.theme")
local entry = {}
entry.__index = setmetatable(entry, {
    __index = quad,
})

---create a new text entry
---@param options table?
---@return table
function entry:new(options)
    options = options or {}
    local text = options.initial_text or ""
    local text_label = label:new("")
    local obj = quad:new({
        child_element = scroll:new(text_label, { direction = "horizontal" }),
        selectable = true,
        selection_handler = function(elem)
            love.keyboard.setTextInput(elem.selected)
            theme.get_selection_handler()(elem)
        end,
        change_handler = options.change_handler,
    })
    setmetatable(obj, entry)
    obj.cursor_pos = 0
    obj.cursor_pixel_pos = 0
    obj.text = text
    obj.options = options
    obj.label = text_label
    -- overwrite label draw to put in cursor
    local old_draw = obj.label.draw_element
    obj.label.draw_element = function()
        old_draw(obj.label)
        if obj.selected then
            love.graphics.rectangle(
                "fill",
                obj.cursor_pixel_pos - obj.scale,
                0,
                obj.scale * 2,
                obj.label.height - 2 * obj.label.padding * obj.scale
            )
        end
    end
    obj:set_text(text)
    return obj
end

---set the current text inside the entry
---@param text string
function entry:set_text(text)
    self.text = text
    if text == "" and self.options.no_text_text then
        self.cursor_pos = 0
        self.cursor_pixel_pos = 0
        self.label.raw_text = self.options.no_text_text
        self.label:set_style({ color = theme.get("greyed_out_text_color") })
    else
        self.label.raw_text = text
        self.label:set_style({ color = theme.get("text_color") })
    end
    self.label.changed = true
    if self.parent then
        self:update_size()
    else
        self:calculate_layout(self.last_available_width, self.last_available_height)
    end
end

---calculate layout
---@param width number
---@param height number
---@return number
---@return number
function entry:calculate_element_layout(width, height)
    if self.options.expand then
        self.flex_expand = 1
    end
    local w, h = quad.calculate_element_layout(self, width, height)
    self.flex_expand = nil
    -- ensure scroll from start boundaries and not available area
    self.element.last_available_width = self.element.width
    self.element.last_available_height = self.element.height
    return w, h
end

---process an event
---@param name any
---@param ... unknown
function entry:process_event(name, ...)
    if quad.process_event(self, name, ...) then
        return true
    end
    if self.selected then
        local text = self.text
        local last_cursor_pos = self.cursor_pos
        local stop_propagation = false
        if name == "textinput" then
            text = text:sub(1, self.cursor_pos) .. ... .. text:sub(self.cursor_pos + 1, -1)
            self.cursor_pos = self.cursor_pos + 1
            stop_propagation = true
        end
        if name == "customkeyrepeat" or name == "customkeydown" then
            local key = ...
            if key == "ui_left" then
                self.cursor_pos = self.cursor_pos - 1
            elseif key == "ui_right" then
                self.cursor_pos = self.cursor_pos + 1
            elseif key == "ui_backspace" then
                text = text:sub(1, math.max(self.cursor_pos - 1, 0)) .. text:sub(self.cursor_pos + 1, -1)
                self.cursor_pos = self.cursor_pos - 1
            elseif key == "ui_delete" then
                text = text:sub(1, self.cursor_pos) .. text:sub(self.cursor_pos + 2, -1)
            end
        end
        if text ~= self.text then
            self:set_text(text)
            if self.change_handler then
                if self.change_handler(text) then
                    stop_propagation = true
                end
            end
        end
        if self.cursor_pos ~= last_cursor_pos then
            if self.cursor_pos > #text then
                self.cursor_pos = #text
            elseif self.cursor_pos < 0 then
                self.cursor_pos = 0
            end
            if self.cursor_pos ~= last_cursor_pos then
                self.element:scroll_into_view(
                    self.label.padding * self.scale + self.cursor_pixel_pos - self.scale * 20,
                    0,
                    self.scale * 40,
                    0
                )
                self.cursor_pixel_pos = self.label.text:getFont():getWidth(text:sub(1, self.cursor_pos))
                stop_propagation = true
            end
        end
        return stop_propagation
    end
end

return entry
