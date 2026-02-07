local args = require("args")
local log = require("log")(...)
local audio = require("audio")
local music = {
    volume = 1,
}

function music.update_volume(volume)
    if music.playing and music.playing.source then
        music.playing.source.volume = volume
    end
    music.volume = volume
end

function music.play(music_data, random_segment, time, pitch)
    if not music_data then
        return
    end
    if not music_data.source and not args.headless and music_data.file_path then
        music_data.source = audio.new_stream(music_data.file_path)
        music_data.source.volume = music.volume
        music_data.source.looping = true
    end
    if time then
        if music_data.source then
            music_data.source:seek(time)
        end
    else
        local segment
        if type(random_segment) == "number" then
            segment = random_segment
        else
            segment = random_segment and math.random(1, #music_data.segments) or 1
        end
        music.segment = music_data.segments[segment]
        if music_data.source then
            music_data.source:seek(music.segment.time or 0)
        end
    end
    if music_data.source then
        pitch = pitch or 1
        if pitch > 0 then
            music_data.source:set_pitch(pitch)
        else
            log("Invalid pitch of", pitch)
        end
        music_data.source:play()
    end
    music.playing = music_data
end

function music.set_pitch(pitch)
    if pitch <= 0 then
        log("Invalid pitch of", pitch)
        return
    end
    if music.playing and music.playing.source then
        music.playing.source:set_pitch(pitch)
    end
end

function music.stop()
    if music.playing then
        if music.playing.source then
            music.playing.source:stop()
            music.playing.source:release()
            music.playing.source = nil
        end
        music.playing = nil
        music.segment = nil
    end
end

return music
