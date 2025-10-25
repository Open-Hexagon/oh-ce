local music = require("compat.music")
local level_status = require("compat.game21.level_status")
local sound = require("compat.sound")

return function(game)
    local pack = game.pack_data
    local public = require("compat.game21")
    local lua_runtime = require("compat.game21.lua_runtime")
    local env = lua_runtime.env
    env.a_setMusic = function(music_id)
        env.a_setMusicSegment(music_id, 0)
    end
    env.a_setMusicSegment = function(music_id, segment)
        local new_music = game.pack_data.music[music_id]
        if new_music == nil then
            lua_runtime.error("Music with id '" .. music_id .. "' doesn't exist!")
        else
            music.stop()
            music.play(new_music, segment + 1, nil, public.refresh_music_pitch())
        end
    end
    env.a_setMusicSeconds = function(music_id, seconds)
        local new_music = game.pack_data.music[music_id]
        if new_music == nil then
            lua_runtime.error("Music with id '" .. music_id .. "' doesn't exist!")
        else
            music.stop()
            music.play(new_music, false, seconds, public.refresh_music_pitch())
        end
    end
    env.a_playSound = function(sound_id)
        sound.play_pack(pack, sound_id)
    end
    env.a_playPackSound = function(sound_id)
        sound.play_pack(pack, pack.info.id .. "_" .. sound_id)
    end
    env.a_syncMusicToDM = function(value)
        level_status.sync_music_to_dm = value
        public.refresh_music_pitch()
    end
    env.a_setMusicPitch = function(pitch)
        level_status.music_pitch = pitch
        public.refresh_music_pitch()
    end
    env.a_overrideBeepSound = function(filename)
        level_status.beep_sound = pack.info.id .. "_" .. filename
    end
    env.a_overrideIncrementSound = function(filename)
        level_status.level_up_sound = pack.info.id .. "_" .. filename
    end
    env.a_overrideSwapSound = function(filename)
        level_status.swap_sound = pack.info.id .. "_" .. filename
    end
    env.a_overrideDeathSound = function(filename)
        level_status.death_sound = pack.info.id .. "_" .. filename
    end

    -- deprecated
    env.u_playSound = env.a_playSound
end
