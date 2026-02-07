local animated_transform = require("ui.anim.transform")
local element = require("ui.elements.element")

---@class flex
---@field direction string direction the flex container will position elements in
---@field size_ratios table? size ratios of the elements, length has to be identical to elements list
---@field align_items string aligns items on the container's thickness (values are "start", "stretch", "center" and "end")
---@field justify_content string justify content on the container's length (values are "start", "center", "between", "evenly" and "end")
---@field align_relative_to string set if aligning happens relative to given "area" or to "parent" size or to total "thickness"
---@field elements table list of children
---@field scale number ui scale
---@field style table not used, passed to children
---@field transform animated_transform transform the user can modify
---@field _transform love.Transform transform used for internal layouting
-- store last available width and height to respond to mutations
---@field last_available_width number
---@field last_available_height number
-- last resulting width and height
---@field width number
---@field height number
-- amount that children can expand (in pixels)
---@field expandable_x number
---@field expandable_y number
---@field prevent_child_expand string
---@field changed boolean something changed, requires layout recalculation
local flex = {}
flex.__index = flex
-- ensure that changed is set to true when any property in the change_map is changed
flex.__newindex = function(t, key, value)
    if t.change_map then
        if t.change_map[key] and t[key] ~= value then
            t.changed = true
        end
        rawset(t, key, value)
    end
end

local process_alignement_later = {}

---create a new flex container
---@param elements table
---@param options table?
---@return flex
function flex:new(elements, options)
    options = options or {}
    local obj = setmetatable({
        -- direction the flex container will position elements in
        direction = options.direction or "row",
        -- size ratios of the elements, length has to be identical to elements list
        size_ratios = options.size_ratios,
        -- aligns items on the container's thickness (values are "start", "stretch", "center" and "end")
        align_items = options.align_items or "start",
        -- justify content on the container's length (values are "start", "center", "between", "evenly" and "end")
        justify_content = options.justify_content or "start",
        -- set if aligning happens relative to given "area" or to "parent" size or to total "thickness"
        align_relative_to = options.align_relative_to or "parent",
        elements = elements,
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
        -- amount that children can expand
        expandable_x = 0,
        expandable_y = 0,
        -- something changed, requires layout recalculation
        changed = true,
        change_map = {
            direction = true,
            size_ratios = true,
            align_items = true,
            align_relative_to = true,
            scale = true,
        },
    }, flex)
    obj.prevent_child_expand = "horizontal"
    if options.direction == "column" then
        obj.prevent_child_expand = "vertical"
    end
    for i = 1, #elements do
        elements[i].parent = obj
        elements[i].parent_index = i
    end
    if options.style then
        obj:set_style(options.style)
    end
    return obj
end

---set the style of all children
---@param style table
function flex:set_style(style)
    for i = 1, #self.elements do
        self.elements[i]:set_style(style)
    end
    -- detect changes
    for key, value in pairs(style) do
        if self.style[key] ~= value then
            self.changed = true
            break
        end
    end
    if not self.changed then
        for key, value in pairs(self.style) do
            if style[key] ~= value then
                self.changed = true
                break
            end
        end
    end
    self.style = style
end

---set the gui scale of all elements in the flex container
---@param scale number
function flex:set_scale(scale)
    for i = 1, #self.elements do
        self.elements[i]:set_scale(scale)
    end
    if self.scale ~= scale then
        self.changed = true
    end
    self.scale = scale
end

---update the container when a child element changed size or when elements were added or removed
---@param calculate_layout boolean?
function flex:mutated(calculate_layout)
    for i = 1, #self.elements do
        local elem = self.elements[i]
        elem.parent = self
        elem.parent_index = i
        elem:set_scale(self.scale)
        elem:set_style(self.style)
    end
    self.changed = true
    if calculate_layout == nil or calculate_layout then
        self:calculate_layout(self.last_available_width, self.last_available_height)
    end
end

---send an event for the children to process (returns true if propagation should be stopped)
---@param name string
---@param ... unknown
---@return boolean?
function flex:process_event(name, ...)
    love.graphics.push()
    love.graphics.applyTransform(self._transform)
    animated_transform.apply(self.transform)
    for i = 1, #self.elements do
        if self.elements[i]:process_event(name, ...) then
            love.graphics.pop()
            return true
        end
    end
    love.graphics.pop()
end

---calculate the positions and size of the elements in the container (returns total width and height)
---@param width number
---@param height number
---@return number
---@return number
function flex:calculate_layout(width, height)
    if self.last_available_width == width and self.last_available_height == height and not self.changed then
        return self.width, self.height
    end
    self.last_available_width = width
    self.last_available_height = height
    -- define some useful values and functions depending on direction (this prevents cluttering the code with lots of ifs for the direction)
    local available_length, available_thickness, lt2wh, wh2lt
    if self.direction == "row" then
        -- container is a row
        -- +---+---+---+---+---+ ^
        -- |   |   |   |   |   | | thickness
        -- +---+---+---+---+---+ v
        -- <------------------->
        --        length
        available_length = width
        available_thickness = height
        --converts length and thickness to width and height (defaults to avalable area)
        lt2wh = function(length, thickness)
            return length or available_length, thickness or available_thickness
        end
        --converts witdth and height to length and thickness
        wh2lt = function(w, h)
            return w, h
        end
    else
        -- container is a column
        -- +---+ ^
        -- |   | |
        -- +---+ |
        -- |   | |
        -- +---+ |
        -- |   | | length
        -- +---+ |
        -- |   | |
        -- +---+ |
        -- |   | |
        -- +---+ v
        -- <--->
        --  thickness
        available_thickness = width
        available_length = height
        --converts length and thickness to width and height (defaults to avalable area)
        lt2wh = function(length, thickness)
            return thickness or available_thickness, length or available_length
        end
        --converts witdth and height to length and thickness
        wh2lt = function(w, h)
            return h, w
        end
    end
    -- for use in other functions
    self.lt2wh = lt2wh
    self.wh2lt = wh2lt
    -- set alignement options
    local has_non_start_align = false -- used later
    for i = 1, #self.elements do
        local elem = self.elements[i]
        local align = elem.align or self.align_items
        if align == "stretch" and self.align_relative_to == "area" then
            elem.flex_expand = self.direction == "row" and 2 or 1
        elseif align == "center" or align == "end" or align == "stretch" then
            has_non_start_align = true
        end
    end
    -- main layout calculation
    local final_thickness = 0
    local final_length = 0
    if self.size_ratios then
        -- available length is divided according to the given ratios
        -- e.g. this would be the result of this table: {1, 2, 1}
        -- +---+-------+---+
        -- | 1 |   2   | 1 |
        -- +---+-------+---+
        local ratio_sum = 0
        for i = 1, #self.size_ratios do
            ratio_sum = ratio_sum + self.size_ratios[i]
        end
        -- ratio_size_unit * ratio number in list = size of element (in length)
        local ratio_size_unit = available_length / ratio_sum
        local scale_factor = 1
        local length = 0
        local thickness = 0
        for i = 1, #self.elements do
            local size = self.size_ratios[i] * ratio_size_unit
            local len, thick = wh2lt(self.elements[i]:calculate_layout(lt2wh(size)))
            if len > size or thick > available_thickness then
                scale_factor = math.max(scale_factor, math.max(len / size, thick / available_thickness))
            end
            local transform = self.elements[i]._transform
            transform:reset()
            transform:translate(lt2wh(length, 0))
            length = length + size
            thickness = math.max(thickness, thick)
        end
        -- check if elements fit in the area
        if scale_factor ~= 1 then
            -- they don't fit, return larger area causing the gui scale to lower
            return width * scale_factor, height * scale_factor
        end
        -- size ratio layout calculation done
        final_length = length
        final_thickness = thickness
    else
        -- calculate the total and individual size of all elements (in flex direction)
        local sizes = {}
        local length = 0
        local thickness = 0
        for i = 1, #self.elements do
            -- give every element the whole area of the container and see how much space they take for now
            local len, thick = wh2lt(self.elements[i]:calculate_layout(lt2wh()))
            -- transform the element to its position
            local transform = self.elements[i]._transform
            transform:reset()
            transform:translate(lt2wh(length, 0))
            -- store the space it took
            sizes[i] = len
            -- add the space to the total space
            length = length + len
            thickness = math.max(thickness, thick)
        end
        if length > available_length then
            -- All elements together take too much size.
            -- possible output from the first step:
            -- +-----+----------+
            -- |     |          |
            -- +-----+----------+
            -- <---->
            --  available length
            local new_sizes = {}
            local last_sizes = {}
            for i = 1, #sizes do
                last_sizes[i] = sizes[i]
            end
            local too_large_set = {}
            local must_stop = false
            local original_length = length
            repeat
                -- calculate the total length of all elements that can no longer shrink (this is 0 for the first iteration)
                local taken = 0
                -- also calculate the amount of space that these elements took in the original attempt
                local original_taken = 0
                for i = 1, #new_sizes do
                    if new_sizes[i] ~= 0 or new_sizes[i] == sizes[i] then
                        taken = taken + new_sizes[i]
                        original_taken = original_taken + sizes[i]
                    end
                end
                -- if all elements can no longer shrink and still don't fit abort (gui scale will be lowered)
                if taken > available_length then
                    break
                end
                -- calculate a factor for scaling down each elements size so it barely fits
                -- if all elements manage to shrink the result from the above example would look like this:
                -- +-+--+
                -- | |  |
                -- +-+--+
                -- if some couldn't shrink in the last iteration then only scale down the remaining elements
                -- +--+--+
                -- |  |  | < this one must be scaled down more accordingly
                -- +--+--+                                               +-+
                --  ^                                                    | |
                --  couldn't shrink to fit in the prior calculated area: +-+
                --
                -- the scale factor is calculated like this like this:
                --   available_length - taken = now available length to fit all possibly shrinkable elements
                --   original_length - original_taken = total length the now possibly shrinkable elements took in the first attempt
                --   (original_length - original_taken) * factor = available_length - taken
                local factor = (available_length - taken) / (original_length - original_taken)
                thickness = 0
                length = 0
                for i = 1, #sizes do
                    local len, thick = wh2lt(self.elements[i].width, self.elements[i].height)
                    local target_length = sizes[i] * factor
                    -- only recalculate possibly shrinkable element layouts
                    if not too_large_set[i] then
                        len, thick = wh2lt(self.elements[i]:calculate_layout(lt2wh(target_length)))
                    end
                    if len > target_length then
                        too_large_set[i] = true
                        new_sizes[i] = len
                    else
                        -- keep array dimensions and order consistent
                        new_sizes[i] = 0
                    end
                    -- transform the element to its new position
                    local transform = self.elements[i]._transform
                    transform:reset()
                    transform:translate(lt2wh(length, 0))
                    length = length + len
                    thickness = math.max(thickness, thick)
                end
                -- stop if sizes didn't change from the last iteration
                must_stop = true
                for i = 1, #new_sizes do
                    if new_sizes[i] ~= last_sizes[i] then
                        must_stop = false
                        last_sizes[i] = new_sizes[i]
                    end
                end
            until length <= available_length or must_stop
        end
        -- default flex layout calculation done
        final_length = length
        final_thickness = thickness
    end
    -- cannot align relative to parent without parent, area has desired effect in this case
    if not self.parent and self.align_relative_to == "parent" then
        self.align_relative_to = "area"
    end
    if
        self.align_relative_to ~= "area"
        and self.align_relative_to ~= "thickness"
        and self.align_relative_to ~= "parent"
        and self.align_relative_to ~= "parentparent"
    then
        error("Invalid value for align_relative_to: '" .. self.align_relative_to .. "'.")
    end
    if self.align_relative_to == "area" and has_non_start_align then
        final_thickness = math.max(final_thickness, available_thickness)
    end
    if
        (self.align_relative_to == "parent" or self.align_relative_to == "parentparent")
        and (has_non_start_align or self.justify_content ~= "start")
    then
        process_alignement_later[#process_alignement_later + 1] = self
        self.must_calculate_alignement = true
        flex.must_calculate_alignement = true
    else
        if self.justify_content ~= "start" then
            self.final_length_before_adjust = final_length
            final_length = math.max(final_length, available_length)
        end
        self.width, self.height = lt2wh(final_length, final_thickness)
        self.must_calculate_alignement = true
        self:align_and_justify()
    end
    self.width, self.height = lt2wh(final_length, final_thickness)
    self.expandable_x = math.max(width - self.width, 0)
    self.expandable_y = math.max(height - self.height, 0)
    element._update_child_expand(self)
    self.changed = false
    self.chunks = nil
    return self.width, self.height
end

---modifies child transforms to respect align_items and justify_content options
function flex:align_and_justify()
    -- ensure that elements aren't moved more than once (they are moved relatively)
    if not self.must_calculate_alignement then
        return
    end
    self.must_calculate_alignement = false
    local final_length, final_thickness = self.wh2lt(self.width, self.height)
    if self.align_relative_to == "parentparent" then
        _, final_thickness = self.wh2lt(self.parent.width, self.parent.height)
        if self.parent.padding then
            final_thickness = final_thickness - 2 * self.parent.padding * self.scale
        end
    end
    for i = 1, #self.elements do
        local elem = self.elements[i]
        local align = elem.align or self.align_items
        -- no need to do anything on "start" it's the default
        if align == "stretch" and self.align_relative_to ~= "area" then
            local len, thick = self.wh2lt(elem.width, elem.height)
            thick = final_thickness
            elem.flex_expand = self.direction == "row" and 2 or 1
            elem:calculate_layout(self.lt2wh(len, thick))
            elem.flex_expand = nil
        elseif align == "stretch" then
            elem.flex_expand = nil
        elseif align == "center" then
            local _, thick = self.wh2lt(elem.width, elem.height)
            elem._transform:translate(self.lt2wh(0, final_thickness / 2 - thick / 2))
        elseif align == "end" then
            local _, thick = self.wh2lt(elem.width, elem.height)
            elem._transform:translate(self.lt2wh(0, final_thickness - thick))
        elseif align ~= "start" then
            error(
                "Invalid value for align option '"
                    .. align
                    .. "' possible values are: 'start', 'center', 'end' and 'stretch'"
            )
        end
    end
    if self.justify_content ~= "start" then
        local free_space = final_length - self.final_length_before_adjust
        self.final_length_before_adjust = nil
        if self.justify_content == "center" then
            local move = free_space / 2
            for i = 1, #self.elements do
                self.elements[i]._transform:translate(self.lt2wh(move, 0))
            end
        elseif self.justify_content == "between" then
            local gap_size = free_space / (#self.elements - 1)
            local move = gap_size
            -- first element stays, start at 2
            for i = 2, #self.elements do
                self.elements[i]._transform:translate(self.lt2wh(move, 0))
                move = move + gap_size
            end
        elseif self.justify_content == "evenly" then
            local gap_size = free_space / (#self.elements + 1)
            local move = gap_size
            for i = 1, #self.elements do
                self.elements[i]._transform:translate(self.lt2wh(move, 0))
                move = move + gap_size
            end
        elseif self.justify_content == "end" then
            for i = 1, #self.elements do
                self.elements[i]._transform:translate(self.lt2wh(free_space, 0))
            end
        else
            error(
                "Invalid value for justify_content option '"
                    .. self.justify_content
                    .. "' possible values are: 'start', 'center', 'between', 'evenly' and 'end'"
            )
        end
    end
end

local function get_rotation()
    local x1, y1 = love.graphics.transformPoint(0, 0)
    local x2, y2 = love.graphics.transformPoint(0, 100)
    return math.atan2(x2 - x1, y2 - y1)
end

local chunk_size = 500

local function generate_chunks(self)
    local size_name = self.direction == "row" and "width" or "height"
    self.chunks = {}
    local pos = 0
    for i = 1, #self.elements do
        local elem = self.elements[i]
        local chunk_start = math.floor(pos / chunk_size)
        pos = pos + elem[size_name]
        local chunk_end = math.ceil(pos / chunk_size)
        for index = chunk_start, chunk_end do
            self.chunks[index] = self.chunks[index] or {}
            self.chunks[index][#self.chunks[index] + 1] = elem
        end
    end
end

---draw all the elements in the container
---@param view table?
function flex:draw(view)
    if self.must_calculate_alignement then
        flex.process_alignement()
    end
    love.graphics.push()
    love.graphics.applyTransform(self._transform)
    animated_transform.apply(self.transform)
    self.x, self.y = love.graphics.transformPoint(0, 0)
    if #self.elements == 0 then
        love.graphics.pop()
        return
    end
    if not view or get_rotation() ~= 0 then
        for i = 1, #self.elements do
            self.elements[i]:draw(view)
        end
    else -- can only optimize easily if no rotation transform is present
        if not self.chunks then
            generate_chunks(self)
        end
        local view_x1, view_y1 = love.graphics.inverseTransformPoint(unpack(view, 1, 2))
        local view_x2, view_y2 = love.graphics.inverseTransformPoint(unpack(view, 3, 4))
        local local_start, local_end
        if self.direction == "row" then
            local_start = view_x1
            local_end = view_x2
        else
            local_start = view_y1
            local_end = view_y2
        end
        local chunk_start = math.floor(local_start / chunk_size)
        local chunk_end = math.ceil(local_end / chunk_size)
        for i = chunk_start, chunk_end do
            if self.chunks[i] then
                for j = 1, #self.chunks[i] do
                    local elem = self.chunks[i][j]
                    if not elem.was_drawn then
                        elem:draw(view)
                        if not self.chunks then
                            generate_chunks(self)
                            break
                        end
                        elem.was_drawn = true
                    end
                end
            end
        end
        for i = 1, #self.elements do
            self.elements[i].was_drawn = false
        end
    end
    love.graphics.pop()
end

function flex.process_alignement()
    local start_amount, end_amount
    repeat
        start_amount = #process_alignement_later
        for i = 1, #process_alignement_later do
            local elem = process_alignement_later[i]
            local parent = elem.parent
            elem.final_length_before_adjust = elem.wh2lt(elem.width, elem.height)
            if parent.direction == "row" then
                elem.height = parent.height
            elseif parent.direction == "column" then
                elem.width = parent.width
            end
            elem:align_and_justify()
        end
        end_amount = #process_alignement_later
    until start_amount == end_amount
    process_alignement_later = {}
end

return flex
