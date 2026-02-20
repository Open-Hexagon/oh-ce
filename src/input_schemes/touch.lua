local args = require("args")
local controls
if not args.headless then
    -- TODO: remove
    controls = require("ui.screens.game.controls")
end
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
            -- prevent move on ui button press
            if not controls.is_in(x, y) then
                return true
            end
        end
    end
    return false
end

return touch
