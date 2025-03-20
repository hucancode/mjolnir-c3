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

fn void ResourcePool.init(&this) {
    this.entries.init(allocator::heap());
    this.free_indices.init(allocator::heap());
}

fn Handle ResourcePool.malloc(&this) {
    uint? index = this.free_indices.pop();
    if (catch e = index) {
        Handle ret = {
            .index = (uint)this.entries.size,
            .generation = 1
        };
        this.entries.push({ .generation = 1, .active = true });
        return ret;
    }
    char gen = this.entries[index].generation + 1;
    this.entries[index].generation = gen;
    this.entries[index].active = true;
    return { .index = index, .generation = gen };
}

fn void ResourcePool.free(&this, Handle handle) {
    if (handle.index >= this.entries.size) {
        return;
    }
    char gen = this.entries[handle.index].generation;
    if (gen != handle.generation) {
        return;
    }
    if (!this.entries[handle.index].active) {
        return;
    }
    this.entries[handle.index].active = false;
    this.free_indices.push(handle.index);
}

macro Type* ResourcePool.get(&this, Handle handle) @operator([]) {
    if (handle.index >= this.entries.size) {
        io::printfn("ResourcePool.get: index (%d) out of bounds (%d)", handle.index, this.entries.size);
        return null;
    }
    if (!this.entries[handle.index].active) {
        io::printfn("ResourcePool.get: index (%d) has been freed", handle.index);
        return null;
    }
    char gen = this.entries[handle.index].generation;
    if (gen != handle.generation) {
        io::printfn("ResourcePool.get: index (%d) has been allocated to other resource, its generation is changed from %d to %d", handle.index, gen, handle.generation);
        return null;
    }
    return &this.entries[handle.index].item;
}

fn void ResourcePool.destroy(&this) {
    this.entries.free();
    this.free_indices.free();
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

fn void ResourceManager.init(&this) {
    this.meshes.init();
    this.skeletal_meshes.init();
    this.materials.init();
    this.skinned_materials.init();
    this.textures.init();
    this.lights.init();
    this.nodes.init();
}

fn StaticMeshHandle ResourceManager.mallocMesh(&this) @inline {
    return this.meshes.malloc();
}

fn StaticMesh* ResourceManager.getMesh(&this, StaticMeshHandle handle) @inline {
    return this.meshes[handle];
}

fn SkeletalMeshHandle ResourceManager.mallocSkeletalMesh(&this) @inline {
    return this.skeletal_meshes.malloc();
}

fn SkeletalMesh* ResourceManager.getSkeletalMesh(&this, SkeletalMeshHandle handle) @inline {
    return this.skeletal_meshes[handle];
}

fn MaterialHandle ResourceManager.mallocMaterial(&this) @inline {
    return this.materials.malloc();
}

fn Material* ResourceManager.getMaterial(&this, MaterialHandle handle) @inline {
    return this.materials[handle];
}

fn SkinnedMaterialHandle ResourceManager.createSkinnedMaterial(&this) @inline {
    return this.skinned_materials.malloc();
}

fn SkinnedMaterial* ResourceManager.getSkinnedMaterial(&this, SkinnedMaterialHandle handle) @inline {
    return this.skinned_materials[handle];
}

fn TextureHandle ResourceManager.mallocTexture(&this) @inline {
    return this.textures.malloc();
}

fn Texture* ResourceManager.getTexture(&this, TextureHandle handle) @inline {
    return this.textures[handle];
}

fn LightHandle ResourceManager.createLight(&this){
    LightHandle ret = this.lights.malloc();
    Light* light = this.lights[ret];
    light.color = {1.0f, 1.0f, 1.0f};
    light.intensity = 1.0f;
    return ret;
}

fn Light* ResourceManager.getLight(&this, LightHandle handle) @inline {
    return this.lights[handle];
}

fn NodeHandle ResourceManager.createNode(&this, NodeType type = NodeType.GROUP) {
    NodeHandle ret = this.nodes.malloc();
    Node* node = this.nodes[ret];
    node.init();
    node.type = type;
    return ret;
}

fn Node* ResourceManager.getNode(&this, NodeHandle handle) @inline {
    return this.nodes[handle];
}

fn Node* Engine.getNode(&this, NodeHandle handle) @inline {
    return this.resource.getNode(handle);
}

fn NodeHandle ResourceManager.createMeshNode(&this, StaticMeshHandle mesh) {
    NodeHandle ret = this.createNode(NodeType.STATIC_MESH);
    Node* node = this.nodes[ret];
    node.mesh = mesh;
    return ret;
}

fn NodeHandle ResourceManager.createSkeletalMeshNode(&this, SkeletalMeshHandle mesh) {
    NodeHandle ret = this.createNode(NodeType.SKELETAL_MESH);
    Node* node = this.nodes[ret];
    node.skeletal_mesh = mesh;
    return ret;
}

fn NodeHandle ResourceManager.createLightNode(&this, LightHandle light) {
    NodeHandle node = this.createNode(NodeType.LIGHT);
    Node* n = this.nodes[node];
    n.light = light;
    return node;
}

fn void ResourceManager.destroyNode(&this, NodeHandle handle) {
    this.nodes.unparent(handle);
    // TODO: manage resource reference count, mesh, skeletal mesh, light
    this.nodes.free(handle);
}

fn void ResourceManager.destroyMesh(&this, StaticMeshHandle handle, vk::Device device) {
    StaticMesh* mesh = this.meshes[handle];
    mesh.destroy(device);
    // TODO: manage resource reference count, material
    this.meshes.free(handle);
}

fn void ResourceManager.destroySkeletalMesh(&this, SkeletalMeshHandle handle, vk::Device device) {
    SkeletalMesh* mesh = this.skeletal_meshes[handle];
    mesh.destroy(device);
    // TODO: manage resource reference count, material
    this.skeletal_meshes.free(handle);
}

// texture
fn void ResourceManager.destroyTexture(&this, TextureHandle handle, vk::Device device) {
    Texture* texture = this.textures[handle];
    texture.destroy(device);
    this.textures.free(handle);
}

fn void ResourceManager.destroyMaterial(&this, MaterialHandle handle, vk::Device device) {
    Material* material = this.materials[handle];
    material.destroy(device);
    // TODO: manage resource reference count, texture
    this.materials.free(handle);
}

fn void ResourceManager.destroySkinnedMaterial(&this, SkinnedMaterialHandle handle, vk::Device device) {
    SkinnedMaterial* material = this.skinned_materials[handle];
    material.destroy(device);
    // TODO: manage resource reference count, texture
    this.skinned_materials.free(handle);
}

fn void ResourceManager.destroyLight(&this, LightHandle handle) {
    this.lights.free(handle);
}

fn void ResourceManager.destroy(&this, vk::Device device) {
    foreach(i, &entry : this.nodes.entries) {
        if (entry.active) {
            this.destroyNode({.index = (uint)i, .generation = entry.generation});
        }
    }
    this.nodes.destroy();
    foreach(i, &entry : this.meshes.entries) {
        if (entry.active) {
            io::printfn("Destroying mesh %d", i);
            this.destroyMesh({.index = (uint)i, .generation = entry.generation}, device);
        }
    }
    this.meshes.destroy();
    foreach(i, &entry : this.skeletal_meshes.entries) {
        if (entry.active) {
            this.destroySkeletalMesh({.index = (uint)i, .generation = entry.generation}, device);
        }
    }
    this.skeletal_meshes.destroy();
    foreach(i, &entry : this.textures.entries) {
        if (entry.active) {
            this.destroyTexture({.index = (uint)i, .generation = entry.generation}, device);
        }
    }
    this.textures.destroy();
    foreach(i, &entry : this.materials.entries) {
        if (entry.active) {
            this.destroyMaterial({.index = (uint)i, .generation = entry.generation}, device);
        }
    }
    this.materials.destroy();
    foreach(i, &entry : this.skinned_materials.entries) {
        if (entry.active) {
            this.destroySkinnedMaterial({.index = (uint)i, .generation = entry.generation}, device);
        }
    }
    this.skinned_materials.destroy();
    foreach(i, &entry : this.lights.entries) {
        if (entry.active) {
            this.destroyLight({.index = (uint)i, .generation = entry.generation});
        }
    }
    this.lights.destroy();
}
