#ifdef MATH_INCLUDE
#else
#define MATH_INCLUDE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"

float RayIntersectSphere(float3 center, float radius, float3 rayStart, float3 rayDir)
{
    float OS = length(center - rayStart);
    float SH = dot(center - rayStart, rayDir);
    float OH = sqrt(OS * OS - SH * SH);
    float PH = sqrt(radius * radius - OH * OH);

    // ray miss sphere
    if (OH > radius) return -1;

    // use min distance
    float t1 = SH - PH;
    float t2 = SH + PH;
    float t = (t1 < 0) ? t2 : t1;

    return t;
}

float3 ScreenUvToWorldDir(float2 uv)
{
    float2 ndc = (uv * 2 - 1) * float2(1, -1);
    float4 clip = mul(unity_MatrixInvP, float4(ndc, 1, 1));
    float3 world_dir = mul(unity_MatrixInvV, float4(clip.xyz / clip.w, 0)).xyz;
    return normalize(world_dir);
}

/// [phi, theta]
float3 PolarToCartesian(float2 polar)
{
    float sinTheta = sin(polar.y);
    float x = sinTheta * cos(polar.x);
    float z = sinTheta * sin(polar.x);
    float y = cos(polar.y);

    return float3(x, y, z);
}

/// [phi, theta]
float2 CartesianToPolar(float3 dir)
{
    return float2(FastAtan2(dir.z, dir.x), FastACos(dir.y));
}

float3 UVToViewDir(float2 uv)
{
    float theta = (1.0 - uv.y) * PI;
    float phi = (uv.x * 2 - 1) * PI;

    float x = sin(theta) * cos(phi);
    float z = sin(theta) * sin(phi);
    float y = cos(theta);

    return float3(x, y, z);
}

float2 ViewDirToUV(float3 v)
{
    float2 uv = float2(atan2(v.z, v.x), asin(v.y));
    uv /= float2(2.0 * PI, PI);
    uv += float2(0.5, 0.5);

    return uv;
}

#endif
