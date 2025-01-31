Shader "Hidden/Sky"
{
    Properties
    {
        _RayleighScattering ("Rayleigh Scattering", Vector) = (5.802, 13.558, 33.1, 1)
        _RayleighScalarHeight ("Rayleigh Scalar Height", Float) = 8500

        _MieScattering ("Mie Scattering", Vector) = (3.996, 3.996, 3.996, 1)
        _MieAbsorption ("Mie Absorption", Float) = (4.4, 4.4, 4.4, 1)
        _MieAnisotropy ("Mie Anisotropy", Float) = 0.4
        _MieScalarHeight ("Mie Scalar Height", Float) = 1200

        _Samples ("Samples", Integer) = 8
        _PlanetRadius ("Planet Radius", Float) = 6360000
        _AtmosphereThickness ("Atmosphere Thickness", Float) = 60000

        _OzoneAbsorption ("Ozone Absorption", Vector) = (0.650, 1.881, 0.085, 1)
        _OzoneCenter ("Ozone Center", Float) = 25000
        _OzoneThickness ("Ozone Thickness", Float) = 25000

        _ScatterIntensity ("Scatter Intensity", Float) = 0.000001
        _AbsorptionIntensity ("Absorption Intensity", Float) = 0.000001

        _SunRadius ("Sun Radius", Float) = 0.2

        _AerialPerspectiveMaxDist ("Aerial Perspective Max Dist", Float) = 320000
    }

    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always

        Pass
        {
            Name "Ray Marching Atmosphere"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "FullscreenVertex.hlsl"
            #include "SkyCommon.hlsl"
            #include "Math.hlsl"

            float4 frag(VertexOutput input) : SV_Target
            {
                AtmoParams params = GetAtmoParams();
                float3 sunDir = _MainLightPosition.xyz;
                float3 sunColor = _MainLightColor.rgb;
                float3 viewDir = ScreenUvToWorldDir(input.uv);
                float3 viewPos = float3(0, _PlanetRadius + _WorldSpaceCameraPos.y, 0);

                float3 atmo = RayMarchTransmittance(viewPos, viewDir, sunDir, params);
                float3 sun = SunDisk(viewDir, sunDir, sunColor);

                return float4(atmo + sun, 1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "Transmittance Precomputation"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "FullscreenVertex.hlsl"
            #include "SkyCommon.hlsl"

            float4 frag(VertexOutput input) : SV_Target
            {
                AtmoParams params = GetAtmoParams();
                float2 lutParams = ScreenUvToLutParams(input.uv, params);
                float3 viewDir = float3(sqrt(1 - lutParams.y * lutParams.y), lutParams.y, 0);
                float3 viewPos = float3(0, lutParams.x, 0);

                float atmoDist = RayIntersectSphere(0, _PlanetRadius + _AtmosphereThickness, viewPos, viewDir);
                float3 intersection = viewPos + atmoDist * viewDir;

                return float4(Transmittance(viewPos, intersection, _Samples, params), 1);
            }
            ENDHLSL
        }


        Pass
        {
            Name "Multi-Scattering Precomputation"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "FullscreenVertex.hlsl"
            #include "SkyCommon.hlsl"

            float4 frag(VertexOutput input) : SV_Target
            {
                AtmoParams params = GetAtmoParams();
                float sunCosZenithAngle = input.uv.x * 2 - 1;
                float sunSinZenithAngle = SafeSqrt(1 - sunCosZenithAngle * sunCosZenithAngle);
                float3 sunDir = float3(sunSinZenithAngle, sunCosZenithAngle, 0);
                float3 viewPos = float3(0, input.uv.y * _AtmosphereThickness + _PlanetRadius, 0);

                return float4(RayMarchMultiScattering(viewPos, sunDir, params), 1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "Sky View Precomputation"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "FullscreenVertex.hlsl"
            #include "SkyCommon.hlsl"

            float4 frag(VertexOutput input) : SV_Target
            {
                AtmoParams params = GetAtmoParams();
                float3 sunDir = _MainLightPosition.xyz;

                // 0 ~ 2pi
                float phi = input.uv.x * 2 * PI;
                // 0 ~ pi
                float theta = input.uv.y * PI;
                float3 viewDir = PolarToCartesian(float2(phi, theta));
                float3 viewPos = float3(0, _PlanetRadius + _WorldSpaceCameraPos.y, 0);

                return float4(RayMarchSkyView(viewPos, viewDir, sunDir, params), 1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "Sky View Lookup"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "FullscreenVertex.hlsl"
            #include "SkyCommon.hlsl"

            float4 frag(VertexOutput input) : SV_Target
            {
                float3 sunDir = _MainLightPosition.xyz;
                float3 sunColor = _MainLightColor.rgb;
                float3 viewDir = ScreenUvToWorldDir(input.uv);

                float3 atmo = LookupSkyView(viewDir) * sunColor;
                float3 sun = SunDisk(viewDir, sunDir, sunColor);

                return float4(atmo + sun, 1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "Ray Marching Sky View"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "FullscreenVertex.hlsl"
            #include "SkyCommon.hlsl"
            #include "Math.hlsl"

            float4 frag(VertexOutput input) : SV_Target
            {
                AtmoParams params = GetAtmoParams();
                float3 sunDir = _MainLightPosition.xyz;
                float3 sunColor = _MainLightColor.rgb;
                float3 viewDir = ScreenUvToWorldDir(input.uv);
                float3 viewPos = float3(0, _PlanetRadius + _WorldSpaceCameraPos.y, 0);

                float3 atmo = RayMarchSkyView(viewPos, viewDir, sunDir, params) * sunColor;
                float3 sun = SunDisk(viewDir, sunDir, sunColor);

                return float4(atmo + sun, 1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "Aerial Perspective Precomputation"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "FullscreenVertex.hlsl"
            #include "SkyCommon.hlsl"
            #include "Math.hlsl"

            float4 frag(VertexOutput input) : SV_Target
            {
                const int VOXEL_CNT = 32;

                float texelX = input.uv.x * VOXEL_CNT * VOXEL_CNT;
                float texelY = input.uv.y * VOXEL_CNT;

                float voxelX = fmod(texelX, VOXEL_CNT);
                float voxelY = texelY;
                float voxelZ = texelX / VOXEL_CNT;

                AtmoParams params = GetAtmoParams();
                float3 sunDir = _MainLightPosition.xyz;
                float3 sunColor = _MainLightColor.rgb;
                float3 viewDir = ScreenUvToWorldDir(float2(voxelX, voxelY) / VOXEL_CNT);
                float3 viewPos = float3(0, _PlanetRadius + _WorldSpaceCameraPos.y, 0);

                float voxelDist = _AerialPerspectiveMaxDist * (voxelZ / VOXEL_CNT);
                float3 voxelPos = viewPos + viewDir * voxelDist;

                float3 sky = RayMarchSkyView(viewPos, viewDir, sunDir, params, voxelDist) * sunColor;
                float3 transmittanceEye = LookupTransmittanceToAtmosphere(viewPos, sunDir, params);
                float3 transmittanceVoxel = LookupTransmittanceToAtmosphere(voxelPos, sunDir, params);
                float3 transmittance = transmittanceEye / transmittanceVoxel;

                return float4(sky, dot(transmittance, 1.0 / 3.0));
            }
            ENDHLSL
        }

        Pass
        {
            Name "Aerial Perspective Lookup"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/GlobalSamplers.hlsl"
            #include "FullscreenVertex.hlsl"
            #include "SkyCommon.hlsl"

            float4 frag(VertexOutput input) : SV_Target
            {
                const int VOXEL_CNT = 32;

                float3 sceneColor = SampleSceneColor(input.uv).rgb;
                float depth = SampleSceneDepth(input.uv);
                if (depth == 0.0) return float4(sceneColor, 1);
                float z = Linear01Depth(depth, _ZBufferParams);

                float voxelZFloor = floor(z * VOXEL_CNT);
                float voxelZCeil = ceil(z * VOXEL_CNT);

                float sampleXFloor = input.uv.x / VOXEL_CNT + voxelZFloor / VOXEL_CNT;
                float sampleXCeil = input.uv.x / VOXEL_CNT + voxelZCeil / VOXEL_CNT;
                float sampleY = input.uv.y;

                float4 persp = lerp(
                    SAMPLE_TEXTURE2D(_AerialPerspectiveLut, sampler_LinearClamp, float2(sampleXFloor, sampleY)),
                    SAMPLE_TEXTURE2D(_AerialPerspectiveLut, sampler_LinearClamp, float2(sampleXCeil, sampleY)),
                    frac(z * VOXEL_CNT)
                );

                return float4(sceneColor * persp.a + persp.rgb, 1);
            }
            ENDHLSL
        }
    }
}