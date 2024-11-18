// Project Libraries
import component;

struct GameObject{
    IComponent[ComponentType] mComponents;
    ScriptComponent[] mScripts;

    void Input(){
        foreach(component; mComponents){
            component.Input();
        }
    }

    void Update(){
        foreach(component; mComponents){
            component.Update();
        }
        foreach(script; mScripts){
            script.Update();
        }
    }

    void Render(){
        foreach(component; mComponents){
            component.Render();
        }
    }

    IComponent GetComponent(ComponentType type){
        if (type !in mComponents){
            return null;
        }
        return mComponents[type];
    }

    ScriptComponent GetScript(string name){
        foreach(script; mScripts){
            if (script.name == name){
                return script;
            }
        }
        return null;
    }

    void AddComponent(ComponentType T)(IComponent component){
        if (T == ComponentType.SCRIPT){
            mScripts ~= cast(ScriptComponent) component;
            return;
        }
        mComponents[T] = component;
    }
}
