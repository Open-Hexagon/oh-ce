local animated_transform = require("ui.anim.transform")
local signal = require("ui2.anim.signal")
local update_expand = require("ui.elements.element")._update_child_expand
local flex = require("ui.layout.flex")

local collapse = {}
collapse.__index = collapse
-- ensure that changed is set to true when any property in the change_map is changed
collapse.__newindex = function(t, key, value)
    if t.change_map[key] and t[key] ~= value then
        t.changed = true
    end
    rawset(t, key, value)
end

---create a collapsible container with a child element
---@param element table
---@return table
function collapse:new(element, options)
    options = options or {}
    if not element then
        error("cannot create a collapse container without a child element")
    end
    local obj = setmetatable({
        -- child element that will be made collapsible
        element = element,
        -- direction of the collapse animation, only one is allowed (horizontal or vertical)
        direction = options.direction or "vertical",
        -- reverse the direction of the animation
        reverse = options.reverse or false,
        scale = 1,
        style = {},
        -- transform the user can modify
        transform = animated_transform:new(),
        -- transform used for internal layouting
        _transform = love.math.newTransform(),
        -- store last available area in order to only recalculate this container's layout in response to mutation
        last_available_width = 0,
        last_available_height = 0,
        -- last resulting width and height
        width = 0,
        height = 0,
        -- keep track of that to determine when it's time to recreate the canvas (may not need to for every layout calculation)
        last_width = 0,
        last_height = 0,
        -- canvas may be nil initially, required to cut content off
        canvas = nil,
        -- current length, can animate size using signal
        pos = signal.new_queue(0),
        -- detect changes
        last_pos = 0,
        is_open = false,
        -- time it takes to open/close
        duration = options.duration or 0.2,
        -- how much child can expand
        expandable_x = 0,
        expandable_y = 0,
        -- something requiring layout recalculation changed
        changed = true,
        change_map = {
            scale = true,
            pos = true,
        },
        prevent_child_expand = "all",
    }, collapse)
    obj.element.parent = obj
    if options.style then
        obj:set_style(options.style)
    end
    -- define convenience functions for converting width and height to length and thickness depending on collapse direction
    if obj.direction == "horizontal" then
        -- horizontally collapsible container
        -- collapse -->
        -- +-----------+ ^
        -- |           | | thickness
        -- +-----------+ v
        -- <----------->
        --    length
        obj.wh2lt = function(w, h)
            return w, h
        end
        obj.lt2wh = function(l, t)
            return l, t
        end
    elseif obj.direction == "vertical" then
        -- vertically collapsible container
        --          +---+ ^
        -- collapse |   | |
        --        | |   | | length
        --        v |   | |
        --          +---+ v
        --          <--->
        --        thickness
        obj.wh2lt = function(w, h)
            return h, w
        end
        obj.lt2wh = function(l, t)
            return t, l
        end
    end
    return obj
end

---set the style
---@param style table
function collapse:set_style(style)
    self.element:set_style(style)
    if self.element.changed then
        self.changed = true
    end
end

---set the gui scale
---@param scale any
function collapse:set_scale(scale)
    self.element:set_scale(scale)
    if self.scale ~= scale then
        self.changed = true
    end
    self.scale = scale
end

---update the container when the child's size is changed or when the child itself changes
function collapse:mutated()
    if self.element.parent ~= self then
        self.element.parent = self
    end
    self.changed = true
    self.element:set_scale(self.scale)
    self.element:set_style(self.style)
    self:calculate_layout(self.last_available_width, self.last_available_height)
end

---process an event
---@param name string
---@param ... unknown
---@return boolean?
function collapse:process_event(name, ...)
    if self.pos() == self.content_length then
        love.graphics.push()
        love.graphics.applyTransform(self._transform)
        animated_transform.apply(self.transform)
        local res = self.element:process_event(name, ...)
        love.graphics.pop()
        return res
    end
end

---open or close the collapse
---@param bool boolean
function collapse:toggle(bool)
    local previous_state = self.is_open
    if bool == nil then
        self.is_open = not self.is_open
    else
        self.is_open = bool
    end
    if previous_state ~= self.is_open then
        self.pos:stop()
        if self.is_open then
            self.pos:keyframe(self.duration, self.content_length)
        else
            self.pos:keyframe(self.duration, 0)
        end
    end
end

---calculate the layout
---@param width number
---@param height number
---@return number
---@return number
function collapse:calculate_layout(width, height)
    if self.last_available_width == width and self.last_available_height == height and not self.changed then
        return self.width, self.height
    end
    self.last_available_width = width
    self.last_available_height = height
    self.element.flex_expand = self.flex_expand
    local content_width, content_height = self.element:calculate_layout(width, height)
    self.element.flex_expand = nil
    if not self.canvas or self.canvas:getWidth() ~= content_width or self.canvas:getHeight() ~= content_height then
        local w, h = math.floor(content_width + 0.5), math.floor(content_height + 0.5)
        if w ~= 0 and h ~= 0 then
            self.canvas = love.graphics.newCanvas(w, h)
        end
    end
    local fully_open = self.pos() == self.content_length
    local last_len = self.content_length
    self.content_length, self.content_thickness = self.wh2lt(content_width, content_height)
    if fully_open and self.content_length ~= last_len then
        self.pos:set_immediate_value(self.content_length)
    end
    self.width, self.height = self.lt2wh(self.pos(), self.content_thickness)
    self.expandable_x = math.max(width - self.width, 0)
    self.expandable_y = math.max(height - self.height, 0)
    update_expand(self)
    self.changed = false
    return self.width, self.height
end

---draw the collapse container with its child
function collapse:draw()
    if self.pos() ~= self.last_pos then
        self.last_pos = self.pos()
        self.changed = true
        require("ui.elements.element").update_size(self)
        flex.process_alignement()
    end
    if math.floor(self.width) == 0 or math.floor(self.height) == 0 or self.canvas == nil then
        -- don't draw anything without having any size or canvas
        return
    end
    -- draw child onto canvas
    love.graphics.push()
    local last_canvas = love.graphics.getCanvas()
    love.graphics.setCanvas(self.canvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    -- this way the child moves in
    -- closed state            animating state     open state
    -- +--------+              +--------+          +--------+
    -- |        +--------+     |    +---+----+     +--------+
    -- | canvas | child  | <-> | can| child  | <-> | child  |
    -- |        +--------+     |    +---+----+     +--------+
    -- +--------+              +--------+          +--------+
    -- (thickness stays the same, it's different here for better understanding)
    love.graphics.translate(self.lt2wh(self.content_length - self.pos(), 0))
    self.element:draw()
    love.graphics.setCanvas(last_canvas)
    love.graphics.pop()

    -- draw the canvas
    love.graphics.push()
    love.graphics.applyTransform(self._transform)
    animated_transform.apply(self.transform)
    -- negate the translation of the child, this way the child position is constant and just the cutoff from the canvas is moving
    love.graphics.translate(self.lt2wh(self.pos() - self.content_length, 0))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.draw(self.canvas)
    love.graphics.setBlendMode("alpha", "alphamultiply")
    love.graphics.pop()
end

return collapse
