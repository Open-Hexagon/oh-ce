local flex = require("ui.layout.flex")
local theme = require("ui.theme")
local quad = require("ui.elements.quad")
local entry = require("ui.elements.entry")
local label = require("ui.elements.label")
local icon = require("ui.elements.icon")
local element = require("ui.elements.element")
local dialog = require("ui.overlay.dialog")

local modifyable_list = {}
modifyable_list.__index = modifyable_list

function modifyable_list:new(callbacks)
    local flex_list = flex:new({}, { direction = "column", align_items = "stretch" })
    local new_entry = entry:new({ no_text_text = "Type a name" })
    local obj
    obj = setmetatable({
        callbacks = callbacks,
        items = {},
        flex_list = flex_list,
        new_entry = new_entry,
        layout = flex:new({
            flex_list,
            flex:new({
                new_entry,
                quad:new({
                    child_element = icon:new("plus-lg"),
                    selectable = true,
                    click_handler = function()
                        local name = new_entry.text
                        if name == "" then
                            dialog.alert("Entry name cannot be empty.")
                            return
                        end
                        for i = 1, #obj.items do
                            if obj.items[i] == name then
                                dialog.alert(("Entry with name '%s' already exists."):format(name))
                                return
                            end
                        end
                        obj:add(name)
                        new_entry:set_text("")
                        obj:select(name)
                    end,
                }),
            }, { justify_content = "between" }),
        }, { direction = "column", align_items = "stretch" }),
        do_refresh = true,
    }, modifyable_list)
    return obj
end

function modifyable_list:refresh()
    if self.do_refresh then
        self.flex_list:mutated(false)
        element.update_size(self.flex_list)
    end
end

function modifyable_list:clear()
    self.flex_list.elements = {}
    self.items = {}
    self:refresh()
end

function modifyable_list:set(strings, default_selection)
    self.do_refresh = false
    self:clear()
    for i = 1, #strings do
        self:add(strings[i])
    end
    self.do_refresh = true
    self:refresh()
    self:select(default_selection or strings[1])
end

function modifyable_list:add(str)
    self.callbacks.addition(str)
    local index = #self.flex_list.elements + 1
    self.flex_list.elements[index] = flex:new({
        quad:new({
            child_element = label:new(str),
            selectable = true,
            click_handler = function(elem)
                for i = 1, #self.flex_list.elements do
                    self.flex_list.elements[i].elements[1].background_color = theme.get("background_color")
                end
                elem.background_color = theme.get("transparent_light_selection_color")
                self.callbacks.selection(str)
            end,
        }),
        quad:new({
            child_element = icon:new("trash"),
            selectable = true,
            click_handler = function()
                if #self.items == 1 then
                    dialog.alert("Can't delete the last entry.")
                    return
                end
                dialog.yes_no(string.format("Do you really want to delete '%s'?", str)):done(function(confirmed)
                    if confirmed then
                        self:remove(str)
                    end
                end)
            end,
        }),
    }, { justify_content = "between" })
    self.items[index] = str
    self:refresh()
end

function modifyable_list:remove(str)
    for i = 1, #self.items do
        if self.items[i] == str then
            self.callbacks.deletion(str)
            table.remove(self.items, i)
            table.remove(self.flex_list.elements, i)
            self:refresh()
            self.flex_list.last_selection = nil
            if self.items[i - 1] then
                self:select(self.items[i - 1])
            elseif self.items[i] then
                self:select(self.items[i])
            end
            return
        end
    end
end

function modifyable_list:select(str)
    for i = 1, #self.items do
        if self.items[i] == str then
            self.flex_list.elements[i].elements[1]:click()
            return
        end
    end
end

return modifyable_list
