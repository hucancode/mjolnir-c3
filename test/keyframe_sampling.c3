import std::sort;
import std::math;
import std::io;

struct Keyframe {
    float time;
    float value;
}

fn float sample(Keyframe[] frames, float t) {
    usz n = frames.len;
    if (frames.len == 0 || t - frames[0].time < 1e-6f) {
        return 0.0f;
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
    float ret = a.value + (b.value - a.value) * alpha;
    io::printfn("sample(%f) = (%f -> %f, %f) = %f", t, a.value, b.value, alpha, ret);
    return ret;
}

fn bool almostEqual(float a, float b) {
    return math::abs(a - b) < 1e-4f;
}

const Keyframe[] FRAMES = {
    {0.0f, 0.0f},
    {1.0f, 1.0f},
    {2.0f, 2.0f},
    {3.0f, 300.0f},
    {4.0f, 4.0f},
    {5.0f, 5.0f},
    {6.0f, 60.0f},
    {7.0f, 17.0f},
    {8.0f, 18.0f},
    {9.0f, 19.0f},
};

fn void findExactKey() @test {
    assert(almostEqual(sample(FRAMES, 0.0f), 0.0f));
    assert(almostEqual(sample(FRAMES, 1.0f), 1.0f));
    assert(almostEqual(sample(FRAMES, 2.0f), 2.0f));
    assert(almostEqual(sample(FRAMES, 3.0f), 300.0f));
    assert(almostEqual(sample(FRAMES, 4.0f), 4.0f));
    assert(almostEqual(sample(FRAMES, 5.0f), 5.0f));
    assert(almostEqual(sample(FRAMES, 6.0f), 60.0f));
    assert(almostEqual(sample(FRAMES, 7.0f), 17.0f));
    assert(almostEqual(sample(FRAMES, 8.0f), 18.0f));
    assert(almostEqual(sample(FRAMES, 9.0f), 19.0f));
}

fn void findBlendedKey() @test {
    assert(almostEqual(sample(FRAMES, 0.5f), 0.5f));
    assert(almostEqual(sample(FRAMES, 1.5f), 1.5f));
    assert(almostEqual(sample(FRAMES, 2.3f), 91.4f));
    assert(almostEqual(sample(FRAMES, 3.5f), 152.0f));
    assert(almostEqual(sample(FRAMES, 5.5f), 32.5f));
}

fn void findOutOfRange() @test {
    assert(almostEqual(sample(FRAMES, -1.0f), 0.0f));
    assert(almostEqual(sample(FRAMES, 10.0f), 19.0f));
    assert(almostEqual(sample(FRAMES, 11.0f), 19.0f));
}
