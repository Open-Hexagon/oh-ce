local animated_transform = require("ui.anim.transform")
local element = require("ui.elements.element")
local theme = require("ui.theme")
local hexagon = {}
hexagon.__index = setmetatable(hexagon, {
    __index = element,
})

---create a new hexagon that can have a child element and a border
---@param options any
---@return table
function hexagon:new(options)
    options = options or {}
    local obj = element.new(
        setmetatable({
            element = options.child_element,
            border_thickness = theme.get("border_thickness"),
            border_color = theme.get("border_color"),
            background_color = theme.get("background_color"),
            vertices = {},
            prevent_child_expand = "all",
        }, hexagon),
        options
    )
    if obj.element then
        obj.element.parent = obj
    end
    obj.change_map.element = true
    return obj
end

---notify the element about mutations to its child
function hexagon:mutated()
    self.changed = true
    self:calculate_layout(self.last_available_width, self.last_available_height)
end

---set the style
---@param style table
function hexagon:set_style(style)
    if self.element then
        self.element:set_style(style)
        self.changed = self.changed or self.element.changed
    end
    self.background_color = self.style.background_color or style.background_color or self.background_color
    self.border_thickness = self.style.border_thickness or style.border_thickness or self.border_thickness
    self.border_color = self.style.border_color or style.border_color or self.border_color
    element.set_style(self, style)
end

---set the gui scale
---@param scale number
function hexagon:set_scale(scale)
    if self.element then
        self.element:set_scale(scale)
    end
    if self.scale ~= scale then
        self.changed = true
    end
    self.scale = scale
end

---process an event
---@param ... unknown
function hexagon:process_event(...)
    love.graphics.push()
    love.graphics.applyTransform(self._transform)
    animated_transform.apply(self.transform)
    if self.element then
        if self.element:process_event(...) then
            love.graphics.pop()
            return true
        end
    end
    love.graphics.pop()
    if element.process_event(self, ...) then
        return true
    end
end

---calculate the layout
---@param available_width number
---@param available_height number
---@return number
---@return number
function hexagon:calculate_element_layout(available_width, available_height)
    local size = math.min(available_width, available_height)
    local inner_size = 0.75 * size
    if self.element then
        local width, height = self.element:calculate_layout(inner_size, inner_size)
        local res_size = math.max(width, height)
        inner_size = res_size
        size = inner_size * 4 / 3
        self.element._transform:reset()
        self.element._transform:translate((size - width) / 2, (size - height) / 2)
    end
    return size, size
end

---draw the hexagon
---@param view table?
function hexagon:draw_element(view)
    local radius = math.max(self.width, self.height) / 2 - self.padding * self.scale
    love.graphics.translate(radius, radius)
    love.graphics.setColor(self.background_color)
    love.graphics.circle("fill", 0, 0, radius, 6)
    if self.border_thickness ~= 0 then
        love.graphics.setColor(self.border_color)
        love.graphics.setLineWidth(self.border_thickness * self.scale)
        love.graphics.circle("line", 0, 0, radius, 6)
    end
    love.graphics.translate(-radius, -radius)
    if self.element then
        self.element:draw(view)
    end
end

return hexagon
