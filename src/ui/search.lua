local element = require("ui.elements.element")
local search = {}

---finds a text pattern in any type of element, returns the number of matches
---@param elem any
---@param pattern string
---@return number
function search.match(elem, pattern)
    local found_pattern = 0
    if elem.raw_text then
        local upper = elem.raw_text:upper()
        local init_pos = 1
        repeat
            local start_pos, end_pos = upper:find(pattern:upper(), init_pos, true)
            if end_pos then
                init_pos = end_pos + 1
                elem.highlights[#elem.highlights + 1] = { start_pos, end_pos }
                found_pattern = found_pattern + 1
            end
        until start_pos == nil
    elseif elem.element then
        found_pattern = found_pattern + search.match(elem.element, pattern)
    elseif elem.elements then
        for i = 1, #elem.elements do
            found_pattern = found_pattern + search.match(elem.elements[i], pattern)
        end
    end
    elem.changed = true
    return found_pattern
end

---returns a list of matching elements sorted by the number of matches
---@param pattern string
---@param elements table
---@return table
function search.find(pattern, elements)
    local results = {}
    local matches_per_result = {}
    for i = 1, #elements do
        local matches = search.match(elements[i], pattern)
        if matches > 0 then
            for j = 1, #results + 1 do
                if matches_per_result[j] == matches or matches_per_result[j] == nil then
                    table.insert(results, j, elements[i])
                    table.insert(matches_per_result, j, matches)
                    break
                end
            end
        end
    end
    return results
end

local function remove_highlights(elem)
    if elem.highlights then
        elem.highlights = {}
    elseif elem.element then
        remove_highlights(elem.element)
    elseif elem.elements then
        for i = 1, #elem.elements do
            remove_highlights(elem.elements[i])
        end
    end
    elem.changed = true
end

local old_layouts = {}
local old_parent_indices = {}
local old_parents = {}
local old_elements = {}

---adds all matching elements to a flex container for showing the result to the user
---also restores the original layout if the pattern is a empty string
---@param pattern string
---@param elements table
---@param flex_container flex
function search.create_result_layout(pattern, elements, flex_container)
    if old_layouts[flex_container] then
        if flex_container.elements == elements then
            elements = old_layouts[flex_container]
        end
        -- remove old highlights
        remove_highlights(flex_container)
    end
    if pattern == "" then
        if old_layouts[flex_container] then
            -- restore old layout
            flex_container.elements = old_layouts[flex_container]
            local elems = old_elements[flex_container]
            for i = 1, #elems do
                elems[i].parent = old_parents[flex_container][i]
                elems[i].parent_index = old_parent_indices[flex_container][i]
            end
            flex_container:mutated(false)
            flex_container.changed = true
            element.update_size(flex_container)
            flex_container.search_pattern = nil
        end
    else
        local results = search.find(pattern, elements)
        if not old_layouts[flex_container] then
            -- backup old layout
            local parent_indices = {}
            local parents = {}
            for i = 1, #elements do
                parents[i] = elements[i].parent
                parent_indices[i] = elements[i].parent_index
            end
            old_parent_indices[flex_container] = parent_indices
            old_parents[flex_container] = parents
            old_layouts[flex_container] = flex_container.elements
            old_elements[flex_container] = elements
        end
        flex_container.elements = results
        flex_container:mutated(false)
        flex_container.changed = true
        element.update_size(flex_container)
        flex_container.search_pattern = pattern
    end
    flex_container.last_selection = nil
end

return search
