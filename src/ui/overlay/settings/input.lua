local input = require("ui.elements.input")
local config = require("config")
local flex = require("ui.layout.flex")
local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local collapse = require("ui.layout.collapse")
local input_schemes = require("input_schemes")
local async = require("async")

local function make_button(name, callback)
    return quad:new({
        child_element = label:new(name),
        selectable = true,
        click_handler = callback,
    })
end

local input_setting = {}
input_setting.__index = setmetatable(input_setting, { __index = flex })

function input_setting:new(property)
    local obj = setmetatable(flex:new({}, { direction = "column" }), input_setting)
    obj.property = property
    obj.scheme_select_collapse = collapse:new(flex:new({
        make_button("keyboard", function()
            obj.set_scheme("keyboard")
            return true
        end),
        make_button("mouse", function()
            obj.set_scheme("mouse")
            return true
        end),
        make_button("touch", function()
            obj.set_scheme("touch")
            return true
        end),
        make_button("cancel", function()
            obj.scheme_select_collapse:toggle(false)
            return true
        end),
    }))
    obj:init_bindings()
    return obj
end

function input_setting:init_bindings()
    self.schemes = config.get(self.property.name)
    local items = {}
    for i = 1, #self.schemes do
        for j = 1, #self.schemes[i].ids do
            local scheme_name = self.schemes[i].scheme
            local input_id = self.schemes[i].ids[j]
            items[#items + 1] = self:new_binding(scheme_name, input_id)
        end
    end
    items[#items + 1] = quad:new({
        child_element = label:new("+"),
        selectable = true,
        click_handler = function()
            async.promise
                :new(function(resolve)
                    self.set_scheme = resolve
                    self.scheme_select_collapse:toggle(true)
                end)
                :done(function(scheme)
                    self.scheme_select_collapse:toggle(false)
                    local input_id = input_schemes[scheme].defaults.right[1]
                    local scheme_index
                    for i = 1, #self.schemes do
                        if self.schemes[i].scheme == scheme then
                            scheme_index = i
                            break
                        end
                    end
                    if not scheme_index then
                        scheme_index = #self.schemes + 1
                        self.schemes[#self.schemes + 1] = {
                            scheme = scheme,
                            ids = { input_id },
                        }
                    else
                        self.schemes[scheme_index].ids[#self.schemes[scheme_index].ids + 1] = input_id
                    end
                    local elem = self:new_binding(scheme, input_id)
                    elem:click()
                end)
            return true
        end,
    })
    self.item_layout = flex:new(items, { align_items = "center" })
    self.layout = flex:new(
        { label:new(self.property.display_name), self.item_layout },
        { justify_content = "between", align_items = "center" }
    )
    self.elements = {
        self.layout,
        self.scheme_select_collapse,
    }
    self:mutated(false)
end

function input_setting:new_binding(scheme_name, input_id)
    local function search_indices()
        local scheme_index, id_index
        for k = 1, #self.schemes do
            if self.schemes[k].scheme == scheme_name then
                scheme_index = k
                break
            end
        end
        for k = 1, #self.schemes[scheme_index].ids do
            if self.schemes[scheme_index].ids[k] == input_id then
                id_index = k
                break
            end
        end
        return scheme_index, id_index
    end
    return quad:new({
        child_element = input:new(scheme_name, input_id, {
            change_handler = function(id)
                -- search scheme and id index as it may have change
                local scheme_index, id_index = search_indices()
                input_id = id
                self.schemes[scheme_index].ids[id_index] = id
            end,
        }),
        selectable = true,
        click_handler = function(elem)
            elem.element:wait_for_input():done(function(btn)
                local is_in = false
                for i = 1, #self.item_layout.elements do
                    if self.item_layout.elements[i] == elem then
                        is_in = true
                        break
                    end
                end
                if not is_in then
                    if btn then
                        return
                    end
                    table.insert(self.item_layout.elements, #self.item_layout.elements, elem)
                    self.item_layout:mutated(false)
                end
                if btn == "remove" then
                    -- search scheme and id index as it may have change
                    local scheme_index, id_index = search_indices()
                    table.remove(self.schemes[scheme_index].ids, id_index)
                    -- remove quad from parent
                    table.remove(elem.parent.elements, elem.parent_index)
                    self.item_layout:mutated(false)
                    self.layout.changed = true
                    require("ui.elements.element").update_size(self.item_layout)
                else
                    elem:update_size()
                end
            end)
            return true
        end,
    })
end

return input_setting
