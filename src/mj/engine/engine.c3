module mj;
import std::time;
import std::io;
import std::collections::list;
import std::math;
import libc;
import vk;
import glfw;

const RENDER_FPS = 120;
const FRAME_TIME = 1.0 / RENDER_FPS;
const UPDATE_FPS = 8;
const UPDATE_FRAME_TIME = 1.0 / UPDATE_FPS;
struct Engine {
    glfw::Window* window;
    VulkanContext context;
    Renderer renderer;
    ResourceManager resource;
    Scene scene;
    Time last_frame_timestamp;
    Time last_update_timestamp;
    Time start_timestamp;
}

fn void? Engine.init(&this, uint width, uint height, ZString title) {
    io::printfn("GLFW %s",glfw::getVersionString());
    glfw::setErrorCallback(fn void(int error, ZString description) => io::printfn("GLFW error(%x): %s", error, description));
    if (!glfw::init()) {
        return vk::error::NOT_READY?;
    }
    glfw::windowHint(glfw::CLIENT_API, glfw::NO_API);
    this.window = glfw::createWindow(width, height, title, null, null);
    if (this.window == null) {
        return vk::error::NOT_READY?;
    }
    io::printfn("Window created %x", this.window);
    this.start_timestamp = time::now();
    this.last_frame_timestamp = time::now();
    this.last_update_timestamp = time::now();
    this.context.init(this.window)!;
    this.resource.init();
    this.buildScene()!;
    this.buildRenderer()!;
    this.scene.camera.aspect_ratio = (float)this.renderer.extent.width / (float)this.renderer.extent.height;
    io::printfn("Engine initialized");
}

fn void? Engine.buildScene(&this) {
    this.scene.init(this.context.device)!;
    this.scene.root = this.resource.createNode(NodeType.ROOT);
}

fn void? Engine.buildRenderer(&this) {
    QueueFamilyIndices indices = this.context.findQueueFamilies(this.context.physical_device)!;
    SwapchainSupport support= this.context.querySwapchainSupport(this.context.physical_device)!;
    this.renderer.buildSwapchain(this.context.device, this.context.surface, support.capabilities, support.formats, support.present_modes, indices.graphics_family, indices.present_family)!;
    this.renderer.buildCommandBuffers(this.context.device, this.context.command_pool)!;
    this.renderer.buildSynchronizers(this.context.device)!;
    for (uint i = 0; i < MAX_FRAMES_IN_FLIGHT; i++) {
        this.renderer.frames[i].uniform =  this.context.mallocHostVisibleBuffer(SceneUniform.sizeof, { .uniform_buffer })!;
        vk::DescriptorSetAllocateInfo alloc_info = {
    		.s_type              = vk::STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
    		.descriptor_pool     = this.context.descriptor_pool,
    		.descriptor_set_count = 1,
    		.p_set_layouts        = &this.scene.descriptor_set_layout,
    	};
        io::printfn("creating descriptor set for frame %d with pool %x and set layout %x", i, this.context.descriptor_pool, this.scene.descriptor_set_layout);
    	vk::allocateDescriptorSets(this.context.device, &alloc_info, &this.renderer.frames[i].descriptor_set)!;
        io::printfn("created descriptor set");
        vk::DescriptorBufferInfo uniform_info = {
            .buffer = this.renderer.frames[i].uniform.buffer,
            .offset = 0,
            .range = SceneUniform.sizeof
        };
        vk::WriteDescriptorSet[*] writes = {{
            .s_type = vk::STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dst_set = this.renderer.frames[i].descriptor_set,
            .dst_binding = 0,
            .descriptor_type = vk::DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .descriptor_count = 1,
            .p_buffer_info = &uniform_info
        }};
        vk::updateDescriptorSets(this.context.device, writes.len, &writes);
    }
    this.renderer.depth_buffer = this.context.createDepthImage(vk::FORMAT_D32_SFLOAT, this.renderer.extent.width, this.renderer.extent.height)!;
}

fn void Engine.pushSceneUniform(&this) {
    SceneUniform data = {
        .view = this.scene.viewMatrix(),
        .projection = this.scene.projectionMatrix(),
        .time = (float)time::now().diff_sec(this.start_timestamp),
    };
    this.context.writeBuffer(this.renderer.getUniform(), &data);
}
fn void? Engine.tryRender(&this) {
    uint image_idx = this.renderer.begin(this.context.device)!;
    this.pushSceneUniform();
    vk::CommandBuffer command_buffer = this.renderer.getCommandBuffer();
    List{NodeHandle} node_stack;
    List{Matrix4f} transform_stack;
    node_stack.tinit();
    transform_stack.tinit();
    defer {
        node_stack.free();
        transform_stack.free();
    }
    foreach (node : this.resource.nodes[this.scene.root].children) {
        node_stack.push(node);
        transform_stack.push(MATRIX4F_IDENTITY);
    }
    while (!node_stack.is_empty()) {
        NodeHandle handle = node_stack.pop()!;
        Node* node = this.resource.getNode(handle);
        Matrix4f local_matrix = node.transform.toMatrix();
        Matrix4f world_matrix = transform_stack.pop()!.mul(local_matrix);
        switch (node.type) {
            case NodeType.GROUP:
                break;
            case NodeType.SKELETAL_MESH:
                SkeletalMesh* mesh = this.resource.getSkeletalMesh(node.skeletal_mesh);
                SkinnedMaterial* material = this.resource.getSkinnedMaterial(mesh.material);
                // Update bone matrices
                Matrix4f* bones = (Matrix4f*)mesh.bone_buffer.mapped;
                for (uint i = 0; i < mesh.bones.len; i++) {
                    Node* bone_node = this.resource.getNode(mesh.bones[i]);
                    bones[i] = bone_node.transform.toMatrix();
                }
                material.updateBoneBuffer(this.context.device, mesh.bone_buffer.buffer, (vk::DeviceSize)mesh.bone_buffer.size);
                vk::cmdBindPipeline(command_buffer, vk::PIPELINE_BIND_POINT_GRAPHICS, material.pipeline);
                vk::DescriptorSet[*] sets = {
                    this.renderer.getDescriptorSet(),
                    material.descriptor_set
                };
                vk::cmdBindDescriptorSets(
                    command_buffer,
                    vk::PIPELINE_BIND_POINT_GRAPHICS,
                    material.pipeline_layout,
                    0,
                    sets.len,
                    &sets,
                    0,
                    null
                );
                vk::cmdPushConstants(
                    command_buffer,
                    material.pipeline_layout,
                    {.vertex},
                    0,
                    Matrix4f.sizeof,
                    &&world_matrix.transpose(),
                );
                vk::DeviceSize offset = 0;
                vk::cmdBindVertexBuffers(command_buffer, 0, 1, &mesh.vertex_buffer.buffer, &offset);
                vk::cmdBindIndexBuffer(command_buffer, mesh.index_buffer.buffer, 0, vk::INDEX_TYPE_UINT32);
                vk::cmdDrawIndexed(command_buffer, mesh.indices.len);
                break;
            case NodeType.STATIC_MESH:
                StaticMesh* mesh = this.resource.getMesh(node.mesh);
                Material* material = this.resource.getMaterial(mesh.material);
                // io::printfn("drawing mesh %x, material %x", mesh, material);
                vk::cmdBindPipeline(command_buffer, vk::PIPELINE_BIND_POINT_GRAPHICS, material.pipeline);
                vk::DescriptorSet[*] descriptor_sets = {
                    this.renderer.getDescriptorSet(),
                    material.descriptor_set,
                };
                vk::cmdBindDescriptorSets(
                    command_buffer,
                    vk::PIPELINE_BIND_POINT_GRAPHICS,
                    material.pipeline_layout,
                    0,
                    descriptor_sets.len,
                    &descriptor_sets,
                    0,
                    null
                );
                vk::cmdPushConstants(
                    command_buffer,
                    material.pipeline_layout,
                    {.vertex},
                    0,
                    Matrix4f.sizeof,
                    &&world_matrix.transpose(),
                );
                vk::DeviceSize offset = 0;
                vk::cmdBindVertexBuffers(command_buffer, 0, 1, &mesh.vertex_buffer.buffer, &offset);
                vk::cmdBindIndexBuffer(command_buffer, mesh.index_buffer.buffer, 0, vk::INDEX_TYPE_UINT32);
                vk::cmdDrawIndexed(command_buffer, mesh.indices.len);
                break;
            default:
                io::printfn("this.resource.nodes[this.scene.root].children = %d", this.resource.nodes[this.scene.root].children.len());
                io::printfn("Unknown node type %d, handle = %d - %d", node.type.ordinal, handle.index, handle.generation);
                // libc::exit(1);
                break;
        }
        // io::printfn("traversing children for node %x %d", node, node.children.len());
        foreach (child : node.children) {
            if (child.index == 0) {
                io::printfn("a node can't have root node as a child %d %d", handle.index, handle.generation);
                // libc::exit(1);
            }
            node_stack.push(child);
            transform_stack.push(world_matrix);
        }
    }
    this.renderer.end(image_idx, this.context.graphics_queue, this.context.present_queue)!;
}

fn void Engine.render(&this) {
    if (time::now().diff_sec(this.last_frame_timestamp) < FRAME_TIME) {
        return;
    }
    fault excuse = @catch(this.tryRender());
    if (excuse == vk::error::ERROR_OUT_OF_DATE_KHR || excuse == vk::error::SUBOPTIMAL_KHR) {
        excuse = @catch(this.recreateSwapchain());
        if (excuse) {
            io::printfn("Something went wrong while recreating swapchain!");
        }
    } else if (excuse) {
        io::printfn("Something went wrong while rendering!");
    }
    this.last_frame_timestamp = time::now();
}

fn void? Engine.recreateSwapchain(&this) {
    SwapchainSupport support = this.context.querySwapchainSupport(this.context.physical_device)!;
    QueueFamilyIndices indices = this.context.findQueueFamilies(this.context.physical_device)!;
    vk::deviceWaitIdle(this.context.device)!;
    this.renderer.destroySwapchain(this.context.device);
    this.renderer.buildSwapchain(this.context.device, this.context.surface, support.capabilities, support.formats, support.present_modes, indices.graphics_family, indices.present_family)!;
}

fn float Engine.getDeltaTime(&this) {
    return (float)time::now().diff_sec(this.last_update_timestamp);
}

fn float Engine.getTime(&this) {
    return (float)time::now().diff_sec(this.start_timestamp);
}

fn bool Engine.shouldClose(&this) {
    return glfw::windowShouldClose(this.window) != 0;
}

fn bool Engine.update(&this) {
    glfw::pollEvents();
    float delta_time = this.getDeltaTime();
    if (delta_time < UPDATE_FRAME_TIME) {
        return false;
    }
    foreach (&entry : this.resource.nodes.entries) {
        if (!entry.active) continue;
        Node* node = &entry.item;
        if (node.type != NodeType.SKELETAL_MESH) continue;
        if (node.animation.status != AnimationStatus.PLAYING) continue;
        AnimationInstance* anim = &node.animation;
        anim.time += delta_time;
        SkeletalMesh* mesh = this.resource.getSkeletalMesh(node.skeletal_mesh);
        if (!mesh) continue;
        AnimationTrack? track = mesh.animations[anim.name];
        if (catch excuse = track) {
            continue;
        }
        switch (anim.mode) {
            case AnimationPlayMode.LOOP:
                anim.time = fmod(anim.time, track.duration);
                break;
            case AnimationPlayMode.ONCE:
                if (anim.time >= track.duration) {
                    anim.time = track.duration;
                    anim.status = AnimationStatus.STOPPED;
                }
                break;
            case AnimationPlayMode.PINGPONG:
                // handle playing in reverse
                break;
            default: break;
        }
        track.update(anim.time, &this.resource.nodes, mesh.bones);
    }
    this.last_update_timestamp = time::now();
    return true;
}

fn void? Engine.destroy(&this) {
    vk::deviceWaitIdle(this.context.device)!;
    this.resource.destroy(this.context.device);
    this.renderer.destroy(this.context.device, this.context.command_pool);
    this.scene.destroy(this.context.device);
    this.context.destroy()!;
    glfw::destroyWindow(this.window);
    glfw::terminate();
}
