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
    defer e.destroy();
    TextureHandle texture = e.createTexture($embed("mj/assets/statue-1275469_1280.jpg"))!!;
    Texture* texture_ptr = e.resource.getTexture(texture);
    MaterialHandle material = e.createMaterial()!!;
    io::printfn("Material created");
    e.resource.getMaterial(material).updateTextures(e.context.device, texture_ptr, texture_ptr, texture_ptr);
    StaticMeshHandle mesh = e.createCube(material)!!;
    io::printfn("Cube mesh created");
    NodeHandle handle = e.resource.createMeshNode(mesh);
    io::printfn("Node created");
    e.addToRoot(handle);
    Node* cube = e.getNode(handle);
    e.scene.camera.position = {2.0, 2.0, 2.0};
    io::printfn("App initialized");
    while (!e.shouldClose()) {
        cube.transform.rotation.setFromAxisAngle(mj::VEC_UP, math::PI * e.getTime());
        e.update();
        e.render();
    };
    return 0;
}
