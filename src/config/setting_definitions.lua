local game_input_methods = require("game_input.methods")
local ohui = require("ohui")
local ui_settings = ohui.settings
local auto_gui_scale = require("ui2.auto_gui_scale")
local buffer = require("string.buffer")

local categories, properties = ...

---creates a category
---@param name string
local function create_category(name)
    if categories[name] then
        error("category aleady exists", 2)
    end
    local c = { name = name }
    table.insert(categories, c)
    categories[name] = c
end

---add a setting to the config
---@param category string setting category
---@param name string internal setting name
---@param default number|string|boolean|table default value
---@param options table?
local function add_setting(category, name, default, options)
    if not categories[category] then
        error("category does not exist", 2)
    end
    if properties[name] then
        error("setting aleady exists", 2)
    end

    options = options or {}
    if options.can_change_in_offical == nil then
        options.can_change_in_offical = true
    end
    if not options.can_change_in_offical then
        options.dependencies = options.dependencies or {}
        options.dependencies.official_mode = false
    end

    local property = options -- reuse the options table for the settings

    property.name = name
    property.default = default
    if type(default) == "table" then
        -- if the default is a table, we encode it so it can be quickly deep copied if the default setting needs to be set.
        -- we don't want to reference the actual default table or else any edits to it will change the actual default value.
        property.default_serialized = buffer.encode(default)
    end
    property.category = category
    if not property.display_name then
        property.display_name = name:gsub("_", " "):gsub("^%l", string.upper)
    end

    properties[name] = property
    table.insert(categories[category], property)
end

local function add_input(name, versions)
    local default_bindings = {}
    for method_name, method in pairs(game_input_methods) do
        local defaults = method.defaults[name]
        if defaults and #defaults > 0 then
            default_bindings[method_name] = defaults
        end
    end
    add_setting("Input", name, default_bindings, {
        game_version = versions,
    })
end

-- ## BEGIN DEFINITIONS

-- create categories in order
create_category("Gameplay")
create_category("UI")
create_category("Audio")
create_category("General")
create_category("Display")
create_category("Input")

--#region Gameplay settings

add_setting("Gameplay", "game_resolution_scale", 1, {
    min = 1,
    max = 10,
    positions = 10,
    show_positions = true,
    onchange = function()
        require("game_handler").process_event("resize", love.graphics.getDimensions())
    end,
})

add_setting("Gameplay", "official_mode", true, {
    game_version = { 192, 20, 21, 3 },
    tooltip = [[
On: For competition. Scores are saved and submitted to leaderboards. Forces certain default settings to keep things fair.
Off: Enables more settings. Scores are saved but not submitted. Useful for level creation/debugging.]],
})
add_setting(
    "Gameplay",
    "beatpulse",
    true,
    { can_change_in_offical = false, game_version = { 192, 20, 21 }, tooltip = "The center polygon pulse." }
)
add_setting("Gameplay", "pulse", true, {
    can_change_in_offical = false,
    game_version = { 192, 20, 21 },
    tooltip = "The pulse of the whole level. It typically is what causes walls to slow down and speed up rhythmically.",
})
add_setting(
    "Gameplay",
    "black_and_white",
    false,
    { can_change_in_offical = false, game_version = { 192, 20, 21 }, tooltip = "Dog vision." }
)
add_setting("Gameplay", "3D_enabled", true, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("Gameplay", "background", true, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("Gameplay", "invincible", false, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("Gameplay", "rotation", true, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("Gameplay", "messages", true, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("Gameplay", "flash", true, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("Gameplay", "shaders", true, { can_change_in_offical = false, game_version = 21 })
add_setting("Gameplay", "player_tilt_intensity", 1, {
    game_version = 21,
    min = 0,
    max = 5,
    positions = 51,
    format = "%.1f",
    tooltip = "How much the player arrow tilts while moving.",
})
add_setting("Gameplay", "swap_blinking_effect", true, { game_version = 21 })
add_setting("Gameplay", "show_swap_particles", true, { game_version = 21 })
add_setting("Gameplay", "text_scale", 1, { game_version = 21, min = 0.1, max = 4, positions = 79, format = "%.2f" })
add_setting("Gameplay", "show_player_trail", false, { game_version = 21 })
add_setting("Gameplay", "player_trail_decay", 3, {
    game_version = 21,
    dependencies = { show_player_trail = true },
    min_display_text = "0.05",
    min = 0,
    max = 50,
    positions = 21,
    format = "%.1f",
})
add_setting("Gameplay", "player_trail_scale", 0.9, {
    game_version = 21,
    dependencies = { show_player_trail = true },
    min = 0.05,
    max = 1,
    positions = 20,
    format = "%.2f",
})
add_setting(
    "Gameplay",
    "player_trail_alpha",
    35,
    { game_version = 21, dependencies = { show_player_trail = true }, min = 0, max = 255, positions = 256 }
)
add_setting(
    "Gameplay",
    "player_trail_has_swap_color",
    true,
    { game_version = 21, dependencies = { show_player_trail = true } }
)

--#endregion

--#region UI settings

add_setting("UI", "gui_scale", 1, {
    display_name = "GUI scale",
    min = 0,
    max = 2,
    min_display_text = "Auto",
    positions = 5,
    format = "%.1fx",
    show_positions = true,
    onchange = function(value)
        if value > 0 then
            ui_settings.scale = value
        elseif value == 0 then
            ui_settings.scale = auto_gui_scale(love.graphics.getDimensions())
        else
            error("invalid gui_scale value")
        end
    end,
})
add_setting("UI", "input_display", true, { tooltip = "Display inputs on screen during gameplay." })
add_setting("UI", "background_preview_mode", 1, {
    options = { "Minimal", "Full" },
    onchange = function(value)
        if value == "full" then
            -- TODO: remove
            -- require("ui.screens.levelselect.level").resume_preview()
            -- require("ui.screens.levelselect.level").current_preview_active = false
        else
            -- TODO: remove
            -- require("game_handler").stop()
            -- require("ui.screens.levelselect.level").current_preview_active = true
        end
    end,
})
add_setting("UI", "background_preview_has_text", false, { dependencies = { background_preview_mode = 2 } })
add_setting("UI", "background_preview_music_volume", 0, {
    display_name = "BG preview music volume",
    min = 0,
    max = 1,
    positions = 101,
    inc_dec_buttons = 0,
    format = function(n)
        return tostring(n * 100) .. "%"
    end,
    onchange = function(value)
        require("game_handler").set_volume(value)
    end,
    dependencies = { background_preview_mode = 2 },
})
add_setting("UI", "background_preview_sound_volume", 0, {
    display_name = "BG preview sound volume",
    min = 0,
    max = 1,
    positions = 101,
    inc_dec_buttons = 0,
    format = function(n)
        return tostring(n * 100) .. "%"
    end,
    onchange = function(value)
        require("game_handler").set_volume(nil, value)
    end,
    dependencies = { background_preview_mode = 2 },
})

--#endregion

--#region Audio settings

add_setting("Audio", "sound_volume", 1, {
    game_version = { 192, 20, 21, 3 },
    min = 0,
    max = 1,
    positions = 101,
    inc_dec_buttons = 0,
    format = function(n)
        return tostring(n * 100) .. "%"
    end,
})
add_setting("Audio", "music_volume", 1, {
    game_version = { 192, 20, 21, 3 },
    min = 0,
    max = 1,
    positions = 101,
    inc_dec_buttons = 0,
    format = function(n)
        return tostring(n * 100) .. "%"
    end,
})
add_setting(
    "Audio",
    "sync_music_to_dm",
    true,
    { game_version = { 20, 21 }, display_name = "Sync music to difficulty multiplier" }
)
add_setting("Audio", "music_speed_mult", 1, {
    display_name = "Music speed multiplier",
    game_version = 21,
    min = 0.7,
    max = 1.3,
    positions = 13,
    format = "%.2fx",
    onchange = function()
        require("compat.game21").refresh_music_pitch()
    end,
})
add_setting("Audio", "play_swap_sound", true, { game_version = 21 })

--#endregion

--#region General settings

add_setting("General", "preload_all_packs", false)

--#endregion

--#region Display settings

add_setting("Display", "fps_limit", 60, {
    display_name = "FPS limit",
    min = 30,
    max = 1005,
    positions = 196,
    max_display_text = "Unlimited",
    inc_dec_buttons = true,
})
add_setting("Display", "fullscreen", 3, {
    options = { "Exclusive", "Borderless", "Windowed" },
    onchange = function(value)
        if love.window and love.window.isOpen() then
            love.window.setFullscreen(value ~= 3, value == 2 and "desktop" or "exclusive")
        end
    end,
})

--#endregion

--#region hidden settings

add_setting("hidden", "server_url", "openhexagon.fun")
add_setting("hidden", "server_http_api_port", 8003)
add_setting("hidden", "server_https_api_port", 8001)

-- Missing/hidden gameplay settings
-- These may be revealed at a later point
add_setting("hidden", "player_size", 7.3, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("hidden", "player_speed", 9.45, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("hidden", "player_focus_speed", 4.625, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("hidden", "3D_multiplier", 1, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("hidden", "3D_max_depth", 100, { can_change_in_offical = false, game_version = { 192, 20 } })
add_setting("hidden", "camera_shake_mult", 1, { game_version = 21 })

--#endregion

--#region Input settings

add_input("left", { 192, 20, 21 })
add_input("right", { 192, 20, 21 })
add_input("focus", { 192, 20, 21 })
add_input("swap", { 20, 21 })
add_input("exit", { 192, 20, 21, 3 })
add_input("restart", { 192, 20, 21, 3 })

--#endregion
