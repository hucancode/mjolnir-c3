module mj;
import std::io;
import stbimage;
import vk;

struct Texture {
    char* pixels;
    int width;
    int height;
    int channel;
    ImageBuffer buffer;
    vk::Sampler sampler;
}

fn void! Texture.init(&this, vk::Device device, char[] data) {
    this.pixels = stbimage::load_from_memory(data, data.len, &this.width, &this.height, &this.channel, stbimage::RGB_ALPHA);
    this.channel = 4;
}

fn void Texture.destroy(&this, vk::Device device) {
    this.buffer.destroy(device);
    vk::destroySampler(device, this.sampler);
}

fn vk::ImageView! createImageView(vk::Device device, vk::Image image, vk::Format format, vk::ImageAspectFlags aspect = { .color }) {
    vk::ImageViewCreateInfo info = {
        .s_type = vk::STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .image = image,
        .view_type = vk::IMAGE_VIEW_TYPE_2D,
        .format = format,
        .subresource_range = {
            .aspect_mask = aspect,
            .level_count = 1,
            .layer_count = 1,
        },
    };
    return vk::createImageView(device, &info)!;
}

fn void! VulkanContext.buildTexture(&this, Texture* texture) {
    texture.buffer = this.createImageBuffer(texture.pixels, vk::FORMAT_R8G8B8A8_SRGB, texture.width, texture.height, texture.channel)!;
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

fn TextureHandle! Engine.createTexture(&this, char[] data) {
    TextureHandle ret = this.resource.mallocTexture();
    Texture* texture = this.resource.getTexture(ret);
    texture.init(this.context.device, data)!;
    this.context.buildTexture(texture)!;
    io::printfn("Texture created %d", ret.index);
    return ret;
}
