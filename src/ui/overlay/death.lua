local flex = require("ui.layout.flex")
local quad = require("ui.elements.quad")
local label = require("ui.elements.label")
local overlay = require("ui.overlay")
local game_handler = require("game_handler")
local transitions = require("ui.anim.transitions")
local score = require("ui.screens.levelselect.score")

local death = overlay:new()

death.layout = flex:new({
    quad:new({
        child_element = label:new("Retry"),
        selectable = true,
        click_handler = function()
            game_handler.stop()
            death:close()
            game_handler.retry()
        end,
    }),
    quad:new({
        child_element = label:new("Back"),
        selectable = true,
        click_handler = function()
            local ui = require("ui")
            game_handler.preview_start("", "", {}, false, true)
            score.refresh()
            ui.open_screen("levelselect")
            death:close()
        end,
    }),
}, { align_items = "center", justify_content = "center" })

death.backdrop = false
death.transition = transitions.scale

return death
