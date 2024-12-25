using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class Atmosphere : ScriptableRendererFeature
{
    public enum AtmosphereComputation
    {
        BruteForceRayMarching,
        PrecomputedTransmittance,
        PrecomputedSkyView,
    }

    public enum PassIndices
    {
        RayMarchingAtmosphere,
        TransmittancePrecomputation,
        MultiScatteringPrecomputation,
        SkyViewPrecomputation,
        SkyViewLookup,
        RayMarchingSkyView,
        AerialPerspectivePrecomputation,
        AerialPerspectiveLookup,
    }

    public class PassNames
    {
        public const string RayMarchingAtmosphere = "Ray Marching Atmosphere";
        public const string TransmittancePrecomputation = "Transmittance Precomputation";
        public const string MultiScatteringPrecomputation = "Multi-Scattering Precomputation";
        public const string SkyViewPrecomputation = "Sky View Precomputation";
        public const string SkyViewLookup = "Sky View Lookup";
        public const string RayMarchingSkyView = "Ray Marching Sky View";
        public const string AerialPerspectivePrecomputation = "Aerial Perspective Precomputation";
        public const string AerialPerspectiveLookup = "Aerial Perspective Lookup";
    }

    public class ShaderProps
    {
        public static int TransmittanceLut = Shader.PropertyToID("_TransmittanceLut");
        public static int MultiScatteringLut = Shader.PropertyToID("_MultiScatteringLut");
        public static int SkyViewLut = Shader.PropertyToID("_SkyViewLut");
        public static int AerialPerspectiveLut = Shader.PropertyToID("_AerialPerspectiveLut");
    }

    public class DummyPassData
    {
    }

    private AtmospherePass _atmoPass;
    private AerialPerspectivePass _aerialPass;

    public Material material;

    public override void Create()
    {
        _atmoPass = new AtmospherePass(material, RenderPassEvent.BeforeRenderingShadows);
        _aerialPass = new AerialPerspectivePass(material, RenderPassEvent.AfterRenderingPostProcessing);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(_atmoPass);
        renderer.EnqueuePass(_aerialPass);
    }
}