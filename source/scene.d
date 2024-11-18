import gameobject;

struct Node {
    Node*[] children;
    GameObject* gameObject;

    this(GameObject* gameObject) {
        this.gameObject = gameObject;
    }
}

struct Scene {
    GameObject*[] Traverse() {
        // Simple DFS traversal for now; not using strategy pattern
        // to avoid premature abstraction
        GameObject*[] gameObjects;
        foreach(node; mRoot.children) {
            gameObjects ~= node.gameObject;
            foreach(child; node.children) {
                gameObjects ~= child.gameObject;
            }
        }
        return gameObjects;
    }
    void SetRoot(Node* node) {
        mRoot = node;
    }
    void AddNode(Node* node) {
        mRoot.children ~= node;
    }
    Node* mRoot;
}