local flex = require("ui.layout.flex")
local scroll = require("ui.layout.scroll")
local label = require("ui.elements.label")
local entry = require("ui.elements.entry")
local level_preview = require("ui.elements.level_preview")
local quad = require("ui.elements.quad")
local icon = require("ui.elements.icon")
local overlay = require("ui.overlay")
local transitions = require("ui.anim.transitions")
local search = require("ui.search")

local details = overlay:new()
local level_list = flex:new({}, { direction = "column", align_items = "stretch" })

function details.set_pack(pack)
    for i = 1, pack.level_count do
        local level = pack.levels[i]
        local preview =
            level_preview:new(pack.game_version, pack.id, level.id, { style = { padding = 4 }, has_pack = false })
        level_list.elements[i] = quad:new({
            child_element = flex:new({
                preview,
                flex:new({
                    label:new(level.name, { font_size = 40, wrap = true, style = { padding = 5 } }),
                    label:new(level.author, { font_size = 26, wrap = true, style = { padding = 5 } }),
                    label:new(level.description, { font_size = 16, wrap = true }),
                }, { direction = "column" }),
            }),
            selectable = true,
        })
    end
    while level_list.elements[pack.level_count + 1] do
        level_list.elements[#level_list.elements] = nil
    end
    if level_list.elements[1] then
        level_list:mutated(false)
        level_list.elements[1]:update_size()
    else
        level_list:mutated()
    end
end

details.layout = quad:new({
    child_element = flex:new({
        flex:new({
            entry:new({
                no_text_text = "Search levels",
                change_handler = function(text)
                    search.create_result_layout(text, level_list.elements, level_list)
                end,
            }),
            quad:new({
                child_element = icon:new("x-lg"),
                selectable = true,
                click_handler = function()
                    details:close()
                end,
            }),
        }, { justify_content = "between" }),
        scroll:new(level_list),
    }, { direction = "column" }),
})
details.layout.padding = 0

details.transition = transitions.slide

return details
