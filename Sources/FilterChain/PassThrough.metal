#include <metal_stdlib>
using namespace metal;

struct VSOut {
    float4 position [[position]];
    float2 uv;
};

vertex VSOut passThroughVertex(uint vid [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -3.0),
        float2(-1.0,  1.0),
        float2( 3.0,  1.0)
    };
    float2 uvs[3] = {
        float2(0.0, 2.0),
        float2(0.0, 0.0),
        float2(2.0, 0.0)
    };
    VSOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = uvs[vid];
    return out;
}

fragment float4 passThroughFragment(VSOut in [[stage_in]],
                                    texture2d<float> source [[texture(0)]]) {
    constexpr sampler s(filter::linear);
    return source.sample(s, in.uv);
}
