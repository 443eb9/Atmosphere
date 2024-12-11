#ifdef ATMOSPHERE_COMMON_INCLUDE
#else
#define ATMOSPHERE_COMMON_INCLUDE

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Macros.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/GlobalSamplers.hlsl"
#include "Math.hlsl"

float4 _RayleighScattering;
float _RayleighScalarHeight;

float4 _MieScattering;
float4 _MieAbsorption;
float _MieScalarHeight;
float _MieAnisotropy;

int _Samples;
float _PlanetRadius;
float _AtmosphereThickness;

float3 _OzoneAbsorption;
float _OzoneCenter;
float _OzoneThickness;

float _ScatterIntensity;
float _AbsorptionIntensity;
float _SunRadius;

TEXTURE2D(_TransmittanceLut);
TEXTURE2D(_SkyViewLut);

struct AtmoParams
{
    float planetRadius, atmoThickness, mieScalarHeight, rayleighScalarHeight, mieG, ozoneCenter, ozoneThickness;
    float3 mieScatter, rayleighScatter, mieAbsorption, ozoneAbsorption;
};

AtmoParams GetAtmoParams()
{
    AtmoParams params;
    params.planetRadius = _PlanetRadius;
    params.atmoThickness = _AtmosphereThickness;
    params.rayleighScalarHeight = _RayleighScalarHeight;
    params.mieScalarHeight = _MieScalarHeight;
    params.mieAbsorption = _MieAbsorption.rgb * _AbsorptionIntensity;
    params.rayleighScatter = _RayleighScattering.rgb * _ScatterIntensity;
    params.mieScatter = _MieScattering.rgb * _ScatterIntensity;
    params.mieG = _MieAnisotropy;
    params.ozoneAbsorption = _OzoneAbsorption.rgb * _AbsorptionIntensity;
    params.ozoneCenter = _OzoneCenter;
    params.ozoneThickness = _OzoneThickness;
    return params;
}

float RayleighPhase(float cosTheta)
{
    return 3.0 / 16 * PI * (1.0 + cosTheta * cosTheta);
}

float MiePhaseHG(float g, float cosTheta)
{
    return (1.0 - g * g) / (4.0 * PI * pow(max(0, 1.0 + g * g - 2.0 * g * cosTheta), 1.5));
}

float SchlickKFromG(float g)
{
    return 1.55 * g - 0.55 * g * g * g;
}

float MiePhaseSchlick(float k, float cosTheta)
{
    float t = 1.0 + k * cosTheta;
    return (1.0 - k * k) / (4.0 * PI * t * t);
}

float Attenuation(float h, float scalarH)
{
    return exp(-h / scalarH);
}

float3 RayleighScattering(float h, AtmoParams params)
{
    float rho = Attenuation(h, params.rayleighScalarHeight);
    return params.rayleighScatter * rho;
}

float3 MieScattering(float h, AtmoParams params)
{
    float rho = Attenuation(h, params.mieScalarHeight);
    return params.mieScatter * rho;
}

float3 MieAbsorption(float h, AtmoParams params)
{
    float rho = Attenuation(h, params.mieScalarHeight);
    return params.mieAbsorption * rho;
}

float3 OzoneAbsorption(float h, AtmoParams params)
{
    float rho = max(0, 1 - abs(h - params.ozoneCenter) / params.ozoneThickness);
    return params.ozoneAbsorption * rho;
}

float3 Scattering(float3 p, float3 in_dir, float3 out_dir, in AtmoParams params)
{
    float cosTheta = dot(in_dir, out_dir);
    float h = length(p) - params.planetRadius;

    float attenRayleigh = Attenuation(h, params.rayleighScalarHeight);
    float attenMie = Attenuation(h, params.mieScalarHeight);
    float3 rayleighColor = attenRayleigh * RayleighPhase(cosTheta) * params.rayleighScatter;
    float3 mieColor = attenMie * MiePhaseHG(params.mieG, cosTheta) * params.mieScatter;

    return rayleighColor + mieColor;
}

float3 Transmittance(float3 p1, float3 p2, int samples, in AtmoParams params)
{
    float3 delta = p2 - p1;
    float ds = length(delta) / float(samples);
    float3 acc = 0;

    for (int i = 0; i < samples; i++)
    {
        float3 p = lerp(p1, p2, (float(i) + 0.5) / samples);
        float h = length(p) - params.planetRadius;

        float3 scatter = RayleighScattering(h, params) + MieScattering(h, params);
        float3 absorption = OzoneAbsorption(h, params) + MieAbsorption(h, params);
        float3 extinction = scatter + absorption;

        acc += extinction * ds;
    }

    return exp(-acc);
}

/// Returns [
///     distance between sample point and planet center,
///     cosine angle between light direction and up vector
/// ]
float2 ScreenUvToLutParams(float2 uv, in AtmoParams params)
{
    // Interpolation coefficients
    float dCoeff = uv.x;
    float rCoeff = uv.y;

    float bodyRadius = params.planetRadius + params.atmoThickness;

    float H = SafeSqrt(bodyRadius * bodyRadius - params.planetRadius * params.planetRadius);
    float rho = rCoeff * H;
    float r = SafeSqrt(rho * rho + params.planetRadius * params.planetRadius);

    float dMin = bodyRadius - r;
    float dMax = rho + H;
    float d = lerp(dMin, dMax, dCoeff);
    float mu = (H * H - rho * rho - d * d) / (2 * r * d);
    mu = clamp(mu, -1, 1);

    return float2(r, mu);
}

/// lutParams = [
///     distance between sample point and planet center,
///     cosine of angle between light direction and up vector
/// ]
float2 LutParamsToLutUv(float2 lutParams, in AtmoParams params)
{
    float r = lutParams.x;
    float mu = lutParams.y;

    float bodyRadius = params.planetRadius + params.atmoThickness;

    float H = SafeSqrt(bodyRadius * bodyRadius - params.planetRadius * params.planetRadius);
    float rho = SafeSqrt(r * r - params.planetRadius * params.planetRadius);

    float dMin = bodyRadius - r;
    float dMax = rho + H;
    float discriminant = r * r * (mu * mu - 1) + bodyRadius * bodyRadius;
    float d = max(0, -r * mu + SafeSqrt(discriminant));

    return float2((d - dMin) / (dMax - dMin), rho / H);
}

float3 RayMarchTransmittance(float3 viewPos, float3 viewDir, float3 sunDir, float3 sunColor, in AtmoParams params)
{
    float ds = _AtmosphereThickness / _Samples;
    float viewAtmoDist = RayIntersectSphere(0, _PlanetRadius + _AtmosphereThickness, viewPos, viewDir);
    float3 viewAtmoIntersection = viewPos + viewAtmoDist * viewDir;

    float3 sum = 0;

    for (int i = 0; i < _Samples; i++)
    {
        float3 p1 = lerp(viewPos, viewAtmoIntersection, (float(i) + 0.5) / _Samples);
        float3 sampleAtmoDist = RayIntersectSphere(0, _PlanetRadius + _AtmosphereThickness, p1, sunDir);
        float3 p2 = p1 + sunDir * sampleAtmoDist;

        float3 t1 = Transmittance(p1, p2, _Samples, params);
        float3 s = Scattering(p1, sunDir, viewDir, params);
        float3 t2 = Transmittance(p1, viewPos, _Samples, params);

        float3 in_scattering = t1 * s * t2 * ds * sunColor;
        sum += in_scattering;
    }

    return sum;
}

float3 LookupTransmittance(float3 viewPos, float3 sunDir, in AtmoParams params)
{
    float2 uv = LutParamsToLutUv(float2(length(viewPos), sunDir.y), params);
    return _TransmittanceLut.SampleLevel(sampler_LinearClamp, uv, 0).rgb;
}

float3 RayMarchSkyView(float3 viewPos, float3 viewDir, float3 sunDir, float3 sunColor, in AtmoParams params)
{
    float ds = _AtmosphereThickness / _Samples;
    float viewAtmoDist = RayIntersectSphere(0, _PlanetRadius + _AtmosphereThickness, viewPos, viewDir);
    float3 viewAtmoIntersection = viewPos + viewAtmoDist * viewDir;

    float3 sum = 0;
    float3 opticalDepth = 0;

    for (int i = 0; i < _Samples; i++)
    {
        float3 p1 = lerp(viewPos, viewAtmoIntersection, (float(i) + 0.5) / _Samples);

        float h = length(p1) - params.planetRadius;
        float3 scatter = RayleighScattering(h, params) + MieScattering(h, params);
        float3 absorption = OzoneAbsorption(h, params) + MieAbsorption(h, params);
        float3 extinction = scatter + absorption;
        opticalDepth += extinction * ds;

        float3 t1 = LookupTransmittance(p1, sunDir, params);
        float3 s = Scattering(p1, sunDir, viewDir, params);
        float3 t2 = exp(-opticalDepth);

        float3 in_scattering = t1 * s * t2 * ds * sunColor;
        sum += in_scattering;
    }

    return sum;
}

float3 LookupSkyView(float3 viewDir)
{
    float2 polar = CartesianToPolar(viewDir) / float2(2 * PI, PI);
    polar.y = 1 - polar.y;
    polar.x += 0.5;

    return _SkyViewLut.Sample(sampler_LinearRepeat, polar).rgb;
}

#endif
