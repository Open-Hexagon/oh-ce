local keyboard_navigation = require("ui.keyboard_navigation")
local element = require("ui.elements.element")
local signal = require("ui.anim.signal")
local extmath = require("ui.extmath")
local theme = require("ui.theme")
local slider = {}
slider.__index = setmetatable(slider, { __index = element })

function slider:new(options)
    options = options or {}
    local obj = element.new(
        setmetatable({
            steps = (options.steps or 3) - 1,
            step_size = options.step_size or 40,
            state = options.initial_state or 0,
            radius = options.radius or 16,
            background_color = { 0.5, 0.5, 0.5, 1 },
            selection_color = theme.get("selection_color"),
            border_thickness = theme.get("border_thickness"),
            position = signal.new_queue(0),
            grabbed = false,
        }, slider),
        options
    )
    obj.selectable = true
    obj.position:set_immediate_value(obj.state)
    obj.change_map.steps = true
    obj.change_map.step_size = true
    obj.change_map.radius = true
    return obj
end

function slider:process_event(name, ...)
    if element.process_event(self, name, ...) then
        return true
    end
    local last_state = self.state
    if name == "wheelmoved" and self.is_mouse_over and self:check_screen() then
        keyboard_navigation.select_element(self)
        local _, direction = ...
        self.state = extmath.clamp(self.state - direction, 0, self.steps)
    end
    local function move_state_to_mouse()
        self.state = math.floor((self.local_mouse_x - self.radius * self.scale) / (self.step_size * self.scale) + 0.5)
        self.state = extmath.clamp(self.state, 0, self.steps)
    end
    if name == "mousepressed" and self.is_mouse_over then
        self.grabbed = true
        require("ui").set_grabbed(self)
        keyboard_navigation.select_element(self)
        move_state_to_mouse()
    end
    if name == "mousemoved" and self.grabbed then
        move_state_to_mouse()
    end
    if name == "mousereleased" then
        if self.grabbed then
            self.grabbed = false
            require("ui").set_grabbed(nil)
            if self.change_handler then
                self.change_handler(self.state)
            end
            return true
        end
    end
    if (name == "customkeydown" or name == "customkeyrepeat") and self.selected then
        local key = ...
        if key == "ui_left" then
            self.state = extmath.clamp(self.state - 1, 0, self.steps)
        elseif key == "ui_right" then
            self.state = extmath.clamp(self.state + 1, 0, self.steps)
        end
    end
    if self.state ~= last_state then
        self.position:stop()
        self.position:keyframe(0.1, self.state)
        if self.change_handler then
            self.change_handler(self.state)
        end
        return true
    end
end

function slider:set(state)
    if state == self.state then
        return
    end
    self.state = state
    self.position:stop()
    self.position:keyframe(0.1, self.state)
    if self.change_handler then
        self.change_handler(self.state)
    end
end

function slider:set_style(style)
    self.background_color = self.style.background_color or style.background_color or self.background_color
    self.border_thickness = self.style.border_thickness or style.border_thickness or self.border_thickness
    self.selection_color = self.style.selection_color or style.selection_color or self.selection_color
    element.set_style(self, style)
end

function slider:calculate_element_layout()
    -- max and min size is the same, so available area doesn't matter here at all
    local diameter = self.radius * 2 * self.scale
    local width = self.steps * self.step_size * self.scale + diameter
    local height = diameter
    return width, height
end

function slider:draw_element()
    local radius = self.radius * self.scale
    local inner_radius = radius * 0.5
    local x = radius
    local y = radius
    local inner_width = self.steps * self.step_size * self.scale
    local segments = 100
    love.graphics.setColor(self.background_color)
    love.graphics.circle("fill", x, y, inner_radius, segments)
    love.graphics.circle("fill", x + inner_width, y, inner_radius, segments)
    love.graphics.rectangle("fill", x, y - inner_radius, inner_width, inner_radius * 2)
    love.graphics.setColor(self.color)
    local indicator_x = x + self.position() * self.step_size * self.scale
    love.graphics.circle("fill", indicator_x, y, radius, segments)
    if self.selected then
        love.graphics.setLineWidth(self.scale * self.border_thickness)
        love.graphics.setColor(self.selection_color)
        love.graphics.circle("line", indicator_x, y, radius, segments)
    end
end

return slider
