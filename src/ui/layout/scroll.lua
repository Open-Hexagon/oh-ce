local animated_transform = require("ui.anim.transform")
local signal = require("ui2.anim.signal")
local ease = require("ui2.anim.ease")
local extmath = require("ui.extmath")
local update_expand = require("ui.elements.element")._update_child_expand

-- how much has to be moved on touchscreen until scrolling starts (if 0 clicking in a scrollable container becomes impossible as it's always registered as scroll since touch is analog input which will always have small fluctuations)
local SCROLL_THRESHOLD = 10

local scroll = {}
scroll.__index = scroll
-- ensure that changed is set to true when any property in the change_map is changed
scroll.__newindex = function(t, key, value)
    if t.change_map[key] and t[key] ~= value then
        t.changed = true
    end
    rawset(t, key, value)
end

---create a scroll container with a child element
---@param element table
---@return table
function scroll:new(element, options)
    options = options or {}
    if not element then
        error("cannot create a scroll container without a child element")
    end
    local obj = setmetatable({
        -- child element that will be made scrollable
        element = element,
        -- scroll direction of the container, only one is allowed (horizontal or vertical)
        direction = options.direction or "vertical",
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
        -- canvas may be nil if not scrollable, required when scrollable to cut content off
        canvas = nil,
        -- bool for the ui system to know that it may scroll child element boundaries into view (may be false if contents are small enough)
        scrollable = false,
        -- current scroll position (can animate scroll using signal)
        scroll_pos = signal.new_queue(0),
        -- max amount that can be scrolled
        max_scroll = 0,
        -- target of the current scroll animation
        scroll_target = 0,
        -- true while the user is dragging the scrollbar
        scrollbar_grabbed = false,
        -- timestamp of last scroll interaction, controls scrollbar vanishing
        scrollbar_visibility_timer = -2,
        -- controls if the scrollbar should vanish at all
        scrollbar_vanish = true,
        -- the color of the scrollbar
        scrollbar_color = { 1, 1, 1, 1 },
        -- the thickness of the scrollbar (height depends on content)
        scrollbar_thickness = 10,
        -- the position and dimensions of the scrollbar
        scrollbar_area = { x = 0, y = 0, width = 0, height = 0 },
        -- velocity of touch scroll
        scroll_velocity = 0,
        -- used for scroll
        last_mouse_pos = { 0, 0 },
        content_length = 0,
        change_handler = options.change_handler,
        last_content_length = 0,
        -- amount that children can expand
        expandable_x = 0,
        expandable_y = 0,
        -- something requiring layout recalculation changed
        changed = true,
        change_map = {
            scale = true,
        },
        -- position on screen
        x = 0,
        y = 0,
        prevent_child_expand = "all",
    }, scroll)
    obj.element.parent = obj
    if options.style then
        obj:set_style(options.style)
    end
    -- define convenience functions for converting width and height to length and thickness depending on scroll direction
    if obj.direction == "horizontal" then
        -- horizontally scrollable container
        --   <-- scroll -->
        -- +----------------+ ^
        -- |                | | thickness
        -- +----------------+ v
        -- <---------------->
        --       length
        obj.wh2lt = function(w, h)
            return w, h
        end
        obj.lt2wh = function(l, t)
            return l, t
        end
    elseif obj.direction == "vertical" then
        -- vertically scrollable container
        --        +---+ ^
        --      ^ |   | |
        --      | |   | |
        -- scroll |   | | length
        --      | |   | |
        --      v |   | |
        --        +---+ v
        --        <--->
        --      thickness
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
function scroll:set_style(style)
    self.element:set_style(style)
    if self.element.changed then
        self.changed = true
    end
    self.scrollbar_vanish = style.scrollbar_vanish or self.scrollbar_vanish
    self.scrollbar_color = style.scrollbar_color or self.scrollbar_color
    self.scrollbar_thickness = style.scrollbar_thickness or self.scrollbar_thickness
end

---set the gui scale
---@param scale any
function scroll:set_scale(scale)
    self.element:set_scale(scale)
    if self.scale ~= scale then
        self.changed = true
    end
    self.scale = scale
end

---update the container when the child's size is changed or when the child itself changes
function scroll:mutated()
    if self.element.parent ~= self then
        self.element.parent = self
    end
    self.changed = true
    self.element:set_scale(self.scale)
    self.element:set_style(self.style)
    self:calculate_layout(self.last_available_width, self.last_available_height)
end

---scroll some bounds in this container's coordinate system into view
---@param x number
---@param y number
---@param width number
---@param height number
---@param instant boolean?
function scroll:scroll_into_view(x, y, width, height, instant)
    if self.scrollable then
        local bounds_start = self.wh2lt(x, y)
        local bounds_end = self.wh2lt(x + width, y + height)
        local visual_length = self.wh2lt(self.width, self.height)
        if self.scroll_target > bounds_start then
            --          +---+------------+
            -- bounds > |   |    view    |
            --          +---+------------+
            -- view has to move so the start of the bounds (left side) is on the start of the view
            self.scroll_target = bounds_start
        elseif self.scroll_target + visual_length < bounds_end then
            -- +------------+---+
            -- |    view    |   | < bounds
            -- +------------+---+
            -- view has to move so the end of the bounds (right side) is on the end of the view
            self.scroll_target = bounds_end - visual_length
        end
        self:set_pos(self.scroll_target, instant)
    end
end

---set scroll pos directly
---@param scroll_pos number
---@param instant boolean?
function scroll:set_pos(scroll_pos, instant)
    if self.scrollable then
        local scroll_before = self.scroll_pos()
        self.scroll_target = extmath.clamp(scroll_pos, 0, self.max_scroll)
        if scroll_before ~= self.scroll_target then
            self.scroll_pos:stop()
            if instant then
                self.scroll_pos:set_immediate_value(self.scroll_target)
            else
                self.scrollbar_visibility_timer = love.timer.getTime()
                self.scroll_pos:keyframe(0.2, self.scroll_target)
            end
        end
    end
end

local function point_in_scrollbar(self, x, y)
    return x >= self.scrollbar_area.x
        and y >= self.scrollbar_area.y
        and x <= self.scrollbar_area.x + self.scrollbar_area.width
        and y <= self.scrollbar_area.y + self.scrollbar_area.height
end

---process an event
---@param name string
---@param ... unknown
function scroll:process_event(name, ...)
    love.graphics.push()
    -- can just apply transforms and scroll, canvas is only a rendering detail (may need to limit interaction to container dimensions though)
    love.graphics.applyTransform(self._transform)
    animated_transform.apply(self.transform)

    ---check if container contains a point
    ---@param x number
    ---@param y number
    ---@return boolean
    local function contains(x, y)
        return x >= 0 and y >= 0 and x <= self.width and y <= self.height
    end

    -- may not want to propagate events to children in certain cases (e.g. touch scroll is not a click)
    local propagate = true
    if name == "mousepressed" then
        local x, y = ...
        x, y = love.graphics.inverseTransformPoint(x, y)
        if point_in_scrollbar(self, x, y) then
            propagate = false
            self.scrollbar_grabbed = true
            require("ui").set_grabbed(self)
        end
    end

    -- stop propagating mouse presses if outside scroll container
    if name == "mousepressed" or name == "mousereleased" then
        local x, y = ...
        x, y = love.graphics.inverseTransformPoint(x, y)
        propagate = contains(x, y)
    end
    if name == "wheelmoved" then
        local x, y = love.graphics.inverseTransformPoint(love.mouse.getPosition())
        propagate = contains(x, y)
    end

    if name == "mousereleased" then
        if self.last_finger then
            -- last finger that touched the screen is not nil -> was touch scrolling
            propagate = false
            self.scroll_pos:stop()
            self.scroll_target = extmath.clamp(self.scroll_target + self.scroll_velocity * 10, 0, self.max_scroll)
            self.scroll_pos:keyframe(0.3, self.scroll_target, ease.out_sine)
        end
        if self.scrollbar_grabbed then
            -- scrollbar was grabbed, mouse was released to stop scrolling, not to click
            propagate = false
        end
        self.last_finger = nil
        self.last_finger_x = nil
        self.last_finger_y = nil
        self.first_touch_pos = nil
        self.scrollbar_grabbed = false
    end
    if propagate then
        love.graphics.push()
        love.graphics.translate(self.lt2wh(-self.scroll_pos(), 0))
        if self.element:process_event(name, ...) then
            love.graphics.pop()
            love.graphics.pop()
            return true
        end
        love.graphics.pop()
    end
    -- touch scroll
    if name == "touchmoved" and self.scrollable and not self.scrollbar_grabbed and not scroll.scrolled_already then
        local finger, x, y = ...
        x, y = love.graphics.inverseTransformPoint(x, y)
        if not self.first_touch_pos then
            self.first_touch_pos = { x, y }
        end
        if
            contains(x, y)
            and (
                math.abs(x - self.first_touch_pos[1]) > SCROLL_THRESHOLD
                or math.abs(y - self.first_touch_pos[2]) > SCROLL_THRESHOLD
                or self.last_finger ~= nil
            )
        then
            if finger == self.last_finger then
                -- get position change in scroll direction
                local dx = x - self.last_finger_x
                local dy = y - self.last_finger_y
                local scroll_delta = self.wh2lt(dx, dy)
                -- set scroll velocity to change amount
                self.scroll_velocity = -scroll_delta
                -- change scroll
                self.scroll_target = self.scroll_target - scroll_delta
                self.scroll_target = extmath.clamp(self.scroll_target, 0, self.max_scroll)
                self.scroll_pos:stop()
                self.scroll_pos:set_immediate_value(self.scroll_target)
                -- tell other containers that scroll is already happening
                scroll.scrolled_already = true
                -- show the scrollbar while scrolling
                self.scrollbar_visibility_timer = love.timer.getTime()
            end
            self.last_finger = finger
            self.last_finger_x = x
            self.last_finger_y = y
        end
    elseif name == "touchmoved" then
        -- forget last finger if moved without being able to scroll (avoids weird jumps)
        self.last_finger = nil
    end
    -- scrollbar grab scroll
    if name == "mousemoved" and self.scrollable then
        local x, y = ...
        x, y = love.graphics.inverseTransformPoint(x, y)
        if self.scrollbar_grabbed and not scroll.scrolled_already then
            local dx = x - self.last_mouse_pos[1]
            local dy = y - self.last_mouse_pos[2]
            local scroll_delta = self.wh2lt(dx, dy)
            local scrollbar_length = self.wh2lt(self.scrollbar_area.width, self.scrollbar_area.height)
            local visible_length = self.wh2lt(self.width, self.height)
            -- max amount the scrollbar itself can move
            local max_move = visible_length - scrollbar_length
            -- translate scrollbar movement to scroll position
            self.scroll_target = self.scroll_target + scroll_delta * self.max_scroll / max_move
            self.scroll_target = extmath.clamp(self.scroll_target, 0, self.max_scroll)
            self.scroll_pos:stop()
            self.scroll_pos:set_immediate_value(self.scroll_target)
            -- tell other containers that scroll is already happening
            scroll.scrolled_already = true
            -- show the scrollbar while scrolling
            self.scrollbar_visibility_timer = love.timer.getTime()
        elseif point_in_scrollbar(self, x, y) then
            -- show the scrollbar when hovering over it
            self.scrollbar_visibility_timer = love.timer.getTime()
        end
        self.last_mouse_pos[1] = x
        self.last_mouse_pos[2] = y
    end
    -- mouse wheel scroll
    if name == "wheelmoved" and self.scrollable and not scroll.scrolled_already then
        local x, y = love.mouse.getPosition()
        x, y = love.graphics.inverseTransformPoint(x, y)
        if contains(x, y) then
            -- when the mouse is inside the container move 50px depending on wheel direction
            local _, direction = ...
            self.scroll_target = self.scroll_target - 50 * direction
            self.scroll_target = extmath.clamp(self.scroll_target, 0, self.max_scroll)
            self.scroll_pos:stop()
            self.scroll_pos:keyframe(0.1, self.scroll_target)
            -- tell other containers that scroll is already happening
            scroll.scrolled_already = true
            -- show the scrollbar while scrolling
            self.scrollbar_visibility_timer = love.timer.getTime()
        end
    end
    love.graphics.pop()
end

---calculate the layout
---@param width number
---@param height number
---@return number
---@return number
function scroll:calculate_layout(width, height)
    if self.last_available_width == width and self.last_available_height == height and not self.changed then
        return self.width, self.height
    end
    self.last_available_width = width
    self.last_available_height = height
    local avail_len, avail_thick = self.wh2lt(width, height)
    local thick
    self.content_length, thick = self.wh2lt(self.element:calculate_layout(width, height))
    -- determine if container is overflowing
    --            overflow
    --           <---------->
    -- +---------+----------+
    -- |         |          |
    -- +---------+----------+
    -- <-------------------->
    --  content length
    -- <--------->
    --  avail_len
    local overflow = self.content_length - avail_len
    -- scroll if there is overflow
    self.scrollable = overflow > 0
    self.max_scroll = math.max(overflow, 0)
    local expandable_len = self.scrollable and math.huge or 0
    self.expandable_x, self.expandable_y = self.lt2wh(expandable_len, avail_thick - thick)
    self.expandable_x = math.max(self.expandable_x, 0)
    self.expandable_y = math.max(self.expandable_y, 0)
    update_expand(self)
    local _, expand_thick = self.wh2lt(self.expandable_x, self.expandable_y)
    self.expandable_x, self.expandable_y = self.lt2wh(expandable_len, expand_thick)
    self.width, self.height = self.lt2wh(math.min(self.content_length, avail_len), thick)
    self.changed = false
    return self.width, self.height
end

---draw the scroll container with its child
function scroll:draw()
    -- stop scroll from going over boundaries
    local new_scroll_target = extmath.clamp(self.scroll_target, 0, self.max_scroll)
    if self.scroll_target ~= new_scroll_target then
        self.scroll_target = new_scroll_target
        self.scroll_pos:stop()
        self.scroll_pos:set_immediate_value(self.scroll_target)
    end
    self.x, self.y = love.graphics.transformPoint(0, 0)
    if self.width <= 0 or self.height <= 0 then
        -- don't draw anything without having any size
        return
    end
    local size_changed = false
    if self.width ~= self.last_width or self.height ~= self.last_height then
        size_changed = true
        self.last_width = self.width
        self.last_height = self.height
    end
    if size_changed or (self.scrollable and not self.canvas) then
        local w = math.floor(self.width)
        local h = math.floor(self.height)
        if self.scrollable and w ~= 0 and h ~= 0 then
            -- dimensions changed or scrollable but no canvas created yet
            self.canvas = love.graphics.newCanvas(w, h)
        end
        self.last_width = self.width
        self.last_height = self.height
    end
    if
        self.scrollable
        and self.canvas
        and (
            self.scroll_pos() ~= self.last_scroll_value
            or size_changed
            or self.content_length ~= self.last_content_length
        )
    then
        if self.change_handler then
            self.change_handler(self.scroll_pos())
        end
        self.last_content_length = self.content_length
        self.last_scroll_value = self.scroll_pos()
        -- update the scrollbar area
        local normalized_scroll = self.last_scroll_value / self.max_scroll
        local visible_length, visible_thickness = self.wh2lt(self.width, self.height)
        local bar_thick = self.scrollbar_thickness * self.scale
        -- visible_length + self.max_scroll = content length
        -- visible_length / content length = ratio between content and visible length
        -- visible_length * ratio = scrollbar length
        -- put it together and you get:
        local bar_length = visible_length ^ 2 / (visible_length + self.max_scroll)
        -- max the scrollbar can move around
        local max_move = visible_length - bar_length
        self.scrollbar_area.x, self.scrollbar_area.y =
            self.lt2wh(normalized_scroll * max_move, visible_thickness - bar_thick)
        self.scrollbar_area.width, self.scrollbar_area.height = self.lt2wh(bar_length, bar_thick)
    end
    love.graphics.push()
    local last_canvas
    if self.scrollable and self.canvas then
        last_canvas = love.graphics.getCanvas()
        love.graphics.setCanvas(self.canvas)
        love.graphics.clear(0, 0, 0, 0)
        -- when drawing on canvas 0, 0 (origin) will always be the top left corner
        love.graphics.origin()
        love.graphics.translate(self.lt2wh(-self.scroll_pos(), 0))
        self.view = self.view or {}
        self.view[1], self.view[2] = 0, 0
        self.view[3], self.view[4] = self.width, self.height
    else
        -- when not drawing on canvas transformations have to be taken into account
        love.graphics.applyTransform(self._transform)
        animated_transform.apply(self.transform)
    end
    self.element:draw(self.view)
    if self.scrollable and self.canvas then
        love.graphics.setCanvas(last_canvas)
        love.graphics.pop()
        love.graphics.push()
        -- canvas is drawn with transformations now (elements in canvas are not)
        love.graphics.applyTransform(self._transform)
        animated_transform.apply(self.transform)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setBlendMode("alpha", "premultiplied")
        love.graphics.draw(self.canvas)
        love.graphics.setBlendMode("alpha", "alphamultiply")
        if self.scrollbar_vanish then
            -- visible for 1.5s after interaction, then fading out
            self.scrollbar_color[4] =
                math.min(math.max(1.5 - love.timer.getTime() + self.scrollbar_visibility_timer, 0), 1)
        end
        -- draw scrollbar
        love.graphics.setColor(self.scrollbar_color)
        love.graphics.rectangle(
            "fill",
            self.scrollbar_area.x,
            self.scrollbar_area.y,
            self.scrollbar_area.width,
            self.scrollbar_area.height
        )
    end
    love.graphics.pop()
end

return scroll
