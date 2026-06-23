#include <metal_stdlib>
using namespace metal;

struct VSOut {
    float4 position [[position]];
    float2 uv;
};

fragment float4 vintageBWFragment(VSOut in [[stage_in]],
                                  texture2d<float> source [[texture(0)]]) {
    constexpr sampler s(filter::linear);
    float4 color = source.sample(s, in.uv);

    // Rec. 709 luma
    float luma = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));

    // Lift blacks — faded film stock look
    luma = luma * 0.85 + 0.07;

    // Vignette
    float2 d = in.uv - 0.5;
    float vignette = clamp(1.0 - dot(d, d) * 2.2, 0.0, 1.0);
    luma *= vignette;

    // Static film grain
    float2 seed = floor(in.uv * float2(1080.0, 1920.0));
    float grain = fract(sin(dot(seed, float2(127.1, 311.7))) * 43758.5453) - 0.5;
    luma = clamp(luma + grain * 0.04, 0.0, 1.0);

    return float4(luma, luma, luma, color.a);
}
