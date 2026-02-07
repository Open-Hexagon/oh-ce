local log = require("log")(...)
local args = require("args")
local music = require("compat.music")
local style = require("compat.game192.style")
local status = require("compat.game192.status")
local sound = require("compat.sound")
local executing_events = {}
local queued_events = {}
local events = {}
local level_events
local event_executors

local EventList = {}
EventList.__index = EventList

function EventList:new(event_table)
    return setmetatable({
        events = event_table,
        done = {},
        time = 0,
        finished = false,
    }, EventList)
end

function EventList:update(frametime)
    self.time = self.time + frametime / 60
    self.finished = self:execute(self.time)
end

function EventList:execute(time)
    local all_done = true
    for i = 1, #self.events do
        if not self.done[i] then
            all_done = false
            local event = self.events[i]
            local event_time = event.time or 0
            if event_time <= time then
                self.done[i] = true
                local executor = event_executors[event.type]
                if executor == nil then
                    log("Unknown event type '" .. event.type .. "'")
                else
                    executor(event)
                end
            end
        end
    end
    return all_done
end

-- initalize the events defined in the level json
function events.init(game, public)
    -- require here to avoid circular import
    local lua_runtime = require("compat.game192.lua_runtime")
    level_events = EventList:new(game.level_data.events == 0 and {} or game.level_data.events)
    executing_events = {}
    queued_events = {}
    event_executors = {
        level_change = function(event)
            status.must_restart = true
            game.restart_id = event.id:match("/(.*)"):match("/(.*)")
            game.restart_first_time = true
        end,
        menu = function()
            if public.death_callback then
                public.death_callback()
            end
            require("game_handler").stop()
        end,
        message_add = function(event)
            lua_runtime.env.messageAdd(event.message, event.duration)
        end,
        message_important_add = function(event)
            lua_runtime.env.messageImportantAdd(event.message, event.duration)
        end,
        message_clear = function()
            game.message_text = nil
        end,
        time_stop = function(event)
            status.time_stop = event.duration
        end,
        timeline_wait = function(event)
            game.main_timeline:append_wait(event.duration)
        end,
        timeline_clear = function()
            game.main_timeline:clear()
            game.main_timeline:reset()
        end,
        -- level float set, add, subtract, multiply, divide
        level_float_set = function(event)
            lua_runtime.env.setLevelValueFloat(event.value_name, event.value)
        end,
        level_float_add = function(event)
            lua_runtime.env.setLevelValueFloat(
                event.value_name,
                lua_runtime.env.getLevelValueFloat(event.value_name) + event.value
            )
        end,
        level_float_subtract = function(event)
            lua_runtime.env.setLevelValueFloat(
                event.value_name,
                lua_runtime.env.getLevelValueFloat(event.value_name) - event.value
            )
        end,
        level_float_multiply = function(event)
            lua_runtime.env.setLevelValueFloat(
                event.value_name,
                lua_runtime.env.getLevelValueFloat(event.value_name) * event.value
            )
        end,
        level_float_divide = function(event)
            lua_runtime.env.setLevelValueFloat(
                event.value_name,
                lua_runtime.env.getLevelValueFloat(event.value_name) / event.value
            )
        end,
        -- level int set, add, subtract, multiply, divide
        level_int_set = function(event)
            lua_runtime.env.setLevelValueInt(event.value_name, event.value)
        end,
        level_int_add = function(event)
            lua_runtime.env.setLevelValueInt(
                event.value_name,
                lua_runtime.env.getLevelValueFloat(event.value_name) + event.value
            )
        end,
        level_int_subtract = function(event)
            lua_runtime.env.setLevelValueInt(
                event.value_name,
                lua_runtime.env.getLevelValueFloat(event.value_name) - event.value
            )
        end,
        level_int_multiply = function(event)
            lua_runtime.env.setLevelValueInt(
                event.value_name,
                lua_runtime.env.getLevelValueFloat(event.value_name) * event.value
            )
        end,
        level_int_divide = function(event)
            lua_runtime.env.setLevelValueInt(
                event.value_name,
                lua_runtime.env.getLevelValueFloat(event.value_name) / event.value
            )
        end,
        -- style float set, add, subtract, multiply, divide
        style_float_set = function(event)
            lua_runtime.env.setStyleValueFloat(event.value_name, event.value)
        end,
        style_float_add = function(event)
            lua_runtime.env.setStyleValueFloat(
                event.value_name,
                lua_runtime.env.getLevelValueFloat(event.value_name) + event.value
            )
        end,
        style_float_subtract = function(event)
            lua_runtime.env.setStyleValueFloat(
                event.value_name,
                lua_runtime.env.getLevelValueFloat(event.value_name) - event.value
            )
        end,
        style_float_multiply = function(event)
            lua_runtime.env.setStyleValueFloat(
                event.value_name,
                lua_runtime.env.getLevelValueFloat(event.value_name) * event.value
            )
        end,
        style_float_divide = function(event)
            lua_runtime.env.setStyleValueFloat(
                event.value_name,
                lua_runtime.env.getLevelValueFloat(event.value_name) / event.value
            )
        end,
        -- style int set, add, subtract, multiply, divide
        style_int_set = function(event)
            lua_runtime.env.setStyleValueInt(event.value_name, event.value)
        end,
        style_int_add = function(event)
            lua_runtime.env.setStyleValueInt(
                event.value_name,
                lua_runtime.env.getLevelValueFloat(event.value_name) + event.value
            )
        end,
        style_int_subtract = function(event)
            lua_runtime.env.setStyleValueInt(
                event.value_name,
                lua_runtime.env.getLevelValueFloat(event.value_name) - event.value
            )
        end,
        style_int_multiply = function(event)
            lua_runtime.env.setStyleValueInt(
                event.value_name,
                lua_runtime.env.getLevelValueFloat(event.value_name) * event.value
            )
        end,
        style_int_divide = function(event)
            lua_runtime.env.setStyleValueInt(
                event.value_name,
                lua_runtime.env.getLevelValueFloat(event.value_name) / event.value
            )
        end,
        music_set = function(event)
            local new_music = game.pack.music[event.id]
            if new_music == nil then
                log("Music with id '" .. event.id .. "' not found")
                return
            end
            music.stop()
            music.play(new_music, true)
        end,
        music_set_segment = function(event)
            local new_music = game.pack.music[event.id]
            if new_music == nil then
                log("Music with id '" .. event.id .. "' not found")
                return
            end
            music.stop()
            music.play(new_music, (event.segment_index or 0) + 1)
        end,
        music_set_seconds = function(event)
            local new_music = game.pack.music[event.id]
            if new_music == nil then
                log("Music with id '" .. event.id .. "' not found")
                return
            end
            music.stop()
            music.play(new_music, false, event.seconds or 0)
        end,
        style_set = function(event)
            local style_data = game.pack.styles[event.id]
            if style_data == nil then
                log("Invalid style id '" .. event.id .. "'")
                return
            end
            style.select(style_data)
        end,
        side_changing_stop = function()
            status.random_side_changes_enabled = false
        end,
        side_changing_start = function()
            status.random_side_changes_enabled = true
        end,
        increment_stop = function()
            status.increment_enabled = false
        end,
        increment_start = function()
            status.increment_enabled = true
        end,
        event_exec = function(event)
            events.exec(game.pack.events[event.id])
        end,
        event_enqueue = function(event)
            events.queue(game.pack.events[event.id])
        end,
        script_exec = function(event)
            lua_runtime.run_lua_file(game.pack.info.path .. "Scripts/" .. event.value_name)
        end,
        play_sound = function(event)
            sound.play_pack(game.pack, event.id)
        end,
    }
end

function events.exec(event_table)
    if event_table ~= nil then
        executing_events[#executing_events + 1] = EventList:new(event_table)
    end
end

function events.queue(event_table)
    if event_table ~= nil then
        queued_events[#queued_events + 1] = EventList:new(event_table)
    end
end

function events.update(frametime, level_time, message_timeline)
    for i = #executing_events, 1, -1 do
        executing_events[i]:update(frametime)
        if executing_events[i].finished then
            table.remove(executing_events, i)
        end
    end
    if #queued_events ~= 0 then
        queued_events[1]:update(frametime)
        if queued_events[1].finished then
            table.remove(queued_events, 1)
        end
    end
    if not args.headless then
        message_timeline:update(frametime)
        if message_timeline.finished then
            message_timeline:clear()
            message_timeline:reset()
        end
    end
    level_events:execute(level_time)
end

return events
