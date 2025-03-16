module mj;
import std::collections::map;
import vk;

struct SkinnedVertex {
	Vec3f position;
	Vec3f normal;
	Vec4f color;
	Vec2f uv;
	Vec4u joints;
	Vec4f weights;
}

const vk::VertexInputBindingDescription[*] SKINNED_VERTEX_DESCRIPTION = {{
	.binding   = 0,
	.stride    = SkinnedVertex.sizeof,
	.input_rate = vk::VERTEX_INPUT_RATE_VERTEX,
}};

const vk::VertexInputAttributeDescription[*] SKINNED_VERTEX_ATTR_DESCRIPTION = {{
   .binding = 0, .location = 0, .format = vk::FORMAT_R32G32B32_SFLOAT, .offset = SkinnedVertex.position.offsetof
}, {
   .binding = 0, .location = 1, .format = vk::FORMAT_R32G32B32_SFLOAT, .offset = SkinnedVertex.normal.offsetof
}, {
   .binding = 0, .location = 2, .format = vk::FORMAT_R32G32B32A32_SFLOAT, .offset = SkinnedVertex.color.offsetof
}, {
   .binding = 0, .location = 3, .format = vk::FORMAT_R32G32_SFLOAT, .offset = SkinnedVertex.uv.offsetof
}, {
   .binding = 0, .location = 4, .format = vk::FORMAT_R32G32B32A32_UINT, .offset = SkinnedVertex.joints.offsetof
}, {
   .binding = 0, .location = 5, .format = vk::FORMAT_R32G32B32A32_SFLOAT, .offset = SkinnedVertex.weights.offsetof
}};

struct SkeletalMesh {
    SkinnedVertex[] vertices;
    uint[] indices;
    NodeHandle[] bones;
    HashMap(<String, AnimationTrack>) animations;
    DataBuffer vertex_buffer;
    DataBuffer index_buffer;
    DataBuffer bone_buffer;
    SkinnedMaterialHandle material;
}

fn void! Engine.buildSkeletalMesh(&this, SkeletalMesh* mesh, SkinnedVertex[] vertices, uint[] indices, NodeHandle[] bones, SkinnedMaterialHandle material) {
    mesh.material = material;
    mesh.vertices = vertices;
    mesh.indices = indices;
    mesh.bones = bones;
    mesh.animations.tinit();
    mesh.vertex_buffer = this.context.createLocalBuffer(mesh.vertices, SkinnedVertex.sizeof * mesh.vertices.len, { .vertex_buffer })!;
    mesh.index_buffer = this.context.createLocalBuffer(mesh.indices, uint.sizeof * mesh.indices.len, { .index_buffer })!;

    // Create storage for bone matrices if needed
    if (bones.len > 0) {
        usz bone_buffer_size = bones.len * Matrix4f.sizeof;
        mesh.bone_buffer = this.context.mallocHostVisibleBuffer(bone_buffer_size, { .storage_buffer, .transfer_dst })!;
    }
}

fn void! Engine.buildSegmentedCube(&this, SkeletalMesh* mesh, SkinnedMaterialHandle material, uint segments = 2, float[<4>] color = {0.125, 0.25, 0.5, 1.0}) {
    if (segments < 2) segments = 2;

    // Create bones
    NodeHandle* buf = malloc(segments * NodeHandle.sizeof);
    NodeHandle* bones = buf[:segments];
    defer free(bones);
    for (uint i = 0; i < segments; i++) {
        bones[i] = this.resource.createNode(NodeType.BONE);
        Node* node = this.resource.getNode(bones[i]);
        node.transform.position = {0.0f, (float)i * 2.0f / segments - 1.0f, 0.0f};
    }

    float segment_height = 2.0f / segments;
    float half_segment = segment_height / 2.0f;

    // Create vertices and indices
    // We need 8 vertices per segment plus shared vertices between segments
    uint vertex_count = segments * 8;
    uint index_count = segments * 36; // 6 faces * 2 triangles * 3 vertices

    SkinnedVertex* vertices = (SkinnedVertex*)malloc(vertex_count * SkinnedVertex.sizeof);
    defer free(vertices);

    uint* indices = (uint*)malloc(index_count * uint.sizeof);
    defer free(indices);

    uint vertex_idx = 0;
    uint index_idx = 0;

    for (uint s = 0; s < segments; s++) {
        float y_bottom = -1.0f + s * segment_height;
        float y_top = y_bottom + segment_height;

        // Calculate which bones influence this segment and by how much
        uint primary_bone = s;
        uint secondary_bone = s < segments - 1 ? s + 1 : s;
        float primary_weight = 1.0f;
        float secondary_weight = 0.0f;

        // For segments after the first one, blend with previous bone
        if (s > 0) {
            secondary_bone = s - 1;
            secondary_weight = 0.3f;
            primary_weight = 0.7f;
        }

        // Vertices for this segment
        // Bottom face
        vertices[vertex_idx++] = {
            .position = {-1.0f, y_bottom, -1.0f},
            .normal = VEC_DOWN,
            .color = color,
            .uv = {0.0f, 0.0f},
            .joints = {primary_bone, secondary_bone, 0, 0},
            .weights = {primary_weight, secondary_weight, 0.0f, 0.0f}
        };

        vertices[vertex_idx++] = {
            .position = {1.0f, y_bottom, -1.0f},
            .normal = VEC_DOWN,
            .color = color,
            .uv = {1.0f, 0.0f},
            .joints = {primary_bone, secondary_bone, 0, 0},
            .weights = {primary_weight, secondary_weight, 0.0f, 0.0f}
        };

        vertices[vertex_idx++] = {
            .position = {1.0f, y_bottom, 1.0f},
            .normal = VEC_DOWN,
            .color = color,
            .uv = {1.0f, 1.0f},
            .joints = {primary_bone, secondary_bone, 0, 0},
            .weights = {primary_weight, secondary_weight, 0.0f, 0.0f}
        };

        vertices[vertex_idx++] = {
            .position = {-1.0f, y_bottom, 1.0f},
            .normal = VEC_DOWN,
            .color = color,
            .uv = {0.0f, 1.0f},
            .joints = {primary_bone, secondary_bone, 0, 0},
            .weights = {primary_weight, secondary_weight, 0.0f, 0.0f}
        };

        // Top face
        vertices[vertex_idx++] = {
            .position = {-1.0f, y_top, -1.0f},
            .normal = VEC_UP,
            .color = color,
            .uv = {0.0f, 0.0f},
            .joints = {primary_bone, secondary_bone, 0, 0},
            .weights = {primary_weight, secondary_weight, 0.0f, 0.0f}
        };

        vertices[vertex_idx++] = {
            .position = {1.0f, y_top, -1.0f},
            .normal = VEC_UP,
            .color = color,
            .uv = {1.0f, 0.0f},
            .joints = {primary_bone, secondary_bone, 0, 0},
            .weights = {primary_weight, secondary_weight, 0.0f, 0.0f}
        };

        vertices[vertex_idx++] = {
            .position = {1.0f, y_top, 1.0f},
            .normal = VEC_UP,
            .color = color,
            .uv = {1.0f, 1.0f},
            .joints = {primary_bone, secondary_bone, 0, 0},
            .weights = {primary_weight, secondary_weight, 0.0f, 0.0f}
        };

        vertices[vertex_idx++] = {
            .position = {-1.0f, y_top, 1.0f},
            .normal = VEC_UP,
            .color = color,
            .uv = {0.0f, 1.0f},
            .joints = {primary_bone, secondary_bone, 0, 0},
            .weights = {primary_weight, secondary_weight, 0.0f, 0.0f}
        };

        // Indices for this segment
        uint base = s * 8;

        // Bottom face
        indices[index_idx++] = base + 0;
        indices[index_idx++] = base + 2;
        indices[index_idx++] = base + 1;
        indices[index_idx++] = base + 0;
        indices[index_idx++] = base + 3;
        indices[index_idx++] = base + 2;

        // Top face
        indices[index_idx++] = base + 4;
        indices[index_idx++] = base + 5;
        indices[index_idx++] = base + 6;
        indices[index_idx++] = base + 4;
        indices[index_idx++] = base + 6;
        indices[index_idx++] = base + 7;

        // Front face
        indices[index_idx++] = base + 3;
        indices[index_idx++] = base + 7;
        indices[index_idx++] = base + 6;
        indices[index_idx++] = base + 3;
        indices[index_idx++] = base + 6;
        indices[index_idx++] = base + 2;

        // Back face
        indices[index_idx++] = base + 0;
        indices[index_idx++] = base + 1;
        indices[index_idx++] = base + 5;
        indices[index_idx++] = base + 0;
        indices[index_idx++] = base + 5;
        indices[index_idx++] = base + 4;

        // Left face
        indices[index_idx++] = base + 0;
        indices[index_idx++] = base + 4;
        indices[index_idx++] = base + 7;
        indices[index_idx++] = base + 0;
        indices[index_idx++] = base + 7;
        indices[index_idx++] = base + 3;

        // Right face
        indices[index_idx++] = base + 1;
        indices[index_idx++] = base + 2;
        indices[index_idx++] = base + 6;
        indices[index_idx++] = base + 1;
        indices[index_idx++] = base + 6;
        indices[index_idx++] = base + 5;
    }

    this.buildSkeletalMesh(mesh, vertices[:vertex_idx], indices[:index_idx], bones[:segments], material)!;

    // Create a simple animation for the bones
    Animation* animation_track = (Animation*)malloc(segments * Animation.sizeof);
    for (uint i = 0; i < segments; i++) {
        Animation* anim = &animation_track[i];
        anim.bone_idx = i;

        // Create rotation keyframes to wiggle the bones
        RotationKeyframe* rotations = (RotationKeyframe*)malloc(3 * RotationKeyframe.sizeof);

        Quat start_rot = {};
        Quat mid_rot = {};
        Quat end_rot = {};

        if (i > 0) {  // Don't animate the root bone
            mid_rot.setFromAxisAngle(VEC_X, 0.3f);
            end_rot.setFromAxisAngle(VEC_X, 0.0f);
        }

        rotations[0] = {.time = 0.0f, .value = start_rot};
        rotations[1] = {.time = 1.0f, .value = mid_rot};
        rotations[2] = {.time = 2.0f, .value = end_rot};

        anim.rotations = rotations[:3];
    }
    mesh.animations["Wiggle"] = AnimationTrack {
        .animations = animation_track[:segments],
        .duration = 2.0f,
    };
}

fn void SkeletalMesh.destroy(&this, vk::Device device) {
    this.vertex_buffer.destroy(device);
    this.index_buffer.destroy(device);
    if (this.bones.len > 0) {
        this.bone_buffer.destroy(device);
    }
    foreach(track : this.animations.value_tlist()) {
        track.destroy();
    };
    this.animations.free();
    free(this.vertices);
    free(this.indices);
    free(this.bones);
}

fn SkeletalMeshHandle! Engine.createSkeletalMesh(&this, SkinnedVertex[] vertices, uint[] indices, NodeHandle[] bones, SkinnedMaterialHandle material) {
    SkeletalMeshHandle ret = this.resource.mallocSkeletalMesh();
    this.buildSkeletalMesh(this.resource.getSkeletalMesh(ret), vertices, indices, bones, material)!;
    return ret;
}

fn SkeletalMeshHandle! Engine.createSegmentedCube(&this, SkinnedMaterialHandle material, uint segments = 2) {
    SkeletalMeshHandle ret = this.resource.mallocSkeletalMesh();
    this.buildSegmentedCube(this.resource.getSkeletalMesh(ret), material, segments)!;
    return ret;
}
