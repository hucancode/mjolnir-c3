module mj;
import std::math::matrix;
import std::math::quaternion;

enum CameraProjection {
    PERSPECTIVE,
    ORTHOGRAPHIC
}

struct Camera {
    union {
        struct {
            float fov;
            float aspect_ratio;
        }
        struct {
            float right;
            float bottom;
        }
    }
    float near;
    float far;
    Vec3f up;
    Position position;
    CameraProjection projection;
    Quat rotation;
}

fn Matrix4f Camera.calculateProjectionMatrix(&this) {
    switch (this.projection) {
        case CameraProjection.PERSPECTIVE:
            return matrix::perspective(<float>)(this.fov, this.aspect_ratio, this.near, this.far)
                .transpose();
        case CameraProjection.ORTHOGRAPHIC:
            return matrix::ortho(<float>)(0.0, this.right, 0.0, this.bottom, this.near, this.far)
                .transpose();
    }
}

fn Matrix4f Camera.calculateLookatMatrix(&this, Position target = {}) {
    return matrix::look_at(<float>)(this.position, target, this.up)
        .transpose();
}

fn Matrix4f Camera.calculateViewMatrix(&this) {
    return this.rotation.to_matrixf()
        .translate(this.position)
        ;
}
