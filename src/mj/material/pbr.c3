module mj;
import std::io;
import vk;

struct Material {
    char[] vertex_code;
    char[] fragment_code;
    TextureHandle albedo;
    TextureHandle metallic;
    TextureHandle roughness;
    vk::PipelineLayout pipeline_layout;
    vk::Pipeline pipeline;
    vk::DescriptorSetLayout descriptor_set_layout;
    vk::DescriptorSet descriptor_set;
}

fn void! Material.initDescriptorSet(&this, vk::Device device, vk::DescriptorPool pool) {
    vk::DescriptorSetLayoutBinding albedo = {
        .binding            = 0,
        .descriptor_type    = vk::DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptor_count   = 1,
        .stage_flags        = { .fragment },
    };
    vk::DescriptorSetLayoutBinding metalic = {
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
    vk::DescriptorSetLayoutBinding[*] bindings = { albedo, metalic, roughness };
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

fn void Material.updateTextures(&this, vk::Device device, Texture* albedo, Texture* metalic, Texture* roughness) {
    vk::WriteDescriptorSet[*] writes = {{
        .s_type           = vk::STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        .dst_set          = this.descriptor_set,
        .dst_binding      = 0,
        .descriptor_type  = vk::DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptor_count = 1,
        .p_image_info     = &&vk::DescriptorImageInfo {
            .sampler        = albedo.sampler,
            .image_view     = albedo.view,
            .image_layout   = vk::IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        },
    }, {
        .s_type           = vk::STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        .dst_set          = this.descriptor_set,
        .dst_binding      = 1,
        .descriptor_type  = vk::DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptor_count = 1,
        .p_image_info     = &&vk::DescriptorImageInfo {
            .sampler        = metalic.sampler,
            .image_view     = metalic.view,
            .image_layout   = vk::IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        },
    }, {
        .s_type           = vk::STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        .dst_set          = this.descriptor_set,
        .dst_binding      = 2,
        .descriptor_type  = vk::DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptor_count = 1,
        .p_image_info     = &&vk::DescriptorImageInfo {
            .sampler        = roughness.sampler,
            .image_view     = roughness.view,
            .image_layout   = vk::IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        },
    }};
	vk::updateDescriptorSets(device, writes.len, &writes);
}

fn void Material.destroy(&this, vk::Device device) {
    vk::destroyPipeline(device, this.pipeline);
    vk::destroyPipelineLayout(device, this.pipeline_layout);
    vk::destroyDescriptorSetLayout(device, this.descriptor_set_layout);
}

fn void! Engine.buildMaterial(&this, Material* mat) {
    vk::ShaderModule v = this.context.createShaderModule(mat.vertex_code)!;
    defer vk::destroyShaderModule(this.context.device, v);
    vk::ShaderModule f = this.context.createShaderModule(mat.fragment_code)!;
    defer vk::destroyShaderModule(this.context.device, f);
    vk::PipelineShaderStageCreateInfo[*] shader_stages = {{
        .s_type     = vk::STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage      = { .vertex },
        .module_    = v,
        .p_name     = "main",
    }, {
        .s_type     = vk::STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage      = { .fragment },
        .module_    = f,
        .p_name     = "main",
    }};
    vk::DynamicState[*] dynamicStates = {
        vk::DYNAMIC_STATE_VIEWPORT,
        vk::DYNAMIC_STATE_SCISSOR
    };
    vk::PipelineDynamicStateCreateInfo dynamicState = {
        .s_type              = vk::STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .dynamic_state_count = dynamicStates.len,
        .p_dynamic_states    = &dynamicStates,
    };
    vk::PipelineVertexInputStateCreateInfo vertexInputInfo = {
        .s_type                             = vk::STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertex_binding_description_count   = VERTEX_DESCRIPTION.len,
    	.p_vertex_binding_descriptions      = &VERTEX_DESCRIPTION,
    	.vertex_attribute_description_count = VERTEX_ATTR_DESCRIPTION.len,
    	.p_vertex_attribute_descriptions    = &VERTEX_ATTR_DESCRIPTION,
    };
    vk::PipelineInputAssemblyStateCreateInfo inputAssembly = {
        .s_type   = vk::STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = vk::PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
    };
    vk::PipelineViewportStateCreateInfo viewportState = {
        .s_type          = vk::STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewport_count  = 1,
        .scissor_count   = 1,
    };
    vk::PipelineRasterizationStateCreateInfo rasterizer = {
        .s_type       = vk::STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .polygon_mode = vk::POLYGON_MODE_FILL,
        .cull_mode    = { .back },
        .front_face   = vk::FRONT_FACE_CLOCKWISE,
        .line_width   = 1.0,
    };
    vk::PipelineMultisampleStateCreateInfo multisampling = {
        .s_type                = vk::STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .rasterization_samples = { .n_1 },
        .min_sample_shading    = 1.0,
    };
    vk::PipelineColorBlendStateCreateInfo blending = {
        .s_type           = vk::STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .attachment_count = 1,
        .p_attachments    = &&vk::PipelineColorBlendAttachmentState { .color_write_mask = { .r, .g, .b, .a } },
    };
    vk::DescriptorSetLayout[*] set_layouts = {
        this.scene.descriptor_set_layout,
        mat.descriptor_set_layout,
    };
    vk::PushConstantRange push_constant = {
        .stage_flags                      = {.vertex},
        .offset                           = 0,
        .size                             = Matrix4f.sizeof
    };
    mat.pipeline_layout = vk::createPipelineLayout(
        this.context.device,
        &&vk::PipelineLayoutCreateInfo {
            .s_type                       = vk::STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            .set_layout_count             = set_layouts.len,
            .p_set_layouts                = &set_layouts,
            .push_constant_range_count    = 1,
            .p_push_constant_ranges       = &push_constant
        })!;
    io::printfn("Material pipeline layout created");
    vk::PipelineRenderingCreateInfoKHR rendering_info = {
        .s_type                           = vk::STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO_KHR,
        .color_attachment_count           = 1,
        .p_color_attachment_formats       = &this.renderer.format.format,
    };
    vk::GraphicsPipelineCreateInfo pipelineInfo = {
        .s_type                           = vk::STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stage_count                      = shader_stages.len,
        .p_stages                         = &shader_stages,
        .p_vertex_input_state             = &vertexInputInfo,
        .p_input_assembly_state           = &inputAssembly,
        .p_viewport_state                 = &viewportState,
        .p_rasterization_state            = &rasterizer,
        .p_multisample_state              = &multisampling,
        .p_color_blend_state              = &blending,
        .p_dynamic_state                  = &dynamicState,
        .layout                           = mat.pipeline_layout,
        .base_pipeline_index              = -1,
        .p_next                           = &rendering_info,
    };
    mat.pipeline = vk::createGraphicsPipelines(
        this.context.device,
        (vk::PipelineCache)0,
        1,
        &pipelineInfo)!;
    io::printfn("Material pipeline created");
}

fn MaterialHandle! Engine.createMaterial(&this) {
    MaterialHandle ret = this.resource.materials.malloc();
    Material* mat = this.resource.materials.get(ret);
    io::printfn("Material allocated");
    mat.vertex_code = $embed("shaders/pbr.vert.spv");
    mat.fragment_code = $embed("shaders/pbr.frag.spv");
    mat.initDescriptorSet(this.context.device, this.context.descriptor_pool)!;
    io::printfn("Material descriptor set initialized");
    this.buildMaterial(mat)!;
    io::printfn("Material created");
    return ret;
}
