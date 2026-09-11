#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut bend_vertex(uint vertexID [[vertex_id]],
                              constant float3 *positions [[buffer(0)]],
                              constant float2 *texCoords [[buffer(1)]],
                              constant float4x4 &mvp [[buffer(2)]]) {
    VertexOut out;
    out.position = mvp * float4(positions[vertexID], 1.0);
    out.texCoord = texCoords[vertexID];
    return out;
}

struct FragmentUniforms {
    float shadeAmount;
    float desaturation;
};

fragment float4 bend_fragment(VertexOut in [[stage_in]],
                               texture2d<float> desktopTexture [[texture(0)]],
                               sampler textureSampler [[sampler(0)]],
                               constant FragmentUniforms &uniforms [[buffer(0)]]) {
    float4 color = desktopTexture.sample(textureSampler, in.texCoord);
    float luminance = dot(color.rgb, float3(0.299, 0.587, 0.114));
    float3 desaturated = mix(color.rgb, float3(luminance), uniforms.desaturation);
    float3 shaded = desaturated * (1.0 - uniforms.shadeAmount);
    return float4(shaded, color.a);
}
