module gameapplication;
// Import D standard libraries
import std.stdio;
import std.string;
import std.conv;

// Third-party libraries
import bindbc.sdl;
import bindbc.sdl.ttf;
import bindbc.sdl.mixer;

// Import our SDL Abstraction
import sdl_abstraction;
import gameobject;
import component;
import scripts;
import resourcemanager;
import audioengine;
import scene;

int FRAME_CAP = 60;

struct GameApplication{
		SDL_Window* mWindow = null;
		SDL_Renderer* mRenderer = null;
		bool mGameIsRunning = true;

		int MS_PER_FRAME = 0;
		int MS_PER_UPDATE = 0;
		string title = null;
		uint last = 0;
		uint lastRender = 0;

		Scene mScene;

		enum SceneType {
			MENU,
			GAME,
			LOSE,
			WIN
		}

		bool mSceneSwitched = true;
		SceneType mSceneType = SceneType.MENU;

		// Constructor
		this(string title){
				MS_PER_FRAME = 1000 / FRAME_CAP;
				MS_PER_UPDATE = 1000 / 60;

				// Create an SDL window
				this.title = title;

				mWindow = SDL_CreateWindow(this.title.toStringz, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 640, 480, SDL_WINDOW_SHOWN);
				mRenderer = SDL_CreateRenderer(mWindow,-1,SDL_RENDERER_ACCELERATED);
				
				if (TTF_Init() == -1) {
					writeln("TTF_Init: ", TTF_GetError());
					return;
				}

				ResourceManager.SetRenderer(mRenderer);
				AudioEngine.Init();
				AudioEngine.PlayMusic("xp");
		}

		// Destructor
		~this(){
				AudioEngine.Clear();
				ResourceManager.Clear();
				TTF_Quit();
				// Destroy our renderer
				SDL_DestroyRenderer(mRenderer);
				// Destroy our window
				SDL_DestroyWindow(mWindow);
		}

		// Scene management methods

		void TriggerSwitchScene(SceneType sceneType){
			mSceneSwitched = true;
			mSceneType = sceneType;
		}

		void SwitchScene (SceneType sceneType) {
			switch(sceneType){
				case SceneType.MENU:
					LoadMenuScene();
					break;
				case SceneType.GAME:
					LoadGameScene();
					break;
				case SceneType.LOSE:
					LoadLoseScene();
					break;
				case SceneType.WIN:
					LoadWinScene();
					break;
				default:
					break;
			}
		}

		void LoadMenuScene () {
				auto mRoot = new Node();
				mScene = Scene();
				mScene.SetRoot(mRoot);

				CreateLabel("SPOTTED INVADERS", 50, 85, 540, 105);
				CreateLabel("A, D to Move   SPC to Shoot", 140, 255, 360, 35);
				CreateStartLabel("Press SPC to Start", 140, 300, 360, 70, SceneType.GAME);
				CreateEnemy(320 - 27, 190, isPeaceful: true);
		}

		void LoadGameScene () {
				auto mRoot = new Node();
				mScene = Scene();
				mScene.SetRoot(mRoot);

				auto level = CreateLevel(30);
				CreatePlayer(level);

				for (int i = 0; i < 10; i++){
					for (int j = 0; j < 3; j++){
						CreateEnemy((54+4) * i, 48 + (48+4) * j, isPeaceful: false, level);
					}
				}
		}

		void LoadLoseScene () {
				auto mRoot = new Node();
				mScene = Scene();
				mScene.SetRoot(mRoot);

				CreateLabel("YOU LOSE!", 50, 130, 540, 105);
				CreateStartLabel("Press SPC for Menu", 140, 250, 360, 70, SceneType.MENU);
				CreateSceneSwitchSound("defeat");
		}

		void LoadWinScene () {
				auto mRoot = new Node();
				mScene = Scene();
				mScene.SetRoot(mRoot);

				CreateLabel("You squashed the bugs!", 50, 130, 540, 105);
				CreateStartLabel("Press SPC for Menu", 140, 250, 360, 70, SceneType.MENU);
				CreateSceneSwitchSound("victory");
		}

		// Game object template methods / prefabs ?

		GameObject* CreateStartLabel(string text, int x, int y, int w, int h, SceneType nextScene) {
				auto gameObject = CreateLabel(text, x, y, w, h);
				gameObject.AddComponent!(ComponentType.SCRIPT)(new PulsateScript(gameObject, 30, 1.005));
				gameObject.AddComponent!(ComponentType.INPUT)(new ComponentInput());
				gameObject.AddComponent!(ComponentType.SCRIPT)(new SceneSwitcherScript(gameObject, () {TriggerSwitchScene(nextScene);}));
				gameObject.AddComponent!(ComponentType.SOUND)(new ComponentSound("select"));
				return gameObject;
		}

		GameObject* CreateLevel(int targetScore){
				auto gameObject = new GameObject();

				// Any components which are possibly dependencies of other components
				auto mComponentPosition = new ComponentPosition(20, 10, 180, 35);

				gameObject.AddComponent!(ComponentType.POSITION)(mComponentPosition);
				gameObject.AddComponent!(ComponentType.SCRIPT)(new LevelScript(
					gameObject,
					targetScore, 
					() {TriggerSwitchScene(SceneType.WIN);},
					() {TriggerSwitchScene(SceneType.LOSE);}
				));
				gameObject.AddComponent!(ComponentType.TEXT)(new ComponentText(
					mRenderer,
					"SCORE: %02d/30",
					SDL_Color(0,0,0,255),
					mComponentPosition,
					ResourceManager.GetInstance().GetFont("JetBrainsMono-Bold"),
					isFormatted: true,
					0,
				));

				auto mNode = new Node(gameObject);
				mScene.AddNode(mNode);
				return gameObject;
		}

		GameObject* CreateSceneSwitcher(void delegate() sceneSwitcher) {
				auto gameObject = new GameObject();

				gameObject.AddComponent!(ComponentType.INPUT)(new ComponentInput());
				gameObject.AddComponent!(ComponentType.SCRIPT)(new SceneSwitcherScript(gameObject, sceneSwitcher));
				auto mNode = new Node(gameObject);
				mScene.AddNode(mNode);
				return gameObject;
		}

		GameObject* CreateSceneSwitchSound(string soundPath){
				auto gameObject = new GameObject();

				gameObject.AddComponent!(ComponentType.SOUND)(new ComponentSound(soundPath));
				gameObject.AddComponent!(ComponentType.SCRIPT)(new SceneSoundScript(gameObject));

				auto mNode = new Node(gameObject);
				mScene.AddNode(mNode);
				return gameObject;
		}

		GameObject* CreateLabel(string text, int x, int y, int w, int h){
				auto gameObject = new GameObject();

				auto mComponentPosition = new ComponentPosition(x, y, w, h);

				gameObject.AddComponent!(ComponentType.POSITION)(mComponentPosition);
				gameObject.AddComponent!(ComponentType.TEXT)(new ComponentText(
					mRenderer,
					text,
					SDL_Color(0,0,0,255),
					mComponentPosition,
					ResourceManager.GetInstance().GetFont("JetBrainsMono-Bold")
				));

				auto mNode = new Node(gameObject);
				mScene.AddNode(mNode);
				return gameObject;
		}

		GameObject* CreatePlayer(GameObject* level){
				auto gameObject = new GameObject();

				auto mComponentPosition = new ComponentPosition(270,400,54,54);

				gameObject.AddComponent!(ComponentType.INPUT)(new ComponentInput());
				gameObject.AddComponent!(ComponentType.POSITION)(mComponentPosition);
				gameObject.AddComponent!(ComponentType.COLLISION)(new ComponentCollision(mScene, mComponentPosition, 0));
				gameObject.AddComponent!(ComponentType.TEXTURE)(new ComponentTexture(
					mRenderer,
					ResourceManager.GetInstance().GetSprite("player"), 
					mComponentPosition
				));
				gameObject.AddComponent!(ComponentType.SCRIPT)(new PlayerScript(
					gameObject,
					(int x, int y) {CreateProjectile(x, y, speed: 4, false, false);},
					level
				));
				gameObject.AddComponent!(ComponentType.SCRIPT)(new KeepInBoundsScript(gameObject));

				auto mNode = new Node(gameObject);
				mScene.AddNode(mNode);
				return gameObject;
		}

		GameObject* CreateEnemy(int x, int y, bool isPeaceful = false, GameObject* level = null){
				auto gameObject = new GameObject();

				auto eComponentPosition = new ComponentPosition(x, y, 54, 48);

				gameObject.AddComponent!(ComponentType.POSITION)(eComponentPosition);
				gameObject.AddComponent!(ComponentType.COLLISION)(new ComponentCollision(mScene, eComponentPosition, 1));
				gameObject.AddComponent!(ComponentType.TEXTURE)(new ComponentTexture(
					mRenderer, 
					ResourceManager.GetInstance().GetSprite("enemy"), 
					eComponentPosition
				));
				gameObject.AddComponent!(ComponentType.SOUND)(new ComponentSound("splat"));
				if (!isPeaceful) {
					gameObject.AddComponent!(ComponentType.SCRIPT)(new EnemyScript(
						gameObject,
						(int x, int y) {CreateProjectile(x, y, speed: 6, true, true);}, 
						level
					));
				}

				auto mNode = new Node(gameObject);
				mScene.AddNode(mNode);
				return gameObject;
		} 

		GameObject* CreateProjectile(int x, int y, int speed, bool isGoingDown, bool isEnemy){
				auto gameObject = new GameObject();

				auto pComponentPosition = new ComponentPosition(x, y, 16, 32);

				gameObject.AddComponent!(ComponentType.POSITION)(pComponentPosition);
				gameObject.AddComponent!(ComponentType.COLLISION)(new ComponentCollision(mScene, pComponentPosition, isEnemy ? 0 : 1));
				gameObject.AddComponent!(ComponentType.TEXTURE)(new ComponentTexture(
					mRenderer, 
					ResourceManager.GetInstance().GetSprite("projectile"), 
					pComponentPosition
				));
				gameObject.AddComponent!(ComponentType.SCRIPT)(new ProjectileScript(gameObject, !isGoingDown, speed));

				auto mNode = new Node(gameObject);
				mScene.AddNode(mNode);
				return gameObject;
		}

		// Handle input
		void Input(){
				SDL_Event event;
				// Start our event loop
				while(SDL_PollEvent(&event)){
						// Handle each specific event
						if(event.type == SDL_QUIT){
								mGameIsRunning= false;
						}
				}

				foreach(gameObject; mScene.Traverse()){
					auto inp = (*gameObject).GetComponent(ComponentType.INPUT);
					if(inp !is null){
						inp.Input();
					}
				}
		}

		void Update(){
				foreach(gameObject; mScene.Traverse()){
					(*gameObject).Update();
				}
		}

		void Render(){
				static uint frames = 0;
				// Set the render draw color 
				SDL_SetRenderDrawColor(mRenderer,230, 230, 230,SDL_ALPHA_OPAQUE);
				// Clear the renderer each time we render
				SDL_RenderClear(mRenderer);

				foreach(gameObject; mScene.Traverse()){
					auto tex = (*gameObject).GetComponent(ComponentType.TEXTURE);
					if(tex !is null){
						tex.Render();
					}
				}

				foreach(gameObject; mScene.Traverse()){
					auto tex = (*gameObject).GetComponent(ComponentType.TEXT);
					if(tex !is null){
						tex.Render();
					}
				}

				// Final step is to present what we have copied into
				// video memory
				SDL_RenderPresent(mRenderer);

				while(AudioEngine.Update() == 0) {
					continue;
				}

				frames++;
				auto newTime = SDL_GetTicks();
				if(newTime - lastRender >= 1000){
					SDL_SetWindowTitle(mWindow, (this.title ~ " (FPS: " ~ frames.to!string ~ ")").toStringz);
					frames = 0;
					lastRender = newTime;
				}
		}

		// Advance world one frame at a time
		void AdvanceFrame(){
				static uint lag = 0;
				uint curr = SDL_GetTicks();
				lag += curr - last;

				Input();
				while (lag >= MS_PER_UPDATE){
						Update();
						lag -= MS_PER_UPDATE;
				}
				Render();

				int elapsed = int(curr + MS_PER_FRAME) - int(SDL_GetTicks());
				SDL_Delay(elapsed > 0 ? elapsed : 0);

				last = curr;
		}

		void RunLoop(){
				// Main application loop
				last = SDL_GetTicks();
				lastRender = SDL_GetTicks();
				while(mGameIsRunning){
					if (mSceneSwitched){
						SwitchScene(mSceneType);
						mSceneSwitched = false;
					}

					AdvanceFrame();	
				}
		}
}
