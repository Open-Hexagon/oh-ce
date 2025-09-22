require("love.thread")
if arg == nil then
    -- called from thread
    local args = love.thread.getChannel("command_line_arguments"):peek()
    assert(args, "args.lua has to be included in main thread before usage in other threads")
    args.headless = true -- threads are always headless, this is a limitation of sdl which love is based on
    return args
end
local argparse = require("extlibs.argparse")

local parser = argparse("oh-ce", "Open Hexagon Community Edition")

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

local ret = parser:parse(love.arg.parseGameArguments(arg))
if (ret.server and not ret.render) or ret.migrate then
    ret.headless = true
end
ret.is_main_headless = ret.headless
love.thread.getChannel("command_line_arguments"):push(ret)
return ret
