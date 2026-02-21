local element = require("ui.elements.element")
local preview = require("ui.screens.levelselect.level_preview")
local signal = require("ui2.anim.signal")
local theme = require("ui.theme")
local level_preview = {}
level_preview.__index = setmetatable(level_preview, {
    __index = element,
})
local SIZE = 96

function level_preview:new(game_version, pack, level, options)
    local obj = element.new(
        setmetatable({
            preview = preview:new(),
            background_color = theme.get("background_color"),
            border_color = theme.get("border_color"),
            border_thickness = theme.get("border_thickness"),
            angle = signal.new_waveform(1, function(x)
                return x * 2 * math.pi
            end),
        }, level_preview),
        options
    )
    obj.preview:set(game_version, pack, level, options.has_pack)
    return obj
end

function level_preview:set_style(style)
    self.background_color = self.style.background_color or style.background_color or self.background_color
    self.border_thickness = self.style.border_thickness or style.border_thickness or self.border_thickness
    self.border_color = self.style.border_color or style.border_color or self.border_color
    element.set_style(self, style)
end

function level_preview:calculate_element_layout()
    return SIZE * self.scale, SIZE * self.scale
end

function level_preview:draw_element()
    local half_size = SIZE * self.scale / 2
    if self.preview.data then
        love.graphics.translate(half_size, half_size)
        love.graphics.scale(self.scale, self.scale)
        self.preview:draw()
        -- border
        love.graphics.setColor(self.border_color)
        love.graphics.setLineWidth(self.border_thickness)
        love.graphics.polygon("line", self.preview.vertices)
    else
        love.graphics.setColor(self.border_color)
        love.graphics.setLineWidth(self.scale * 5)
        love.graphics.circle("line", half_size, half_size, half_size / 2, 100)
        local half_sector_size = math.pi / 4
        local radius = half_size
        love.graphics.setColor(self.background_color)
        love.graphics.polygon(
            "fill",
            half_size,
            half_size,
            half_size + math.cos(self.angle() - half_sector_size) * radius,
            half_size + math.sin(self.angle() - half_sector_size) * radius,
            half_size + math.cos(self.angle() + half_sector_size) * radius,
            half_size + math.sin(self.angle() + half_sector_size) * radius
        )
    end
end

return level_preview
