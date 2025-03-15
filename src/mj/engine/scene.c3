module mj;
import std::time;
import vk;

struct Scene {
    NodeHandle root;
    Camera camera;
    vk::DescriptorSetLayout descriptor_set_layout;
}

fn void! Scene.init(&this, vk::Device device) {
    this.camera = {
        .projection = CameraProjection.PERSPECTIVE,
        .fov = 45.0,
        .aspect_ratio = 16.0 / 9.0,
        .near = 0.1,
        .far = 10000.0,
        .up = VEC_UP,
    };
    // scene-level descriptor set layout
    vk::DescriptorSetLayoutBinding view= {
        .binding = 0,
        .descriptor_type = vk::DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptor_count = 1,
        .stage_flags = { .vertex },
    };
    vk::DescriptorSetLayoutBinding proj = {
        .binding = 1,
        .descriptor_type = vk::DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptor_count = 1,
        .stage_flags = { .vertex },
    };
    vk::DescriptorSetLayoutBinding time = {
        .binding = 2,
        .descriptor_type = vk::DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptor_count = 1,
        .stage_flags = { .vertex, .fragment },
    };
    vk::DescriptorSetLayoutBinding[*] bindings = { view, proj, time };
    vk::DescriptorSetLayoutCreateInfo info = {
        .s_type        = vk::STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
  		.binding_count = bindings.len,
  		.p_bindings    = &bindings,
   	};
   	this.descriptor_set_layout = vk::createDescriptorSetLayout(device, &info)!;
}

fn void Scene.destroy(&this, vk::Device device) {
    vk::destroyDescriptorSetLayout(device, this.descriptor_set_layout);
}

fn Matrix4f Scene.viewMatrix(&this) @inline {
    return this.camera.calculateLookatMatrix();
}

fn Matrix4f Scene.projectionMatrix(&this) @inline {
    return this.camera.calculateProjectionMatrix();
}
