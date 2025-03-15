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
    vk::ImageView view;
}

// const char[*] DATA = $embed("assets/statue-1275469_1280.jpg");
// defer stbimage::image_free(pixels);

fn void! Texture.init(&this, vk::Device device, char[] data) {
    this.pixels = stbimage::load_from_memory(data, data.len, &this.width, &this.height, &this.channel, stbimage::RGB_ALPHA);
    this.channel = 4;
}

fn void Texture.destroy(&this, vk::Device device) {
    this.buffer.destroy(device);
    vk::destroyImageView(device, this.view);
    vk::destroySampler(device, this.sampler);
}

fn vk::ImageView! createImageView(vk::Device device, vk::Image image, vk::Format format) {
    vk::ImageViewCreateInfo info = {
        .s_type = vk::STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .image = image,
        .view_type = vk::IMAGE_VIEW_TYPE_2D,
        .format = format,
        .subresource_range = {
            .aspect_mask = { .color },
            .level_count = 1,
            .layer_count = 1,
        },
    };
    return vk::createImageView(device, &info)!;
}

fn TextureHandle! Engine.createTexture(&this, char[] data) {
    TextureHandle ret = this.resource.mallocTexture();
    Texture* texture = this.resource.getTexture(ret);
    texture.init(this.context.device, data)!;
    this.context.buildTexture(texture)!;
    io::printfn("Texture created %d", ret.index);
    return ret;
}
