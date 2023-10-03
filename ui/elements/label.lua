local element = require("ui.elements.element")
local log = require("log")
local label = {}
label.__index = setmetatable(label, {
    __index = element,
})
local default_font_size = 32
local default_font_file = "assets/font/OpenSquare-Regular.ttf"
local cached_fonts = {}
cached_fonts[default_font_file] = {}
cached_fonts[default_font_file][default_font_size] = love.graphics.newFont(default_font_file, default_font_size)

---create a new label
---@param text string
---@param options table?
---@return table
function label:new(text, options)
    options = options or {}
    local font = cached_fonts[default_font_file]
    if options.font_file then
        if not cached_fonts[options.font_file] then
            cached_fonts[options.font_file] = {}
        end
        font = cached_fonts[options.font_file]
    end
    local font_size = options.font_size or default_font_size
    if not font[font_size] then
        font[font_size] = love.graphics.newFont(options.font_file or default_font_file, font_size)
    end
    local obj = element.new(
        setmetatable({
            raw_text = text,
            text = love.graphics.newText(font[font_size], text),
            wrap = options.wrap or false,
            font = font,
            font_file = options.font_file or default_font_file,
            font_size = font_size,
            cutoff_suffix = options.cutoff_suffix,
        }, label),
        options
    )
    obj.change_map.raw_text = true
    obj.change_map.wrap = true
    obj.change_map.font = true
    obj.change_map.font_file = true
    obj.change_map.font_size = true
    obj.change_map.cutoff_suffix = true
    return obj
end

---set the gui scale for the label
---@param scale number
function label:set_scale(scale)
    local font_size = math.floor(self.font_size * scale)
    if font_size == 0 then
        log("received invalid scale: ", scale)
        return
    end
    if not self.font[font_size] then
        self.font[font_size] = love.graphics.newFont(self.font_file, font_size)
    end
    self.text:setFont(self.font[font_size])
    if self.scale ~= scale then
        self.changed = true
    end
    self.scale = scale
end

---recalculate position and size depending on available area for the label, returns width and height
---@param available_width number
---@return number
---@return number
function label:calculate_element_layout(available_width)
    local width, height
    local function get_dimensions()
        width, height = self.text:getDimensions()
    end
    local text = self.raw_text
    if self.cutoff_suffix then
        local amount = #self.raw_text
        while self.text:getFont():getWidth(text) > available_width do
            amount = amount - 1
            if amount < 1 then
                break
            end
            text = self.raw_text:sub(1, amount) .. self.cutoff_suffix
        end
    end
    self.text:set(text)
    get_dimensions()
    if self.wrap and available_width < width then
        self.text:setf(self.raw_text, available_width, "left")
        get_dimensions()
    end
    return width, height
end

---draw the label
function label:draw_element()
    -- TODO: replace temporary visual selection state
    if self.selected then
        love.graphics.setColor(0, 0, 1, 1)
    else
        love.graphics.setColor(self.color)
    end
    love.graphics.draw(self.text)
end

return label
