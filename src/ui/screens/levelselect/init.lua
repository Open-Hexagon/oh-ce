local flex = require("ui.layout.flex")
local icon = require("ui.elements.icon")
local quad = require("ui.elements.quad")
local hexagon = require("ui.elements.hexagon")
local entry = require("ui.elements.entry")
local scroll = require("ui.layout.scroll")
local settings = require("ui.overlay.settings")
local pack_overlay = require("ui.overlay.packs")
local pack_elements = require("ui.screens.levelselect.packs")
local score = require("ui.screens.levelselect.score")
local options = require("ui.screens.levelselect.options")
local search = require("ui.search")
local dialog = require("ui.overlay.dialog")

local state = {}

local pack_elems = pack_elements.init(state)

state.packs = flex:new(pack_elems, { direction = "column", align_items = "stretch", align_relative_to = "area" })

state.levels = scroll:new(flex:new({}, { direction = "column", align_items = "center" }))

local packs = quad:new({
    child_element = scroll:new(state.packs),
})
packs.padding = 0

local info_column = quad:new({
    child_element = flex:new({
        score.layout,
        options.layout,
    }, { direction = "column", align_items = "stretch", align_relative_to = "area" }),
})
info_column.padding = 0

state.columns = flex:new({
    packs,
    state.levels,
    info_column,
}, { size_ratios = { 1, 2, 1 } })

local slope_width = 80

state.top_bar = flex:new({
    quad:new({
        child_element = flex:new({
            hexagon:new({
                child_element = icon:new("gear"),
                selectable = true,
                click_handler = function()
                    settings:open()
                end,
            }),
        }),
        vertex_offsets = { 0, 0, slope_width, 0, 0, 0, 0, 0 },
        limit_area = function(_, height)
            return love.graphics.getWidth() / 4 + slope_width, height
        end,
    }),
    entry:new({
        expand = true,
        no_text_text = "Search a level",
        change_handler = function(text)
            search.create_result_layout(text, state.levels.element.elements, state.levels.element)
        end,
    }),
    quad:new({
        child_element = flex:new({
            hexagon:new({
                child_element = icon:new("download"),
                selectable = true,
                click_handler = function()
                    pack_overlay:open()
                end,
            }),
        }, { justify_content = "end", align_relative_to = "area" }),
        vertex_offsets = { slope_width, 0, 0, 0, 0, 0, 0, 0 },
        limit_area = function(_, height)
            return love.graphics.getWidth() / 4 + slope_width, height
        end,
    }),
}, { justify_content = "between", align_relative_to = "area" })
state.top_bar.elements[1].padding = 0
state.top_bar.elements[3].padding = 0
state.top_bar.elements[1].flex_expand = 1
state.top_bar.elements[3].flex_expand = 1

state.root = flex:new({
    state.top_bar,
    state.columns,
}, { direction = "column", align_items = "stretch", align_relative_to = "area" })

if #pack_elems > 0 then
    pack_elems[1]:click(false)
end

state.root.state = state

return state.root
