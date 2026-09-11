#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float objectY;
};

vertex VertexOut bend_vertex(uint vertexID [[vertex_id]],
                              constant float3 *positions [[buffer(0)]],
                              constant float2 *texCoords [[buffer(1)]],
                              constant float4x4 &mvp [[buffer(2)]]) {
    VertexOut out;
    float3 position = positions[vertexID];
    out.position = mvp * float4(position, 1.0);
    out.texCoord = texCoords[vertexID];
    out.objectY = position.y;
    return out;
}

float3 desaturate(float3 color, float amount) {
    float luminance = dot(color, float3(0.299, 0.587, 0.114));
    return mix(color, float3(luminance), saturate(amount));
}

struct FragmentUniforms {
    float shadeAmount;
    float desaturation;
};

fragment float4 bend_fragment(VertexOut in [[stage_in]],
                               texture2d<float> sharpTexture [[texture(0)]],
                               texture2d<float> blurredTexture [[texture(1)]],
                               sampler textureSampler [[sampler(0)]],
                               constant FragmentUniforms &uniforms [[buffer(0)]]) {
    float hingeToFar = (in.objectY + 1.0) * 0.5;

    float4 sharp = sharpTexture.sample(textureSampler, in.texCoord);
    float4 blurred = blurredTexture.sample(textureSampler, in.texCoord);
    float4 color = mix(sharp, blurred, saturate(hingeToFar));

    float3 desaturated = desaturate(color.rgb, uniforms.desaturation * hingeToFar);
    float localShade = saturate(uniforms.shadeAmount * mix(0.15, 1.0, hingeToFar));
    float3 shaded = desaturated * (1.0 - localShade);

    return float4(shaded, color.a);
}

struct BackgroundUniforms {
    float alpha;
};

fragment float4 background_fragment(VertexOut in [[stage_in]],
                                     constant BackgroundUniforms &uniforms [[buffer(0)]]) {
    return float4(0.0, 0.0, 0.0, saturate(uniforms.alpha));
}
