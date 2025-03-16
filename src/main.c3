module hellovk;
import std::io;
import std::math;
import glfw;
import mj;

const WIDTH = 1024;
const HEIGHT = 768;
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
    Node*[4] nodes;
    NodeHandle prev = e.scene.root;
    for (uint i = 0;i<4;i++) {
        NodeHandle handle = e.resource.createMeshNode(mesh);
        nodes[i] = e.getNode(handle);
        e.resource.nodes.parent(prev, handle);
        if (i > 0) {
            nodes[i].transform.position.x = 4.0f;
        }
        prev = handle;
    }
    e.scene.camera.position = {0.0, 5.0, 20.0};
    io::printfn("App initialized");
    while (!e.shouldClose()) {
        for (uint i = 0;i<4;i++) {
            nodes[i].transform.rotation.setFromAxisAngle(mj::VEC_UP, math::PI * e.getTime()*0.5f);
        }
        e.update();
        e.render();
    };
    return 0;
}
