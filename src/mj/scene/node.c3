module mj;
import std::io;
import std::math::matrix;
import std::math::quaternion;
import std::collections::list;

enum NodeType {
    ROOT,
    GROUP,
    LIGHT,
    SKELETAL_MESH,
    STATIC_MESH,
    BONE,
}
struct Transform {
    Position position;
    Quat rotation;
    Scale scale;
    bool is_dirty;
    Matrix4f local_matrix;
    Matrix4f world_matrix;
}

struct Node {
    NodeHandle parent;
    List(<NodeHandle>) children;
    NodeType type;
    union {
        StaticMeshHandle mesh;
        LightHandle light;
        struct {
            SkeletalMeshHandle skeletal_mesh;
            AnimationInstance animation;
        }
    }
    Transform transform;
}

fn Matrix4f Transform.toMatrix(&this) {
    return this.rotation.to_matrixf()
        .translate(this.position)
        .scale(this.scale);
}

fn Transform newTransform() {
    return Transform {
        .scale = {1.0, 1.0, 1.0},
    };
}



fn void NodePool.unparent(&this, NodeHandle node) {
    Node* n = this.get(node);
    if (n == null) {
        return;
    }
    Node* p = this.get(n.parent);
    if (p != null && p != n) {
        if (try i = p.children.index_of(node)) {
            p.children.swap(i, p.children.len() - 1);
            anyfault e = @catch(p.children.pop());
        }
    }
    n.parent = node;
}

fn void NodePool.parent(&this, NodeHandle parent, NodeHandle child) {
    this.unparent(child);
    Node* p = this.get(parent);
    Node* c = this.get(child);
    io::printfn("Parenting node %x type %d to %x type %d", c, c.type, p, p.type);
    if (p == null || c == null) {
        return;
    }
    c.parent = parent;
    p.children.push(child);
}

fn void Engine.parentNode(&this, NodeHandle parent, NodeHandle child) {
    this.resource.nodes.parent(parent, child);
}

fn void Engine.addToRoot(&this, NodeHandle node) {
    this.parentNode(this.scene.root, node);
}
