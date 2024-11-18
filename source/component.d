import core.atomic;
import std.stdio;
import std.conv;
import std.array;
import std.format;
import std.string;
import std.math;
// Third-party libraries
import bindbc.sdl;
import gameobject;
import scene;
import resourcemanager;
import audioengine;

/// Store an individual Frame for an animation

enum ComponentType{
    INPUT,
    POSITION,
    COLLISION,
    TEXTURE,
    TEXT,
    SOUND,
    SCRIPT
}

interface IComponent{
    void Input();
    void Update();
    void Render();
}

class ScriptComponent : IComponent {
    static int sId;
    int mId;
    string name;

    this(){
        mId = ++ sId;
    }

    void Input(){}
    void Update(){}
    void Render(){}
}

class ComponentInput : IComponent{
    enum INPUT_STATE{LEFT,RIGHT,NONE};
    INPUT_STATE mInputState = INPUT_STATE.NONE;
    bool mSpacePressed = false;
    bool mSpaceDown = false;
    
    this(){
        ubyte* initState = SDL_GetKeyboardState(null);
        if(initState[SDL_SCANCODE_SPACE]){
            mSpacePressed = true;
        }
    }
    void Input(){
        ubyte* state = SDL_GetKeyboardState(null);

        if(state[SDL_SCANCODE_A] && !state[SDL_SCANCODE_D]){
            mInputState = INPUT_STATE.LEFT;
        }
        else if(state[SDL_SCANCODE_D] && !state[SDL_SCANCODE_A]){
            mInputState = INPUT_STATE.RIGHT;
        }
        else{
            mInputState = INPUT_STATE.NONE;
        }
        if(state[SDL_SCANCODE_SPACE]){
            if (!mSpacePressed){
                mSpaceDown = true;
            } else {
                mSpaceDown = false;
            }
            mSpacePressed = true;
        } else {
            mSpacePressed = false; 
        }

        return;
    }

    void Update(){}
    void Render(){}

    INPUT_STATE GetInputState(){
        return mInputState;
    }

    bool GetSpaceDown(){
        return mSpaceDown;
    }
}

class ComponentPosition : IComponent{
    SDL_Rect mBaseRect;
    SDL_Rect mRect;
    double mAngle = 0.0;
    double mScale = 1.0;
    int wDelta = 0;
    int hDelta = 0;
    int xDelta = 0;
    int yDelta = 0;
    double angleDelta = 0.0;

    this(int x, int y, int w, int h){
        mBaseRect.x = x;
        mBaseRect.y = y;
        mBaseRect.w = w;
        mBaseRect.h = h;

        mRect = mBaseRect;
    }

    void Input(){}
    void Update(){
        mBaseRect.w += wDelta;
        mBaseRect.h += hDelta;
        mBaseRect.x += xDelta;
        mBaseRect.y += yDelta;
        mAngle += angleDelta;

        mRect.w = cast (int) round(mBaseRect.w * mScale);
        mRect.h = cast (int) round(mBaseRect.h * mScale);
        mRect.x = cast (int) round(mBaseRect.x - (mRect.w - mBaseRect.w) / 2.0);
        mRect.y = cast (int) round(mBaseRect.y - (mRect.h - mBaseRect.h) / 2.0);

        wDelta = 0;
        hDelta = 0;
        xDelta = 0;
        yDelta = 0;
        angleDelta = 0.0;
    }
    void Render(){}

    void Move(int x, int y){
        xDelta += x;
        yDelta += y;
    }

    void RotateClockwise(double angle){
        angleDelta += angle;
    }

    void Scale(double amount){
        mScale *= amount;
    }

    SDL_Rect* GetRectRef(){
        return &mRect;
    }
}

class ComponentCollision: IComponent{
    // I'm not storing a separate hitbox here, just a pointer to
    // the position, but if our use cases got more advanced that could be a possibility.
    ComponentPosition mPosition;
    Scene mScene;
    GameObject*[] mCollisions;
    int mLayer;
    bool mHasUniqueCollision = false;

    this(Scene scene, ComponentPosition position, int layer){
        mScene = scene;
        mPosition = position;
        mLayer = layer;
    }

    void Input(){}
    void Update(){
        if (mLayer < 0){
            return;
        }

        mCollisions = [];

        foreach(gameObject; mScene.Traverse()){
            auto collision = cast(ComponentCollision) (*gameObject).GetComponent(ComponentType.COLLISION);
            if (collision !is null && collision !is this && mLayer == collision.mLayer){
                auto otherPosition = collision.mPosition;
                if (otherPosition !is null){
                    if (SDL_TRUE == SDL_IntersectRect(mPosition.GetRectRef(), otherPosition.GetRectRef(), new SDL_Rect())){
                        mCollisions ~= gameObject;

                        // Pair collisions for use cases where we need to know if a collision is unique
                        if (!mHasUniqueCollision && !collision.mHasUniqueCollision){
                            mHasUniqueCollision = true;
                            collision.mHasUniqueCollision = true;
                        }
                    }
                }
            }
        }
    }
    void Render(){}

    void Disable(){
        mLayer = -1;
    }

    // unused in this game, but most games would use this
    GameObject*[]* GetCollisions(){
        return &mCollisions;
    }

    bool HasUniqueCollision(){
        return mHasUniqueCollision;
    }
}

class ComponentTexture : IComponent{
    // References to the Sprites data
    // We don't necesssarily want this 'AnimationSequences' to own any data,
    // just otherwise access it, and iterate through the data.
    SDL_Renderer* mRendererRef;
    SDL_Texture* mTextureRef;
    ComponentPosition mPosition;

    Frame[]* mFrames;
    long[][string]* mFrameNumbers;
    string name;
    string mCurrentAnimationName;
    long mCurrentFramePlaying;
    long mLastFrameInSequence;
    int mCurrentFrameLife;

    /// Hold a copy of the texture that is referenced
    this(SDL_Renderer* r, Sprite* tex_reference, ComponentPosition position){
        mRendererRef = r;
        mTextureRef = tex_reference.texture;
        mPosition = position;
        mFrames = &(tex_reference.mFrames);
        mFrameNumbers = &(tex_reference.mFrameNumbers);
        name = "idle";
    }

    /// Play an animation based on the name of the animation sequence
    /// specified in the data file.

    void Input(){}
    void Update(){
        // Get the sequence
        if (mCurrentFrameLife > 5){
            mCurrentFrameLife = 0;
            mCurrentFramePlaying++;
        } else {
            mCurrentFrameLife++;
        }
        
        if (name == "inactive"){
            mCurrentAnimationName = "inactive";
            mCurrentFramePlaying = 0;
            mLastFrameInSequence = 1;
        }

        if (name != mCurrentAnimationName){
            mCurrentAnimationName = name;
            mCurrentFramePlaying = 0;
            mLastFrameInSequence = (*mFrameNumbers)[name].length;
        } else {
            if (mCurrentFramePlaying >= mLastFrameInSequence){
                mCurrentFramePlaying = 0;
            }
        }
    }

    void Render(){
        if (mCurrentAnimationName != "" && mCurrentAnimationName != "inactive"){
            SDL_RenderCopyEx(mRendererRef, mTextureRef, &(*mFrames)[(*mFrameNumbers)[mCurrentAnimationName][mCurrentFramePlaying]].mRect, mPosition.GetRectRef(), mPosition.mAngle, null, SDL_FLIP_NONE);
        } else {
            return;
        }
    }

    void SetAnimation(string name){
        this.name = name;
    }
}

class ComponentText : IComponent{
    SDL_Renderer* mRendererRef;
    SDL_Texture* mTextureRef;
    string mText;
    SDL_Color mColor;
    ComponentPosition mPosition;
    TTF_Font* mFont;
    bool mIsFormatted;
    int mValue;

    this(SDL_Renderer* r, string text, SDL_Color color, ComponentPosition position, TTF_Font* font, bool isFormatted = false, int input = 0){
        mRendererRef = r;
        mText = text;
        mColor = color;
        mPosition = position;
        mFont = font;
        mIsFormatted = isFormatted;
        mValue = input;
    }

    void Input(){}
    void Update(){}
    void Render(){
        SDL_Surface* mSurface;
        if (mIsFormatted){
            mSurface = TTF_RenderText_Solid(mFont, format(mText, mValue).toStringz, mColor);
        } else {
            mSurface = TTF_RenderText_Solid(mFont, mText.toStringz, mColor);
        }
        mTextureRef = SDL_CreateTextureFromSurface(mRendererRef, mSurface);
        SDL_FreeSurface(mSurface);
        SDL_RenderCopy(mRendererRef, mTextureRef, null, mPosition.GetRectRef());
    }

    void SetText(string text, bool isFormatted = false){
        mText = text;
        mIsFormatted = isFormatted;
    }

    void SetValue(int value){
        mValue = value;
    }
}

class ComponentSound : IComponent{
    string mSound;
    bool mPlaying = false;

    this(string sound){
        mSound = sound;
    }

    void Input(){}
    void Update(){
        if (mPlaying){
            AudioEngine.PlaySound(SoundEvent(mSound, 128));
            mPlaying = false;
        }
    }
    void Render(){}

    void Play(){
        mPlaying = true;
    }
}