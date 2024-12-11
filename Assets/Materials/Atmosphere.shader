Shader "Hidden/RayMarchingAtmosphere"
{
    Properties
    {
        _RayleighScattering("Rayleigh Scattering", Vector) = (5.802, 13.558, 33.1, 1)
        _RayleighScalarHeight("Rayleigh Scalar Height", Float) = 8500

        _MieScattering("Mie Scattering", Vector) = (3.996, 3.996, 3.996, 1)
        _MieAbsorption("Mie Absorption", Float) = (4.4, 4.4, 4.4, 1)
        _MieAnisotropy("Mie Anisotropy", Float) = 0.4
        _MieScalarHeight("Mie Scalar Height", Float) = 1200

        _Samples("Samples", Integer) = 8
        _PlanetRadius("Planet Radius", Float) = 6360000
        _AtmosphereThickness("Atmosphere Thickness", Float) = 60000

        _OzoneAbsorption("Ozone Absorption", Vector) = (0.650, 1.881, 0.085, 1)
        _OzoneCenter("Ozone Center", Float) = 25000
        _OzoneThickness("Ozone Thickness", Float) = 25000

        _ScatterIntensity("Scatter Intensity", Float) = 0.000001
        _AbsorptionIntensity("Absorption Intensity", Float) = 0.000001

        _SunRadius("Sun Radius", Float) = 0.2
    }

    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always

        // 0
        Pass
        {
            Name "Ray Marching Atmosphere"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "FullscreenVertex.hlsl"
            #include "AtmosphereCommon.hlsl"
            #include "Math.hlsl"

            float4 frag(VertexOutput input) : SV_Target
            {
                AtmoParams params = GetAtmoParams();
                Light sun = GetMainLight();
                float3 viewDir = ScreenUvToWorldDir(input.uv);
                float3 viewPos = float3(0, _PlanetRadius, 0);

                if (dot(viewDir, sun.direction) > 1 - _SunRadius && viewDir.y > 0)
                {
                    return float4(sun.color, 1);
                }

                return float4(RayMarchTransmittance(viewPos, viewDir, sun.direction, sun.color, params), 1);
            }
            ENDHLSL
        }

        // 1
        Pass
        {
            Name "Transmittance Precomputation"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "FullscreenVertex.hlsl"
            #include "AtmosphereCommon.hlsl"

            float4 frag(VertexOutput input) : SV_Target
            {
                AtmoParams params = GetAtmoParams();
                float2 lutParams = ScreenUvToLutParams(input.uv, params);
                float3 viewDir = float3(sqrt(1 - lutParams.y * lutParams.y), lutParams.y, 0);
                float3 viewPos = float3(0, lutParams.x, 0);

                float atmoDist = RayIntersectSphere(0, params.atmoThickness + params.planetRadius, viewPos, viewDir);
                float3 intersection = viewPos + atmoDist * viewDir;

                return float4(Transmittance(viewPos, intersection, _Samples, params), 1);
            }
            ENDHLSL
        }

        // 2
        Pass
        {
            Name "Sky View Precomputation"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "FullscreenVertex.hlsl"
            #include "AtmosphereCommon.hlsl"

            float4 frag(VertexOutput input) : SV_Target
            {
                AtmoParams params = GetAtmoParams();
                float3 sunDir = _MainLightPosition.xyz;
                float3 sunColor = _MainLightColor.rgb;

                // -pi ~ pi
                float phi = (input.uv.x * 2 - 1) * PI;
                // -pi/2 ~ pi/2
                float theta = (1 - input.uv.y) * PI;
                float3 viewDir = PolarToCartesian(float2(phi, theta));
                float3 viewPos = float3(0, _PlanetRadius, 0);

                return float4(RayMarchSkyView(viewPos, viewDir, sunDir, sunColor, params), 1);
            }
            ENDHLSL
        }

        // 3
        Pass
        {
            Name "Sky View Lookup"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "FullscreenVertex.hlsl"
            #include "AtmosphereCommon.hlsl"

            float4 frag(VertexOutput input) : SV_Target
            {
                float3 sunDir = _MainLightPosition.xyz;
                float3 sunColor = _MainLightColor.rgb;
                float3 viewDir = ScreenUvToWorldDir(input.uv);

                if (dot(viewDir, sunDir) > 1 - _SunRadius && viewDir.y > 0)
                {
                    return float4(sunColor, 1);
                }

                return float4(LookupSkyView(viewDir), 1);
            }
            ENDHLSL
        }

        // 4
        Pass
        {
            Name "Ray Marching Sky View"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "FullscreenVertex.hlsl"
            #include "AtmosphereCommon.hlsl"
            #include "Math.hlsl"

            float3 SunDisk(float3 viewDir, float3 sunDir, float3 sunColor)
            {
                if (dot(viewDir, sunDir) > 1 - _SunRadius && viewDir.y > -0.05)
                {
                    return float4(sunColor, 1);
                }
                return 0;
            }

            float4 frag(VertexOutput input) : SV_Target
            {
                AtmoParams params = GetAtmoParams();
                float3 sunDir = _MainLightPosition.xyz;
                float3 sunColor = _MainLightColor.rgb;
                float3 viewDir = ScreenUvToWorldDir(input.uv);
                float3 viewPos = float3(0, _PlanetRadius, 0);

                float3 atmo = RayMarchSkyView(viewPos, viewDir, sunDir, sunColor, params);
                float3 sun = SunDisk(viewDir, sunDir, sunColor);

                return float4(atmo + sun, 1);
            }
            ENDHLSL
        }
    }
}