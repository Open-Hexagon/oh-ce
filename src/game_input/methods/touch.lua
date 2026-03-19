-- TODO something might be needed here to handle headless mode

local touch = {
    defaults = {
        right = { "right" },
        left = { "left" },
    },
}

function touch.is_down(side)
    local touches = love.touch.getTouches()
    local half_width = love.graphics.getWidth() / 2
    for i = 1, #touches do
        local id = touches[i]
        local x, y = love.touch.getPosition(id)
        if (side == "left" and x <= half_width) or (side == "right" and x >= half_width) then
            return true
        end
    end
    return false
end

return touch
