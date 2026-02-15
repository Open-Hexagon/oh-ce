-- parses command line arguments

-- this is here only in case this gets run from a thread
require("love.thread")

local args
local ch = love.thread.getChannel("command_line_arguments")

if arg == nil then
    -- called from thread
    args = ch:peek()
    assert(args, "args.lua has to be included in main thread before usage in other threads")
    args.headless = true -- threads are always headless, this is a limitation of sdl which love is based on
    return args
end

local argparse = require("extlibs.argparse")

local parser = argparse("ohce", "Open Hexagon Community Edition")

parser:argument("replay_file", "Path to replay file."):args("?")
parser:flag(
    "--replay-viewer",
    "Close the game after replay has finished. Only does anything if a replay file is given."
)
parser:flag("--headless", "Run the game in headless mode.")
parser:flag("--server", "Start the game server.")
parser:flag("--render", "Render a video of the given replay. Also enables server side replay rendering for #1 scores.")
parser:flag("--web", "Enables the web api.")
parser:option("--migrate", "Steam version server database to migrate to new format."):argname("<path>")
parser
    :option(
        "--mount-pack-folder",
        "Mount a different pack folder/archive into the game. All packs in the folder/archive must have the same game version."
    )
    :args(2)
    :count("*")
    :argname({ "<192|20|21>", "<path>" })
parser:flag("--extract-working-replays", "Extracts all replays from submitted scores that are working.")
parser
    :flag("-l --logging-level", "Logging level. One of the following: 'DEBUG', 'INFO', 'WARNING', 'ERROR'.")
    :default("WARNING")
    :args(1)
parser:flag("--quiet", "don't print logs to stderr")

--TODO: These aren't being used yet. They'll be helpful once the new ui is in place
parser:option("--tickrate", "number of ticks per second (default is 60)", 60, tonumber, 1)
parser:flag("--overlay-masks", "(ui) overlay mask elements")
parser:flag("--overlay-mouse-sensors", "(ui) overlay mouse sensor elements")
parser:flag("--overlay-view-request", "(ui) overlay mouse view requests")
parser:option("--overlay-grid", "(ui) overlay grid and set its size", nil, tonumber, "?"):action(function(args, _, list)
    args.overlay_grid = list[1] or 50
end)

args = parser:parse(love.arg.parseGameArguments(arg))

if (args.server and not args.render) or args.migrate or args.extract_working_replays then
    args.headless = true
end
args.is_main_headless = args.headless

ch:push(args)

return args
