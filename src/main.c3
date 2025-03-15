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
    MaterialHandle material = e.createMaterial()!!;
    io::printfn("Material created");
    StaticMeshHandle mesh = e.createCube(material)!!;
    io::printfn("Cube mesh created");
    NodeHandle handle = e.resource.createMeshNode(mesh);
    io::printfn("Node created");
    e.addToRoot(handle);
    Node* cube = e.getNode(handle);
    io::printfn("App initialized");
    while (!e.shouldClose()) {
        cube.transform.rotation.setFromAxisAngle(mj::VEC_UP, math::PI * e.getTime());
        e.update();
        e.render();
        io::printfn("Frame rendered");
    };
    return 0;
}
