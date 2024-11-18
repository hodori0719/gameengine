import bindbc.sdl;
import std.format;
import std.conv;
import std.string;
import std.stdio;
import std.file;
import std.json;
import resourcemanager;

struct SoundEvent{
    string mSoundId;
    int volume;
}

struct AudioEngine {
    static void Init () {
        if( Mix_OpenAudio( 22050, MIX_DEFAULT_FORMAT, 2, 4096 ) == -1 )
        {
            writeln("Mix_OpenAudio: ", Mix_GetError());
            return;    
        }
    }

    static AudioEngine* GetInstance() {
        if (!mInstance) {
            mInstance = new AudioEngine();
        }
        return mInstance;
    }

    static void PlayMusic (string track) {
        Mix_PlayMusic(ResourceManager.GetInstance().GetMusic(track), -1);
    }

    // returns -1 on failure
    static int Update () {
        // no pending requests
        if (head == tail) {
            return -1;
        }
        auto sound = ResourceManager.GetInstance().GetSound(pending[head].mSoundId);
        if (sound is null) {
            return -1;
        }
        // Play on first free channel
        auto err = Mix_PlayChannel(-1, sound, 0);
        if (err == -1) {
            return -1;
        } else {
            Mix_Volume(err, pending[head].volume);
        }
        head = (head + 1) % MAX_SOUNDS;
        return 0;
    }

    static void PlaySound (SoundEvent soundEvent) {
        if (((tail + 1) % MAX_SOUNDS) == head) {
            return;
        }

        pending[tail] = soundEvent;
        tail = (tail + 1) % MAX_SOUNDS;
    }

    static void Clear() {
        Mix_CloseAudio();
    }

    private:
        static AudioEngine* mInstance;
        static const int MAX_SOUNDS = 10;
        static SoundEvent[MAX_SOUNDS] pending;
        static int tail = 0;
        static int head = 0;
}