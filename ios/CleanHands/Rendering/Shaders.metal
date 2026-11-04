#include <metal_stdlib>
using namespace metal;

// The blacklight look (research R6), in three passes:
//   1. hand light pool: soft "lamp light" around the hands, plus a tight hand mask, from joints;
//   2. coverage: every glow mark drawn additively into an offscreen texture;
//   3. final: violet skin under UV, glow broken by grain and skin creases, tiny bloom, nail tint.
// Layouts match the Swift structs in Renderer.swift. Mark shapes and grain mirror MarkShape.swift.

struct FullscreenOut {
    float4 position [[position]];
    float2 uv;
};

vertex FullscreenOut fullscreenVertex(uint vid [[vertex_id]]) {
    float2 p = float2((vid << 1) & 2, vid & 2);
    FullscreenOut out;
    out.position = float4(p * 2.0 - 1.0, 0, 1);
    out.uv = float2(p.x, 1.0 - p.y);
    return out;
}

// MARK: - 1. Hand light pool

struct Capsule {
    float4 ab;      // a.xy, b.xy in buffer pixels
    float4 params;  // radius px, hand scale px, hand index, unused
};

struct PalmOutline {
    float4 p01;     // six outline points in buffer pixels
    float4 p23;
    float4 p45;
    float4 params;  // hand scale px, presence, unused, unused
};

struct PoolUniforms {
    float4 info;    // capsule count, hand count, dilate, blur (in scales)
    float4 size;    // buffer width, height, falloff, unused
};

static float segmentDistance(float2 p, float2 a, float2 b) {
    float2 ab = b - a;
    float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
    return length(p - (a + ab * t));
}

static float polygonSignedDistance(float2 p, thread const float2 *v, int n) {
    float d = 1e9;
    bool inside = false;
    for (int i = 0, j = n - 1; i < n; j = i++) {
        d = min(d, segmentDistance(p, v[j], v[i]));
        if ((v[i].y > p.y) != (v[j].y > p.y) &&
            p.x < (v[j].x - v[i].x) * (p.y - v[i].y) / (v[j].y - v[i].y) + v[i].x) {
            inside = !inside;
        }
    }
    return inside ? -d : d;
}

fragment float2 poolFragment(FullscreenOut in [[stage_in]],
                             constant PoolUniforms &u [[buffer(0)]],
                             constant Capsule *capsules [[buffer(1)]],
                             constant PalmOutline *palms [[buffer(2)]]) {
    float2 p = in.uv * u.size.xy;
    int handCount = int(u.info.y);
    float pool = 0;
    float tight = 0;
    for (int h = 0; h < handCount; h++) {
        PalmOutline palm = palms[h];
        float2 outline[6] = { palm.p01.xy, palm.p01.zw, palm.p23.xy, palm.p23.zw, palm.p45.xy, palm.p45.zw };
        float d = polygonSignedDistance(p, outline, 6);
        for (int i = 0; i < int(u.info.x); i++) {
            Capsule c = capsules[i];
            if (int(c.params.z) != h) continue;
            d = min(d, segmentDistance(p, c.ab.xy, c.ab.zw) - c.params.x);
        }
        float dn = d / max(palm.params.x, 1.0);
        float lit = 1.0 - smoothstep(u.info.z, u.info.z + u.info.w, dn);
        pool = max(pool, pow(lit, u.size.z) * palm.params.y);
        tight = max(tight, (1.0 - smoothstep(-0.02, 0.01, dn)) * palm.params.y);
    }
    return float2(pool, tight);
}

// MARK: - 2. Coverage

struct MarkInstance {
    float4 centerAxis;  // centre.xy px, axis.xy (unit)
    float4 extent;      // half-length px, half-width px, hand scale px, kind (0 cap, 1 streak, 2 fleck, 3 patch)
    float4 params;      // intensity × fades, hue, grain scale, grain strength
    uint4 seed;         // grain seed, unused…
};

struct CoverageUniforms {
    float4 size;        // buffer width, height, unused, unused
};

struct MarkOut {
    float4 position [[position]];
    float2 local;
    float2 handOffset;
    float kind [[flat]];
    float intensity [[flat]];
    float hue [[flat]];
    float grainScale [[flat]];
    float grainStrength [[flat]];
    uint seed [[flat]];
};

vertex MarkOut markVertex(uint vid [[vertex_id]], uint iid [[instance_id]],
                          constant MarkInstance *marks [[buffer(0)]],
                          constant CoverageUniforms &u [[buffer(1)]]) {
    const float2 corners[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
    MarkInstance m = marks[iid];
    float2 c = corners[vid];
    float2 axis = m.centerAxis.zw;
    float2 perp = float2(-axis.y, axis.x);
    float2 along = c.x * m.extent.x * axis;
    float2 across = c.y * m.extent.y * perp;
    float2 px = m.centerAxis.xy + along + across;

    MarkOut out;
    out.position = float4(px.x / u.size.x * 2.0 - 1.0, 1.0 - px.y / u.size.y * 2.0, 0, 1);
    out.local = c;
    out.handOffset = float2(c.x * m.extent.x, c.y * m.extent.y) / max(m.extent.z, 1.0);
    out.kind = m.extent.w;
    out.intensity = m.params.x;
    out.hue = m.params.y;
    out.grainScale = m.params.z;
    out.grainStrength = m.params.w;
    out.seed = m.seed.x;
    return out;
}

static float markValue(int kind, float2 local, float intensity) {
    float d = length(local);
    if (kind == 0) {
        float2 q = local * local;
        float box = sqrt(sqrt(q.x * q.x + q.y * q.y));
        return intensity * (1.0 - smoothstep(0.8, 1.0, box)) * (0.35 + 0.65 * smoothstep(-1.0, -0.3, local.x));
    }
    if (kind == 1) return intensity * (1.0 - smoothstep(0.3, 1.0, d));
    if (kind == 2) return intensity * (1.0 - smoothstep(0.5, 1.0, d));
    return intensity * (1.0 - smoothstep(0.0, 1.0, d));
}

static float grainHash(int x, int y, uint seed) {
    uint h = (as_type<uint>(x) * 0x8DA6B343u) ^ (as_type<uint>(y) * 0xD8163841u) ^ (seed * 0xCB1AB31Fu);
    h ^= h >> 16;
    h *= 0x7FEB352Du;
    h ^= h >> 15;
    h *= 0x846CA68Bu;
    h ^= h >> 16;
    return float(h >> 8) / float(1 << 24);
}

fragment float2 markFragment(MarkOut in [[stage_in]]) {
    float value = markValue(int(in.kind), in.local, in.intensity);
    int2 cell = int2(floor(in.handOffset / in.grainScale));
    float grain = (1.0 - in.grainStrength) + in.grainStrength * 1.6 * grainHash(cell.x, cell.y, in.seed);
    value *= grain;
    return float2(value, value * in.hue);
}

// MARK: - 3. Final composite

struct FinalUniforms {
    float4 transform;   // buffer uv = screen uv × xy + zw
    float4 flags;       // uvAmount (0 = camera), exposure gain, skin local contrast, skin detail strength
    float4 bloom;       // radius px, intensity, hue jitter, blankAmount (1 = black screen)
    float4 texel;       // 1 / buffer size, lamp channels: room dark, skin (computed on the CPU)
    float4 ramp[4];     // skin ramp, black → dark violet
    float4 palette[4];  // glow palette low → peak
    float4 nail;        // rgb, strength
    float4 background;  // rgb
    float4 tips[10];    // fingertip xy px, radius px, presence
    float4 tipInfo;     // tip count, unused…
};

static float3 rampColor(constant float4 *ramp, float t) {
    float x = clamp(t, 0.0, 1.0) * 3.0;
    int i = min(int(x), 2);
    return mix(ramp[i].rgb, ramp[i + 1].rgb, x - float(i));
}

fragment float4 finalFragment(FullscreenOut in [[stage_in]],
                              constant FinalUniforms &u [[buffer(0)]],
                              texture2d<float> camera [[texture(0)]],
                              texture2d<float> pool [[texture(1)]],
                              texture2d<float> coverage [[texture(2)]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    // Face guard first: black, before any lamp math (002 FR-020).
    if (u.bloom.w >= 1.0) return float4(0, 0, 0, 1);
    float keep = 1.0 - u.bloom.w;

    float2 uv = in.uv * u.transform.xy + u.transform.zw;
    float3 cam = camera.sample(s, uv).rgb;
    if (u.flags.x <= 0.0) return float4(cam * keep, 1);
    // The lamp's channels come from the CPU, so this pass only mixes (002 lamp-transition §3).
    float dark = u.texel.z;
    float skinMix = u.texel.w;

    // Skin under UV: brightness with a light local contrast, mapped onto the violet ramp.
    const float3 lumaWeights = float3(0.299, 0.587, 0.114);
    float luma = dot(cam, lumaWeights);
    float2 t = u.texel.xy * 1.5;
    float blur = 0.25 * (dot(camera.sample(s, uv + float2(t.x, 0)).rgb, lumaWeights)
                       + dot(camera.sample(s, uv - float2(t.x, 0)).rgb, lumaWeights)
                       + dot(camera.sample(s, uv + float2(0, t.y)).rgb, lumaWeights)
                       + dot(camera.sample(s, uv - float2(0, t.y)).rgb, lumaWeights));
    float highPass = luma - blur;
    float skinValue = clamp((luma + u.flags.z * 3.0 * highPass) * u.flags.y, 0.0, 1.0);
    float2 lit = pool.sample(s, uv).rg;
    float3 outside = mix(cam, u.background.rgb, dark);
    float3 inside = mix(cam, rampColor(u.ramp, skinValue), skinMix);
    float3 color = mix(outside, inside, lit.r);

    // Glow coating: only crease-scale detail cuts it, clamped so broad patterns such as henna
    // never print into the glow.
    float2 cov = coverage.sample(s, uv).rg;
    float c = clamp(cov.r, 0.0, 1.0);
    float hue = cov.g / max(cov.r, 1e-4);
    float crease = min(clamp(-highPass * 8.0, 0.0, 1.0), 0.7);
    c *= (1.0 - u.flags.w * crease) * lit.g;

    float bloomSum = 0;
    for (int i = 0; i < 8; i++) {
        float a = float(i) * 0.785398;
        bloomSum += coverage.sample(s, uv + float2(cos(a), sin(a)) * u.bloom.x * u.texel.xy).r;
    }
    float bloom = clamp(bloomSum / 8.0, 0.0, 1.0) * u.bloom.y * lit.g;

    float3 glow = rampColor(u.palette, clamp(c + (hue - 0.5) * u.bloom.z, 0.0, 1.0));
    color = mix(color, glow, smoothstep(0.05, 0.45, c)) + glow * bloom;

    // Real fingernails fluoresce faintly under UV.
    float2 p = uv / u.texel.xy;
    for (int i = 0; i < int(u.tipInfo.x); i++) {
        float4 tip = u.tips[i];
        float falloff = 1.0 - smoothstep(0.0, tip.z, length(p - tip.xy));
        color += u.nail.rgb * u.nail.w * falloff * tip.w * lit.r * skinMix;
    }
    return float4(color * keep, 1);
}
