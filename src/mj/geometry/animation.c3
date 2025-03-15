module mj::animation::keyframe (<Type>);
import std::sort;

struct Keyframe {
    float time;
    Type value;
}

struct Sample {
    float alpha;
    Type a;
    Type b;
}

def MergeProc = fn Type(Type a, Type b, float alpha);

fn Type sample(Keyframe[] frames, float t, MergeProc merge) {
    usz n = frames.len;
    if (frames.len == 0 || t - frames[0].time < 1e-6f) {
        Type ret;
        return ret;
    }
    if (t >= frames[n - 1].time) {
        return frames[n - 1].value;
    }
    usz i = binarysearch(frames, Keyframe { .time = t }, fn int(Keyframe a, Keyframe b) {
        if (a.time > b.time) {
            return 1;
        } else if (a.time < b.time) {
            return -1;
        }
        return 0;
    });
    Keyframe a = frames[i - 1];
    Keyframe b = frames[i];
    float alpha = (t - a.time) / (b.time - a.time);
    return merge(a.value, b.value, alpha);
}



module mj;
import mj::animation::keyframe;

def PositionKeyframe = Keyframe(<Position>);
def RotationKeyframe = Keyframe(<Quat>);
def ScaleKeyframe = Keyframe(<Scale>);
def samplePosition = keyframe::sample(<Position>);
def sampleRotation = keyframe::sample(<Quat>);
def sampleScale = keyframe::sample(<Scale>);

enum AnimationStatus {
    PLAYING,
    PAUSED,
    STOPPED
}

enum AnimationPlayMode {
    LOOP,
    ONCE,
    PINGPONG
}

struct AnimationInstance {
    AnimationPlayMode mode;
    AnimationStatus status;
    String name;
    float time;
}

struct Animation {
    uint bone_idx;
    PositionKeyframe[] positions;
    RotationKeyframe[] rotations;
    ScaleKeyframe[] scales;
}

fn void updateAnimationTrack(Animation[] track, float t, NodePool* manager, NodeHandle[] bones) {
    for (uint i = 0; i < track.len; i++) {
        updateAnimation(&track[i], t, manager, bones);
    }
}

fn void updateAnimation(Animation* animation, float t, NodePool* manager, NodeHandle[] bones) {
    Node* target = manager.get(bones[animation.bone_idx]);
    if (animation.positions.len > 0) {
        target.transform.position = samplePosition(animation.positions, t,
            fn(a,b,alpha) => a*alpha + b*(1.0f - alpha));
    }
    if (animation.rotations.len > 0) {
        target.transform.rotation = sampleRotation(animation.rotations, t,
            fn(a,b,alpha) => a.slerp(b, alpha));
    }
    if (animation.scales.len > 0) {
        target.transform.scale = sampleScale(animation.scales, t,
            fn(a,b,alpha) => a*alpha + b*(1.0f - alpha));
    }
}
