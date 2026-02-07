local log = require("log")(...)
local ffi = require("ffi")

ffi.cdef([[
int start_encoding(const char* file, const int width, const int height, const int framerate, const int sample_rate);
int get_audio_frame_size();
int supply_audio_data(const void* audio_data);
int supply_video_data(const void* video_data);
void stop_encoding();
]])

local clib_path = "lib/libencode.so"
local sys = love.system.getOS()
if sys == "OS X" or sys == "iOS" then
    clib_path = "lib/libencode.dylib"
elseif sys == "Windows" then
    clib_path = "lib/libencode.dll"
end
local success, clib = pcall(ffi.load, clib_path)
if not success then
    log(("Failed to load '%s'. The video encoder is unavailable. Error: %s"):format(clib_path, clib))
end

local api = {}
api.running = false

---start encoding a video file
---@param filename string
---@param width integer
---@param height integer
---@param framerate integer
---@param sample_rate integer
function api.start(filename, width, height, framerate, sample_rate)
    assert(width % 2 == 0 and height % 2 == 0, "width and height must be a multiple of 2.")
    assert(clib, "Tried to encode video without encoder.")
    assert(clib.start_encoding(filename, width, height, framerate, sample_rate) == 0, "Failed to initialize ffmpeg.")
    api.audio_frame_size = clib.get_audio_frame_size()
    api.running = true
end

local imagedata

---add a video frame
---@param texture love.Texture
function api.supply_video_data(texture)
    imagedata = love.graphics.readbackTexture(texture, nil, nil, nil, nil, nil, nil, imagedata)
    assert(clib.supply_video_data(imagedata:getFFIPointer()) == 0, "Failed sending video frame.")
end

---add an audio frame
---@param audiodata love.SoundData
function api.supply_audio_data(audiodata)
    assert(clib.supply_audio_data(audiodata:getFFIPointer()) == 0, "Failed sending audio frame.")
end

---stop encoding the video
function api.stop()
    clib.stop_encoding()
    api.running = false
end

return api
