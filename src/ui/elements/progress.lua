local element = require("ui.elements.element")
local theme = require("ui.theme")
local progress = {}
progress.__index = setmetatable(progress, {
    __index = element,
})

---create a new progress bar
---@param options table
---@return table
function progress:new(options)
    local obj = element.new(
        setmetatable({
            percentage = 0,
            background_color = theme.get("background_color"),
        }, progress),
        options
    )
    return obj
end

---set the style
---@param style table
function progress:set_style(style)
    self.background_color = self.style.background_color or style.background_color or self.background_color
    self.padding = 0
    element.set_style(self, style)
end

---calculate the layout
---@param available_width number
---@param available_height number
---@return number
---@return number
function progress:calculate_element_layout(available_width, available_height)
    local width = 100 * self.scale
    local height = 10 * self.scale
    if self.flex_expand then
        if self.flex_expand == 1 then
            -- only expand in width
            width = available_width
        elseif self.flex_expand == 2 then
            -- only expand in height
            height = available_height
        end
    end
    return width, height
end

---draw the progress bar
function progress:draw_element()
    love.graphics.setColor(self.background_color)
    love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", 0, 0, self.width * self.percentage / 100, self.height)
end

return progress
