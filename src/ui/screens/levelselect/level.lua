local preview = require("ui.screens.levelselect.level_preview")
local level_preview = require("ui.elements.level_preview")
local game_handler = require("game_handler")
local config = require("config")
local async = require("async")
local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local flex = require("ui.layout.flex")
local options = require("ui.screens.levelselect.options")
local theme = require("ui.theme")

local t = {}

t.current_preview = preview:new()
t.current_preview_active = false
local pending_promise
local last_pack, last_level
local set_preview_level = async(function(pack, level)
    last_pack = pack
    last_level = level
    if config.get("background_preview") == "full" then
        if pending_promise then
            async.await(pending_promise)
            pending_promise = nil
        end
        game_handler.set_version(pack.game_version)
        pending_promise = game_handler.preview_start(pack.id, level.id, {})
    else
        game_handler.stop()
        t.current_preview:set(pack.game_version, pack.folder_name, level.id)
        t.current_preview_active = true
    end
end)

local start_game = async(function(pack, level)
    local ui = require("ui")
    ui.open_screen("loading")
    if pending_promise then
        async.await(pending_promise)
    end
    game_handler.set_version(pack.game_version)
    async.await(game_handler.record_start(pack.id, level.id, options.current))
    ui.open_screen("game")
end)

local level_element_selected

function t.resume_preview()
    if last_pack and last_level then
        set_preview_level(last_pack, last_level)
    end
end

function t.create(state, pack, level, extra_info)
    extra_info = extra_info or {}
    extra_info.song = extra_info.song or "no song"
    extra_info.composer = extra_info.composer or "no composer"
    local music = extra_info.song .. "\n" .. extra_info.composer
    local preview_elem = level_preview:new(pack.game_version, pack.folder_name, level.id, { style = { padding = 4 } })
    return quad:new({
        child_element = flex:new({
            flex:new({
                preview_elem,
                flex:new({
                    label:new(level.name, { font_size = 40, wrap = true, style = { padding = 5 } }),
                    label:new(level.author, { font_size = 26, wrap = true, style = { padding = 5 } }),
                    label:new(level.description, { font_size = 16, wrap = true }),
                }, { direction = "column" }),
            }),
            --label:new(music, { font_size = 30 })
        }, { direction = "row", justify_content = "between", align_relative_to = "area" }),
        selectable = true,
        click_handler = function(self)
            if level_element_selected ~= self then
                local elems = self.parent.elements
                for i = 1, #elems do
                    elems[i].style.background_color = theme.get("background_color")
                end
                options.set_level(pack, level)
                self.style.background_color = theme.get("transparent_light_selection_color")
                state.columns:mutated()
                level_element_selected = self
                set_preview_level(pack, level)
            else
                start_game(pack, level, state)
            end
        end,
    })
end

return t
