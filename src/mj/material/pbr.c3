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

fn void? Material.initDescriptorSet(&self, vk::Device device, vk::DescriptorPool pool) {
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
    self.descriptor_set_layout = vk::createDescriptorSetLayout(device, &info)!;
	vk::DescriptorSetAllocateInfo alloc_info = {
		.s_type               = vk::STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
		.descriptor_pool      = pool,
		.descriptor_set_count = 1,
		.p_set_layouts        = &self.descriptor_set_layout,
	};
	vk::allocateDescriptorSets(device, &alloc_info, &self.descriptor_set)!;
}

fn void Material.updateTextures(&self, vk::Device device, Texture* albedo, Texture* metalic, Texture* roughness) {
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
        .dst_set          = self.descriptor_set,
        .dst_binding      = 0,
        .descriptor_type  = vk::DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptor_count = 1,
        .p_image_info     = &image_infos[0],
    }, {
        .s_type           = vk::STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        .dst_set          = self.descriptor_set,
        .dst_binding      = 1,
        .descriptor_type  = vk::DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptor_count = 1,
        .p_image_info     = &image_infos[1],
    }, {
        .s_type           = vk::STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        .dst_set          = self.descriptor_set,
        .dst_binding      = 2,
        .descriptor_type  = vk::DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptor_count = 1,
        .p_image_info     = &image_infos[2],
    }};
	vk::updateDescriptorSets(device, writes.len, &writes);
}

fn void Material.destroy(&self, vk::Device device) {
    vk::destroyPipeline(device, self.pipeline);
    vk::destroyPipelineLayout(device, self.pipeline_layout);
    vk::destroyDescriptorSetLayout(device, self.descriptor_set_layout);
}

fn void? Engine.buildMaterial(&self, Material* mat) {
    vk::ShaderModule v = self.context.createShaderModule(mat.vertex_code)!;
    defer vk::destroyShaderModule(self.context.device, v);
    vk::ShaderModule f = self.context.createShaderModule(mat.fragment_code)!;
    defer vk::destroyShaderModule(self.context.device, f);
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
    vk::PipelineColorBlendAttachmentState colorBlendAttachment = {
        .color_write_mask = { .r, .g, .b, .a },
    };
    vk::PipelineColorBlendStateCreateInfo blending = {
        .s_type           = vk::STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .attachment_count = 1,
        .p_attachments    = &colorBlendAttachment,
    };
    vk::DescriptorSetLayout[*] set_layouts = {
        self.scene.descriptor_set_layout,
        mat.descriptor_set_layout,
    };
    vk::PushConstantRange push_constant = {
        .stage_flags                      = {.vertex},
        .offset                           = 0,
        .size                             = Matrix4f.sizeof
    };
    vk::PipelineLayoutCreateInfo layout_info = {
        .s_type                       = vk::STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .set_layout_count             = set_layouts.len,
        .p_set_layouts                = &set_layouts,
        .push_constant_range_count    = 1,
        .p_push_constant_ranges       = &push_constant
    };
    mat.pipeline_layout = vk::createPipelineLayout(self.context.device, &layout_info)!;
    io::printfn("Material pipeline layout created");
    vk::PipelineRenderingCreateInfoKHR rendering_info = {
        .s_type                           = vk::STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO_KHR,
        .color_attachment_count           = 1,
        .p_color_attachment_formats       = &self.renderer.format.format,
        .depth_attachment_format          = vk::FORMAT_D32_SFLOAT,
    };
    vk::PipelineDepthStencilStateCreateInfo depth_stencil = {
        .s_type = vk::STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
        .depth_test_enable = vk::TRUE,
        .depth_write_enable = vk::TRUE,
        .depth_compare_op = vk::COMPARE_OP_LESS,
        .depth_bounds_test_enable = vk::FALSE,
        .stencil_test_enable = vk::FALSE,
    };
    vk::GraphicsPipelineCreateInfo pipelineInfo = {
        .s_type                 = vk::STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stage_count            = shader_stages.len,
        .p_stages               = &shader_stages,
        .p_vertex_input_state   = &vertexInputInfo,
        .p_input_assembly_state = &inputAssembly,
        .p_viewport_state       = &viewportState,
        .p_rasterization_state  = &rasterizer,
        .p_multisample_state    = &multisampling,
        .p_color_blend_state    = &blending,
        .p_dynamic_state        = &dynamicState,
        .p_depth_stencil_state  = &depth_stencil,
        .layout                 = mat.pipeline_layout,
        .base_pipeline_index    = -1,
        .p_next                 = &rendering_info,
    };
    mat.pipeline = vk::createGraphicsPipelines(
        self.context.device,
        (vk::PipelineCache)0,
        1,
        &pipelineInfo)!;
    io::printfn("Material pipeline created");
}

fn MaterialHandle? Engine.createMaterial(&self) {
    MaterialHandle ret = self.resource.materials.malloc();
    Material* mat = self.resource.materials[ret];
    io::printfn("Material allocated");
    mat.vertex_code = $embed("shaders/pbr.vert.spv");
    mat.fragment_code = $embed("shaders/pbr.frag.spv");
    mat.initDescriptorSet(self.context.device, self.context.descriptor_pool)!;
    io::printfn("Material descriptor set initialized");
    self.buildMaterial(mat)!;
    io::printfn("Material created");
    return ret;
}
