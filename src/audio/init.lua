local args = require("args")
local audio

-- TODO: make configurable
-- (will have to restart when changing, might be different once the asset rework is done)
if args.render then
    audio = require("audio.queue")
else
    audio = require("audio.immediate")
end

audio.sound_volume = 1
local cached = {}

function audio.play_sound(obj)
    if obj then
        if obj.typeOf and obj:typeOf("SoundData") then
            if not cached[obj] then
                cached[obj] = audio.new_static(obj)
            end
            obj = cached[obj]
        end
        obj.volume = audio.sound_volume
        obj:seek(0)
        obj:play()
    end
end

return audio
