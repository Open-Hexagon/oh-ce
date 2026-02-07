local overlay = require("ui.overlay")
local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local flex = require("ui.layout.flex")
local async = require("async")
local transitions = require("ui.anim.transitions")

local resolve = function(_) end
local dialog = overlay:new()
local dialog_label = label:new("", { wrap = true })
dialog.layout = flex:new({
    quad:new({
        child_element = flex:new({
            dialog_label,
            flex:new({
                quad:new({
                    child_element = label:new("Yes"),
                    selectable = true,
                    click_handler = function()
                        dialog.onclose = nil
                        dialog:close()
                        resolve(true)
                    end,
                }),
                quad:new({
                    child_element = label:new("No"),
                    selectable = true,
                    click_handler = function()
                        dialog:close()
                    end,
                }),
            }),
        }, { direction = "column", align_items = "center" }),
    }),
}, { justify_content = "center", align_items = "center" })
dialog.transition = transitions.scale

local dialogs = {}

function dialogs.yes_no(text)
    return async.promise:new(function(promise_resolve)
        resolve = promise_resolve
        dialog.onclose = function()
            resolve(false)
        end
        dialog_label.raw_text = text
        dialog_label.changed = true
        dialog_label:update_size()
        dialog:open()
    end)
end

local alert = overlay:new()
alert.transition = transitions.scale
local alert_label = label:new("", { wrap = true })
alert.layout = flex:new({
    quad:new({
        child_element = flex:new({
            alert_label,
            quad:new({
                child_element = label:new("Ok"),
                selectable = true,
                click_handler = function()
                    alert:close()
                end,
            }),
        }, { direction = "column", align_items = "center" }),
    }),
}, { justify_content = "center", align_items = "center" })

function dialogs.alert(text)
    alert_label.raw_text = text
    alert_label.changed = true
    alert_label:update_size()
    alert:open()
end

return dialogs
