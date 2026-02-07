require("platform")
require("love.timer")
require("love.event")
local socket = require("socket")
local player_tracker = require("server.player_tracker")
local argparse = require("extlibs.argparse")
local assets = require("asset_system")
local async = require("async")

local called_exit = false

-- make sure argparse can't just exit
-- (this is fine as this thread is isolated from everything else)
---@diagnostic disable-next-line
os.exit = function()
    called_exit = true
end

-- overwrite print so stdout gets sent to client
local client
print = function(...)
    if client then
        client:send(table.concat({ ... }, "\t") .. "\n")
    else
        print(...)
    end
end

local commands = {}
local parser = argparse("", "Server commands")
parser:command_target("command")

function commands.list(options)
    if options.players then
        for steam_id, username in pairs(player_tracker.get()) do
            print(("%s (%s)"):format(steam_id, username))
        end
    elseif options.packs then
        async.busy_await(assets.index.request("pack_level_data", "pack.load_register"))
        local packs = assets.mirror.pack_level_data
        for i = 1, #packs do
            local pack = packs[i]
            if pack.game_version == 192 or pack.game_version == 20 then
                print(
                    ("game_version=%d folder/id=%s name=%s levels=%d"):format(
                        pack.game_version,
                        pack.folder_name,
                        pack.name,
                        pack.level_count
                    )
                )
            else
                print(
                    ("game_version=%d folder=%s id=%s name=%s levels=%d"):format(
                        pack.game_version,
                        pack.folder_name,
                        pack.id,
                        pack.name,
                        pack.level_count
                    )
                )
            end
        end
    end
end
local list = parser:command("list")
list:command("players")
list:command("packs")

function commands.reload(options)
    if options.resource and options.recursive then
        assets.index.prefix_changed(options.id)
    elseif options.resource then
        assets.index.changed(options.id)
    else
        assets.index.reload(options.id)
    end
end
local reload = parser:command("reload")
reload:argument("id", "asset or resource id")
reload:flag("--resource", "indicates that the id argument is a resource id")
reload:flag("--recursive", "reload all resource ids starting with the id argument")

commands["inspect-asset-dependencies"] = function(options)
    if options.reverse then
        print(async.busy_await(assets.index.get_dependency_graph(options.asset_id)))
    else
        print(async.busy_await(assets.index.get_dependency_graph(options.asset_id, true)))
    end
end
local inspect_asset_dependencies = parser:command("inspect-asset-dependencies")
inspect_asset_dependencies:argument("asset_id")
inspect_asset_dependencies:flag("--reverse")

local exit_channel = love.thread.getChannel("scheduled_exit")
function commands.exit(options)
    local code = tonumber(options.code)
    if options.unschedule then
        exit_channel:clear()
    elseif options.schedule then
        exit_channel:push(code)
    else
        love.event.push("quit", code)
    end
end
local exit = parser:command("exit")
exit:argument("code"):default("0")
exit:mutex(
    exit:flag("--schedule", "schedules exit until nothing is happening"),
    exit:flag("--unschedule", "unschedules pending exit")
)

local sock = assert(socket.bind("localhost", 50506))
while true do
    client = sock:accept()
    local line = client:receive("*l")
    if line then
        local cmd = {}
        for part in line:gmatch("[^ \n]+") do
            cmd[#cmd + 1] = part
        end
        called_exit = false
        local success, result = parser:pparse(cmd)
        if not called_exit then
            if not success then
                print(("invalid command '%s': %s"):format(line, result))
            else
                commands[result.command](result)
            end
        end
    end
    client:close()
    client = nil
end
