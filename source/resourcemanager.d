import bindbc.sdl;
import std.format;
import std.conv;
import std.string;
import std.stdio;
import std.file;
import std.json;

struct Frame{
    SDL_Rect mRect;
}

struct Sprite {
    SDL_Texture* texture;
    Frame[] mFrames;
    long[][string] mFrameNumbers;
}

const int DEFAULT_FONT_SIZE = 16;
const string DEFAULT_TEXTURE_PATH = "./assets/images/%s.bmp";
const string DEFAULT_TEXTURE_DATA_PATH = "./assets/images/%s.json";
const string DEFAULT_FONT_PATH = "./assets/fonts/%s.ttf";
const string DEFAULT_SOUND_PATH = "./assets/sounds/%s.wav";
const string DEFAULT_MUSIC_PATH = "./assets/sounds/%s.mp3";

struct ResourceManager {
    static ResourceManager* GetInstance() {
        if (!mInstance) {
            mInstance = new ResourceManager();
        }
        return mInstance;
    }

    static Sprite* GetSprite(string spritePath) {
        if (spritePath in mSpriteResourceMap) {
            return mSpriteResourceMap[spritePath];
        } else {
            // Load textures if they don't exist already.
            Sprite* sprite = new Sprite();
            SDL_Surface* mSurface = SDL_LoadBMP(format(DEFAULT_TEXTURE_PATH, spritePath).toStringz);
			sprite.texture = SDL_CreateTextureFromSurface(mRenderer, mSurface);
            SDL_FreeSurface(mSurface);

            auto json = cast(string)std.file.read(format(DEFAULT_TEXTURE_DATA_PATH, spritePath));
            auto parsed = json.parseJSON();

            // Parse format
            auto format = parsed["format"];
            auto fullX = to!int(format["width"].to!string);
            auto fullY = to!int(format["height"].to!string);
            auto frameX = to!int(format["tileWidth"].to!string);
            auto frameY = to!int(format["tileHeight"].to!string);
            auto rows = fullX / frameX;
            auto cols = fullY / frameY;
            foreach(i; 0..cols){
                foreach(j; 0..rows){
                    Frame frame;
                    frame.mRect.x = j * frameX;
                    frame.mRect.y = i * frameY;
                    frame.mRect.w = frameX;
                    frame.mRect.h = frameY;
                    sprite.mFrames ~= frame;
                }
            }
            
            // Parse frames
            auto frames = parsed["frames"];
            foreach(string key, ref value; frames){
                long[] frameNumbers;
                foreach(number; value.array){
                    frameNumbers ~= to!long(number.to!string);
                }
                sprite.mFrameNumbers[key] = frameNumbers;
            }

            mSpriteResourceMap[spritePath] = sprite;
            return sprite;
        }
    }

    static TTF_Font* GetFont(string fontPath) {
        if (fontPath in mFontResourceMap) {
            return mFontResourceMap[fontPath];
        } else {
            // Load fonts if they don't exist already.
            TTF_Font* font = TTF_OpenFont(format(DEFAULT_FONT_PATH, fontPath).toStringz, DEFAULT_FONT_SIZE);
            if (font is null) {
                writeln("TTF_OpenFont: ", TTF_GetError());
                return null;
            }
            mFontResourceMap[fontPath] = font;
            return font;
        }
    }

    static Mix_Chunk* GetSound(string soundPath) {
        if (soundPath in mSoundResourceMap) {
            return mSoundResourceMap[soundPath];
        } else {
            Mix_Chunk* sound = Mix_LoadWAV(format(DEFAULT_SOUND_PATH, soundPath).toStringz);
            if (sound is null) {
                writeln("Mix_LoadWAV: ", Mix_GetError());
                return null;
            }
            mSoundResourceMap[soundPath] = sound;
            return sound;
        }
    }

    static Mix_Music* GetMusic(string musicPath) {
        if (musicPath in mMusicResourceMap) {
            return mMusicResourceMap[musicPath];
        } else {
            Mix_Music* music = Mix_LoadMUS(format(DEFAULT_MUSIC_PATH, musicPath).toStringz);
            if (music is null) {
                writeln("Mix_LoadMUS: ", Mix_GetError());
                return null;
            }
            mMusicResourceMap[musicPath] = music;
            return music;
        }
    }

    static void SetRenderer(SDL_Renderer* renderer) {
        mRenderer = renderer;
    }

    static void Clear() {
        foreach(sprite; mSpriteResourceMap){
            SDL_DestroyTexture(sprite.texture);
        }
        foreach(font; mFontResourceMap){
            TTF_CloseFont(font);
        }
        foreach(sound; mSoundResourceMap){
            Mix_FreeChunk(sound);
        }
        foreach(music; mMusicResourceMap){
            Mix_FreeMusic(music);
        }
        mSpriteResourceMap.clear();
        mFontResourceMap.clear();
        mSoundResourceMap.clear();
        mMusicResourceMap.clear();
    }

    private:
        static ResourceManager* mInstance;
        static Sprite*[string] mSpriteResourceMap;
        static TTF_Font*[string] mFontResourceMap;
        static Mix_Chunk*[string] mSoundResourceMap;
        static Mix_Music*[string] mMusicResourceMap;
        static SDL_Renderer* mRenderer;
}