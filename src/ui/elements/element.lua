local log = require("log")(...)
local disabled_shader = require("ui.disabled")
local animated_transform = require("ui.anim.transform")
local keyboard_navigation = require("ui.keyboard_navigation")
local theme = require("ui.theme")
local element = {}
element.__index = element
-- ensure that changed is set to true when any property in the change_map is changed
element.__newindex = function(t, key, value)
    if t.change_map[key] and t[key] ~= value then
        t.changed = true
    end
    rawset(t, key, value)
end
-- element the user is currently clicking on (holding down)
local hold_element

---set which element the user is currently holding click on
---@param elem table?
local function set_hold_element(elem)
    if hold_element and hold_element.hold_handler then
        hold_element.hold_handler(hold_element, false)
    end
    hold_element = elem
    if elem and elem.hold_handler then
        elem.hold_handler(elem, true)
    end
end

---get outermost parent of element
---@param elem any
---@return unknown
local function get_parent(elem)
    if elem.parent then
        return get_parent(elem.parent)
    end
    return elem
end

---find a sufficiently expandable parent
---@param elem any
---@param amount_x number
---@param amount_y number
---@return any
local function find_expandable_parent(elem, amount_x, amount_y)
    elem.changed = true
    if elem.expandable_x >= amount_x and elem.expandable_y >= amount_y then
        return elem
    else
        if elem.parent then
            return find_expandable_parent(elem.parent, amount_x, amount_y)
        else
            log("no sufficiently expandable parent!")
            return elem
        end
    end
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
    self.color = theme.get("text_color")
    self.align = options.align
    self.selectable = options.selectable or false
    self.is_mouse_over = false
    self.selected = false
    self.selection_handler = options.selection_handler or theme.get_selection_handler()
    self.click_handler = options.click_handler
    self.hold_handler = options.hold_handler
    self.change_handler = options.change_handler
    self.limit_area = options.limit_area
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
    self.x = 0
    self.y = 0
    self.disabled = false
    self.deselect_on_disable = options.deselect_on_disable
    if self.deselect_on_disable == nil then
        self.deselect_on_disable = true
    end
    if options.style then
        self:set_style(options.style)
    end
    return self
end

---call after modifying element
function element:update_size()
    self.changed = true
    local old_width, old_height = self.width, self.height
    self:calculate_layout(self.last_available_width, self.last_available_height)
    local x = self.width - old_width
    local y = self.height - old_height
    if x == 0 and y == 0 then
        return
    end
    if x > 0 or y > 0 then
        self.last_space_maker = find_expandable_parent(self, x, y)
        if not self.last_space_maker.mutated then
            self.last_space_maker = nil
            return
        end
        self.last_space_maker:mutated()
    elseif self.last_space_maker then
        local parent = self.parent
        while parent ~= self.last_space_maker do
            parent.changed = true
            parent = parent.parent
        end
        self.last_space_maker:mutated()
    else
        local parent = self
        local last_parent_width, last_parent_height
        repeat
            parent = parent.parent
            if not parent then
                break
            end
            last_parent_width = parent.width
            last_parent_height = parent.height
            parent.changed = true
            parent:calculate_layout(parent.last_available_width, parent.last_available_height)
        until parent.width == last_parent_width and parent.height == last_parent_height
    end
end

function element:_update_child_expand()
    if self.parent and self.parent.prevent_child_expand then
        if self.parent.prevent_child_expand then
            self.expandable_x = 0
            self.expandable_y = 0
        end
    end
end

---set the style of the element
---@param style table
function element:set_style(style)
    local new_padding = self.style.padding or style.padding or self.padding
    if self.padding ~= new_padding then
        self.changed = true
    end
    self.padding = new_padding
    self.color = self.style.color or style.color or self.color
    if style.disabled ~= nil then
        self.disabled = style.disabled
    elseif self.style.disabled ~= nil then
        self.disabled = self.style.disabled
    end
    if self.deselect_on_disable then
        if self.disabled and self.selectable then
            self.was_selectable = true
            self.selectable = false
        end
        if not self.disabled and self.was_selectable then
            self.was_selectable = nil
            self.selectable = true
        end
    end
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
    if self.limit_area then
        width, height = self.limit_area(width, height)
    end
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
    self.expandable_x = math.max(width - self.width, 0)
    self.expandable_y = math.max(height - self.height, 0)
    self:_update_child_expand()
    return self.width, self.height
end

---follows the references to element's parent until an element has no parent, this element is returned
---@return table
function element:get_root()
    return get_parent(self)
end

---checks if the root element of this element corresponds to the screen the keyboard navigation is on
---@return boolean
function element:check_screen()
    return self:get_root() == keyboard_navigation.get_screen()
end

---simulate a click on the element
---@param should_select boolean
function element:click(should_select)
    if should_select == nil then
        should_select = true
    end
    if not self.selected and should_select then
        keyboard_navigation.select_element(self)
    end
    if self.click_handler then
        self.click_handler(self)
    end
end

---process an event (handles selection and clicking)
---@param name string
---@param ... unknown
---@return boolean?
function element:process_event(name, ...)
    if self.disabled then
        return
    end

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
        if name == "mousereleased" then
            if self.selectable then
                if self.selected ~= self.is_mouse_over then
                    self.selected = self.is_mouse_over
                    if self.selected then
                        keyboard_navigation.select_element(self)
                    else
                        keyboard_navigation.deselect_element(self)
                    end
                end
            end
            if self.click_handler and self.is_mouse_over then
                if self.click_handler(self) == true then
                    return true
                end
            end
        end
        if name == "mousepressed" and self.is_mouse_over then
            set_hold_element(self)
        end
        if name == "mousereleased" and self == hold_element then
            set_hold_element()
        end
    end
    if name == "customkeydown" then
        local key = ...
        if key == "ui_click" then
            if self.selected then
                set_hold_element(self)
                if self.click_handler then
                    if self.click_handler(self) == true then
                        return true
                    end
                end
            end
        end
    end
    if name == "customkeyup" then
        local key = ...
        if key == "ui_click" and self == hold_element then
            set_hold_element()
        end
    end
end

---draw the element
---@param view table
function element:draw(view)
    love.graphics.push()
    love.graphics.applyTransform(self._transform)
    animated_transform.apply(self.transform)
    self.x, self.y = love.graphics.transformPoint(0, 0)
    local padding = self.padding * self.scale
    love.graphics.translate(padding, padding)
    if self.disabled then
        local last_shader = love.graphics.getShader()
        love.graphics.setShader(disabled_shader)
        self:draw_element(view)
        love.graphics.setShader(last_shader)
    else
        self:draw_element(view)
    end
    love.graphics.pop()
end

return element
