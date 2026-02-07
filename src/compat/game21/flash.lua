local set_color = require("compat.game21.color_transform")
local status = require("compat.game21.status")
local flash = {}
local game

function flash.init(pass_game)
    game = pass_game
    game.flash_color = { 255, 255, 255, 0 }
end

function flash.start_white()
    game.flash_color[1] = 255
    game.flash_color[2] = 255
    game.flash_color[3] = 255
    status.flash_effect = 255
end

function flash.update(frametime)
    if status.flash_effect > 0 then
        status.flash_effect = status.flash_effect - 3 * frametime
    end
    if status.flash_effect < 0 then
        status.flash_effect = 0
    elseif status.flash_effect > 255 then
        status.flash_effect = 255
    end
    game.flash_color[4] = status.flash_effect
end

function flash.draw(should_draw, zoom_factor)
    if game.flash_color[4] ~= 0 and should_draw then
        set_color(unpack(game.flash_color))
        love.graphics.rectangle("fill", 0, 0, game.width / zoom_factor, game.height / zoom_factor)
    end
end

return flash
