module mj;
import std::math::matrix;
import std::math::quaternion;

// take a seed value and return array of n, each element is a copy of seed
macro @repeat(seed, $n) {
    $typeof(seed)* ret = ($typeof(seed)*) malloc($typeof(seed).sizeof * $n);
    $for var $i = 0; $i < $n; $i++ :
        ret[$i] = seed;
    $endfor
    return ret[:$n];
}

macro @repeatn(seed, n) {
    $typeof(seed)* ret = ($typeof(seed)*) malloc($typeof(seed).sizeof * n);
    for (var i = 0; i < n; i++) {
        ret[i] = seed;
    }
    return ret[:n];
}

alias Quat = Quaternion{float};
alias Matrix4f = Matrix4x4{float};
alias Vec4f = float[<4>];
alias Vec3f = float[<3>];
alias Vec2f = float[<2>];
alias Vec4i = int[<4>];
alias Vec3i = int[<3>];
alias Vec2i = int[<2>];
alias Vec4u = uint[<4>];
alias Vec3u = uint[<3>];
alias Vec2u = uint[<2>];
alias Position = float[<3>];
alias Position4 = float[<4>];
alias Scale = float[<3>];
alias Scale4 = float[<4>];
alias Color = float[<4>];

const Vec3f VEC_UP = {0.0, 1.0, 0.0};
const Vec3f VEC_DOWN = {0.0, -1.0, 0.0};
const Vec3f VEC_RIGHT = {1.0, 0.0, 0.0};
const Vec3f VEC_LEFT = {-1.0, 0.0, 0.0};
const Vec3f VEC_FORWARD = {0.0, 0.0, 1.0};
const Vec3f VEC_BACKWARD = {0.0, 0.0, -1.0};
const Vec3f VEC_Y = VEC_UP;
const Vec3f VEC_Y_NEG = VEC_DOWN;
const Vec3f VEC_X = VEC_RIGHT;
const Vec3f VEC_X_NEG = VEC_LEFT;
const Vec3f VEC_Z = VEC_FORWARD;
const Vec3f VEC_Z_NEG = VEC_BACKWARD;

fn void Quat.setFromAxisAngle(&self, Vec3f axis, float angle) {
    float s = (float)math::sin(angle * 0.5);
    self.i = axis.x * s;
    self.j = axis.y * s;
    self.k = axis.z * s;
    self.l = (float)math::cos(angle * 0.5);
}

fn float fmod(float x, float y) {
    if (y == 0.0f) {
        return 0.0f;
    }
    return x - ((int)(x / y)) * y;
}
