local thread_id = require("thread_id")
local args = require("args")

---@alias stream {
---  write:fun(self:unknown, ...:any),
---  flush:fun(self:unknown)?,
---  close:fun(self:unknown)?,
---}

local logging = {
    DEBUG = 10,
    INFO = 20,
    WARNING = 30,
    ERROR = 40,
}

---@type stream[]
local streams = {}
local stream_levels = {}
local stream_preamble_formats = {}
local stream_level_labels = {}

local DEFAULT_LEVEL_LABELS = {
    [logging.DEBUG] = "DEBUG",
    [logging.INFO] = "INFO",
    [logging.WARNING] = "WARNING",
    [logging.ERROR] = "ERROR",
}
local DEFAULT_PREAMBLE_FORMAT = "%thread_id [%level] [%modname]"

---Writes a message across all streams
---@param level integer
---@param modname string
---@param ... unknown
local function write_all(level, modname, ...)
    local content = " " .. table.concat({ ... }, "\t") .. "\n"
    for i = 1, #streams do
        if level >= stream_levels[i] then
            local level_label = (stream_level_labels[i] or DEFAULT_LEVEL_LABELS)[level] or tostring(level)
            local preamble_format = stream_preamble_formats[i] or DEFAULT_PREAMBLE_FORMAT
            streams[i]:write(
                preamble_format
                    :gsub("%%thread_id", thread_id)
                    :gsub("%%timestamp", os.date("%H:%M:%S"))
                    :gsub("%%modname", modname)
                    :gsub("%%level", level_label) .. content
            )
        end
    end
end

---@class Logger
---@field modname string
local Logger = {}
Logger.__index = Logger

function Logger:debug(...)
    write_all(logging.DEBUG, self.modname, ...)
end

function Logger:info(...)
    write_all(logging.INFO, self.modname, ...)
end

function Logger:warning(...)
    write_all(logging.WARNING, self.modname, ...)
end

function Logger:error(...)
    write_all(logging.ERROR, self.modname, ...)
end

function Logger:not_implemented()
    local loc_info = debug.getinfo(2, "Sl")
    write_all(
        logging.ERROR,
        self.modname,
        string.format("%s:%s: not implemented", loc_info.short_src, loc_info.currentline)
    )
end

---Add a stream to log to. The preamble format string should contain exactly 4 '%s' format options.
---These are replaced in order of: thread_id, timestamp, level label, and modname.
---@param stream stream any table like object that has a write method e.g. io.stderr
---@param level integer logging level for this stream
---@param preamble_format string? preamble format string
---@param level_labels table<integer, string>? logging level number to level label
function logging.add_stream(stream, level, preamble_format, level_labels)
    local next_i = #streams + 1
    streams[next_i] = stream
    stream_levels[next_i] = level
    stream_preamble_formats[next_i] = preamble_format
    stream_level_labels[next_i] = level_labels
end

function logging.get_logger(modname)
    return setmetatable({ modname = modname }, Logger)
end

function logging.flush_all()
    for i = 1, #streams do
        if streams[i].flush then
            streams[i]:flush()
        end
    end
end

function logging.close_all()
    logging.flush_all()
    for i = 1, #streams do
        if streams[i].close then
            streams[i]:close()
        end
    end
end

local LOGGING_PATH = "logs/"
local MAX_LOG_FILES = 16

-- set up a log file
do
    require("love.thread")

    local ch = love.thread.getChannel("logging_file")

    if not love.filesystem.getInfo(LOGGING_PATH) then
        love.filesystem.createDirectory(LOGGING_PATH)
    end

    local log_file
    if arg == nil then
        -- called from thread
        log_file = ch:peek()
        assert(log_file, "logging.lua has to be included in main thread before usage in other threads")
    else
        -- create a new log file
        local attempt = 1
        local path

        local function get_path()
            local disambiguator
            if attempt == 1 then
                disambiguator = ""
            else
                disambiguator = "_" .. tostring(attempt)
            end
            path = LOGGING_PATH .. string.format("log_%s%s.txt", os.date("%Y%m%dT%H%M%S"), disambiguator)
        end

        get_path()

        while love.filesystem.getInfo(path) do
            attempt = attempt + 1
            get_path()
        end

        local err
        log_file, err = love.filesystem.openFile(path, "w")

        if not log_file then
            io.stderr:write(err)
            error("failed to create log file")
        end

        -- we can let the log file buffer since it will get flushed by the error handler when the game is quit
        ch:push(log_file)
    end

    logging.add_stream(log_file, logging.DEBUG, "%timestamp (%thread_id) [%level] [%modname]")
end

-- set up logging to stderr
if not args.quiet then
    local logging_level = logging[
        (args.logging_level --[[@as string]]):upper()
    ]
    if type(logging_level) ~= "number" then
        error("invalid logging level")
    end

    logging.add_stream(io.stderr, logging_level, "%thread_id \x1b[1m[%level] [%modname]\x1b[22m", {
        [logging.DEBUG] = "\x1b[36mDEBUG\x1b[39m",
        [logging.INFO] = "INFO",
        [logging.WARNING] = "\x1b[33mWARNING\x1b[39m",
        [logging.ERROR] = "\x1b[31mERROR\x1b[39m",
    })
end

local log = logging.get_logger(string.format("logger (THREAD %d)", thread_id))

log:debug("begin logging")

-- clean up old logs in the main thread
if arg then
    local items = love.filesystem.getDirectoryItems(LOGGING_PATH)
    local files = {}

    for i = 1, #items do
        local item = items[i]
        local fullPath = LOGGING_PATH .. item
        local info = love.filesystem.getInfo(fullPath)

        if info and info.type == "file" then
            table.insert(files, {
                path = fullPath,
                modtime = info.modtime or 0,
            })
        end
    end

    table.sort(files, function(a, b)
        return a.modtime > b.modtime
    end)

    for i = MAX_LOG_FILES + 1, #files do
        love.filesystem.remove(files[i].path)
        log:info("removed log file: " .. files[i].path)
    end
end

return logging
