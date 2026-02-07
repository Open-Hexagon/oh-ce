local flex = require("ui.layout.flex")
local label = require("ui.elements.label")
local profile = require("game_handler.profile")

local score = {}

local score_label = label:new("", { font_size = 60, cutoff_suffix = "..." })

score.layout = flex:new({
    label:new("Your Score:", { font_size = 16, wrap = true }),
    score_label,
}, { direction = "column", align_items = "stretch", align_relative_to = "area" })

local last_pack, last_level

function score.refresh(pack, level)
    local options = require("ui.screens.levelselect.options")
    pack = pack or last_pack
    level = level or last_level
    if not pack or not level then
        return
    end
    local data = profile.get_scores(pack, level, options.current)
    local number = 0
    for i = 1, #data do
        if data[i].score > number then
            number = data[i].score
        end
    end
    score_label.raw_text = tostring(math.floor(number * 1000) / 1000)
    score_label.changed = true
    score_label:update_size()
    last_pack = pack
    last_level = level
end

return score
