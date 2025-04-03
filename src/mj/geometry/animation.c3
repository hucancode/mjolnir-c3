module mj::animation::keyframe {Type};
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

alias MergeProc = fn Type(Type a, Type b, float alpha);

fn Type sample(Keyframe[] frames, float t, MergeProc merge) {
    usz n = frames.len;
    if (frames.len == 0 || t - frames[0].time < 1e-6f) {
        Type ret;
        return ret;
    }
    if (t >= frames[n - 1].time) {
        return frames[n - 1].value;
    }
    Keyframe target = { .time = t };
    usz i = binarysearch(frames, target, fn int(Keyframe a, Keyframe b) {
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

alias PositionKeyframe = Keyframe{Position};
alias RotationKeyframe = Keyframe{Quat};
alias ScaleKeyframe = Keyframe{Scale};
alias samplePosition = keyframe::sample{Position};
alias sampleRotation = keyframe::sample{Quat};
alias sampleScale = keyframe::sample{Scale};

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

fn void Animation.destroy(&self) {
    free(self.positions);
    free(self.rotations);
    free(self.scales);
}

struct AnimationTrack {
    Animation[] animations;
    float duration;
}

fn void AnimationTrack.destroy(&self) {
    foreach (&animation: self.animations) {
        animation.destroy();
    }
    free(self.animations);
}

fn void AnimationTrack.update(&self, float t, NodePool* manager, NodeHandle[] bones) {
    foreach (&animation: self.animations) {
        animation.update(t, manager, bones);
    }
}

fn void Animation.update(&self, float t, NodePool* manager, NodeHandle[] bones) {
    Node* target = manager.get(bones[self.bone_idx]);
    if (self.positions.len > 0) {
        target.transform.position = samplePosition(self.positions, t,
            fn(a,b,alpha) => a*alpha + b*(1.0f - alpha));
    }
    if (self.rotations.len > 0) {
        target.transform.rotation = sampleRotation(self.rotations, t,
            fn(a,b,alpha) => a.slerp(b, alpha));
    }
    if (self.scales.len > 0) {
        target.transform.scale = sampleScale(self.scales, t,
            fn(a,b,alpha) => a*alpha + b*(1.0f - alpha));
    }
}
