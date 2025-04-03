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

fn Matrix4f Camera.calculateProjectionMatrix(&self) {
    switch (self.projection) {
        case CameraProjection.PERSPECTIVE:
            return matrix::perspective{float}(self.fov, self.aspect_ratio, self.near, self.far)
                .transpose();
        case CameraProjection.ORTHOGRAPHIC:
            return matrix::ortho{float}(0.0, self.right, 0.0, self.bottom, self.near, self.far)
                .transpose();
    }
}

fn Matrix4f Camera.calculateLookatMatrix(&self, Position target = {}) {
    return matrix::look_at{float}(self.position, target, self.up)
        .transpose();
}

fn Matrix4f Camera.calculateViewMatrix(&self) {
    return self.rotation.to_matrixf()
        .translate(self.position)
        ;
}
