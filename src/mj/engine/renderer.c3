module std::core::env;
const bool GLFW_INCLUDE_VULKAN = true;
module mj;
import std::time;
import std::math::matrix;
import std::math;
import vk;
import glfw;

const MAX_FRAMES_IN_FLIGHT = 2;

struct SceneUniform {
    Matrix4f view;
    Matrix4f projection;
    float time;
}

struct Frame {
    vk::Semaphore image_available_semaphore;
    vk::Semaphore render_finished_semaphore;
    vk::Fence fence;
    vk::CommandBuffer command_buffer;
    DataBuffer uniform;
    vk::DescriptorSet descriptor_set;
}

struct Renderer {
    vk::SwapchainKHR swapchain;
    vk::SurfaceFormatKHR format;
    vk::Extent2D extent;
    vk::Image[] images;
    vk::ImageView[] views;
    vk::DescriptorSetLayout mutable_uniform_layout;
    Frame[MAX_FRAMES_IN_FLIGHT] frames;
    ImageBuffer depth_buffer;
    uint current_frame;
}

fn void! Renderer.buildCommandBuffers(&this, vk::Device device, vk::CommandPool command_pool) {
    vk::CommandBufferAllocateInfo allocInfo = {
        .s_type = vk::STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .command_pool = command_pool,
        .level = vk::COMMAND_BUFFER_LEVEL_PRIMARY,
        .command_buffer_count = 1,
    };
    for (uint i = 0; i < MAX_FRAMES_IN_FLIGHT; i++) {
        vk::allocateCommandBuffers(device, &allocInfo, &this.frames[i].command_buffer)!;
    }
}

fn void! Renderer.buildSynchronizers(&this, vk::Device device) {
    vk::SemaphoreCreateInfo semaphoreInfo = {
        .s_type = vk::STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
    };
    vk::FenceCreateInfo fenceInfo = {
        .s_type = vk::STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = { .signaled },
    };
    for (uint i = 0; i < MAX_FRAMES_IN_FLIGHT; i++) {
        this.frames[i].image_available_semaphore = vk::createSemaphore(device, &semaphoreInfo)!;
        this.frames[i].render_finished_semaphore = vk::createSemaphore(device, &semaphoreInfo)!;
        this.frames[i].fence = vk::createFence(device, &fenceInfo)!;
    }
}

fn ImageBuffer! VulkanContext.createDepthImage(&this, vk::Format format, uint width, uint height) {
    vk::ImageCreateInfo create_info = {
        .s_type = vk::STRUCTURE_TYPE_IMAGE_CREATE_INFO,
        .image_type = vk::IMAGE_TYPE_2D,
        .extent = { .width = width, .height = height, .depth = 1 },
        .mip_levels = 1,
        .array_layers = 1,
        .format = format,
        .tiling = vk::IMAGE_TILING_OPTIMAL,
        .initial_layout = vk::IMAGE_LAYOUT_UNDEFINED,
        .usage = { .depth_stencil_attachment },
        .sharing_mode = vk::SHARING_MODE_EXCLUSIVE,
        .samples = { .n_1 },
    };
    ImageBuffer ret;
    ret.image = vk::createImage(this.device, &create_info)!;
    ret.memory = this.allocateMemory(vk::getImageMemoryRequirements(this.device, ret.image))!;
    vk::bindImageMemory(this.device, ret.image, ret.memory, 0)!;

    // Transition image layout
    vk::CommandBuffer cmd = this.beginSingleTimeCommand()!;
    vk::ImageMemoryBarrier barrier = {
        .s_type = vk::STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
        .old_layout = vk::IMAGE_LAYOUT_UNDEFINED,
        .new_layout = vk::IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
        .src_queue_family_index = vk::QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk::QUEUE_FAMILY_IGNORED,
        .image = ret.image,
        .subresource_range = {
            .aspect_mask = { .depth },
            .base_mip_level = 0,
            .level_count = 1,
            .base_array_layer = 0,
            .layer_count = 1,
        },
        .src_access_mask = {},
        .dst_access_mask = { .depth_stencil_attachment_write },
    };
    vk::cmdPipelineBarrier(
        cmd,
        { .top_of_pipe },
        { .early_fragment_tests },
        {},
        0, null,
        0, null,
        1, &barrier
    );
    this.endSingleTimeCommand(cmd)!;

    // Create image view
    ret.view = createImageView(this.device, ret.image, format, { .depth })!;
    return ret;
}

fn void! Renderer.buildSwapchain(&this, vk::Device device, vk::SurfaceKHR surface, vk::SurfaceCapabilitiesKHR capabilities,
    vk::SurfaceFormatKHR[] formats, vk::PresentModeKHR[] present_modes,
    uint graphics_family, uint present_family) {
    this.buildSwapSurfaceFormat(formats);
    this.buildSwapExtent(capabilities);
    uint count = capabilities.min_image_count + 1;
    bool unlimited = capabilities.max_image_count == 0;
    if (!unlimited && count > capabilities.max_image_count) {
        count = capabilities.max_image_count;
    }
    uint[*] indiceArray = { graphics_family, present_family };
    vk::SwapchainCreateInfoKHR createInfo = {
        .s_type = vk::STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = surface,
        .min_image_count = count,
        .image_format = this.format.format,
        .image_color_space = this.format.color_space,
        .image_extent = this.extent,
        .image_array_layers = 1,
        .image_usage = { .color_attachment },
        .image_sharing_mode = vk::SHARING_MODE_EXCLUSIVE,
        .queue_family_index_count = indiceArray.len,
        .p_queue_family_indices = &indiceArray,
        .pre_transform = capabilities.current_transform,
        .composite_alpha = { .opaque },
        .present_mode = pickSwapPresentMode(present_modes),
        .clipped = vk::TRUE,
    };
    if (graphics_family != present_family) {
        createInfo.image_sharing_mode = vk::SHARING_MODE_CONCURRENT;
        createInfo.queue_family_index_count = indiceArray.len;
        createInfo.p_queue_family_indices = &indiceArray;
    }
    this.swapchain = vk::createSwapchainKHR(device, &createInfo)!;
    this.images = vk::getSwapchainImagesKHR(device, this.swapchain)!;
    uint n = this.images.len;
    vk::ImageView* buffer = (vk::ImageView*) malloc(n * vk::ImageView.sizeof);
    this.views = buffer[:n];
    for (uint i = 0; i < n; i++) {
        this.views[i] = createImageView(device, this.images[i], this.format.format)!;
    }
}

fn vk::Fence Renderer.getInFlightFence(&this) @inline {
    return this.frames[this.current_frame].fence;
}

fn vk::Semaphore Renderer.getImageAvailableSemaphore(&this) @inline {
    return this.frames[this.current_frame].image_available_semaphore;
}

fn vk::Semaphore Renderer.getRenderFinishedSemaphore(&this) @inline {
    return this.frames[this.current_frame].render_finished_semaphore;
}

fn vk::CommandBuffer Renderer.getCommandBuffer(&this) @inline {
    return this.frames[this.current_frame].command_buffer;
}

fn DataBuffer* Renderer.getUniform(&this) @inline {
    return &this.frames[this.current_frame].uniform;
}

fn vk::DescriptorSet Renderer.getDescriptorSet(&this) @inline {
    return this.frames[this.current_frame].descriptor_set;
}

fn void Renderer.destroy(&this, vk::Device device, vk::CommandPool command_pool) {
    foreach(f : this.frames) {
        vk::destroySemaphore(device, f.image_available_semaphore);
        vk::destroySemaphore(device, f.render_finished_semaphore);
        vk::destroyFence(device, f.fence);
        vk::freeCommandBuffers(device, command_pool, 1, &f.command_buffer);
    }
}

fn uint! Renderer.begin(&this, vk::Device device) {
    vk::waitForFences(device, 1, &&this.getInFlightFence())!;
    uint image_idx = vk::acquireNextImageKHR(device, this.swapchain, ulong.max, this.getImageAvailableSemaphore())!;
    vk::resetFences(device, 1, &&this.getInFlightFence())!;
    vk::resetCommandBuffer(this.getCommandBuffer(), { .release_resources })!;
    vk::beginCommandBuffer(this.getCommandBuffer(), &&vk::CommandBufferBeginInfo {
        .s_type = vk::STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = { .one_time_submit },
    })!;
    vk::ImageMemoryBarrier barrier = {
        .s_type = vk::STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
        .old_layout = vk::IMAGE_LAYOUT_UNDEFINED,
        .new_layout = vk::IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        .src_queue_family_index = vk::QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk::QUEUE_FAMILY_IGNORED,
        .image = this.images[image_idx],
        .subresource_range = {
            .aspect_mask = {.color},
            .base_mip_level = 0,
            .level_count = 1,
            .base_array_layer = 0,
            .layer_count = 1
        },
        .src_access_mask = {},
        .dst_access_mask = {.color_attachment_write},
    };
    vk::cmdPipelineBarrier(
        this.getCommandBuffer(),
        {.top_of_pipe},
        {.color_attachment_output},
        {},
        0, null,
        0, null,
        1, &barrier
    );
    vk::RenderingAttachmentInfoKHR color_attachment = {
        .s_type = vk::STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO_KHR,
        .image_view = this.views[image_idx],
        .image_layout = vk::IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        .load_op = vk::ATTACHMENT_LOAD_OP_CLEAR,
        .store_op = vk::ATTACHMENT_STORE_OP_STORE,
        .clear_value = { .color = { .float32 = {0.0117, 0.0117, 0.0179, 1.0} } }
    };
    vk::RenderingAttachmentInfoKHR depth_attachment = {
        .s_type = vk::STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO_KHR,
        .image_view = this.depth_buffer.view,
        .image_layout = vk::IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
        .load_op = vk::ATTACHMENT_LOAD_OP_CLEAR,
        .store_op = vk::ATTACHMENT_STORE_OP_STORE,
        .clear_value = { .depth_stencil = { .depth = 1.0f } },
    };
    vk::RenderingInfoKHR render_info = {
        .s_type = vk::STRUCTURE_TYPE_RENDERING_INFO_KHR,
        .render_area = {.extent = this.extent},
        .layer_count = 1,
        .color_attachment_count = 1,
        .p_color_attachments = &color_attachment,
        .p_depth_attachment = &depth_attachment,
    };
    vk::cmdBeginRenderingKHR(this.getCommandBuffer(), &render_info);
    vk::cmdSetViewport(this.getCommandBuffer(), 0, 1, &&vk::Viewport {
        .width = this.extent.width,
        .height = this.extent.height,
        .max_depth = 1.0,
    });
    vk::cmdSetScissor(this.getCommandBuffer(), 0, 1, &&vk::Rect2D {
        .extent = this.extent,
    });
    return image_idx;
}

fn void! Renderer.end(&this, uint image_idx, vk::Queue graphic_queue, vk::Queue present_queue) {
    vk::cmdEndRenderingKHR(this.getCommandBuffer());
    vk::ImageMemoryBarrier barrier = {
        .s_type = vk::STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
        .old_layout = vk::IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        .new_layout = vk::IMAGE_LAYOUT_PRESENT_SRC_KHR,
        .src_queue_family_index = vk::QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk::QUEUE_FAMILY_IGNORED,
        .image = this.images[image_idx],
        .subresource_range = {
            .aspect_mask = {.color},
            .base_mip_level = 0,
            .level_count = 1,
            .base_array_layer = 0,
            .layer_count = 1
        },
        .src_access_mask = {.color_attachment_write},
        .dst_access_mask = {}
    };

    vk::cmdPipelineBarrier(
        this.getCommandBuffer(),
        {.color_attachment_output},
        {.bottom_of_pipe},
        {},
        0, null,
        0, null,
        1, &barrier
    );
    vk::endCommandBuffer(this.getCommandBuffer())!;
    vk::SubmitInfo submitInfo = {
        .s_type = vk::STRUCTURE_TYPE_SUBMIT_INFO,
        .wait_semaphore_count = 1,
        .p_wait_semaphores = &&this.getImageAvailableSemaphore(),
        .p_wait_dst_stage_mask = &&vk::PipelineStageFlags { .color_attachment_output },
        .command_buffer_count = 1,
        .p_command_buffers = &&this.getCommandBuffer(),
        .signal_semaphore_count = 1,
        .p_signal_semaphores = &&this.getRenderFinishedSemaphore(),
    };
    vk::queueSubmit(graphic_queue, 1, &submitInfo, this.getInFlightFence())!;
    vk::PresentInfoKHR presentInfo = {
        .s_type = vk::STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .wait_semaphore_count = 1,
        .p_wait_semaphores = &&this.getRenderFinishedSemaphore(),
        .swapchain_count = 1,
        .p_swapchains = &this.swapchain,
        .p_image_indices = &image_idx,
    };
    vk::queuePresentKHR(present_queue, &presentInfo)!;
    this.current_frame = (this.current_frame + 1) % MAX_FRAMES_IN_FLIGHT;
}

fn void Renderer.buildSwapSurfaceFormat(&this, vk::SurfaceFormatKHR[] formats) {
    foreach (f: formats) {
        if (f.format == vk::FORMAT_B8G8R8A8_SRGB &&
        f.color_space == vk::COLOR_SPACE_SRGB_NONLINEAR_KHR) {
            this.format = f;
            return;
        }
    }
    this.format = formats[0];
}

fn vk::PresentModeKHR pickSwapPresentMode(vk::PresentModeKHR[] presentModes) {
    foreach (p: presentModes) {
        if (p == vk::PRESENT_MODE_MAILBOX_KHR) {
            return p;
        }
    }
    return vk::PRESENT_MODE_FIFO_KHR;
}

fn void Renderer.buildSwapExtent(&this, vk::SurfaceCapabilitiesKHR capabilities) {
    if (capabilities.current_extent.width != uint.max) {
        this.extent = capabilities.current_extent;
        return;
    }
    this.extent = {
        .width = 800,
        .height = 600,
    };
    this.extent.width = max(capabilities.min_image_extent.width, min(capabilities.max_image_extent.width, this.extent.width));
    this.extent.height = max(capabilities.min_image_extent.height, min(capabilities.max_image_extent.height, this.extent.height));
}

fn void Renderer.destroySwapchain(&this, vk::Device device) {
    foreach (image : this.images) {
        vk::destroyImage(device, image);
    }
    foreach (view : this.views) {
        vk::destroyImageView(device, view);
    }
    this.depth_buffer.destroy(device);
    vk::destroySwapchainKHR(device, this.swapchain);
    free(this.views);
    free(this.images);
}
