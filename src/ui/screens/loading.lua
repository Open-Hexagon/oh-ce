local flex = require("ui.layout.flex")
local quad = require("ui.elements.quad")
local label = require("ui.elements.label")

local bar_label = label:new("Loading...", { wrap = true })
local bar = flex:new({
    quad:new({
        style = {
            background_color = { 1, 1, 1, 1 },
            border_thickness = 0,
            padding = 0,
        },
    }),
    quad:new({
        style = {
            background_color = { 0, 0, 0, 1 },
            border_thickness = 0,
            padding = 0,
        },
    }),
}, { size_ratios = { 0, 1 } })

local root = flex:new({
    flex:new({
        bar_label,
    }, { align_items = "end" }),
    quad:new({
        child_element = bar,
        style = { padding = 0 },
    }),
    label:new(""),
}, { align_items = "center", direction = "column", size_ratios = { 3, 1, 3 } })

return root
