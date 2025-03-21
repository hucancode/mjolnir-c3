module hellovk;
import std::io;
import std::math;
import glfw;
import mj;

const WIDTH = 1280;
const HEIGHT = 720;
const TITLE = "Hello Mjolnir!";

fn int main(String[] args) {
    Engine e;
    e.init(WIDTH, HEIGHT, TITLE)!!;
    defer e.destroy()!!;
    TextureHandle texture = e.createTexture($embed("mj/assets/statue-1275469_1280.jpg"))!!;
    Texture* texture_ptr = e.resource.getTexture(texture);
    MaterialHandle material = e.createMaterial()!!;
    e.resource
        .getMaterial(material)
        .updateTextures(e.context.device, texture_ptr, texture_ptr, texture_ptr);
    StaticMeshHandle mesh = e.createCube(material)!!;
    NodeHandle[4] nodes;
    NodeHandle prev = e.scene.root;
    // animating tail
    for (uint i = 0;i<4;i++) {
        nodes[i] = e.resource.createMeshNode(mesh);
        Node* node = e.resource.nodes[nodes[i]];
        e.parentNode(prev, nodes[i]);
        if (i > 0) {
            node.transform.position.x = 3.0f;
        } else {
            node.transform.position.y = 2.5f;
        }
        prev = nodes[i];
    }
    // cube array
    for (int i = -2;i<=2;i++) {
        for (int j = -2;j<=2;j++) {
            NodeHandle handle = e.resource.createMeshNode(mesh);
            e.addToRoot(handle);
            Node* node = e.resource.nodes[handle];
            node.transform.position.x = i * 3.0f;
            node.transform.position.z = j * 3.0f;
        }
    }
    e.scene.camera.position = {0.0, 5.0, 10.0};
    io::printfn("App initialized");
    while (!e.shouldClose()) {
        if(e.update()) {
            // animate tail by setting rotation
            foreach (cube : nodes) {
                e.resource.nodes[cube].transform.rotation
                    .setFromAxisAngle(mj::VEC_UP, math::PI * e.getTime()*0.5f);
            }
        }
        e.render();
        //break;
    };
    return 0;
}
