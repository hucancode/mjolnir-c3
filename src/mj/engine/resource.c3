module mj::resource {Type};
import std::collections::list;
import std::core::mem::allocator;
import std::io;

bitstruct Handle: uint {
    uint index: 0..23; // lower 24 bits for index, max 8_388_608 items
    char generation: 24..31; // upper 8 bits for generation, max 256 generations
}

struct Entry {
    char generation;
    bool active;
    Type item;
}

struct ResourcePool {
    List{Entry} entries;
    List{uint} free_indices;
}

fn void ResourcePool.init(&self) {
    self.entries.init(allocator::heap());
    self.free_indices.init(allocator::heap());
}

fn Handle ResourcePool.malloc(&self) {
    uint? index = self.free_indices.pop();
    if (catch e = index) {
        Handle ret = {
            .index = (uint)self.entries.size,
            .generation = 1
        };
        self.entries.push({ .generation = 1, .active = true });
        return ret;
    }
    char gen = self.entries[index].generation + 1;
    self.entries[index].generation = gen;
    self.entries[index].active = true;
    return { .index = index, .generation = gen };
}

fn void ResourcePool.free(&self, Handle handle) {
    if (handle.index >= self.entries.size) {
        return;
    }
    char gen = self.entries[handle.index].generation;
    if (gen != handle.generation) {
        return;
    }
    if (!self.entries[handle.index].active) {
        return;
    }
    self.entries[handle.index].active = false;
    self.free_indices.push(handle.index);
}

macro Type* ResourcePool.get(&self, Handle handle) @operator([]) {
    if (handle.index >= self.entries.size) {
        io::printfn("ResourcePool.get: index (%d) out of bounds (%d)", handle.index, self.entries.size);
        return null;
    }
    if (!self.entries[handle.index].active) {
        io::printfn("ResourcePool.get: index (%d) has been freed", handle.index);
        return null;
    }
    if (self.entries[handle.index].generation != handle.generation) {
        io::printfn("ResourcePool.get: index (%d) has been freed and now belongs to other resource, its generation is changed from %d to %d", handle.index, handle.generation, self.entries[handle.index].generation);
        io::printf("Node pool: (%d) [", self.entries.len());
        foreach (n: self.entries) {
            io::printf("%d, ", n.generation);
        }
        io::printfn("]");
        return null;
    }
    return &self.entries[handle.index].item;
}

fn void ResourcePool.destroy(&self) {
    self.entries.free();
    self.free_indices.free();
}

module mj;
import std::io;
import mj::resource;
import vk;

alias StaticMeshPool = ResourcePool{StaticMesh};
alias SkeletalMeshPool = ResourcePool{SkeletalMesh};
alias MaterialPool = ResourcePool{Material};
alias SkinnedMaterialPool = ResourcePool{SkinnedMaterial};
alias TexturePool = ResourcePool{Texture};
alias LightPool = ResourcePool{Light};
alias NodePool = ResourcePool{Node};

alias StaticMeshHandle = Handle{StaticMesh};
alias SkeletalMeshHandle = Handle{SkeletalMesh};
alias MaterialHandle = Handle{Material};
alias SkinnedMaterialHandle = Handle{SkinnedMaterial};
alias TextureHandle = Handle{Texture};
alias LightHandle = Handle{Light};
alias NodeHandle = Handle{Node};

struct ResourceManager {
    StaticMeshPool meshes;
    SkeletalMeshPool skeletal_meshes;
    MaterialPool materials;
    SkinnedMaterialPool skinned_materials;
    TexturePool textures;
    LightPool lights;
    NodePool nodes;
}

fn void ResourceManager.init(&self) {
    self.meshes.init();
    self.skeletal_meshes.init();
    self.materials.init();
    self.skinned_materials.init();
    self.textures.init();
    self.lights.init();
    self.nodes.init();
}

fn StaticMeshHandle ResourceManager.mallocMesh(&self) @inline {
    return self.meshes.malloc();
}

fn StaticMesh* ResourceManager.getMesh(&self, StaticMeshHandle handle) @inline {
    return self.meshes[handle];
}

fn SkeletalMeshHandle ResourceManager.mallocSkeletalMesh(&self) @inline {
    return self.skeletal_meshes.malloc();
}

fn SkeletalMesh* ResourceManager.getSkeletalMesh(&self, SkeletalMeshHandle handle) @inline {
    return self.skeletal_meshes[handle];
}

fn MaterialHandle ResourceManager.mallocMaterial(&self) @inline {
    return self.materials.malloc();
}

fn Material* ResourceManager.getMaterial(&self, MaterialHandle handle) @inline {
    return self.materials[handle];
}

fn SkinnedMaterialHandle ResourceManager.createSkinnedMaterial(&self) @inline {
    return self.skinned_materials.malloc();
}

fn SkinnedMaterial* ResourceManager.getSkinnedMaterial(&self, SkinnedMaterialHandle handle) @inline {
    return self.skinned_materials[handle];
}

fn TextureHandle ResourceManager.mallocTexture(&self) @inline {
    return self.textures.malloc();
}

fn Texture* ResourceManager.getTexture(&self, TextureHandle handle) @inline {
    return self.textures[handle];
}

fn LightHandle ResourceManager.createLight(&self){
    LightHandle ret = self.lights.malloc();
    Light* light = self.lights[ret];
    light.color = {1.0f, 1.0f, 1.0f};
    light.intensity = 1.0f;
    return ret;
}

fn Light* ResourceManager.getLight(&self, LightHandle handle) @inline {
    return self.lights[handle];
}

fn NodeHandle ResourceManager.createNode(&self, NodeType type = NodeType.GROUP) {
    NodeHandle ret = self.nodes.malloc();
    Node* node = self.nodes[ret];
    node.init();
    node.type = type;
    node.parent = ret;
    return ret;
}

fn Node* ResourceManager.getNode(&self, NodeHandle handle) @inline {
    return self.nodes[handle];
}

fn Node* Engine.getNode(&self, NodeHandle handle) @inline {
    return self.resource.getNode(handle);
}

fn NodeHandle ResourceManager.createMeshNode(&self, StaticMeshHandle mesh) {
    NodeHandle ret = self.createNode(NodeType.STATIC_MESH);
    Node* node = self.nodes[ret];
    node.mesh = mesh;
    return ret;
}

fn NodeHandle ResourceManager.createSkeletalMeshNode(&self, SkeletalMeshHandle mesh) {
    NodeHandle ret = self.createNode(NodeType.SKELETAL_MESH);
    Node* node = self.nodes[ret];
    node.skeletal_mesh = mesh;
    return ret;
}

fn NodeHandle ResourceManager.createLightNode(&self, LightHandle light) {
    NodeHandle node = self.createNode(NodeType.LIGHT);
    Node* n = self.nodes[node];
    n.light = light;
    return node;
}

fn void ResourceManager.destroyNode(&self, NodeHandle handle) {
    self.nodes.unparent(handle);
    self.nodes[handle].destroy();
    // TODO: manage resource reference count, mesh, skeletal mesh, light
    self.nodes.free(handle);
}

fn void ResourceManager.destroyMesh(&self, StaticMeshHandle handle, vk::Device device) {
    self.meshes[handle].destroy(device);
    // TODO: manage resource reference count, material
    self.meshes.free(handle);
}

fn void ResourceManager.destroySkeletalMesh(&self, SkeletalMeshHandle handle, vk::Device device) {
    self.skeletal_meshes[handle].destroy(device);
    // TODO: manage resource reference count, material
    self.skeletal_meshes.free(handle);
}

// texture
fn void ResourceManager.destroyTexture(&self, TextureHandle handle, vk::Device device) {
    self.textures[handle].destroy(device);
    self.textures.free(handle);
}

fn void ResourceManager.destroyMaterial(&self, MaterialHandle handle, vk::Device device) {
    self.materials[handle].destroy(device);
    // TODO: manage resource reference count, texture
    self.materials.free(handle);
}

fn void ResourceManager.destroySkinnedMaterial(&self, SkinnedMaterialHandle handle, vk::Device device) {
    self.skinned_materials[handle].destroy(device);
    // TODO: manage resource reference count, texture
    self.skinned_materials.free(handle);
}

fn void ResourceManager.destroyLight(&self, LightHandle handle) {
    self.lights.free(handle);
}

fn void ResourceManager.destroy(&self, vk::Device device) {
    foreach(i, &entry : self.nodes.entries) {
        if (entry.active) {
            self.destroyNode({.index = (uint)i, .generation = entry.generation});
        }
    }
    self.nodes.destroy();
    foreach(i, &entry : self.meshes.entries) {
        if (entry.active) {
            io::printfn("Destroying mesh %d", i);
            self.destroyMesh({.index = (uint)i, .generation = entry.generation}, device);
        }
    }
    self.meshes.destroy();
    foreach(i, &entry : self.skeletal_meshes.entries) {
        if (entry.active) {
            self.destroySkeletalMesh({.index = (uint)i, .generation = entry.generation}, device);
        }
    }
    self.skeletal_meshes.destroy();
    foreach(i, &entry : self.textures.entries) {
        if (entry.active) {
            self.destroyTexture({.index = (uint)i, .generation = entry.generation}, device);
        }
    }
    self.textures.destroy();
    foreach(i, &entry : self.materials.entries) {
        if (entry.active) {
            self.destroyMaterial({.index = (uint)i, .generation = entry.generation}, device);
        }
    }
    self.materials.destroy();
    foreach(i, &entry : self.skinned_materials.entries) {
        if (entry.active) {
            self.destroySkinnedMaterial({.index = (uint)i, .generation = entry.generation}, device);
        }
    }
    self.skinned_materials.destroy();
    foreach(i, &entry : self.lights.entries) {
        if (entry.active) {
            self.destroyLight({.index = (uint)i, .generation = entry.generation});
        }
    }
    self.lights.destroy();
}
