local quad = require("ui.elements.quad")
local label = require("ui.elements.label")
local icon = require("ui.elements.icon")
local flex = require("ui.layout.flex")
local theme = require("ui.theme")
local score = require("ui.screens.levelselect.score")

local options = {}

options.current = {}
local current_pack
local current_level
local profiles = {}
local profile_index = 1

local left_button = quad:new({
    child_element = icon:new("chevron-left"),
    selectable = true,
    deselect_on_disable = false,
    style = {
        background_color = theme.get("background_color"),
        border_color = theme.get("border_color"),
        border_thickness = 1,
    },
    selection_handler = function(self)
        theme.get_selection_handler()(self)
        self.style.border_color = self.border_color
    end,
    click_handler = function()
        options.change(-1)
    end,
})
local right_button = quad:new({
    child_element = icon:new("chevron-right"),
    selectable = true,
    deselect_on_disable = false,
    style = {
        background_color = theme.get("background_color"),
        border_color = theme.get("border_color"),
        border_thickness = 1,
    },
    selection_handler = function(self)
        theme.get_selection_handler()(self)
        self.style.border_color = self.border_color
    end,
    click_handler = function()
        options.change(1)
    end,
})

local function update_disabled_state()
    left_button.style.disabled = profile_index == 1
    left_button.disabled = profile_index == 1
    right_button.style.disabled = profile_index == #profiles
    right_button.disabled = profile_index == #profiles
end

local difficulty_profile_label = label:new("")

function options.set_profile(index)
    profile_index = index
    if current_pack.game_version ~= 3 then
        difficulty_profile_label.raw_text = tostring(current_level.options.difficulty_mult[index])
        difficulty_profile_label.changed = true
        difficulty_profile_label:update_size()
    end
    for key, value in pairs(current_level.options) do
        options.current[key] = value[index]
    end
    score.refresh(current_pack.id, current_level.id)
    update_disabled_state()
end

function options.set_level(pack, level)
    if pack.game_version ~= 3 then
        options.current = { difficulty_mult = 1 }
        profiles = level.options.difficulty_mult
        local found = false
        for i = 1, #profiles do
            if profiles[i] == options.current.difficulty_mult then
                profile_index = i
                found = true
                break
            end
        end
        if not found then
            error("difficulty mult 1 not in compat level's options!")
        end
    else
        -- TODO: set default profile_index
    end
    current_pack = pack
    current_level = level
    options.set_profile(profile_index)
end

function options.change(amount)
    profile_index = profile_index + amount
    if profile_index > #profiles then
        profile_index = #profiles
    elseif profile_index < 1 then
        profile_index = 1
    end
    options.set_profile(profile_index)
end

options.layout = flex:new({
    left_button,
    flex:new({
        difficulty_profile_label,
    }, { align_items = "center" }),
    right_button,
}, { justify_content = "between", align_relative_to = "area" })

left_button.style.disabled = true
left_button.disabled = true
right_button.style.disabled = true
right_button.disabled = true

return options
