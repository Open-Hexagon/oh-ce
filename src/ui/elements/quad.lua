local animated_transform = require("ui.anim.transform")
local element = require("ui.elements.element")
local theme = require("ui.theme")
local quad = {}
quad.__index = setmetatable(quad, {
    __index = element,
})

---create a new quad that can have a child element, offsetted vertices and a border
---@param options any
---@return table
function quad:new(options)
    options = options or {}
    local obj = element.new(
        setmetatable({
            vertex_offsets = options.vertex_offsets or { 0, 0, 0, 0, 0, 0, 0, 0 },
            element = options.child_element,
            border_thickness = theme.get("border_thickness"),
            border_color = theme.get("border_color"),
            background_color = theme.get("background_color"),
            vertices = {},
            prevent_child_expand = "all",
        }, quad),
        options
    )
    if obj.element then
        obj.element.parent = obj
    end
    obj.change_map.element = true
    obj.change_map.vertex_offsets = true
    return obj
end

---notify the element about mutations to its child
function quad:mutated()
    self.changed = true
    self:calculate_layout(self.last_available_width, self.last_available_height)
end

---set the style
---@param style table
function quad:set_style(style)
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
function quad:set_scale(scale)
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
function quad:process_event(...)
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
function quad:calculate_element_layout(available_width, available_height)
    local vertex_offsets = {}
    for i = 1, #self.vertex_offsets do
        -- offsets must be positive (outwards) and must be whole numbers
        vertex_offsets[i] = math.floor(math.abs(self.vertex_offsets[i]) * self.scale)
    end
    local top = math.max(vertex_offsets[2], vertex_offsets[4])
    local bot = math.max(vertex_offsets[6], vertex_offsets[8])
    local left = math.max(vertex_offsets[1], vertex_offsets[7])
    local right = math.max(vertex_offsets[3], vertex_offsets[5])
    local width = available_width - right - left
    local height = available_height - bot - top
    if self.element then
        if self.flex_expand then
            local res_width, res_height = self.element:calculate_layout(width, height)
            width = math.max(width, res_width)
            height = math.max(height, res_height)
            if self.flex_expand == 1 then
                -- only expand in width
                height = res_height
            elseif self.flex_expand == 2 then
                -- only expand in height
                width = res_width
            end
        else
            width, height = self.element:calculate_layout(width, height)
        end
        self.element._transform:reset()
        self.element._transform:translate(left, top)
    end
    self.vertices[1] = left - vertex_offsets[1]
    self.vertices[2] = top - vertex_offsets[2]
    self.vertices[3] = left + width + vertex_offsets[3]
    self.vertices[4] = top - vertex_offsets[4]
    self.vertices[5] = left + width + vertex_offsets[5]
    self.vertices[6] = top + height + vertex_offsets[6]
    self.vertices[7] = left - vertex_offsets[7]
    self.vertices[8] = top + height + vertex_offsets[8]
    return left + width + right, top + height + bot
end

---draw the quad
---@param view table
function quad:draw_element(view)
    love.graphics.setColor(self.background_color)
    love.graphics.polygon("fill", self.vertices)
    if self.border_thickness ~= 0 then
        love.graphics.setColor(self.border_color)
        love.graphics.setLineWidth(self.border_thickness * self.scale)
        love.graphics.polygon("line", self.vertices)
    end
    if self.element then
        self.element:draw(view)
    end
end

return quad
