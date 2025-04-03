module mj;
import vk;
import std::core::mem;
import std::io;

struct Vertex {
	Vec3f position;
	Vec3f normal;
	Vec4f color;
	Vec2f uv;
}

const vk::VertexInputBindingDescription[*] VERTEX_DESCRIPTION = {{
	.binding   = 0,
	.stride    = Vertex.sizeof,
	.input_rate = vk::VERTEX_INPUT_RATE_VERTEX,
}};

const vk::VertexInputAttributeDescription[*] VERTEX_ATTR_DESCRIPTION = {{
   .binding = 0, .location = 0, .format = vk::FORMAT_R32G32B32_SFLOAT, .offset = Vertex.position.offsetof
}, {
    .binding = 0, .location = 1, .format = vk::FORMAT_R32G32B32_SFLOAT, .offset = Vertex.normal.offsetof
}, {
   .binding = 0, .location = 2, .format = vk::FORMAT_R32G32B32A32_SFLOAT, .offset = Vertex.color.offsetof
}, {
   .binding = 0, .location = 3, .format = vk::FORMAT_R32G32_SFLOAT, .offset = Vertex.uv.offsetof
}};

struct StaticMesh {
    MaterialHandle material;
    Vertex[] vertices;
    uint[] indices;
    DataBuffer vertex_buffer;
    DataBuffer index_buffer;
}

fn void? VulkanContext.buildMesh(&self, StaticMesh* mesh, Vertex[] vertices, uint[] indices, MaterialHandle material) {
    mesh.material = material;
    mesh.vertices = vertices;
    mesh.indices = indices;
    io::printfn("building mesh with %d vertices %d indices", vertices.len, indices.len);
    mesh.vertex_buffer = self.createLocalBuffer(mesh.vertices, Vertex.sizeof * mesh.vertices.len, { .vertex_buffer })!;
    mesh.index_buffer = self.createLocalBuffer(mesh.indices, uint.sizeof * mesh.indices.len, { .index_buffer })!;
    io::printfn("mesh indices and vertices built");
}

fn void? VulkanContext.buildCube(&self, StaticMesh* mesh, MaterialHandle material, float[<4>] color = {0.125, 0.25, 0.5, 1.0}) {
    const Vec3f A =  {-1.0, -1.0, 1.0};
    const Vec3f B =  {1.0, -1.0, 1.0};
    const Vec3f C =  {1.0, 1.0, 1.0};
    const Vec3f D =  {-1.0, 1.0, 1.0};
    const Vec3f E =  {-1.0, 1.0, -1.0};
    const Vec3f F =  {1.0, 1.0, -1.0};
    const Vec3f G =  {1.0, -1.0, -1.0};
    const Vec3f H =  {-1.0, -1.0, -1.0};
    Vertex[] vertices = {
        // Front face
        {.position = A, .color = color, .normal = VEC_FORWARD, .uv = {0.0, 1.0}},
        {.position = B, .color = color, .normal = VEC_FORWARD, .uv = {1.0, 1.0}},
        {.position = C, .color = color, .normal = VEC_FORWARD, .uv = {1.0, 0.0}},
        {.position = D, .color = color, .normal = VEC_FORWARD, .uv = {0.0, 0.0}},
        // Back face
        {.position = E, .color = color, .normal = VEC_BACKWARD, .uv = {1.0, 1.0}},
        {.position = F, .color = color, .normal = VEC_BACKWARD, .uv = {0.0, 1.0}},
        {.position = G, .color = color, .normal = VEC_BACKWARD, .uv = {0.0, 0.0}},
        {.position = H, .color = color, .normal = VEC_BACKWARD, .uv = {1.0, 0.0}},
        // Top face
        {.position = F, .color = color, .normal = VEC_UP, .uv = {0.0, 1.0}},
        {.position = E, .color = color, .normal = VEC_UP, .uv = {1.0, 1.0}},
        {.position = D, .color = color, .normal = VEC_UP, .uv = {1.0, 0.0}},
        {.position = C, .color = color, .normal = VEC_UP, .uv = {0.0, 0.0}},
        // Bottom face
        {.position = B, .color = color, .normal = VEC_DOWN, .uv = {0.0, 1.0}},
        {.position = A, .color = color, .normal = VEC_DOWN, .uv = {1.0, 1.0}},
        {.position = H, .color = color, .normal = VEC_DOWN, .uv = {1.0, 0.0}},
        {.position = G, .color = color, .normal = VEC_DOWN, .uv = {0.0, 0.0}},
        // Right face
        {.position = G, .color = color, .normal = VEC_RIGHT, .uv = {0.0, 1.0}},
        {.position = F, .color = color, .normal = VEC_RIGHT, .uv = {1.0, 1.0}},
        {.position = C, .color = color, .normal = VEC_RIGHT, .uv = {1.0, 0.0}},
        {.position = B, .color = color, .normal = VEC_RIGHT, .uv = {0.0, 0.0}},
        // Left face
        {.position = A, .color = color, .normal = VEC_LEFT, .uv = {0.0, 1.0}},
        {.position = D, .color = color, .normal = VEC_LEFT, .uv = {1.0, 1.0}},
        {.position = E, .color = color, .normal = VEC_LEFT, .uv = {1.0, 0.0}},
        {.position = H, .color = color, .normal = VEC_LEFT, .uv = {0.0, 0.0}},
    };
    uint[] indices = {
        // Front face
        0, 1, 2, 2, 3, 0,
        // Back face
        4, 5, 6, 6, 7, 4,
        // Top face
        8, 9, 10, 10, 11, 8,
        // Bottom face
        12, 13, 14, 14, 15, 12,
        // Right face
        16, 17, 18, 18, 19, 16,
        // Left face
        20, 21, 22, 22, 23, 20
    };
    self.buildMesh(mesh, vertices, indices, material)!;
}

fn void StaticMesh.destroy(&self, vk::Device device) {
    self.vertex_buffer.destroy(device);
    self.index_buffer.destroy(device);
}

fn StaticMeshHandle? Engine.createMesh(&self, Vertex[] vertices, uint[] indices, MaterialHandle material) {
    StaticMeshHandle ret = self.resource.mallocMesh();
    self.context.buildMesh(self.resource.getMesh(ret), vertices, indices, material)!;
    io::printfn("Mesh created %d", ret.index);
    return ret;
}

fn StaticMeshHandle? Engine.createCube(&self, MaterialHandle material) {
    StaticMeshHandle ret = self.resource.mallocMesh();
    io::printfn("mesh allocated");
    self.context.buildCube(self.resource.getMesh(ret), material)!;
    return ret;
}
