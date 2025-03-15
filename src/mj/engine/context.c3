module mj;
import std::io;
import vk;
import glfw;

const ENGINE_NAME = "Mjolnir";
const TITLE = "Vulkan C3";
const ZString[*] REQUIRED_EXTENSIONS = {
    vk::KHR_SWAPCHAIN_EXTENSION_NAME,
    vk::KHR_DYNAMIC_RENDERING_EXTENSION_NAME,
};
const ENABLE_VALIDATION_LAYERS = true;
const ZString[*] VALIDATION_LAYERS @if(ENABLE_VALIDATION_LAYERS) = {
    "VK_LAYER_KHRONOS_validation",
};
const ACTIVE_MATERIAL_COUNT = 1; // normally we would want around 1000
const MAX_SAMPLER_PER_MATERIAL = 3; // albedo, roughness, metalic
const MAX_SAMPLER_COUNT = ACTIVE_MATERIAL_COUNT * MAX_SAMPLER_PER_MATERIAL;
const SCENE_UNIFORM_COUNT = 3; // view, proj, time

struct SwapchainSupport {
    vk::SurfaceCapabilitiesKHR capabilities;
    vk::SurfaceFormatKHR[] formats;
    vk::PresentModeKHR[] present_modes;
}

fn void SwapchainSupport.free(&this) {
    free(this.formats);
    free(this.present_modes);
}

struct VulkanContext {
    glfw::Window* window;
    vk::Instance instance;
    vk::SurfaceKHR surface;
    vk::SurfaceCapabilitiesKHR surface_capabilities;
    vk::SurfaceFormatKHR[] surface_formats;
    vk::PresentModeKHR[] present_modes;
    vk::DebugUtilsMessengerEXT debug_messenger @if(ENABLE_VALIDATION_LAYERS);
    vk::PhysicalDevice physical_device;
    vk::Device device;
    uint graphics_family;
    vk::Queue graphics_queue;
    uint present_family;
    vk::Queue present_queue;
    vk::DescriptorPool descriptor_pool;
    vk::CommandPool command_pool;
}

fn void! VulkanContext.init(&this, glfw::Window* window) {
    this.window = window;
    this.initVulkanInstance()!;
    this.initWindowSurface()!;
    this.initPhysicalDevice()!;
    this.initLogicalDevice()!;
    this.initCommandPool()!;
    this.initDescriptorPool()!;
}

fn void! VulkanContext.destroy(&this) {
    vk::deviceWaitIdle(this.device)!;
    vk::destroyDescriptorPool(this.device, this.descriptor_pool);
    vk::destroyCommandPool(this.device, this.command_pool);
    vk::destroyDevice(this.device);
    vk::destroySurfaceKHR(this.instance, this.surface);
    $if ENABLE_VALIDATION_LAYERS:
        vk::destroyDebugUtilsMessengerEXT(this.instance, this.debug_messenger);
    $endif
    vk::destroyInstance(this.instance);
}

fn void! VulkanContext.initVulkanInstance(&this) {
    vk::loadProcAddressesGlobal(&glfw::getInstanceProcAddress);
    ulong extensionCount;
    ZString* glfwExtensions = glfw::getRequiredInstanceExtensions(&extensionCount);
    ZString* extensions = (ZString*)malloc(extensionCount * ZString.sizeof);
    mem::copy(extensions, glfwExtensions, extensionCount * ZString.sizeof);
    defer free(extensions);
    vk::InstanceCreateInfo createInfo = {
        .s_type = vk::STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .p_application_info = &&vk::ApplicationInfo {
            .s_type = vk::STRUCTURE_TYPE_APPLICATION_INFO,
            .p_application_name = TITLE,
            .application_version = vk::@make_version(1, 0, 0),
            .p_engine_name = ENGINE_NAME,
            .engine_version = vk::@make_version(1, 0, 0),
            .api_version = vk::API_VERSION_1_3,
        },
    };
    $if env::DARWIN:
        // Mandatory on macOS
        createInfo.flags.enumerate_portability_khr = true;
        extensionCount++;
        extensions = (ZString*)realloc(extensions, extensionCount * ZString.sizeof);
        extensions[extensionCount - 1] = vk::KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME;
    $endif

    $if ENABLE_VALIDATION_LAYERS:
        createInfo.enabled_layer_count = VALIDATION_LAYERS.len;
        createInfo.pp_enabled_layer_names = &VALIDATION_LAYERS;
        extensionCount++;
        extensions = (ZString*)realloc(extensions, extensionCount * ZString.sizeof);
        extensions[extensionCount - 1] = vk::EXT_DEBUG_UTILS_EXTENSION_NAME;
        vk::DebugUtilsMessengerCreateInfoEXT debugCreateInfo = {
            .s_type = vk::STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            .message_severity = vk::DebugUtilsMessageSeverityFlagsEXT { .error, .warning, .info },
            .message_type = vk::DebugUtilsMessageTypeFlagsEXT { .general, .validation, .performance, .device_address_binding },
            .pfn_user_callback = fn uint(vk::DebugUtilsMessageSeverityFlagsEXT messageSeverity,
                vk::DebugUtilsMessageTypeFlagsEXT messageType,
                vk::DebugUtilsMessengerCallbackDataEXT* pCallbackData,
                void* pUserData) {
                if(pCallbackData.p_message) {
                    io::printfn("Debug message: %s", pCallbackData.p_message);
                }
                return 0;
            },
        };
        createInfo.p_next = &debugCreateInfo;
    $endif

    createInfo.enabled_extension_count = (uint)extensionCount;
    createInfo.pp_enabled_extension_names = extensions;
    io::printfn("Required extensions count: %d", (uint)extensionCount);
    for (uint i = 0; i < extensionCount; i++) {
        io::printfn("Required extension: %s", extensions[i]);
    }
    this.instance = vk::createInstance(&createInfo)!;
    vk::loadProcAddressesInstance(this.instance);
    $if ENABLE_VALIDATION_LAYERS:
        this.debug_messenger = vk::createDebugUtilsMessengerEXT(this.instance, &debugCreateInfo)!;
    $endif
    io::printfn("Instance created %x", this.instance);
}

fn void! VulkanContext.initWindowSurface(&this) {
    io::printfn("Initializing window surface with instance %x", this.instance);
    vk::check(glfw::createWindowSurface(this.instance, this.window, null, &this.surface))!;
}

fn SwapchainSupport! VulkanContext.querySwapchainSupport(&this, vk::PhysicalDevice device) {
    return SwapchainSupport {
        .capabilities = vk::getPhysicalDeviceSurfaceCapabilitiesKHR(device, this.surface)!,
        .formats = vk::getPhysicalDeviceSurfaceFormatsKHR(device, this.surface)!,
        .present_modes = vk::getPhysicalDeviceSurfacePresentModesKHR(device, this.surface)!,
    };
}

fn uint VulkanContext.scorePhysicalDevice(&this, vk::PhysicalDevice device) {
    uint score = 0;
    vk::PhysicalDeviceProperties properties = vk::getPhysicalDeviceProperties(device);
    vk::PhysicalDeviceFeatures features = vk::getPhysicalDeviceFeatures(device);
    ZString deviceName = (ZString)properties.device_name[0..];
    io::printfn("Scoring device %s", deviceName);
    defer io::printfn("Device %s scored %d", deviceName, score);
    $if !env::DARWIN:
        if (!features.geometry_shader) {
            return 0;
        }
    $endif
    vk::ExtensionProperties[]! extensions = vk::enumerateDeviceExtensionProperties(device);
    if (catch excuse = extensions) {
        io::printfn("Cound not get extension list for %s", deviceName);
        return 0;
    }
    defer free(extensions);
    // foreach (e:extensions) {
    //     io::printfn("Extension %s", (ZString)e.extension_name[0..]);
    // }
    foreach (required: REQUIRED_EXTENSIONS) {
        bool found = false;
        foreach (e : extensions) {
            ZString name = (ZString)e.extension_name[0..];
            if (name.len() == required.len() && mem::equals(name, required, name.len())) {
                found = true;
                break;
            }
        }
        if (!found) {
            io::printfn("Extension %s not found in %s", required, deviceName);
            return 0;
        }
    }
    SwapchainSupport! support = this.querySwapchainSupport(device);
    if (catch excuse = support) {
        io::printfn("Cound not get swapchain support for %s", deviceName);
        return 0;
    }
    support.free();
    QueueFamilyIndices! indices = this.findQueueFamilies(device);
    if (catch excuse = indices) {
        io::printfn("Cound not get queue families for %s", deviceName);
        return 0;
    }
    switch (properties.device_type) {
    case vk::PHYSICAL_DEVICE_TYPE_DISCRETE_GPU:
        score += 400_000;
    case vk::PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU:
        score += 300_000;
    case vk::PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU:
        score += 200_000;
    case vk::PHYSICAL_DEVICE_TYPE_CPU:
        nextcase;
    case vk::PHYSICAL_DEVICE_TYPE_OTHER:
        score += 100_000;
    }
    score += properties.limits.max_image_dimension2d;
    return score;
}

fn void! VulkanContext.initPhysicalDevice(&this) {
    vk::PhysicalDevice[] devices = vk::enumeratePhysicalDevices(this.instance)!;
    defer free(devices);
    this.physical_device = devices[0];
    uint bestScore = 0;
    foreach (device: devices) {
        int score = this.scorePhysicalDevice(device);
        io::printfn("Device %x score: %d", device, score);
        if (score > bestScore) {
            this.physical_device = device;
            bestScore = score;
        }
    }
    io::printfn("Selected physical device: %x with score %d", this.physical_device, bestScore);
}

struct QueueFamilyIndices {
    uint graphics_family;
    uint present_family;
}

fn QueueFamilyIndices! VulkanContext.findQueueFamilies(&this, vk::PhysicalDevice physical_device) {
    vk::QueueFamilyProperties[] families = vk::getPhysicalDeviceQueueFamilyProperties(physical_device);
    defer free(families);
    QueueFamilyIndices indices;
    bool foundGraphics = false;
    bool foundPresent = false;
    for (uint i = 0; i < families.len; i++) {
        if (families[i].queue_flags.graphics) {
            indices.graphics_family = i;
            foundGraphics = true;
            io::printfn("Queue family %d support graphics", i);
        }
        uint supported = glfw::getPhysicalDevicePresentationSupport(this.instance, physical_device, i);
        if (supported) {
            indices.present_family = i;
            foundPresent = true;
            io::printfn("Queue family %d support present", i);
        }
        if (foundGraphics && foundPresent) {
            return indices;
        }
    }
    return vk::VulkanError.ERROR_UNKNOWN?;
}

fn void! VulkanContext.initLogicalDevice(&this) {
    QueueFamilyIndices indices = this.findQueueFamilies(this.physical_device)!;
    SwapchainSupport support = this.querySwapchainSupport(this.physical_device)!;
    defer support.free();
    this.graphics_family = indices.graphics_family;
    this.present_family = indices.present_family;
    this.surface_capabilities = support.capabilities;
    this.surface_formats = support.formats;
    this.present_modes = support.present_modes;
    ZString[] layers;
    $if ENABLE_VALIDATION_LAYERS:
        layers = ZString[*] {
          "VK_LAYER_KHRONOS_validation"
        };
    $endif
    vk::PhysicalDeviceDynamicRenderingFeatures dynamic_rendering_feature = {
        .s_type = vk::STRUCTURE_TYPE_PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES,
        .dynamic_rendering = vk::TRUE,
    };
    vk::DeviceQueueCreateInfo queueCreateInfo = {
        .s_type = vk::STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queue_family_index = this.graphics_family,
        .queue_count = 1,
        .p_queue_priorities = &&1.0f,
    };
    vk::DeviceCreateInfo createInfo = {
        .s_type = vk::STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .queue_create_info_count = 1,
        .p_queue_create_infos = &queueCreateInfo,
        .enabled_extension_count = REQUIRED_EXTENSIONS.len,
        .pp_enabled_extension_names = &REQUIRED_EXTENSIONS,
        .p_next = &dynamic_rendering_feature,
    };
    $if ENABLE_VALIDATION_LAYERS:
        createInfo.enabled_layer_count = layers.len;
        createInfo.pp_enabled_layer_names = layers.ptr;
    $endif
    this.device = vk::createDevice(this.physical_device, &createInfo)!;
    this.graphics_queue = vk::getDeviceQueue(this.device, this.graphics_family, 0);
    this.present_queue = vk::getDeviceQueue(this.device, this.present_family, 0);
}

fn void! VulkanContext.initDescriptorPool(&this) {
    vk::DescriptorPoolSize sampler = {
        .type = vk::DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptor_count = MAX_SAMPLER_COUNT,
    };
    vk::DescriptorPoolSize uniform = {
        .type = vk::DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptor_count = MAX_FRAMES_IN_FLIGHT * SCENE_UNIFORM_COUNT,
    };
    vk::DescriptorPoolSize[*] pool_sizes = {
        sampler,
        uniform,
    };
    vk::DescriptorPoolCreateInfo create_info = {
        .s_type         = vk::STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .pool_size_count = pool_sizes.len,
        .p_pool_sizes    = &pool_sizes,
        .max_sets       = MAX_FRAMES_IN_FLIGHT + ACTIVE_MATERIAL_COUNT,
    };
    this.descriptor_pool = vk::createDescriptorPool(this.device, &create_info)!;
}

fn vk::ShaderModule! VulkanContext.createShaderModule(&this, char[] code) {
    vk::ShaderModuleCreateInfo createInfo = {
        .s_type = vk::STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .code_size = code.len,
        .p_code = (uint*)code.ptr,
    };
    return vk::createShaderModule(this.device, &createInfo)!;
}

fn void! VulkanContext.initCommandPool(&this) {
    vk::CommandPoolCreateInfo info = {
        .s_type = vk::STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .flags = { .reset_command_buffer },
        .queue_family_index = this.graphics_family,
    };
    this.command_pool = vk::createCommandPool(this.device, &info)!;
}

struct DataBuffer {
    vk::Buffer buffer;
    vk::DeviceMemory memory;
    void* mapped;
    usz size;
}

struct ImageBuffer {
    vk::Image image;
    vk::DeviceMemory memory;
    uint width;
    uint height;
    vk::Format format;
}

fn vk::CommandBuffer! VulkanContext.beginSingleTimeCommand(&this) {
    vk::CommandBuffer ret;
    vk::allocateCommandBuffers(this.device, &&vk::CommandBufferAllocateInfo {
        .s_type = vk::STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .level = vk::COMMAND_BUFFER_LEVEL_PRIMARY,
        .command_pool = this.command_pool,
        .command_buffer_count = 1,
    }, &ret)!;
    vk::beginCommandBuffer(ret, &&vk::CommandBufferBeginInfo {
        .s_type = vk::STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = { .one_time_submit },
    })!;
    return ret;
}

fn void! VulkanContext.endSingleTimeCommand(&this, vk::CommandBuffer command_buffer) {
    defer vk::freeCommandBuffers(this.device, this.command_pool, 1, &command_buffer);
    vk::endCommandBuffer(command_buffer)!;
    vk::queueSubmit(this.graphics_queue, 1, &&vk::SubmitInfo {
        .s_type = vk::STRUCTURE_TYPE_SUBMIT_INFO,
        .command_buffer_count = 1,
        .p_command_buffers = &command_buffer,
    })!;
    vk::queueWaitIdle(this.graphics_queue)!;
}

fn ImageBuffer! VulkanContext.mallocImageBuffer(&this, vk::Format format, uint width, uint height) {
    vk::ImageCreateInfo create_info = {
        .s_type = vk::STRUCTURE_TYPE_IMAGE_CREATE_INFO,
        .image_type = vk::IMAGE_TYPE_2D,
        .extent = {
            .width = width,
            .height = height,
            .depth = 1
        },
        .mip_levels = 1,
        .array_layers = 1,
        .format = format,
        .tiling = vk::IMAGE_TILING_OPTIMAL,
        .usage = { .transfer_dst, .sampled },
        .sharing_mode = vk::SHARING_MODE_EXCLUSIVE,
        .initial_layout = vk::IMAGE_LAYOUT_UNDEFINED,
        .samples = { .n_1 },
    };
    ImageBuffer ret;
    ret.image = vk::createImage(this.device, &create_info)!;
    ret.memory = this.allocateMemory(vk::getImageMemoryRequirements(this.device, ret.image))!;
    ret.width = width;
    ret.height = height;
    ret.format = format;
    vk::bindImageMemory(this.device, ret.image, ret.memory, 0)!;
    return ret;
}

fn DataBuffer! VulkanContext.mallocLocalBuffer(&this, usz size, vk::BufferUsageFlags usage) {
    vk::BufferCreateInfo create_info = {
        .s_type = vk::STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .size = (vk::DeviceSize)size,
        .usage = usage,
        .sharing_mode = vk::SHARING_MODE_EXCLUSIVE,
    };
    DataBuffer ret;
    ret.size = size;
    ret.buffer = vk::createBuffer(this.device, &create_info)!;
    ret.memory = this.allocateMemory(vk::getBufferMemoryRequirements(this.device, ret.buffer), { .host_visible, .host_coherent })!;
    vk::bindBufferMemory(this.device, ret.buffer, ret.memory, 0)!;
    return ret;
}

fn DataBuffer! VulkanContext.mallocHostVisibleBuffer(&this, usz size, vk::BufferUsageFlags usage = { .transfer_src }) {
    vk::BufferCreateInfo create_info = {
        .s_type = vk::STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .size = (vk::DeviceSize)size,
        .usage = usage,
        .sharing_mode = vk::SHARING_MODE_EXCLUSIVE,
    };
    DataBuffer ret;
    ret.size = size;
    ret.buffer = vk::createBuffer(this.device, &create_info)!;
    ret.memory = this.allocateMemory(vk::getBufferMemoryRequirements(this.device, ret.buffer), { .host_visible, .host_coherent })!;
    vk::bindBufferMemory(this.device, ret.buffer, ret.memory, 0)!;
    ret.mapped = vk::mapMemory(this.device, ret.memory, 0, (vk::DeviceSize)size)!;
    return ret;
}

fn DataBuffer! VulkanContext.createLocalBuffer(&this, void* data, usz size, vk::BufferUsageFlags usage) {
    io::printfn("Creating local buffer size %d", size);
    DataBuffer staging = this.createHostVisibleBuffer(data, size, { .transfer_src })!;
    DataBuffer ret = this.mallocLocalBuffer(size, usage | vk::BufferUsageFlags { .transfer_dst })!;
    this.copyBuffer(&ret, &staging)!;
    staging.destroy(this.device);
    return ret;
}

fn DataBuffer! VulkanContext.createHostVisibleBuffer(&this, void* data, usz size, vk::BufferUsageFlags usage = { .transfer_src }) {
    DataBuffer ret = this.mallocHostVisibleBuffer(size, usage)!;
    this.writeBuffer(&ret, data)!;
    return ret;
}

fn ImageBuffer! VulkanContext.createImageBuffer(&this, void* data, vk::Format format, uint width, uint height, uint channel) {
    usz size = (usz)width * (usz)height * (usz)channel;
    DataBuffer staging = this.createHostVisibleBuffer(data, size)!;
    ImageBuffer ret = this.mallocImageBuffer(format, width, height)!;
    this.copyImage(&ret, &staging)!;
    staging.destroy(this.device);
    return ret;
}

fn void! VulkanContext.writeBuffer(&this, DataBuffer* buffer, void* data) {
    if (buffer.mapped) {
        mem::copy(buffer.mapped, data, buffer.size);
    }
}

fn void! VulkanContext.copyBuffer(&this, DataBuffer* dst, DataBuffer* src) {
    vk::CommandBuffer command_buffer = this.beginSingleTimeCommand()!;
    vk::cmdCopyBuffer(command_buffer, src.buffer, dst.buffer, 1, &&vk::BufferCopy { .size = (vk::DeviceSize)src.size });
    this.endSingleTimeCommand(command_buffer)!;
}

// this procedure is assuming input image is uninitialized
fn void! VulkanContext.copyImage(&this, ImageBuffer* dst, DataBuffer* src) {
    this.transitionImageLayout(dst.image, dst.format, vk::IMAGE_LAYOUT_UNDEFINED, vk::IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL)!;
    vk::CommandBuffer command_buffer = this.beginSingleTimeCommand()!;
    vk::BufferImageCopy copy_region = {
        .image_subresource = {
            .aspect_mask = { .color },
            .layer_count = 1,
        },
        .image_extent = {
            .width = dst.width,
            .height = dst.height,
            .depth = 1,
        },
    };
    vk::cmdCopyBufferToImage(command_buffer, src.buffer, dst.image, vk::IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &copy_region);
    this.endSingleTimeCommand(command_buffer)!;
    this.transitionImageLayout(dst.image, dst.format, vk::IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, vk::IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)!;
}

fn uint! VulkanContext.findMemoryType(&this, uint filter, vk::MemoryPropertyFlags flags) {
    vk::PhysicalDeviceMemoryProperties props = vk::getPhysicalDeviceMemoryProperties(this.physical_device);
    for (uint i = 0; i < props.memory_type_count; i++) {
        if (filter & (1 << i) == 0) {
            continue;
        }
        if ((props.memory_types[i].property_flags & flags) != flags) {
            continue;
        }
        return i;
    }
    return vk::VulkanError.ERROR_UNKNOWN?;
}

fn vk::DeviceMemory! VulkanContext.allocateMemory(&this, vk::MemoryRequirements req, vk::MemoryPropertyFlags properties = { .device_local }) {
    vk::MemoryAllocateInfo info = {
        .s_type = vk::STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocation_size = req.size,
        .memory_type_index = this.findMemoryType(req.memory_type_bits, properties)!,
    };
    return vk::allocateMemory(this.device, &info)!;
}

fn void! VulkanContext.buildTexture(&this, Texture* texture) {
    texture.buffer = this.createImageBuffer(texture.pixels, vk::FORMAT_R8G8B8A8_SRGB, texture.width, texture.height, texture.channel)!;
    texture.view = createImageView(this.device, texture.buffer.image, vk::FORMAT_R8G8B8A8_SRGB)!;
    vk::SamplerCreateInfo sampler_info = {
        .s_type = vk::STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
        .mag_filter = vk::FILTER_LINEAR,
        .min_filter = vk::FILTER_LINEAR,
        .address_mode_u = vk::SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
        .address_mode_v = vk::SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
        .address_mode_w = vk::SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
        .anisotropy_enable = vk::FALSE,
        .max_anisotropy = 1.0f,
        .border_color = vk::BORDER_COLOR_INT_OPAQUE_WHITE,
        .unnormalized_coordinates = vk::FALSE,
        .compare_enable = vk::FALSE,
        .compare_op = vk::COMPARE_OP_ALWAYS,
        .mipmap_mode = vk::SAMPLER_MIPMAP_MODE_LINEAR,
    };
    texture.sampler = vk::createSampler(this.device, &sampler_info)!;
}

fn void ImageBuffer.destroy(&this, vk::Device device) {
    vk::unmapMemory(device, this.memory);
    vk::destroyImage(device, this.image);
    vk::freeMemory(device, this.memory);
}

fn void DataBuffer.destroy(&this, vk::Device device) {
    vk::unmapMemory(device, this.memory);
    vk::destroyBuffer(device, this.buffer);
    vk::freeMemory(device, this.memory);
}

// this procedure is assuming image only live in fragment shader
fn void! VulkanContext.transitionImageLayout(&this, vk::Image image, vk::Format format, vk::ImageLayout old, vk::ImageLayout new) {
    vk::CommandBuffer command_buffer = this.beginSingleTimeCommand()!;
    vk::PipelineStageFlags src_stage;
    vk::PipelineStageFlags dst_stage;
    vk::ImageMemoryBarrier barrier = {
        .s_type = vk::STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
        .old_layout = old,
        .new_layout = new,
        .src_queue_family_index = vk::QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk::QUEUE_FAMILY_IGNORED,
        .image = image,
        .subresource_range = {
            .aspect_mask = { .color },
            .base_mip_level = 0,
            .level_count = 1,
            .base_array_layer = 0,
            .layer_count = 1,
        },
    };
    if(old == vk::IMAGE_LAYOUT_UNDEFINED && new == vk::IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL) {
        barrier.dst_access_mask = { .transfer_write };
        src_stage = { .top_of_pipe };
        dst_stage = { .transfer };
    } else if(old == vk::IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL && new == vk::IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL) {
        barrier.src_access_mask = { .transfer_write };
        barrier.dst_access_mask = { .shader_read };
        src_stage = { .transfer };
        dst_stage = { .fragment_shader };
    }
    vk::cmdPipelineBarrier(
        command_buffer,
        src_stage, dst_stage,
        {},
        0, null,
        0, null,
        1, &barrier);
    this.endSingleTimeCommand(command_buffer)!;
}
