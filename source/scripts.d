import component;
import gameobject;
import std.random;

class LevelScript : ScriptComponent {
    GameObject* mOwner;
    int mScore = 0;
    int mTarget = 0;
    void delegate() mOnWin;
    void delegate() mOnLose;

    this(GameObject* owner, int target, void delegate() onWin, void delegate() onLose){
        mOwner = owner;
        name = "level";
        mTarget = target;
        mOnWin = onWin;
        mOnLose = onLose;
    }

    override void Update(){
        ComponentText textComponent = cast(ComponentText) (*mOwner).GetComponent(ComponentType.TEXT);
        textComponent.SetValue(mScore);

        if (mScore == -1) {
            mOnLose();
        } else if (mScore == mTarget){
            mOnWin();
        }
    }

    void AddPoint(){
        mScore++;
    }

    void Lose(){
        mScore = -1;
    }

    int GetScore(){
        return mScore;
    }
}

class ProjectileScript : ScriptComponent {
    GameObject* mOwner;
    bool yDirectionUp = true;
    bool isActive = true;
    int mSpeed;

    this(GameObject* owner, bool direction, int speed){
        mOwner = owner;
        yDirectionUp = direction;
        mSpeed = speed;
    }

    override void Update(){
        if (!isActive){
            return;
        }

        ComponentPosition positionComponent = cast(ComponentPosition) (*mOwner).GetComponent(ComponentType.POSITION);
        ComponentTexture textureComponent = cast(ComponentTexture) (*mOwner).GetComponent(ComponentType.TEXTURE);
        ComponentCollision collisionComponent = cast(ComponentCollision) (*mOwner).GetComponent(ComponentType.COLLISION);
        if (yDirectionUp){
            positionComponent.Move(0, -mSpeed);
            textureComponent.SetAnimation("idle");
        } else {
            positionComponent.Move(0, mSpeed);
            textureComponent.SetAnimation("down");
        }
        if (collisionComponent.HasUniqueCollision()){
            isActive = false;
            textureComponent.SetAnimation("inactive");
            collisionComponent.Disable();
        }
    }
}

class PlayerScript : ScriptComponent {
    GameObject* mOwner;
    GameObject* mLevel;
    int mSpeed = 4;
    int mDebounce = 0;
    void delegate(int, int) mShootCallback;

    this(GameObject* owner, void delegate(int, int) shootCallback, GameObject* level = null){
        mOwner = owner;
        mLevel = level;
        mShootCallback = shootCallback;
    }

    override void Update(){
        ComponentInput inputComponent = cast(ComponentInput) (*mOwner).GetComponent(ComponentType.INPUT);
        ComponentPosition positionComponent = cast(ComponentPosition) (*mOwner).GetComponent(ComponentType.POSITION);
        ComponentTexture textureComponent = cast(ComponentTexture) (*mOwner).GetComponent(ComponentType.TEXTURE);
        ComponentCollision collisionComponent = cast(ComponentCollision) (*mOwner).GetComponent(ComponentType.COLLISION);

        if (collisionComponent.HasUniqueCollision()){
            textureComponent.SetAnimation("inactive");
            collisionComponent.Disable();

            if (mLevel !is null){
                LevelScript levelScript = cast(LevelScript) (*mLevel).GetScript("level");
                levelScript.Lose();
            }

            return;
        }

        if (inputComponent !is null) {
            switch (inputComponent.GetInputState) {
                case ComponentInput.INPUT_STATE.LEFT:
                    positionComponent.Move(-mSpeed, 0);
                    textureComponent.SetAnimation("left");
                    break;
                case ComponentInput.INPUT_STATE.RIGHT:
                    positionComponent.Move(mSpeed, 0);
                    textureComponent.SetAnimation("right");
                    break;
                default:
                    textureComponent.SetAnimation("idle");
                    break;
            }
        }
        if (mDebounce > 0){
            mDebounce--;
        } else {
            if (inputComponent.GetSpaceDown()){
                mShootCallback(positionComponent.mRect.x + 19, positionComponent.mRect.y - 32);
                mDebounce = 50;
            }
        }
    }
}

class EnemyScript : ScriptComponent{
    GameObject* mOwner;
    GameObject* mLevel;
    int mSteps = 0;
    int mSpeed = 1;
    int mHealth = 45;
    Random rng;
    bool xDirectionRight = true;
    int mDebounce = 0;
    void delegate(int, int) mShootCallback;

    this(GameObject* owner, void delegate(int, int) shootCallback = null, GameObject* level = null){
        rng = Random(unpredictableSeed);
        mOwner = owner;
        mLevel = level;

        ComponentTexture textureComponent = cast(ComponentTexture) (*mOwner).GetComponent(ComponentType.TEXTURE);
        textureComponent.SetAnimation("idle");
        mShootCallback = shootCallback;
    }
    override void Update(){
        if (mHealth <= 0){
            return;
        }

        ComponentPosition positionComponent = cast(ComponentPosition) (*mOwner).GetComponent(ComponentType.POSITION);
        ComponentTexture textureComponent = cast(ComponentTexture) (*mOwner).GetComponent(ComponentType.TEXTURE);
        ComponentCollision collisionComponent = cast(ComponentCollision) (*mOwner).GetComponent(ComponentType.COLLISION);

        // Dying state
        if (mHealth > 0 && mHealth < 45){
            mHealth--;
            positionComponent.Scale(0.96);
            positionComponent.RotateClockwise(6.0);
            if (mHealth == 0){
                textureComponent.SetAnimation("inactive");
            }
            return;
        }

        // Hit by bullet
        if (collisionComponent.HasUniqueCollision()){
            ComponentSound soundComponent = cast(ComponentSound) (*mOwner).GetComponent(ComponentType.SOUND);
            soundComponent.Play();
            collisionComponent.Disable();
            mHealth--;

            if (mLevel !is null){
                LevelScript levelScript = cast(LevelScript) (*mLevel).GetScript("level");
                levelScript.AddPoint();
            }

            return;
        }

        mSteps++;
        if (mSteps > 64){
            mSteps = 0;
            ChangeDirection();
        }

        if (xDirectionRight){
            positionComponent.Move(mSpeed, 0);
        } else {
            positionComponent.Move(-mSpeed, 0);
        }

        if (mShootCallback !is null){
            if (mDebounce > 0){
                mDebounce--;
            } else {
                int randomChoice = uniform(0, 1000, rng);
                if (randomChoice == 0){
                    mShootCallback(positionComponent.mRect.x + 19, positionComponent.mRect.y + 32);
                    mDebounce = 50;
                }
            }
        }
    }

    void ChangeDirection(){
        xDirectionRight = !xDirectionRight;
    }
}

class KeepInBoundsScript : ScriptComponent {
    GameObject* mOwner;

    this(GameObject* owner){
        mOwner = owner;
    }

    override void Update(){
        ComponentPosition positionComponent = cast(ComponentPosition) (*mOwner).GetComponent(ComponentType.POSITION);
        if (positionComponent.mRect.x < 0){
            positionComponent.Move(-positionComponent.mRect.x, 0);
        } else if (positionComponent.mRect.x + positionComponent.mRect.w > 640){
            positionComponent.Move(640 - (positionComponent.mRect.x + positionComponent.mRect.w), 0);
        }
    }
}

class SceneSwitcherScript : ScriptComponent {
    GameObject* mOwner;
    void delegate() mCallback;
    int mCountdown = 100;

    this(GameObject* owner, void delegate() callback){
        mOwner = owner;
        mCallback = callback;
    }

    override void Update(){
        if (mCountdown < 100) {
            mCountdown--;
            if (mCountdown % 10 == 0){
                ComponentPosition positionComponent = cast(ComponentPosition) (*mOwner).GetComponent(ComponentType.POSITION);
                if (mCountdown % 20 == 0){
                    positionComponent.Move(0, -1000);
                } else {
                    positionComponent.Move(0, 1000);
                }
            }
        } else {
            ComponentInput inputComponent = cast(ComponentInput) (*mOwner).GetComponent(ComponentType.INPUT);
            if (inputComponent !is null && inputComponent.GetSpaceDown()){
                ComponentSound soundComponent = cast(ComponentSound) (*mOwner).GetComponent(ComponentType.SOUND);
                soundComponent.Play();
                mCountdown--;
            }
        }
        if (mCountdown == 0){
            mCallback();
        }
    }
}

class SceneSoundScript : ScriptComponent {
    GameObject* mOwner;
    bool mPlayed = false;

    this(GameObject* owner){
        mOwner = owner;
    }

    override void Update(){
        if (!mPlayed){
            ComponentSound soundComponent = cast(ComponentSound) (*mOwner).GetComponent(ComponentType.SOUND);
            soundComponent.Play();
            mPlayed = true;
        }
    }
}

class PulsateScript : ScriptComponent {
    GameObject* mOwner;
    int mSteps = 0;
    int mMaxSteps;
    double mSpeed;
    bool mGrowing = true;

    this(GameObject* owner, int steps = 10, double speed = 1.01){
        mOwner = owner;
        mMaxSteps = steps;
        mSpeed = speed;
    }

    override void Update(){
        ComponentPosition positionComponent = cast(ComponentPosition) (*mOwner).GetComponent(ComponentType.POSITION);
        if (mGrowing){
            positionComponent.Scale(mSpeed);
        } else {
            positionComponent.Scale(1.0/mSpeed);
        }
        mSteps++;
        if (mSteps > mMaxSteps){
            mGrowing = !mGrowing;
            mSteps = 0;
        }
    }
}