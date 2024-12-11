#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

struct VertexInput
{
    uint vertex_id : SV_VertexID;
};

struct VertexOutput
{
    float2 uv : TEXCOORD0;
    float4 vertex : SV_POSITION;
};

VertexOutput vert(VertexInput input)
{
    VertexOutput output;
    output.vertex = GetFullScreenTriangleVertexPosition(input.vertex_id);
    output.uv = GetFullScreenTriangleTexCoord(input.vertex_id);
    return output;
}
