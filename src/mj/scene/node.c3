module mj;
import std::io;
import std::math::matrix;
import std::math::quaternion;
import std::collections::list;
import std::core::mem::allocator;

enum NodeType {
    UNKNOWN,
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
    List{NodeHandle} children;
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

fn void Node.init(&self) {
    self.children.init(allocator::heap());
    self.transform.scale = {1.0, 1.0, 1.0};
}

fn void Node.destroy(&self) {
    self.children.free();
}

fn Matrix4f Transform.toMatrix(&self) {
    return self.rotation.to_matrixf()
        .translate(self.position)
        .scale(self.scale);
}

fn void NodePool.unparent(&self, NodeHandle node) {
    Node* n = self.get(node);
    if (n == null) {
        return;
    }
    Node* p = self.get(n.parent);
    if (p != null && p != n) {
        if (try i = p.children.index_of(node)) {
            if(try last = p.children.pop()) {
                if (i < p.children.len()) {
                    p.children[i] = last;
                }
            }
        }
    }
    n.parent = node;
}

fn void NodePool.parent(&self, NodeHandle parent, NodeHandle child) {
    self.unparent(child);
    Node* p = self.get(parent);
    Node* c = self.get(child);
    io::printfn("Parenting node %x type %d to %x type %d", c, c.type.ordinal, p, p.type.ordinal);
    if (p == null || c == null) {
        return;
    }
    io::printfn("Parenting node %x type %d to %x type %d", c, c.type.ordinal, p, p.type.ordinal);
    c.parent = parent;
    p.children.push(child);
}

fn void Engine.parentNode(&self, NodeHandle parent, NodeHandle child) {
    self.resource.nodes.parent(parent, child);
}

fn void Engine.addToRoot(&self, NodeHandle node) {
    self.parentNode(self.scene.root, node);
}
