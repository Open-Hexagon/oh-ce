local label = require("ui.elements.label")
local flex = require("ui.layout.flex")
local quad = require("ui.elements.quad")
local game_handler = require("game_handler")
local death_overlay = require("ui.overlay.death")
local buttons = require("ui.screens.game.controls")
local config = require("config")
local args = require("args")

local timer = quad:new({
    child_element = label:new("", { font_size = 64 }),
    style = { padding = 0, border_thickness = 0 },
    vertex_offsets = { 0, 0, 40, 0, 0, 0, 0, 0 },
})

local function back_to_menu(no_resume)
    death_overlay:close()
    local ui = require("ui")
    if not no_resume then
        game_handler.preview_start("", "", {}, false, true)
    end
    ui.open_screen("levelselect")
end

local stop_time

game_handler.onupdate = function()
    local score = game_handler.get_score()
    score = math.floor(score * 1000) / 1000
    local score_str = tostring(score)
    if score_str:match("%.") then
        -- find the amount of decimal digits
        local pos = score_str:find("%.")
        local places = #(score_str:sub(pos + 1))
        while places < 3 do
            places = places + 1
            score_str = score_str .. "0"
        end
    else
        -- no decimal digits, append .000
        score_str = score_str .. ".000"
    end
    timer.element.raw_text = score_str
    timer.element.changed = true
    timer:mutated()
    buttons.update()
    -- show death screen when dead
    if game_handler.is_dead() then
        if game_handler.is_replaying() then
            if not args.render then
                if args.replay_viewer then
                    if not stop_time then
                        stop_time = love.timer.getTime()
                    end
                    if love.timer.getTime() - stop_time > 3 then
                        love.event.push("quit")
                    end
                else
                    -- TODO: show appropriate ui when replay ends (retry/back buttons would be wrong here)
                    back_to_menu(config.get("background_preview") ~= "full")
                end
            end
        elseif not death_overlay.is_open then
            death_overlay:open()
        end
    elseif not game_handler.is_running() then
        -- execution aborted from somewhere else (not due to player death)
        back_to_menu(true)
    end
end

return flex:new({
    timer,
    buttons.layout,
})
