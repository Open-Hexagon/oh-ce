local log = require("log")(...)
local animated_transform = require("ui.anim.transform")
local keyboard_navigation = require("ui.keyboard_navigation")
local element = {}
element.__index = element
-- ensure that changed is set to true when any property in the change_map is changed
element.__newindex = function(t, key, value)
    if t.change_map[key] and t[key] ~= value then
        t.changed = true
    end
    rawset(t, key, value)
end

---create a new element, implements base functionality for all other elements (does nothing on its own)
---@param options any
---@return table
function element:new(options)
    options = options or {}
    self.changed = true
    self.change_map = {
        padding = true,
        scale = true,
    }
    self.style = options.style or {}
    self.scale = 1
    self.padding = 8
	self.margins = { 0, 0 }
    self.color = { 1, 1, 1, 1 }
    self.selectable = options.selectable or false
    self.is_mouse_over = false
    self.selected = false
    self.selection_handler = options.selection_handler
    self.click_handler = options.click_handler
    self.last_available_width = 0
    self.last_available_height = 0
    self.width = 0
    self.height = 0
    self.transform = animated_transform:new()
    self._transform = love.math.newTransform()
    self.local_mouse_x = 0
    self.local_mouse_y = 0
    self.expandable_x = 0
    self.expandable_y = 0
    if options.style then
        self:set_style(options.style)
    end
    return self
end

---set the style of the element
---@param style table
function element:set_style(style)
    self.margins = self.style.margins or style.margins or self.margins
    local new_padding = self.style.padding or style.padding or self.padding
    if self.padding ~= new_padding then
        self.changed = true
    end
    self.padding = new_padding
    self.color = self.style.color or style.color or self.color
end

---set the scale of the element
---@param scale number
function element:set_scale(scale)
    if self.scale ~= scale then
        self.changed = true
    end
    self.scale = scale
end

---calculate the element's layout
---@param width number
---@param height number
---@return number
---@return number
function element:calculate_layout(width, height)
    if self.last_available_width == width and self.last_available_height == height and not self.changed then
        return self.width, self.height
    end
    self.last_available_width = width
    self.last_available_height = height
    if self.calculate_element_layout then
        -- * 2 as padding is added on both sides
        local padding = self.padding * self.scale * 2
        self.width, self.height = self:calculate_element_layout(width - padding, height - padding)
        self.width = self.width + padding
        self.height = self.height + padding
        self.changed = false
    else
        log("Element has no calculate_element_layout function?")
    end
    self.expandable_x = width - self.width
    self.expandable_y = height - self.height
    return self.width, self.height
end

---follows the references to element's parent until an element has no parent, this element is returned
---@return table
function element:get_root()
    local function get_parent(elem)
        if elem.parent then
            return get_parent(elem.parent)
        end
        return elem
    end
    return get_parent(self)
end

---checks if the root element of this element corresponds to the screen the keyboard navigation is on
---@return boolean
function element:check_screen()
    return self:get_root() == keyboard_navigation.get_screen()
end

---simulate a click on the element
---@param should_select boolean
---@param keyboard_selected boolean
function element:click(should_select)
    if should_select == nil then
        should_select = true
    end
    if keyboard_selected == nil then
        keyboard_selected = false
    end
    if self.click_handler then
        self.click_handler(self)
    end
    if not self.selected and should_select then
        keyboard_navigation.select_element(self, true)
    end
end

---process an event (handles selection and clicking)
---@param name string
---@param ... unknown
---@return boolean?
function element:process_event(name, ...)
    ---converts a point to element space (top left corner of element = 0, 0)
    ---@param x number
    ---@param y number
    ---@return number
    ---@return number
    local function global_to_element_space(x, y)
        x, y = love.graphics.inverseTransformPoint(x, y)
        x, y = self._transform:inverseTransformPoint(x, y)
        return self.transform:inverseTransformPoint(x, y)
    end

    ---check if element contains a point
    ---@param x number
    ---@param y number
    ---@return boolean
    local function contains(x, y)
        x, y = global_to_element_space(x, y)
        return x >= 0 and y >= 0 and x <= self.width and y <= self.height
    end

    if name == "mousemoved" or name == "mousepressed" or name == "mousereleased" then
        local x, y = ...
        self.local_mouse_x, self.local_mouse_y = global_to_element_space(x, y)
        self.is_mouse_over = contains(x, y)
        if name == "mousereleased" and self.selectable then
            if self.click_handler and self.is_mouse_over then
                if self.click_handler(self) == true then
                    return true
                end
            end
            if self.selected ~= self.is_mouse_over then
                self.selected = self.is_mouse_over
                if self.selected then
                    keyboard_navigation.select_element(self, true)
                else
                    keyboard_navigation.deselect_element(self)
                end
            end
        end
    end
    if name == "keypressed" then
        local key = ...
        if key == "return" or key == "space" then
            if self.selected then
                if self.click_handler then
                    if self.click_handler(self) == true then
                        return true
                    end
                end
            end
        end
    end
end

---draw the element
function element:draw()
    love.graphics.push()
    love.graphics.applyTransform(self._transform)
    animated_transform.apply(self.transform)
    local padding = self.padding * self.scale
    love.graphics.translate(padding, padding)
    self:draw_element()
    love.graphics.pop()
end

return element
