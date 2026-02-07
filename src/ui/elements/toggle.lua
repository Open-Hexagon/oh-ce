local element = require("ui.elements.element")
local signal = require("ui.anim.signal")
local theme = require("ui.theme")
local toggle = {}
toggle.__index = setmetatable(toggle, { __index = element })

function toggle:new(options)
    options = options or {}
    local obj = element.new(
        setmetatable({
            state = options.initial_state or false,
            state_indicator_offset = signal.new_queue(0),
            radius = options.radius or 16,
            border_thickness = theme.get("border_thickness"),
            selection_color = theme.get("selection_color"),
            light_selection_color = theme.get("light_selection_color"),
            background_color = theme.get("light_background_color"),
        }, toggle),
        options
    )
    obj.selectable = true
    obj.click_handler = function(elem)
        return elem:set(not elem.state)
    end
    if obj.state then
        obj.state_indicator_offset:set_immediate_value(obj.radius * 2)
    end
    obj.change_map.radius = true
    return obj
end

---set the toggle's state
---@param state boolean
---@return boolean?
function toggle:set(state)
    if self.state == state then
        return
    end
    self.state = state
    self.state_indicator_offset:stop()
    if self.state then
        self.state_indicator_offset:keyframe(0.1, self.radius * 2)
    else
        self.state_indicator_offset:keyframe(0.1, 0)
    end
    if self.change_handler then
        if self.change_handler(self.state) then
            return true
        end
    end
end

function toggle:set_style(style)
    self.background_color = self.style.background_color or style.background_color or self.background_color
    self.border_thickness = self.style.border_thickness or style.border_thickness or self.border_thickness
    self.selection_color = self.style.selection_color or style.selection_color or self.selection_color
    self.light_selection_color = self.style.light_selection_color
        or style.light_selection_color
        or self.light_selection_color
    element.set_style(self, style)
end

function toggle:calculate_element_layout()
    -- max and min size is the same, so available area doesn't matter here at all
    local radius = self.radius * self.scale
    return radius * 4, radius * 2
end

function toggle:draw_element()
    local radius = self.radius * self.scale
    if self.state then
        love.graphics.setColor(self.light_selection_color)
    else
        love.graphics.setColor(self.background_color)
    end
    local segments = 100
    love.graphics.circle("fill", radius, radius, radius, segments)
    love.graphics.circle("fill", 3 * radius, radius, radius, segments)
    love.graphics.rectangle("fill", radius, 0, 2 * radius, 2 * radius)
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", radius + self.state_indicator_offset() * self.scale, radius, radius, segments)
    if self.selected then
        love.graphics.setLineWidth(self.scale * self.border_thickness)
        love.graphics.setColor(self.selection_color)
        love.graphics.circle("line", radius + self.state_indicator_offset() * self.scale, radius, radius, segments)
    end
end

return toggle
