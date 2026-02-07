local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local collapse = require("ui.layout.collapse")
local flex = require("ui.layout.flex")
local global_config = require("global_config")
local modifyable_list = require("ui.overlay.settings.modifyable_list")
local profile = require("game_handler.profile")
local score = require("ui.screens.levelselect.score")

local profile_name_label = label:new(profile.get_current_profile() or "")

local list = modifyable_list:new({
    deletion = function(name)
        profile.open_or_new(name)
        profile.delete()
    end,
    selection = function(name)
        global_config.set_game_profile(name)
        profile_name_label.raw_text = name
        profile_name_label.changed = true
        profile_name_label:update_size()
        score.refresh()
    end,
    addition = function(name)
        local profiles = profile.list()
        for i = 1, #profiles do
            if profiles[i] == name then
                return
            end
        end
        global_config.set_game_profile(name)
    end,
})

list:set(profile.list(), profile.get_current_profile())
local dropdown = collapse:new(list.layout)

local layout = flex:new({
    label:new("Game Profile:"),
    flex:new({
        quad:new({
            child_element = profile_name_label,
            selectable = true,
            click_handler = function()
                dropdown:toggle()
            end,
        }),
        dropdown,
    }, { direction = "column" }),
}, { align_items = "center" })

return layout
