module mj::resource (<Type>);
import std::collections::list;
import std::core::mem;

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
    List(<Entry>) entries;
    List(<uint>) free_indices;
}

fn Handle ResourcePool.malloc(ResourcePool* this) {
    if (this.free_indices.is_empty()) {
        uint index = (uint)this.entries.size;
        this.entries.push({.generation = 0, .active = true});
        return {index, 0};
    }
    uint index = this.free_indices.pop()!!;
    char gen = this.entries[index].generation + 1;
    this.entries[index].generation = gen;
    this.entries[index].active = true;
    return {index, gen};
}

fn void ResourcePool.free(ResourcePool* this, Handle handle) {
    if (handle.index >= this.entries.size) {
        return;
    }
    char gen = this.entries[handle.index].generation;
    if (gen != handle.generation) {
        return;
    }
    this.entries[handle.index].active = false;
    this.free_indices.push(handle.index);
}

fn Type* ResourcePool.get(ResourcePool* this, Handle handle) {
    if (handle.index >= this.entries.size) {
        return null;
    }
    char gen = this.entries[handle.index].generation;
    if (gen != handle.generation) {
        return null;
    }
    if (this.entries[handle.index].generation != gen) {
        return null;
    }
    return &this.entries[handle.index].item;
}

module mj;
import mj::resource;

def StaticMeshPool = ResourcePool(<StaticMesh>);
def SkeletalMeshPool = ResourcePool(<SkeletalMesh>);
def MaterialPool = ResourcePool(<Material>);
def SkinnedMaterialPool = ResourcePool(<SkinnedMaterial>);
def TexturePool = ResourcePool(<Texture>);
def LightPool = ResourcePool(<Light>);
def NodePool = ResourcePool(<Node>);

def StaticMeshHandle = Handle(<StaticMesh>);
def SkeletalMeshHandle = Handle(<SkeletalMesh>);
def MaterialHandle = Handle(<Material>);
def SkinnedMaterialHandle = Handle(<SkinnedMaterial>);
def TextureHandle = Handle(<Texture>);
def LightHandle = Handle(<Light>);
def NodeHandle = Handle(<Node>);

struct ResourceManager {
    StaticMeshPool meshes;
    SkeletalMeshPool skeletal_meshes;
    MaterialPool materials;
    SkinnedMaterialPool skinned_materials;
    TexturePool textures;
    LightPool lights;
    NodePool nodes;
}

fn StaticMeshHandle ResourceManager.mallocMesh(&this) @inline {
    return this.meshes.malloc();
}

fn StaticMesh* ResourceManager.getMesh(&this, StaticMeshHandle handle) @inline {
    return this.meshes.get(handle);
}

fn SkeletalMeshHandle ResourceManager.mallocSkeletalMesh(&this) @inline {
    return this.skeletal_meshes.malloc();
}

fn SkeletalMesh* ResourceManager.getSkeletalMesh(&this, SkeletalMeshHandle handle) @inline {
    return this.skeletal_meshes.get(handle);
}

fn MaterialHandle ResourceManager.mallocMaterial(&this) @inline {
    return this.materials.malloc();
}

fn Material* ResourceManager.getMaterial(&this, MaterialHandle handle) @inline {
    return this.materials.get(handle);
}

fn SkinnedMaterialHandle ResourceManager.createSkinnedMaterial(&this) @inline {
    return this.skinned_materials.malloc();
}

fn SkinnedMaterial* ResourceManager.getSkinnedMaterial(&this, SkinnedMaterialHandle handle) @inline {
    return this.skinned_materials.get(handle);
}

fn TextureHandle ResourceManager.mallocTexture(&this) @inline {
    return this.textures.malloc();
}

fn Texture* ResourceManager.getTexture(&this, TextureHandle handle) @inline {
    return this.textures.get(handle);
}

fn LightHandle ResourceManager.createLight(&this){
    LightHandle ret = this.lights.malloc();
    Light* light = this.lights.get(ret);
    light.color = {1.0f, 1.0f, 1.0f};
    light.intensity = 1.0f;
    return ret;
}

fn Light* ResourceManager.getLight(&this, LightHandle handle) @inline {
    return this.lights.get(handle);
}

fn NodeHandle ResourceManager.createNode(&this, NodeType type = NodeType.GROUP) {
    NodeHandle ret = this.nodes.malloc();
    Node* node = this.nodes.get(ret);
    node.transform.scale = {1.0f, 1.0f, 1.0f};
    node.type = type;
    return ret;
}

fn Node* ResourceManager.getNode(&this, NodeHandle handle) @inline {
    return this.nodes.get(handle);
}

fn Node* Engine.getNode(&this, NodeHandle handle) @inline {
    return this.resource.getNode(handle);
}

fn NodeHandle ResourceManager.createMeshNode(&this, StaticMeshHandle mesh) {
    NodeHandle ret = this.createNode(NodeType.STATIC_MESH);
    Node* node = this.nodes.get(ret);
    node.mesh = mesh;
    return ret;
}

fn NodeHandle ResourceManager.createSkeletalMeshNode(&this, SkeletalMeshHandle mesh) {
    NodeHandle ret = this.createNode(NodeType.SKELETAL_MESH);
    Node* node = this.nodes.get(ret);
    node.skeletal_mesh = mesh;
    return ret;
}

fn NodeHandle ResourceManager.createLightNode(&this, LightHandle light) {
    NodeHandle node = this.createNode(NodeType.LIGHT);
    Node* n = this.nodes.get(node);
    n.light = light;
    return node;
}
