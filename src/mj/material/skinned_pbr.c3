module mj;
import vk;

struct SkinnedMaterial {
    char[] vertex_code;
    char[] fragment_code;
    TextureHandle albedo;
    TextureHandle metallic;
    TextureHandle roughness;
    vk::PipelineLayout pipeline_layout;
    vk::Pipeline pipeline;
    vk::DescriptorSetLayout descriptor_set_layout;
    vk::DescriptorSet descriptor_set;
    uint max_bones;
}

fn void? SkinnedMaterial.initDescriptorSet(&this, vk::Device device, vk::DescriptorPool pool) {
    vk::DescriptorSetLayoutBinding albedo = {
        .binding            = 0,
        .descriptor_type    = vk::DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptor_count   = 1,
        .stage_flags        = { .fragment },
    };
    vk::DescriptorSetLayoutBinding metallic = {
        .binding            = 1,
        .descriptor_type    = vk::DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptor_count   = 1,
        .stage_flags        = { .fragment },
    };
    vk::DescriptorSetLayoutBinding roughness = {
        .binding            = 2,
        .descriptor_type    = vk::DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptor_count   = 1,
        .stage_flags        = { .fragment },
    };
    vk::DescriptorSetLayoutBinding bones = {
        .binding            = 3,
        .descriptor_type    = vk::DESCRIPTOR_TYPE_STORAGE_BUFFER,
        .descriptor_count   = 1,
        .stage_flags        = { .vertex },
    };
    vk::DescriptorSetLayoutBinding[*] bindings = { albedo, metallic, roughness, bones };
    vk::DescriptorSetLayoutCreateInfo info = {
        .s_type        = vk::STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .binding_count = bindings.len,
        .p_bindings    = &bindings,
    };
    this.descriptor_set_layout = vk::createDescriptorSetLayout(device, &info)!;

    vk::DescriptorSetAllocateInfo alloc_info = {
        .s_type               = vk::STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptor_pool      = pool,
        .descriptor_set_count = 1,
        .p_set_layouts        = &this.descriptor_set_layout,
    };
    vk::allocateDescriptorSets(device, &alloc_info, &this.descriptor_set)!;
}

fn void SkinnedMaterial.updateTextures(&this, vk::Device device, Texture* albedo, Texture* metalic, Texture* roughness) {

    vk::DescriptorImageInfo[*] image_infos = {{
        .sampler        = albedo.sampler,
        .image_view     = albedo.buffer.view,
        .image_layout   = vk::IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
    }, {
        .sampler        = metalic.sampler,
        .image_view     = metalic.buffer.view,
        .image_layout   = vk::IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
    }, {
        .sampler        = roughness.sampler,
        .image_view     = roughness.buffer.view,
        .image_layout   = vk::IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
    }};
    vk::WriteDescriptorSet[*] writes = {{
        .s_type           = vk::STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        .dst_set          = this.descriptor_set,
        .dst_binding      = 0,
        .descriptor_type  = vk::DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptor_count = 1,
        .p_image_info     = &image_infos[0],
    }, {
        .s_type           = vk::STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        .dst_set          = this.descriptor_set,
        .dst_binding      = 1,
        .descriptor_type  = vk::DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptor_count = 1,
        .p_image_info     = &image_infos[1],
    }, {
        .s_type           = vk::STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        .dst_set          = this.descriptor_set,
        .dst_binding      = 2,
        .descriptor_type  = vk::DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptor_count = 1,
        .p_image_info     = &image_infos[2],
    }};
    vk::updateDescriptorSets(device, writes.len, &writes);
}

fn void SkinnedMaterial.updateBoneBuffer(&this, vk::Device device, vk::Buffer buffer, vk::DeviceSize size) {
    vk::DescriptorBufferInfo buffer_info = {
        .buffer = buffer,
        .offset = 0,
        .range = size,
    };
    vk::WriteDescriptorSet[*] writes = {{
        .s_type           = vk::STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        .dst_set          = this.descriptor_set,
        .dst_binding      = 3,
        .descriptor_type  = vk::DESCRIPTOR_TYPE_STORAGE_BUFFER,
        .descriptor_count = 1,
        .p_buffer_info    = &buffer_info,
    }};
    vk::updateDescriptorSets(device, writes.len, &writes);
}

fn void SkinnedMaterial.destroy(&this, vk::Device device) {
    vk::destroyPipeline(device, this.pipeline);
    vk::destroyPipelineLayout(device, this.pipeline_layout);
    vk::destroyDescriptorSetLayout(device, this.descriptor_set_layout);
}

fn void? Engine.buildSkinnedMaterial(&this, SkinnedMaterial* mat) {
    vk::ShaderModule vert_module = this.context.createShaderModule(mat.vertex_code)!;
    defer vk::destroyShaderModule(this.context.device, vert_module);
    vk::ShaderModule frag_module = this.context.createShaderModule(mat.fragment_code)!;
    defer vk::destroyShaderModule(this.context.device, frag_module);
    vk::PipelineShaderStageCreateInfo[*] stages = {{
        .s_type = vk::STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = {.vertex},
        .module_ = vert_module,
        .p_name = "main"
    }, {
        .s_type = vk::STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = {.fragment},
        .module_ = frag_module,
        .p_name = "main"
    }};
    vk::PipelineVertexInputStateCreateInfo vertex_input = {
        .s_type = vk::STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertex_binding_description_count = SKINNED_VERTEX_DESCRIPTION.len,
        .p_vertex_binding_descriptions = &SKINNED_VERTEX_DESCRIPTION,
        .vertex_attribute_description_count = SKINNED_VERTEX_ATTR_DESCRIPTION.len,
        .p_vertex_attribute_descriptions = &SKINNED_VERTEX_ATTR_DESCRIPTION
    };
    vk::PipelineInputAssemblyStateCreateInfo input_assembly = {
        .s_type = vk::STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = vk::PRIMITIVE_TOPOLOGY_TRIANGLE_LIST
    };
    vk::PipelineViewportStateCreateInfo viewport_state = {
        .s_type = vk::STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewport_count = 1,
        .scissor_count = 1
    };
    vk::PipelineRasterizationStateCreateInfo rasterizer = {
        .s_type = vk::STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .polygon_mode = vk::POLYGON_MODE_FILL,
        .cull_mode = {.back},
        .front_face = vk::FRONT_FACE_CLOCKWISE,
        .line_width = 1.0
    };
    vk::PipelineMultisampleStateCreateInfo multisampling = {
        .s_type = vk::STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .rasterization_samples = {.n_1}
    };
    vk::PipelineColorBlendAttachmentState color_blend_attachment = {
        .color_write_mask = {.r, .g, .b, .a}
    };
    vk::PipelineColorBlendStateCreateInfo color_blending = {
        .s_type = vk::STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .attachment_count = 1,
        .p_attachments = &color_blend_attachment,
    };
    vk::DynamicState[*] dynamic_states = {
        vk::DYNAMIC_STATE_VIEWPORT,
        vk::DYNAMIC_STATE_SCISSOR
    };
    vk::PipelineDynamicStateCreateInfo dynamic_state = {
        .s_type = vk::STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .dynamic_state_count = dynamic_states.len,
        .p_dynamic_states = &dynamic_states
    };
    vk::PushConstantRange push_constant = {
        .stage_flags = {.vertex},
        .offset = 0,
        .size = Matrix4f.sizeof
    };
    vk::DescriptorSetLayout[*] set_layouts = {
        this.scene.descriptor_set_layout,
        mat.descriptor_set_layout
    };

    vk::PipelineLayoutCreateInfo layout_info = {
        .s_type = vk::STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .set_layout_count = set_layouts.len,
        .p_set_layouts = &set_layouts,
        .push_constant_range_count = 1,
        .p_push_constant_ranges = &push_constant
    };

    mat.pipeline_layout = vk::createPipelineLayout(this.context.device, &layout_info)!;
    vk::PipelineRenderingCreateInfoKHR rendering_info = {
        .s_type                           = vk::STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO_KHR,
        .color_attachment_count           = 1,
        .p_color_attachment_formats       = &this.renderer.format.format,
    };
    vk::GraphicsPipelineCreateInfo pipeline_info = {
        .s_type = vk::STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stage_count = stages.len,
        .p_stages = &stages,
        .p_vertex_input_state = &vertex_input,
        .p_input_assembly_state = &input_assembly,
        .p_viewport_state = &viewport_state,
        .p_rasterization_state = &rasterizer,
        .p_multisample_state = &multisampling,
        .p_color_blend_state = &color_blending,
        .p_dynamic_state = &dynamic_state,
        .layout = mat.pipeline_layout,
        .base_pipeline_index = -1,
        .p_next = &rendering_info,
    };

    mat.pipeline = vk::createGraphicsPipelines(
        this.context.device,
        (vk::PipelineCache)0,
        1,
        &pipeline_info
    )!;
}

fn SkinnedMaterialHandle? Engine.createSkinnedMaterial(&this, uint max_bones) {
    SkinnedMaterialHandle ret = this.resource.skinned_materials.malloc();
    SkinnedMaterial* mat = this.resource.skinned_materials[ret];
    mat.vertex_code = $embed("shaders/skinned_pbr.vert.spv");
    mat.fragment_code = $embed("shaders/pbr.frag.spv");
    mat.max_bones = max_bones;
    mat.initDescriptorSet(this.context.device, this.context.descriptor_pool)!;
    this.buildSkinnedMaterial(mat)!;
    return ret;
}
