local config = require("config")
local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local collapse = require("ui.layout.collapse")
local flex = require("ui.layout.flex")
local global_config = require("global_config")
local modifyable_list = require("ui.overlay.settings.modifyable_list")

local profile_name_label = label:new(config.get_profile() or "")

local list = modifyable_list:new({
    deletion = function(name)
        config.delete_profile(name)
    end,
    selection = function(name)
        local current_profile_exists = false
        local profiles = config.list_profiles()
        for i = 1, #profiles do
            if profiles[i] == config.get_profile() then
                current_profile_exists = true
            end
        end
        if config.get_profile() ~= name and current_profile_exists then
            config.save()
        end
        global_config.set_settings_profile(name)
        for setting, value in pairs(config.get_all()) do
            require("ui.overlay.settings").set(setting, value)
        end
        profile_name_label.raw_text = name
        profile_name_label.changed = true
        profile_name_label:update_size()
    end,
    addition = function(name)
        local profiles = config.list_profiles()
        for i = 1, #profiles do
            if profiles[i] == name then
                return
            end
        end
        config.save()
        config.set_defaults()
        config.create_profile(name)
    end,
})

local function init()
    list:set(config.list_profiles(), config.get_profile())
end
local dropdown = collapse:new(list.layout)

local layout = flex:new({
    label:new("Settings Profile:"),
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

local old = layout.calculate_layout
layout.calculate_layout = function(...)
    init()
    layout.calculate_layout = old
    return old(...)
end

return layout
